import 'dart:collection';

import 'package:knowgo_vehicle_simulator/simulator.dart';

typedef VehicleID = int;
typedef FleetID = int;

extension VehicleIdJsonEncoding on VehicleID {
  Map<String, dynamic> vehicleIdToJson() => {'vehicleId': this};
}

extension FleetIdJsonEncoding on FleetID {
  Map<String, dynamic> fleetIdToJson() => {'fleetId': this};
}

final _dataGenerator = VehicleDataGenerator();

class Fleet {
  final FleetID fleetId;
  final List<VehicleID?> vehicles;

  Fleet()
      : fleetId = _dataGenerator.id(),
        vehicles = [];

  Fleet.generate({required this.vehicles})
      : fleetId = _dataGenerator.id(),
        assert(vehicles.length > 0);

  void addVehicle(VehicleID vehicleId) {
    if (!vehicles.contains(vehicleId)) {
      vehicles.add(vehicleId);
    }
  }

  void removeVehicle(VehicleID vehicleId) =>
      vehicles.removeWhere((id) => id == vehicleId);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['fleetId'] = fleetId;
    json['vehicles'] = vehicles.map((v) => v!.vehicleIdToJson()).toList();
    return json;
  }

  @override
  String toString() {
    return 'Fleet[fleetId=$fleetId, vehicles=$vehicles]';
  }
}

class VehicleExVeModel {
  final List<Fleet> _fleets = [];
  final List<VehicleID> _vehicles = [];

  static final _singleton = VehicleExVeModel._internal();

  factory VehicleExVeModel() {
    return _singleton;
  }

  VehicleExVeModel._internal();

  UnmodifiableListView<Fleet?> get fleets => UnmodifiableListView(_fleets);
  UnmodifiableListView<VehicleID> get vehicles =>
      UnmodifiableListView(_vehicles);

  void addVehicle(VehicleID id) {
    if (!_vehicles.contains(id)) {
      _vehicles.add(id);
    }
  }

  void addFleet(Fleet fleet) {
    if (!_fleets.contains(fleet)) {
      _fleets.add(fleet);
    }
  }

  void removeFleet(FleetID id) => _fleets.removeWhere((f) => f.fleetId == id);
}
