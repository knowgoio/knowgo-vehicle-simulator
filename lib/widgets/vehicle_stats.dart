import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/widgets.dart';
import 'package:provider/provider.dart';

class VehicleStats extends StatefulWidget {
  VehicleStats();

  @override
  _VehicleStatsState createState() => _VehicleStatsState();
}

class _VehicleStatsState extends State<VehicleStats> {
  var group = AutoSizeGroup();
  var minFontSize = 10.0;

  Widget fuelLevelIndicator(VehicleSimulator vehicleSimulator) {
    var fuelLevel = 100.0;

    if (vehicleSimulator.state.fuelLevel != null) {
      fuelLevel = vehicleSimulator.state.fuelLevel / 100.0;
    }

    return LinearProgressIndicator(
      value: fuelLevel,
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.24),
    );
  }

  Widget fuelConsumptionIndicator(VehicleSimulator vehicleSimulator) {
    return LinearProgressIndicator(
      value: (1 - (vehicleSimulator.state.fuelLevel / 100)),
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.24),
    );
  }

  Widget generateStatWidgets(VehicleSimulator vehicleSimulator) {
    if (vehicleSimulator.journey.odometerBegin == null) {
      return AutoSizeText('Waiting for simulator to start..', group: group);
    } else {
      var distanceTraveled = vehicleSimulator.state.odometer -
          vehicleSimulator.journey.odometerBegin;
      if (distanceTraveled < 0.0) {
        distanceTraveled = 0.0;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AutoSizeText(
            'VIN: ${vehicleSimulator.info.VIN}',
            group: group,
            maxLines: 1,
            minFontSize: minFontSize,
          ),
          AutoSizeText(
            'Odometer: ${vehicleSimulator.state.odometer.toStringAsFixed(2)} km',
            group: group,
            maxLines: 1,
            minFontSize: minFontSize,
          ),
          AutoSizeText(
            'Lat: ${vehicleSimulator.state.latitude.toStringAsPrecision(6)}, Lng: ${vehicleSimulator.state.longitude.toStringAsPrecision(6)}, Heading: ${vehicleSimulator.state.bearing.toInt()}°',
            group: group,
            minFontSize: minFontSize,
          ),
          AutoSizeText(
            'Distance Traveled: ${distanceTraveled.toStringAsFixed(2)} km',
            group: group,
            maxLines: 1,
            minFontSize: minFontSize,
          ),
          AutoSizeText(
            'Vehicle Speed: ${vehicleSimulator.state.vehicleSpeed.toStringAsFixed(2)} km/h',
            group: group,
            maxLines: 1,
            minFontSize: minFontSize,
          ),
          AutoSizeText(
            'Engine Speed: ${vehicleSimulator.state.engineSpeed.toInt()} RPMs',
            group: group,
            maxLines: 1,
            minFontSize: minFontSize,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AutoSizeText(
                  'Fuel Consumed:',
                  group: group,
                  maxLines: 1,
                  minFontSize: minFontSize,
                ),
                fuelConsumptionIndicator(vehicleSimulator),
                AutoSizeText(
                  'Fuel Level:',
                  group: group,
                  maxLines: 1,
                  minFontSize: minFontSize,
                ),
                fuelLevelIndicator(vehicleSimulator),
              ],
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var vehicleSimulator = context.watch<VehicleSimulator>();
    return VehicleDataCard(
      title: 'Vehicle Stats',
      child: Container(
        height: MediaQuery.of(context).size.height,
        child: generateStatWidgets(vehicleSimulator),
      ),
    );
  }
}
