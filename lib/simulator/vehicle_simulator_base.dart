import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' if (dart.library.io) '../worker_stub.dart';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:kafka/kafka.dart';
import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:knowgo_vehicle_simulator/simulator/vehicle_notifications.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'vehicle_data_generator.dart';
import 'vehicle_event_loop.dart';
import 'vehicle_state.dart';

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

  // HTTP Server ReceivePort
  final ReceivePort? serverReceivePort;
  SendPort? _serverSendPort;

  final simulatorReceivePort = ReceivePort();

  final notificationModel = VehicleNotificationModel();

  VehicleSimulator([this.serverReceivePort]) {
    initVehicleInfo(info);
    initVehicleState(state);
    journey.autoID = info.autoID;
    journey.driverID = info.driverID;
    _writeConsoleMessage('Waiting for simulator to start..');
  }

  // API Client for optional backend connectivity
  knowgo.ApiClient? apiClient;

  // MQTT client for optional MQTT broker connectivity
  MqttServerClient? mqttClient;

  // Kafka client for optional Kafka broker connectivity
  Producer? kafkaProducer;

  // Information about the generated Vehicle
  knowgo.Auto info = knowgo.Auto();

  // The current Journey the Vehicle is on
  knowgo.Journey journey = knowgo.Journey();

  // The current state of the Vehicle
  knowgo.Event state = knowgo.Event();

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

    // Synchronize vehicle state
    info.odometer = num.parse((update.odometer).toStringAsFixed(2)).toDouble();
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

    // Log event to console
    if (_settingsService.eventLoggingEnabled) {
      _consoleService.write(update.toString());
    }

    // Dispatch event to backend asynchronously
    if (apiClient != null) {
      knowgo.EventsApi(apiClient).addEvent(update).catchError((e) {});
    }

    // Dispatch event to MQTT broker asynchronously
    if (mqttClient != null) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(update.toJson().toString());
      mqttClient?.publishMessage(
          _settingsService.mqttTopic, MqttQos.exactlyOnce, builder.payload,
          retain: false);
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

  Future<void> start() async {
    var _settingsService = serviceLocator.get<SettingsService>();

    // Nothing to do if the simulator is already running
    if (running == true) {
      return;
    } else {
      // Update the simulator state
      running = true;
    }

    // Init API client connection
    if (_settingsService.server != null) {
      apiClient = knowgo.ApiClient(basePath: _settingsService.server);
      if (_settingsService.apiKey != null) {
        apiClient?.addDefaultHeader('X-API-Key', _settingsService.apiKey);
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

  void stop() {
    if (running == false) {
      return;
    }

    if (kIsWeb) {
      _stopWorkers();
    } else {
      _stopIsolates();
    }
  }

  Future<void> update(knowgo.Event update) async {
    var needsRestart = running;
    stop();
    updateVehicleState(state, update);
    if (needsRestart) {
      await start();
    } else {
      notifyListeners();
    }
  }
}
