import 'dart:convert';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_vehicle_simulator/server.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:prometheus_client_shelf/shelf_handler.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';

import 'auth.dart';

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

    // Expose prometheus metrics
    router.get('/metrics', prometheusHandler());

    router.get('/simulator/info', (shelf.Request request) {
      return shelf.Response.ok(json.encode(vehicleSimulator.info),
          headers: {'Content-Type': 'application/json'});
    });

    router.get('/simulator/events', (shelf.Request request) {
      return shelf.Response.ok(json.encode(vehicleSimulator.journey.events),
          headers: {'Content-Type': 'application/json'});
    });

    router.post('/simulator/events', (shelf.Request request) async {
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

      return shelf.Response.ok('Successfully processed events');
    });

    router.post('/simulator/start', (shelf.Request request) {
      // Tell the simulator to start the vehicle
      simulatorSendPort.send([VehicleSimulatorCommands.Start]);
      return shelf.Response.ok('Vehicle started');
    });

    router.post('/simulator/stop', (shelf.Request request) {
      // Tell the simulator to stop the vehicle
      simulatorSendPort.send([VehicleSimulatorCommands.Stop]);
      return shelf.Response.ok('Vehicle stopped');
    });

    router.post('/simulator/notification', (shelf.Request request) async {
      var content = await request.readAsString();
      var data = jsonDecode(content);
      var model = vehicleSimulator.notificationModel;

      model.push(VehicleNotification.fromJson(data));
      return shelf.Response.ok('Notification submitted');
    });

    router.get('/simulator/webhooks', (shelf.Request request) {
      var triggers =
          webhookModel!.triggers.map((e) => describeEnum(e)).toList();
      return shelf.Response.ok(json.encode(triggers),
          headers: {'Content-Type': 'application/json'});
    });

    router.post('/simulator/webhooks', (shelf.Request request) async {
      var content = await request.readAsString();
      var data = jsonDecode(content);
      var subscription = WebhookSubscription.fromJson(data);
      webhookModel!.addSubscription(subscription);
      return shelf.Response.ok(
          json.encode({'subscriptionId': '${subscription.subscriptionId}'}),
          headers: {'Content-Type': 'application/json'});
    });

    router.get('/simulator/webhooks/<subscriptionId>', (shelf.Request request) {
      var subscriptionId = params(request, 'subscriptionId');
      var subscription = webhookModel!.subscriptions.firstWhereOrNull(
          (subscription) => subscription.subscriptionId == subscriptionId);
      if (subscription == null) {
        return shelf.Response.notFound('Subscription not found');
      }

      return shelf.Response.ok(json.encode(subscription),
          headers: {'Content-Type': 'application/json'});
    });

    router.put('/simulator/webhooks/<subscriptionId>',
        (shelf.Request request) async {
      var content = await request.readAsString();
      var data = jsonDecode(content);
      var subscription = WebhookSubscription.fromJson(data);
      subscription.subscriptionId = params(request, 'subscriptionId');
      webhookModel!.updateSubscription(subscription);
      return shelf.Response.ok('Subscription updated');
    });

    router.delete('/simulator/webhooks/<subscriptionId>',
        (shelf.Request request) {
      var subscriptionId = params(request, 'subscriptionId');
      webhookModel!.removeSubscription(subscriptionId);
      return shelf.Response.ok('Subscription deleted');
    });

    router.post('/introspect', (shelf.Request request) async {
      var content = await request.readAsString();
      // token=<token>
      var token = content.split('=')[1];

      if (!AuthService.validateApiKey(token)) {
        return shelf.Response.forbidden('Invalid token specification');
      }

      return shelf.Response.ok(json.encode(AuthService.introspectApiKey(token)),
          headers: {'Content-Type': 'application/json'});
    });

    // Handle all /exve/ requests with the ExVe API sub-router
    if (exveModel != null) {
      final exveApi =
          ExVeAPI(vehicleSimulator: vehicleSimulator, exveModel: exveModel!);
      router.mount(('/exve/'), exveApi.router);
    }

    // All other endpoints will return a 404
    router.all('/<ignored|.*>', (shelf.Request request) {
      return shelf.Response.notFound('Not Found');
    });

    return router;
  }
}
