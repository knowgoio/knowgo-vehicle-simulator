import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/widgets/vehicle_data_card.dart';
import 'package:provider/provider.dart';

class VehicleStats extends StatefulWidget {
  VehicleStats();

  @override
  _VehicleStatsState createState() => _VehicleStatsState();
}

class _VehicleStatsState extends State<VehicleStats> {
  Widget fuelLevelIndicator(VehicleSimulator vehicleSimulator) {
    if (vehicleSimulator.state.fuelLevel != null) {
      return LinearProgressIndicator(
          value: vehicleSimulator.state.fuelLevel / 100.0);
    } else {
      return LinearProgressIndicator();
    }
  }

  Widget fuelConsumptionIndicator(VehicleSimulator vehicleSimulator) {
    if (vehicleSimulator.state.fuelConsumedSinceRestart != null &&
        vehicleSimulator.state.fuelLevel != null) {
      var fuelConsumed = vehicleSimulator.state.fuelConsumedSinceRestart /
          vehicleSimulator.state.fuelLevel;
      return LinearProgressIndicator(value: fuelConsumed);
    } else {
      return LinearProgressIndicator();
    }
  }

  Widget generateStatWidgets(VehicleSimulator vehicleSimulator) {
    if (vehicleSimulator.journey.odometerBegin == null) {
      return Text('Waiting for simulator to start..');
    } else {
      var distanceTraveled = vehicleSimulator.state.odometer -
          vehicleSimulator.journey.odometerBegin;
      if (distanceTraveled < 0.0) {
        distanceTraveled = 0.0;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('VIN: ${vehicleSimulator.info.VIN}'),
          Text(
              'Odometer: ${vehicleSimulator.state.odometer.toStringAsFixed(2)} km'),
          Text(
              'Lat: ${vehicleSimulator.state.latitude.toStringAsPrecision(6)}, Lng: ${vehicleSimulator.state.longitude.toStringAsPrecision(6)}, Heading: ${vehicleSimulator.state.bearing.toInt()}°'),
          Text('Distance Traveled: ${distanceTraveled.toStringAsFixed(2)} km'),
          Text(
              'Vehicle Speed: ${vehicleSimulator.state.vehicleSpeed.toStringAsFixed(2)} km/h'),
          Text(
              'Engine Speed: ${vehicleSimulator.state.engineSpeed.toInt()} RPMs'),
          Spacer(),
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
