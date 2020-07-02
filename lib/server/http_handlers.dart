import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'package:knowgo/api.dart' as knowgo;

Future<void> _handleVehicleInfoRequest(
    VehicleSimulator vehicleSimulator, HttpRequest req) async {
  var resp = req.response;

  resp
    ..statusCode = HttpStatus.ok
    ..write(jsonEncode(vehicleSimulator.info));

  if (vehicleSimulator.state != null) {
    resp.write(jsonEncode(vehicleSimulator.state));
  }

  await resp.close();
}

Future<void> _handleVehicleEventRequest(
    VehicleSimulator vehicleSimulator, HttpRequest req) async {
  var resp = req.response;

  resp
    ..statusCode = HttpStatus.ok
    ..write(jsonEncode(vehicleSimulator.events));
  await resp.close();
}

Future<void> _handleVehicleStateUpdateRequest(VehicleSimulator vehicleSimulator,
    SendPort sendPort, HttpRequest req) async {
  var resp = req.response;

  var content = await utf8.decoder.bind(req).join();
  var data = jsonDecode(content);
  var state = knowgo.Event.fromJson(data);

  // Cache the updated state
  vehicleSimulator.state = state;

  // Send the update to the simulator
  sendPort.send([VehicleSimulatorCommands.Update, state]);

  resp.statusCode = HttpStatus.ok;
  await resp.close();
}

void handleHttpRequest(
    VehicleSimulator vehicleSimulator, SendPort sendPort, HttpRequest req) {
  var resp = req.response;

  switch (req.method) {
    case 'POST':
      switch (req.uri.path) {
        case '/start':
          // Tell the simulator to start the vehicle
          sendPort.send([VehicleSimulatorCommands.Start]);
          resp
            ..statusCode = HttpStatus.ok
            ..write('Vehicle started\n');
          resp.close();
          return;
        case '/stop':
          // Tell the simulator to stop the vehicle
          sendPort.send([VehicleSimulatorCommands.Stop]);
          resp
            ..statusCode = HttpStatus.ok
            ..write('Vehicle stopped\n');
          resp.close();
          return;
        case '/update':
          _handleVehicleStateUpdateRequest(vehicleSimulator, sendPort, req);
          return;
      }
      break;
    case 'GET':
      switch (req.uri.path) {
        case '/info':
          _handleVehicleInfoRequest(vehicleSimulator, req);
          return;
        case '/events':
          _handleVehicleEventRequest(vehicleSimulator, req);
          return;
      }
  }

  resp
    ..statusCode = HttpStatus.methodNotAllowed
    ..write('Unsupported request: ${req.method}.');

  resp.close();
}
