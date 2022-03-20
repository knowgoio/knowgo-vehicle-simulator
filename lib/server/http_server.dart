import 'dart:isolate';

import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_vehicle_simulator/server/auth_middleware.dart';
import 'package:knowgo_vehicle_simulator/server/cors_middleware.dart';
import 'package:knowgo_vehicle_simulator/server/http_metrics_middleware.dart';
import 'package:knowgo_vehicle_simulator/server/http_simulator_api.dart';
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:prometheus_client/runtime_metrics.dart' as runtime_metrics;
import 'package:prometheus_client_shelf/shelf_metrics.dart' as shelf_metrics;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> runHttpServer(SendPort sendPort) async {
  // Register run-time metrics. These are scraped from within the isolate and
  // must therefore be registered in isolate-local memory.
  runtime_metrics.register();

  // Open up a ReceivePort and send a reference to its sendPort back to the
  // main isolate. This is used as a basis for establishing bi-directional
  // message passing between the main and event isolates.
  var commPort = ReceivePort();
  sendPort.send(commPort.sendPort);

  var simulatorCommPort = ReceivePort();
  var vehicleSimulator = VehicleSimulator();
  var exveModel = VehicleExVeModel();
  var webhookModel = WebhookModel();

  commPort.listen((data) async {
    var port = data[0];
    var allowUnauthenticated = data[1];
    var simulatorSendPort = data[2];

    simulatorSendPort.send(simulatorCommPort.sendPort);

    // Proxy notifications back to the main isolate
    var notificationModel = vehicleSimulator.notificationModel;
    notificationModel
        .addListener(() => sendPort.send(notificationModel.notifications));

    // Receive updated vehicle simulator state
    simulatorCommPort.listen((data) {
      // Pass in vehicle info, the previous state, and the updated state for
      // processing webhooks.
      webhookModel.processWebhooks(data[0], vehicleSimulator.state, data[1]);

      vehicleSimulator.info = data[0];
      vehicleSimulator.state = data[1];
      if (data[2] != null) {
        var events = data[2] as List<knowgo.Event>;
        vehicleSimulator.journey.events = events;
        vehicleSimulator.streamController.sink.add(events.last);
      }

      // Add the vehicle to the ExVe model
      exveModel.addVehicle(vehicleSimulator.info.autoID);

      // And a fleet
      final fleet = Fleet.generate(vehicles: [vehicleSimulator.info.autoID]);
      exveModel.addFleet(fleet);
    });

    final vehicleSimulatorApi = VehicleSimulatorApi(
      vehicleSimulator: vehicleSimulator,
      simulatorSendPort: simulatorSendPort,
      exveModel: exveModel,
      webhookModel: webhookModel,
    );

    final handler = const Pipeline()
        .addMiddleware(addCORSHeaders())
        .addMiddleware(shelf_metrics.register())
        .addMiddleware(registerHttpMetrics())
        .addMiddleware(
            registerAuthMiddleware(allowUnauthenticated: allowUnauthenticated))
        .addHandler(vehicleSimulatorApi.router);

    vehicleSimulator.httpServer =
        await shelf_io.serve(handler, 'localhost', port);

    print(
        'Vehicle Simulator listening on ${vehicleSimulator.httpServer!.address.host}:${vehicleSimulator.httpServer!.port}...');
  });
}

class SimulatorHttpServer {
  Isolate? _serverIsolate;
  ReceivePort? _simulatorPort;
  final notificationModel = VehicleNotificationModel();
  final _settingsService = serviceLocator.get<SettingsService>();
  final int port;

  SimulatorHttpServer(this.port);

  Future<void> start(ReceivePort _simulatorReceivePort) async {
    final receivePort = ReceivePort();
    SendPort _sendPort;

    _simulatorPort = _simulatorReceivePort;
    _serverIsolate = await Isolate.spawn(runHttpServer, receivePort.sendPort);

    // Wait for the simulator to open up its ReceivePort
    receivePort.listen((data) {
      if (data is SendPort) {
        _sendPort = data;
        _sendPort.send([
          port,
          _settingsService.allowUnauthenticated,
          _simulatorReceivePort.sendPort
        ]);
      } else {
        notificationModel.pushAll(data);
      }
    });
  }

  void stop() {
    _serverIsolate?.kill(priority: Isolate.immediate);
  }

  Future<void> restart() async {
    stop();
    await start(_simulatorPort!);
  }
}
