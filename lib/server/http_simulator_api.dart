import 'dart:convert';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_vehicle_simulator/server/http_exve_api.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class VehicleSimulatorApi {
  final VehicleSimulator vehicleSimulator;
  final SendPort simulatorSendPort;
  final VehicleExVeModel? exveModel;
  final WebhookModel? webhookModel;

  VehicleSimulatorApi(
      {required this.vehicleSimulator,
      required this.simulatorSendPort,
      this.exveModel = null,
      this.webhookModel = null});

  Router get router {
    final router = Router();

    router.get('/simulator/info', (Request request) {
      return Response.ok(json.encode(vehicleSimulator.info),
          headers: {'Content-Type': 'application/json'});
    });

    router.get('/simulator/events', (Request request) {
      return Response.ok(json.encode(vehicleSimulator.journey.events),
          headers: {'Content-Type': 'application/json'});
    });

    router.post('/simulator/events', (Request request) async {
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

    router.post('/simulator/start', (Request request) {
      // Tell the simulator to start the vehicle
      simulatorSendPort.send([VehicleSimulatorCommands.Start]);
      return Response.ok('Vehicle started');
    });

    router.post('/simulator/stop', (Request request) {
      // Tell the simulator to stop the vehicle
      simulatorSendPort.send([VehicleSimulatorCommands.Stop]);
      return Response.ok('Vehicle stopped');
    });

    router.post('/simulator/notification', (Request request) async {
      var content = await request.readAsString();
      var data = jsonDecode(content);
      var model = vehicleSimulator.notificationModel;

      model.push(VehicleNotification.fromJson(data));
      return Response.ok('Notification submitted');
    });

    router.get('/simulator/webhooks', (Request request) {
      var triggers =
          webhookModel!.triggers.map((e) => describeEnum(e)).toList();
      return Response.ok(json.encode(triggers),
          headers: {'Content-Type': 'application/json'});
    });

    router.post('/simulator/webhooks', (Request request) async {
      var content = await request.readAsString();
      var data = jsonDecode(content);
      var subscription = WebhookSubscription.fromJson(data);
      webhookModel!.addSubscription(subscription);
      return Response.ok(
          json.encode({'subscriptionId': '${subscription.subscriptionId}'}),
          headers: {'Content-Type': 'application/json'});
    });

    router.get('/simulator/webhooks/<subscriptionId>', (Request request) {
      var subscriptionId = params(request, 'subscriptionId');
      var subscription = webhookModel!.subscriptions.firstWhereOrNull(
          (subscription) => subscription.subscriptionId == subscriptionId);
      if (subscription == null) {
        return Response.notFound('Subscription not found');
      }

      return Response.ok(json.encode(subscription),
          headers: {'Content-Type': 'application/json'});
    });

    router.put('/simulator/webhooks/<subscriptionId>', (Request request) async {
      var content = await request.readAsString();
      var data = jsonDecode(content);
      var subscription = WebhookSubscription.fromJson(data);
      subscription.subscriptionId = params(request, 'subscriptionId');
      webhookModel!.updateSubscription(subscription);
      return Response.ok('Subscription updated');
    });

    router.delete('/simulator/webhooks/<subscriptionId>', (Request request) {
      var subscriptionId = params(request, 'subscriptionId');
      webhookModel!.removeSubscription(subscriptionId);
      return Response.ok('Subscription deleted');
    });

    // Handle all /exve/ requests with the ExVe API sub-router
    if (exveModel != null) {
      final exveApi =
          ExVeAPI(vehicleSimulator: vehicleSimulator, exveModel: exveModel!);
      router.mount(('/exve/'), exveApi.router);
    }

    return router;
  }
}
