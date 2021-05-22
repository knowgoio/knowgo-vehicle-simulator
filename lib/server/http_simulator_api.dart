import 'dart:convert';
import 'dart:isolate';

import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/simulator/vehicle_notifications.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class VehicleSimulatorApi {
  final VehicleSimulator vehicleSimulator;
  final SendPort simulatorSendPort;

  VehicleSimulatorApi(
      {required this.vehicleSimulator, required this.simulatorSendPort});

  Router get router {
    final router = Router();

    router.get('/info', (Request request) {
      return Response.ok(json.encode(vehicleSimulator.info),
          headers: {'Content-Type': 'application/json'});
    });

    router.get('/events', (Request request) {
      return Response.ok(json.encode(vehicleSimulator.journey.events),
          headers: {'Content-Type': 'application/json'});
    });

    router.post('/events', (Request request) async {
      var content = await request.readAsString();
      var data = jsonDecode(content);
      var updates = knowgo.Event.listFromJson(data);

      updates.forEach((update) {
        // TODO: Merge partial state updates to prevent state clobbering
        // Cache the updated state
        vehicleSimulator.state = update;

        // Send the update to the simulator
        simulatorSendPort.send([VehicleSimulatorCommands.Update, update]);
      });

      return Response.ok('Successfully processed events');
    });

    router.post('/start', (Request request) {
      // Tell the simulator to start the vehicle
      simulatorSendPort.send([VehicleSimulatorCommands.Start]);
      return Response.ok('Vehicle started');
    });

    router.post('/stop', (Request request) {
      // Tell the simulator to stop the vehicle
      simulatorSendPort.send([VehicleSimulatorCommands.Stop]);
      return Response.ok('Vehicle stopped');
    });

    router.post('/notify', (Request request) async {
      var content = await request.readAsString();
      var data = jsonDecode(content);
      var model = vehicleSimulator.notificationModel;

      model.push(VehicleNotification.fromJson(data));
      return Response.ok('Notification submitted');
    });

    return router;
  }
}
