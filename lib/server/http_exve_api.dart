import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

extension NumberRounding on num {
  num toPrecision(int precision) {
    return num.parse(this.toStringAsFixed(precision));
  }
}

class ExVeResource {
  final String name;
  final String version = '1.0';
  final String href;

  ExVeResource({required HttpServer server, required name, required vehicleId})
      : name = name,
        href =
            'http://${server.address.host}:${server.port}/exve/vehicles/$vehicleId/$name';

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['name'] = name;
    json['version'] = version;
    json['href'] = href;
    return json;
  }
}

class ExVeAPI {
  final VehicleSimulator vehicleSimulator;
  final VehicleExVeModel exveModel;

  ExVeAPI({required this.vehicleSimulator, required this.exveModel});

  Router get router {
    final router = Router();

    router.get('/fleets', (Request request) {
      final fleetIds =
          exveModel.fleets.map((f) => f!.fleetId.fleetIdToJson()).toList();
      return Response.ok(json.encode(fleetIds),
          headers: {'Content-Type': 'application/json'});
    });

    router.post('/fleets', (Request request) async {
      var content = await request.readAsString();
      var data = jsonDecode(content);
      final List<VehicleID> vehicleIds =
          List<VehicleID>.from(data.map((e) => int.parse(e['vehicleId'])));

      for (var vehicleId in vehicleIds) {
        if (vehicleSimulator.info.autoID != vehicleId) {
          return Response.notFound('Vehicle not found');
        }
      }

      final fleet = Fleet.generate(vehicles: vehicleIds);
      exveModel.addFleet(fleet);
      return Response.ok(json.encode(fleet.fleetId.fleetIdToJson()),
          headers: {'Content-Type': 'application/json'});
    });

    router.get('/fleets/<fleetId>', (Request request) {
      final fleetId = int.parse(params(request, 'fleetId'));
      final Fleet? fleet = exveModel.fleets
          .singleWhere((f) => f!.fleetId == fleetId, orElse: () => null);
      if (fleet == null) {
        return Response.notFound('Fleet not found');
      }

      return Response.ok(json.encode(fleet),
          headers: {'Content-Type': 'application/json'});
    });

    router.post('/fleets/<fleetId>', (Request request) async {
      final fleetId = int.parse(params(request, 'fleetId'));
      var content = await request.readAsString();
      var data = jsonDecode(content);
      final List<dynamic> vehicles = data['vehicles'];
      final List<VehicleID> vehicleIds =
          List<VehicleID>.from(vehicles.map((e) => int.parse(e['vehicleId'])));
      final Fleet? fleet = exveModel.fleets
          .singleWhere((f) => f!.fleetId == fleetId, orElse: () => null);
      if (fleet == null) {
        return Response.notFound('Fleet not found');
      }

      for (var vehicleId in vehicleIds) {
        if (vehicleSimulator.info.autoID != vehicleId) {
          return Response.notFound('Vehicle not found');
        }

        if (fleet.vehicles.contains(vehicleId)) {
          return Response.notModified();
        }

        fleet.addVehicle(vehicleId);
      }

      return Response.ok('Vehicles successfully added to fleet');
    });

    router.delete('/fleets/<fleetId>', (Request request) {
      final fleetId = int.parse(params(request, 'fleetId'));
      final Fleet? fleet = exveModel.fleets
          .singleWhere((f) => f!.fleetId == fleetId, orElse: () => null);
      if (fleet == null) {
        return Response.notFound('Fleet not found');
      }

      exveModel.removeFleet(fleetId);
      return Response.ok('Fleet successfully deleted');
    });

    router.get('/fleets/<fleetId>/vehicles', (Request request) {
      final fleetId = int.parse(params(request, 'fleetId'));
      final Fleet? fleet = exveModel.fleets
          .singleWhere((f) => f!.fleetId == fleetId, orElse: () => null);
      if (fleet == null) {
        return Response.notFound('Fleet not found');
      }

      final vehicles = fleet.vehicles.map((v) => v!.vehicleIdToJson()).toList();
      return Response.ok(json.encode(vehicles),
          headers: {'Content-Type': 'application/json'});
    });

    router.get('/fleets/<fleetId>/vehicles/<vehicleId>', (Request request) {
      final fleetId = int.parse(params(request, 'fleetId'));
      final vehicleId = int.parse(params(request, 'vehicleId'));
      final Fleet? fleet = exveModel.fleets
          .singleWhere((f) => f!.fleetId == fleetId, orElse: () => null);
      if (fleet == null) {
        return Response.notFound('Fleet not found');
      }

      final VehicleID? fleetVehicleId =
          fleet.vehicles.singleWhere((v) => v == vehicleId, orElse: () => null);
      if (fleetVehicleId == null ||
          vehicleSimulator.info.autoID != fleetVehicleId) {
        return Response.notFound('Vehicle not found in fleet');
      }

      return Response.ok(json.encode(vehicleSimulator.info),
          headers: {'Content-Type': 'application/json'});
    });

    router.delete('/fleets/<fleetId>/vehicles/<vehicleId>', (Request request) {
      final fleetId = int.parse(params(request, 'fleetId'));
      final vehicleId = int.parse(params(request, 'vehicleId'));
      final Fleet? fleet = exveModel.fleets
          .singleWhere((f) => f!.fleetId == fleetId, orElse: () => null);
      if (fleet == null) {
        return Response.notFound('Fleet not found');
      }

      if (fleet.vehicles.contains(vehicleId)) {
        fleet.removeVehicle(vehicleId);
        return Response.ok('Vehicle successfully removed from fleet');
      }

      return Response.notFound('Vehicle not found in fleet');
    });

    router.get('/vehicles', (Request request) {
      var vehicles =
          exveModel.vehicles.map((v) => v.vehicleIdToJson()).toList();
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

    router.post('/vehicles/<vehicleId>/notification', (Request request) async {
      var vehicleId = int.parse(params(request, 'vehicleId'));
      var content = await request.readAsString();
      var data = jsonDecode(content);
      var model = vehicleSimulator.notificationModel;

      if (vehicleSimulator.info.autoID != vehicleId) {
        return Response.notFound('Vehicle not found');
      }

      model.push(VehicleNotification.fromJson(data));
      return Response.ok('Notification submitted');
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
        case 'capabilities':
        case 'resources':
          data = [
            ExVeResource(
                server: vehicleSimulator.httpServer!,
                name: 'acceleratorPedalPositions',
                vehicleId: vehicleId),
            ExVeResource(
                server: vehicleSimulator.httpServer!,
                name: 'automationLevels',
                vehicleId: vehicleId),
            ExVeResource(
                server: vehicleSimulator.httpServer!,
                name: 'brakePedalPositions',
                vehicleId: vehicleId),
            ExVeResource(
                server: vehicleSimulator.httpServer!,
                name: 'doorStatuses',
                vehicleId: vehicleId),
            ExVeResource(
                server: vehicleSimulator.httpServer!,
                name: 'fuelLevels',
                vehicleId: vehicleId),
            ExVeResource(
                server: vehicleSimulator.httpServer!,
                name: 'ignitionStatuses',
                vehicleId: vehicleId),
            ExVeResource(
                server: vehicleSimulator.httpServer!,
                name: 'locations',
                vehicleId: vehicleId),
            ExVeResource(
                server: vehicleSimulator.httpServer!,
                name: 'odometers',
                vehicleId: vehicleId),
          ];
          break;
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
        case 'automationLevels':
          if (vehicleSimulator.journey.events.isNotEmpty) {
            // Cache the previous reading to avoid issuing unchanged readings
            int lastReading = 0;

            vehicleSimulator.journey.events.forEach((event) {
              Map<String, dynamic> reading = {};
              var automationLevel = event.automationLevel;
              if (automationLevel != lastReading) {
                lastReading = automationLevel;
                reading['level'] = automationLevel;
                reading['timestamp'] = event.timestamp.toIso8601String();
                data.add(reading);
              }
            });
          }
          break;
        case 'brakePedalPositions':
          if (vehicleSimulator.journey.events.isNotEmpty) {
            // Cache the previous reading to avoid issuing unchanged readings
            num lastReading = 0;

            vehicleSimulator.journey.events.forEach((event) {
              Map<String, dynamic> reading = {};
              var brakePedalPosition = event.brakePedalPosition.floor();
              if (brakePedalPosition != lastReading) {
                lastReading = brakePedalPosition;
                reading['value'] = brakePedalPosition;
                reading['units'] = "percent";
                reading['timestamp'] = event.timestamp.toIso8601String();
                data.add(reading);
              }
            });
          }
          break;
        case 'doorStatuses':
          if (vehicleSimulator.journey.events.isNotEmpty) {
            // Cache the previous reading to avoid issuing unchanged readings
            String? lastReading;

            vehicleSimulator.journey.events.forEach((event) {
              Map<String, dynamic> reading = {};
              var doorStatus = describeEnum(event.doorStatus);
              if (doorStatus != lastReading) {
                lastReading = doorStatus;
                reading['value'] = doorStatus;
                reading['timestamp'] = event.timestamp.toIso8601String();
                data.add(reading);
              }
            });
          }
          break;
        case 'fuelLevels':
          if (vehicleSimulator.journey.events.isNotEmpty) {
            // Cache the previous reading to avoid issuing unchanged readings
            num lastReading = 0;

            vehicleSimulator.journey.events.forEach((event) {
              Map<String, dynamic> reading = {};
              var fuelLevel = event.fuelLevel.floor();
              if (fuelLevel != lastReading) {
                lastReading = fuelLevel;
                reading['value'] = fuelLevel;
                reading['units'] = "percent";
                reading['timestamp'] = event.timestamp.toIso8601String();
                data.add(reading);
              }
            });
          }
          break;
        case 'ignitionStatuses':
          if (vehicleSimulator.journey.events.isNotEmpty) {
            // Cache the previous reading to avoid issuing unchanged readings
            String? lastReading;

            vehicleSimulator.journey.events.forEach((event) {
              Map<String, dynamic> reading = {};
              var ignitionStatus = describeEnum(event.ignitionStatus);
              if (ignitionStatus != lastReading) {
                lastReading = ignitionStatus;
                reading['value'] = ignitionStatus;
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
            reading['bearing'] = event.bearing;
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
