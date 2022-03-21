import 'dart:async';
import 'dart:collection';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' if (dart.library.io) '../compat/worker_stub.dart';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kafka/kafka.dart'
    if (dart.library.js) '../compat/kafka_stub.dart';
import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_vehicle_simulator/server.dart';
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

enum VehicleSimulatorCommands {
  Start,
  Stop,
  Update,
}

/// Vehicle Simulator base class.
class VehicleSimulator extends ChangeNotifier {
  // Vehicle Events Web Worker
  Worker? _eventWorker;

  // Vehicle Events Isolate
  Isolate? _eventIsolate;

  // HTTP Server SendPort
  SendPort? _serverSendPort;

  final simulatorReceivePort = ReceivePort();
  final notificationModel = VehicleNotificationModel();
  final webhookModel = WebhookModel();
  final eventInjector = EventInjectorModel();
  final SimulatorHttpServer? simulatorHttpServer;

  VehicleSimulator({this.simulatorHttpServer}) {
    initVehicleInfo(info);
    initVehicleState(state);
    journey.autoID = info.autoID;
    journey.driverID = info.driverID;
    _writeConsoleMessage('Waiting for simulator to start..');
  }

  // HTTP Server for optional REST API
  HttpServer? httpServer;

  // API Client for optional backend connectivity
  knowgo.ApiClient? apiClient;

  // MQTT client for optional MQTT broker connectivity
  MqttServerClient? mqttClient;

  // Kafka client for optional Kafka broker connectivity
  Producer? kafkaProducer;

  // Information about the generated Vehicle
  knowgo.Auto info = knowgo.Auto()..transmission = 'manual';

  // The current Journey the Vehicle is on
  knowgo.Journey journey = knowgo.Journey();

  // The current state of the Vehicle
  knowgo.Event state = knowgo.Event();

  // Stream of generated vehicle events
  final streamController = StreamController<knowgo.Event>.broadcast();
  Stream<knowgo.Event> get eventStream =>
      streamController.stream.asBroadcastStream();

  // Queued events to insert into simulation model
  Queue eventQueue = Queue();

  // Free-running event counter for generating event IDs
  static int _eventCounter = 0;

  // Simulator state
  bool running = false;

  void _writeConsoleMessage(String msg) {
    // As VehicleSimulator may be instantiated in separate isolates,
    // make sure that the service in the main isolate is reachable.
    if (serviceLocator.isRegistered<ConsoleService>() == false) {
      return;
    }
    var _consoleService = serviceLocator.get<ConsoleService>();
    _consoleService.write(msg);
  }

  Future<void> initHttpSync() async {
    simulatorReceivePort.listen((data) {
      if (data is SendPort) {
        _serverSendPort = data;
        _serverSendPort?.send([info, state, null]);
      } else {
        // Handle updates to the simulator from the HTTP Server
        var command = data[0];
        switch (command) {
          case VehicleSimulatorCommands.Start:
            start();
            break;
          case VehicleSimulatorCommands.Stop:
            stop();
            break;
          case VehicleSimulatorCommands.Update:
            update(data[1]);
            break;
        }
      }
    });
  }

  void initMqttConnection() async {
    var _settingsService = serviceLocator.get<SettingsService>();

    if (_settingsService.mqttEnabled == false) {
      return;
    }

    var hostPortPair = _settingsService.mqttBroker?.split(':');

    mqttClient = MqttServerClient.withPort(hostPortPair?[0],
        'knowgo-simulator-desktop', int.parse(hostPortPair![1]));

    try {
      var _status = await mqttClient?.connect();
      if (_status?.state == MqttConnectionState.connected) {
        _writeConsoleMessage('MQTT client connected to broker @ ' +
            _settingsService.mqttBroker! +
            '/' +
            _settingsService.mqttTopic!);
      }
    } catch (e) {
      _writeConsoleMessage('Unable to connect to MQTT broker: $e');
      mqttClient = null;
    }
  }

  void _dispatchEventUpdate(knowgo.Event update) {
    var _consoleService = serviceLocator.get<ConsoleService>();
    var _settingsService = serviceLocator.get<SettingsService>();

    // Sync the event counter
    _eventCounter++;

    // Dequeue a pending event and combine it with the incoming update
    if (eventQueue.isNotEmpty) {
      var queuedEvent = eventQueue.removeFirst();
      updateVehicleState(update, queuedEvent);
    }

    // Synchronize vehicle state
    info.odometer = num.parse((update.odometer).toStringAsFixed(2)).toDouble();

    // Process any webhooks
    if (journey.events.length > 0) {
      webhookModel.processWebhooks(info, journey.events.last, update);
    } else {
      webhookModel.processWebhooks(info, state, update);
    }

    // Update vehicle state
    updateVehicleState(state, update);

    // Check if we need to reset the journey
    if (journey.journeyID == null) {
      var generator = VehicleDataGenerator();

      journey.journeyID = generator.journeyId();
      journey.journeyBegin = DateTime.now();
      journey.odometerBegin = info.odometer;
      journey.events = [];
    }

    // Add to event list
    journey.events.add(update);

    // Push it out to any stream subscribers on the main isolate
    streamController.sink.add(update);

    // Log event to console
    if (_settingsService.eventLoggingEnabled) {
      _consoleService.write(update.toString());
    }

    // Dispatch event to notification endpoint asynchronously
    if (_settingsService.notificationEndpoint != null) {
      final url = Uri.parse(_settingsService.notificationEndpoint!);
      http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(update));
    }

    // Dispatch event to KnowGo backend asynchronously
    if (apiClient != null) {
      knowgo.EventsApi(apiClient).addEvent(update).catchError((e) {});
    }

    // Dispatch event to MQTT broker asynchronously
    if (mqttClient != null) {
      update.toJson().forEach((key, value) {
        // Skip creating ID sub-topics
        if (key == 'EventID' || key == 'AutoID') {
          return;
        }

        final builder = MqttClientPayloadBuilder();
        builder.addString(value.toString());
        mqttClient?.publishMessage(
            _settingsService.mqttTopic! + '/vehicle${update.autoID}/$key',
            MqttQos.exactlyOnce,
            builder.payload,
            retain: false);
      });
    }

    // Dispatch event to Kafka topic asynchronously
    if (kafkaProducer != null) {
      // Use the vehicle ID as the key
      var record = ProducerRecord(_settingsService.kafkaTopic, 0,
          info.autoID.toString(), update.toJson().toString());
      kafkaProducer?.add(record);
    }

    // Auto-stop the vehicle if the current event would render the vehicle
    // out of fuel.
    if (state.fuelLevel <= 0) {
      _writeConsoleMessage('Vehicle is out of fuel, stopping..');
      stop();
    }
  }

  // In the Flutter web case, isolates are not supported, and so the vehicle
  // event loop must be run in a dedicated web worker instead.
  void _startWebWorkers() {
    _eventWorker = Worker('lib/simulator/vehicle_event_worker.js');

    // Listen for event updates
    _eventWorker?.onMessage.listen((msg) {
      var map = Map<String, dynamic>.from(msg.data);
      var update = knowgo.Event.fromJson(map);
      _dispatchEventUpdate(update);
      notifyListeners();
    });

    // Kick-off the web worker
    _eventWorker
        ?.postMessage([jsonEncode(info), _eventCounter, jsonEncode(state)]);
  }

  // The Vehicle Simulator uses a pair of Send/ReceivePorts in order to
  // enable bi-directional communication with the event isolate. As we can not
  // share memory directly between the main and event isolates, we instead have
  // to rely on message passing, and so pass through a snapshot of the vehicle
  // state to the event isolate and then wait to receive back event updates
  // derived from this state. Vehicle events in the main isolate are then
  // updated on receipt of periodic messages from the event isolate.
  Future<void> _startIsolates() async {
    var _receivePort = ReceivePort();
    SendPort _sendPort;

    // Spawn the event isolate
    _eventIsolate =
        await Isolate.spawn(vehicleEventLoop, _receivePort.sendPort);

    _receivePort.listen((data) {
      // Wait for the event isolate to open up a ReceivePort and then send
      // through reference to the current vehicle info, last eventID and state.
      if (data is SendPort) {
        _sendPort = data;
        _sendPort.send([info, _eventCounter++, state]);
      } else {
        // Dispatch any received event updates from the event isolate
        _dispatchEventUpdate(data);

        // Synchronize the HTTP server state
        _serverSendPort?.send([info, state, journey.events]);

        // Trigger UI redraw
        notifyListeners();
      }
    });
  }

  Future<void> start({bool notify = true}) async {
    var _settingsService = serviceLocator.get<SettingsService>();

    // Nothing to do if the simulator is already running
    if (running == true) {
      return;
    } else {
      // Update the simulator state
      running = true;
      if (notify) {
        _writeConsoleMessage('Starting vehicle');
      }
    }

    // Init API client connection
    if (_settingsService.knowgoServer != null) {
      apiClient = knowgo.ApiClient(basePath: _settingsService.knowgoServer);
      if (_settingsService.knowgoApiKey != null) {
        apiClient?.addDefaultHeader('X-API-Key', _settingsService.knowgoApiKey);
      }
    }

    // Init MQTT client
    if (_settingsService.mqttEnabled) {
      initMqttConnection();
    }

    // Init Kafka producer
    if (_settingsService.kafkaEnabled) {
      var kafkaConfig =
          ProducerConfig(bootstrapServers: [_settingsService.kafkaBroker!]);
      kafkaProducer = Producer<String, String>(
          StringSerializer(), StringSerializer(), kafkaConfig);
    }

    if (notify) {
      // Update ignition status
      knowgo.Event prevState = knowgo.Event.fromJson(state.toJson());
      prevState.ignitionStatus = knowgo.IgnitionStatus.off;
      if (info.transmission == 'automatic') {
        state.transmissionGearPosition = knowgo.TransmissionGearPosition.first;
      }
      state.ignitionStatus = knowgo.IgnitionStatus.run;
      state.timestamp = DateTime.now();
      webhookModel.processWebhooks(info, prevState, state);
    }

    // Kick-off the event injection timers
    if (eventInjector.events.isNotEmpty) {
      eventInjector.scheduleAll();
    }

    if (kIsWeb) {
      return _startWebWorkers();
    }

    return _startIsolates();
  }

  void _stopWorkers() {
    _eventWorker?.terminate();
    running = false;
    _eventWorker = null;
    notifyListeners();
  }

  void _stopIsolates() {
    _eventIsolate?.kill(priority: Isolate.immediate);
    running = false;
    _eventIsolate = null;
    notifyListeners();
  }

  void stop({bool notify = true}) {
    if (running == false) {
      return;
    }

    // Cancel any outstanding event injection timers
    if (eventInjector.events.isNotEmpty) {
      eventInjector.descheduleAll();
    }

    if (notify) {
      // Update ignition status
      knowgo.Event prevState = knowgo.Event.fromJson(state.toJson());
      state.ignitionStatus = knowgo.IgnitionStatus.off;
      state.timestamp = DateTime.now();
      webhookModel.processWebhooks(info, prevState, state);
    }

    if (kIsWeb) {
      _stopWorkers();
    } else {
      _stopIsolates();
    }

    if (notify) {
      _writeConsoleMessage('Stopping vehicle');
    }
  }

  // Enqueue event updates to apply into the running simulation model. These
  // will be dequeued periodically (at the regular event generation frequency)
  // and combined with incoming updates from the vehicle dynamics model.
  void enqueueUpdates(List<knowgo.Event> events) {
    eventQueue.addAll(events);
  }

  Future<void> update(knowgo.Event update) async {
    var needsRestart = running;
    var notify = needsRestart == false;
    stop(notify: notify);
    updateVehicleState(state, update);
    if (needsRestart) {
      await start(notify: notify);
    } else {
      notifyListeners();
    }
  }
}
