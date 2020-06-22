import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'package:knowgo/api.dart' as knowgo;
import 'dart:async';

class VehicleStats extends StatefulWidget {
  final knowgo.Event vehicleState;

  VehicleStats(this.vehicleState);

  @override
  _VehicleStatsState createState() => _VehicleStatsState();
}

class _VehicleStatsState extends State<VehicleStats> {
  Timer _tick;

  void initState() {
    super.initState();
    _tick = Timer.periodic(Duration(seconds: 1), (timer) {
      if (widget.vehicleState.fuelLevel != null && widget.vehicleState.fuelLevel <= 0.0) {
        vehicleSimulator.stop();
        setState(() {
          vehicleSimulator.state.ignitionStatus = 'off';
        });
      }
      setState(() {});
    });
  }

  void dispose() {
    super.dispose();
    _tick.cancel();
  }

  Widget fuelLevelIndicator() {
    if (widget.vehicleState != null && widget.vehicleState.fuelLevel != null) {
      return LinearProgressIndicator(value: widget.vehicleState.fuelLevel / 100.0);
    } else {
      return LinearProgressIndicator();
    }
  }

  Widget fuelConsumptionIndicator() {
    if (widget.vehicleState != null &&
        widget.vehicleState.fuelConsumedSinceRestart != null &&
        widget.vehicleState.fuelLevel != null) {
      var fuelConsumed = widget.vehicleState.fuelConsumedSinceRestart / widget.vehicleState.fuelLevel;
      return LinearProgressIndicator(value: fuelConsumed);
    } else {
      return LinearProgressIndicator();
    }
  }

  Widget generateStatWidgets() {
    if (vehicleSimulator.running == false) {
      return Column(
        children: <Widget>[
          Text('Vehicle Stats', style: TextStyle(fontWeight: FontWeight.bold)),
          Spacer(flex: 1),
          Text('Waiting for simulator to start..'),
          Spacer(flex: 1),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(child: Text(
              'Vehicle Stats', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(height: 10),
          Text('Generated VIN: ${vehicleSimulator.info?.VIN}'),
          Text('Odometer: ${widget.vehicleState.odometer.toString()}'),
          Text('Vehicle Speed: ${widget.vehicleState.vehicleSpeed.toString()}'),
          Text('Fuel Consumed:'),
          fuelConsumptionIndicator(),
          Text('Fuel Level:'),
          fuelLevelIndicator(),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: EdgeInsets.all(10.0),
        child: generateStatWidgets(),
      ),
    );
  }
}
