import 'dart:collection';

typedef VehicleID = int;

extension JsonEncoding on VehicleID {
  Map<String, dynamic> toJson() => {'vehicleId': this};
}

class VehicleExVeModel {
  final List<VehicleID> _vehicles = [];
  static final _singleton = VehicleExVeModel._internal();

  factory VehicleExVeModel() {
    return _singleton;
  }

  VehicleExVeModel._internal();

  UnmodifiableListView<VehicleID> get vehicles =>
      UnmodifiableListView(_vehicles);

  void addVehicle(VehicleID id) {
    if (!_vehicles.contains(id)) {
      _vehicles.add(id);
    }
  }
}
