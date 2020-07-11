import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'package:knowgo_simulator_desktop/widgets.dart';
import 'package:provider/provider.dart';

class VehicleOuterView extends StatefulWidget {
  @override
  _VehicleOuterViewState createState() => _VehicleOuterViewState();
}

class _VehicleOuterViewState extends State<VehicleOuterView> {
  @override
  Widget build(BuildContext context) {
    var vehicleSimulator = context.watch<VehicleSimulator>();
    var state = vehicleSimulator.state;

    return Stack(
      children: [
        Card(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(4.0)),
              image: DecorationImage(
                image: AssetImage('assets/car_driving.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment(1.0, 1.0),
              ),
            ),
          ),
        ),
        Positioned(
          top: 125,
          left: 300,
          child: VehicleInfoChip(
            label: 'wipers',
            value: (state.windshieldWiperStatus == 'true') ? 'on' : 'off',
          ),
        ),
        Positioned(
          bottom: 225,
          left: 400,
          child: VehicleInfoChip(
            label: 'doors',
            value: (state.doorStatus == 'driver') ? 'locked' : 'unlocked',
          ),
        ),
        Positioned(
          bottom: 225,
          left: 150,
          child: VehicleInfoChip(
            label: 'headlamp',
            value: (state.headlampStatus == 'true') ? 'on' : 'off',
          ),
        ),
        Positioned(
          bottom: 175,
          left: 300,
          child: VehicleInfoChip(
            label: 'gear',
            value: state.transmissionGearPosition,
          ),
        ),
      ],
    );
  }
}
