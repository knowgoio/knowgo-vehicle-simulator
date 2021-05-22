import 'dart:isolate';

import 'package:knowgo_vehicle_simulator/server/http_simulator_api.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/simulator/vehicle_notifications.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> runHttpServer(SendPort sendPort) async {
  // Open up a ReceivePort and send a reference to its sendPort back to the
  // main isolate. This is used as a basis for establishing bi-directional
  // message passing between the main and event isolates.
  var commPort = ReceivePort();
  sendPort.send(commPort.sendPort);

  var simulatorCommPort = ReceivePort();
  var vehicleSimulator = VehicleSimulator();

  commPort.listen((data) async {
    var port = data[0];
    var simulatorSendPort = data[1];

    simulatorSendPort.send(simulatorCommPort.sendPort);

    var notificationModel = vehicleSimulator.notificationModel;

    // Proxy notifications back to the main isolate
    void _notificationListener() {
      sendPort.send(notificationModel.notifications);
    }

    notificationModel.addListener(_notificationListener);

    // Receive updated vehicle simulator state
    simulatorCommPort.listen((data) {
      vehicleSimulator.info = data[0];
      vehicleSimulator.state = data[1];
      if (data[2] != null) {
        vehicleSimulator.journey.events = data[2];
      }
    });

    final vehicleSimulatorApi = VehicleSimulatorApi(
        vehicleSimulator: vehicleSimulator,
        simulatorSendPort: simulatorSendPort);

    var server =
        await shelf_io.serve(vehicleSimulatorApi.router, 'localhost', port);

    print(
        'Vehicle Simulator listening on ${server.address.host}:${server.port}...');
  });
}

class SimulatorHttpServer {
  Isolate? _serverIsolate;
  final receivePort = ReceivePort();
  final notificationModel = VehicleNotificationModel();
  final int port;

  SimulatorHttpServer(this.port);

  Future<void> start(ReceivePort _simulatorReceivePort) async {
    SendPort _sendPort;

    _serverIsolate = await Isolate.spawn(runHttpServer, receivePort.sendPort);

    // Wait for the simulator to open up its ReceivePort
    receivePort.listen((data) {
      if (data is SendPort) {
        _sendPort = data;
        _sendPort.send([port, _simulatorReceivePort.sendPort]);
      } else {
        notificationModel.pushAll(data);
      }
    });
  }

  void stop() {
    _serverIsolate?.kill(priority: Isolate.immediate);
  }
}
