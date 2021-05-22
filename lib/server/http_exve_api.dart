import 'dart:convert';

import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/simulator/vehicle_exve_model.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

extension NumberRounding on num {
  num toPrecision(int precision) {
    return num.parse(this.toStringAsFixed(precision));
  }
}

class ExVeAPI {
  final VehicleSimulator vehicleSimulator;
  final VehicleExVeModel exveModel;

  ExVeAPI({required this.vehicleSimulator, required this.exveModel});

  Router get router {
    final router = Router();

    router.get('/vehicles', (Request request) {
      var vehicles = exveModel.vehicles.map((v) => v.toJson()).toList();
      return Response.ok(json.encode(vehicles),
          headers: {'Content-Type': 'application/json'});
    });

    router.get('/vehicles/<vehicleId>', (Request request) {
      var vehicleId = int.parse(params(request, 'vehicleId'));
      if (vehicleSimulator.info.autoID == vehicleId) {
        return Response.ok(json.encode(vehicleSimulator.info),
            headers: {'Content-Type': 'application/json'});
      } else {
        return Response.notFound('Vehicle not found');
      }
    });

    router.get('/vehicles/<vehicleId>/<resource>', (Request request) {
      var vehicleId = int.parse(params(request, 'vehicleId'));
      var resource = params(request, 'resource');
      var data = [];
      Map<String, dynamic> payload = {};

      if (vehicleSimulator.info.autoID != vehicleId) {
        return Response.notFound('Vehicle not found');
      }

      switch (resource) {
        case 'acceleratorPedalPositions':
          if (vehicleSimulator.journey.events.isNotEmpty) {
            // Cache the previous reading to avoid issuing unchanged readings
            num lastReading = 0;

            vehicleSimulator.journey.events.forEach((event) {
              Map<String, dynamic> reading = {};
              var acceleratorPedalPosition =
                  event.acceleratorPedalPosition.floor();
              if (acceleratorPedalPosition != lastReading) {
                lastReading = acceleratorPedalPosition;
                reading['value'] = acceleratorPedalPosition;
                reading['units'] = "percent";
                reading['timestamp'] = event.timestamp.toIso8601String();
                data.add(reading);
              }
            });
          }
          break;
        case 'locations':
          vehicleSimulator.journey.events.forEach((event) {
            Map<String, dynamic> reading = {};
            reading['latitude'] = event.latitude;
            reading['longitude'] = event.longitude;
            reading['timestamp'] = event.timestamp.toIso8601String();
            data.add(reading);
          });
          break;
        case 'odometers':
          if (vehicleSimulator.journey.events.isNotEmpty) {
            num lastReading = 0.00;

            // If the simulator is running, fetch the odometer values from the
            // event list
            vehicleSimulator.journey.events.forEach((event) {
              Map<String, dynamic> reading = {};
              var odometer = event.odometer.toPrecision(2);
              if (odometer != lastReading) {
                lastReading = odometer;
                reading['value'] = odometer;
                reading['units'] = "km";
                reading['timestamp'] = event.timestamp.toIso8601String();
                data.add(reading);
              }
            });
          } else {
            // If not, obtain the last odometer value from the vehicle state
            Map<String, dynamic> reading = {};
            reading['value'] = vehicleSimulator.info.odometer.toPrecision(2);
            reading['units'] = "km";
            reading['timestamp'] = DateTime.now().toIso8601String();
            data.add(reading);
          }
          break;
        default:
          return Response.forbidden('Invalid resource type requested');
      }

      payload[resource] = data;
      return Response.ok(json.encode(payload),
          headers: {'Content-Type': 'application/json'});
    });

    return router;
  }
}
