import 'package:flutter/material.dart';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'package:knowgo_simulator_desktop/widgets.dart';

void main() {
  runApp(VehicleSimulatorApp());
}

class VehicleSimulatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KnowGo Vehicle Simulator',
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: VehicleSimulatorHome(),
    );
  }
}

class VehicleSimulatorHome extends StatefulWidget {
  VehicleSimulatorHome({Key key}) : super(key: key);

  @override
  _VehicleSimulatorHomeState createState() => _VehicleSimulatorHomeState();
}

class _VehicleSimulatorHomeState extends State<VehicleSimulatorHome> {
  double odometer = 0.0;
  double fuelConsumed = 0.0;
  double fuelLevel = 100.0;

  @override
  Widget build(BuildContext context) {
    if (vehicleSimulator.events.length > 0) {
      final last = vehicleSimulator.events.last;

      odometer = last.odometer;
      fuelConsumed = last.fuelConsumedSinceRestart;
      fuelLevel = last.fuelLevel;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('KnowGo Vehicle Simulator'),
      ),
      body: Container(
        color: Colors.grey,
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: VehicleOuterView(),
                  ),
                  Expanded(
                    flex: 1,
                    child: VehicleSettings(vehicleSimulator.state),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: EventLog(),
                  ),
                  Expanded(
                    flex: 1,
                    child: VehicleStats(vehicleSimulator.state),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
