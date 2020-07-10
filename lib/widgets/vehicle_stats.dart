import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'package:knowgo_simulator_desktop/widgets/vehicle_data_card.dart';
import 'package:provider/provider.dart';

class VehicleStats extends StatefulWidget {
  VehicleStats();

  @override
  _VehicleStatsState createState() => _VehicleStatsState();
}

class _VehicleStatsState extends State<VehicleStats> {
  Widget fuelLevelIndicator(VehicleSimulator vehicleSimulator) {
    if (vehicleSimulator.state != null &&
        vehicleSimulator.state.fuelLevel != null) {
      return LinearProgressIndicator(
          value: vehicleSimulator.state.fuelLevel / 100.0);
    } else {
      return LinearProgressIndicator();
    }
  }

  Widget fuelConsumptionIndicator(VehicleSimulator vehicleSimulator) {
    if (vehicleSimulator.state != null &&
        vehicleSimulator.state.fuelConsumedSinceRestart != null &&
        vehicleSimulator.state.fuelLevel != null) {
      var fuelConsumed = vehicleSimulator.state.fuelConsumedSinceRestart /
          vehicleSimulator.state.fuelLevel;
      return LinearProgressIndicator(value: fuelConsumed);
    } else {
      return LinearProgressIndicator();
    }
  }

  Widget generateStatWidgets(VehicleSimulator vehicleSimulator) {
    if (vehicleSimulator.running == false) {
      return Text('Waiting for simulator to start..');
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('VIN: ${vehicleSimulator.info?.VIN}'),
          Text(
              'Odometer: ${vehicleSimulator.state.odometer.toStringAsFixed(2)} km'),
          Text(
              'Vehicle Speed: ${vehicleSimulator.state.vehicleSpeed.toStringAsFixed(2)} km/h'),
          Text('Gear: ${vehicleSimulator.state.transmissionGearPosition}'),
          Text('Fuel Consumed:'),
          fuelConsumptionIndicator(vehicleSimulator),
          Text('Fuel Level:'),
          fuelLevelIndicator(vehicleSimulator),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var vehicleSimulator = context.watch<VehicleSimulator>();
    return VehicleDataCard(
      title: 'Vehicle Stats',
      child: generateStatWidgets(vehicleSimulator),
    );
  }
}
