import 'dart:math';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/widgets.dart';
import 'package:provider/provider.dart';
import 'package:wearable_communicator/wearable_communicator.dart';

class VehicleSettings extends StatefulWidget {
  VehicleSettings();

  @override
  _VehicleSettingsState createState() => _VehicleSettingsState();
}

class _VehicleSettingsState extends State<VehicleSettings> {
  final calculator = VehicleDataCalculator();
  var simulatorRunning = false;
  List<bool> _selections = List.generate(3, (_) => false);
  final _consoleService = serviceLocator<ConsoleService>();

  Widget gearShiftButtons(VehicleSimulator vehicleSimulator) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            var update = vehicleSimulator.state;
            update.transmissionGearPosition =
                vehicleSimulator.state.transmissionGearPosition.nextGear;
            _consoleService
                .write('Shifting up to ${update.transmissionGearPosition}');
            await vehicleSimulator.update(update);
          },
          style: ElevatedButton.styleFrom(
            primary: Theme.of(context).accentColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          icon: Icon(Icons.arrow_upward, color: Colors.white),
          label: Text('Shift up', style: TextStyle(color: Colors.white)),
        ),
        SizedBox(width: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            primary: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: () async {
            var update = vehicleSimulator.state;
            update.transmissionGearPosition =
                vehicleSimulator.state.transmissionGearPosition.prevGear;
            _consoleService
                .write('Shifting down to ${update.transmissionGearPosition}');
            await vehicleSimulator.update(update);
          },
          icon: Icon(Icons.arrow_downward),
          label: Text('Shift down'),
        ),
      ],
    );
  }

  Widget simulatorButton(VehicleSimulator vehicleSimulator) {
    if (simulatorRunning == false) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          primary: Theme.of(context).accentColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: () async {
          _consoleService.write('Starting vehicle');
          WearableCommunicator.sendMessage({
            'text': 'starting vehicle',
            'simulator': 'start',
          });
          await vehicleSimulator.start();
          WearableCommunicator.setData(
              '/knowgo/vehicle/info', vehicleSimulator.info.toJson());
          WearableCommunicator.setData(
              '/knowgo/vehicle/journey', vehicleSimulator.journey.toJson());
          WearableCommunicator.setData(
              '/knowgo/vehicle/state', vehicleSimulator.state.toJson());
          setState(() {
            simulatorRunning = true;
          });
        },
        icon: Icon(Icons.play_arrow, color: Colors.white),
        label: Text('Start Vehicle', style: TextStyle(color: Colors.white)),
      );
    } else {
      return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: () {
            _consoleService.write('Stopping vehicle');
            WearableCommunicator.sendMessage({
              'text': 'stopping vehicle',
              'simulator': 'stop',
              // TODO: Obtain an actual risk score from the risk scoring service
              'score': 20 + Random().nextInt(100 - 20),
            });
            vehicleSimulator.stop();
            // Ensure the Journey is restarted
            vehicleSimulator.journey.journeyID = null;
            setState(() {
              simulatorRunning = false;
            });
          },
          icon: Icon(Icons.stop),
          label: Text('Stop Vehicle'));
    }
  }

  @override
  Widget build(BuildContext context) {
    var vehicleSimulator = context.watch<VehicleSimulator>();
    var acceleratorPosition =
        vehicleSimulator.state.acceleratorPedalPosition ?? 0.0;
    var brakePosition = vehicleSimulator.state.brakePedalPosition ?? 0.0;
    var steeringWheelAngle = vehicleSimulator.state.steeringWheelAngle ?? 0.0;

    return VehicleDataCard(
      title: 'Vehicle Controls',
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(horizontal: 10),
        children: [
          VehicleDataSlider(
            title: 'Accelerator',
            min: 0,
            max: 100,
            divisions: 10,
            value: acceleratorPosition,
            label: acceleratorPosition.toString(),
            onChanged: (value) {
              setState(() {
                vehicleSimulator.state.acceleratorPedalPosition = value;
              });
            },
            onChangeEnd: (value) async {
              var update = vehicleSimulator.state;
              update.acceleratorPedalPosition = value;
              await vehicleSimulator.update(update);
              _consoleService.write(
                  'Setting Accelerator Pedal to ${value.toInt().toString()}%');
            },
          ),
          VehicleDataSlider(
            title: 'Brake',
            value: brakePosition,
            label: brakePosition.toString(),
            min: 0,
            max: 100,
            divisions: 10,
            onChanged: (value) {
              setState(() {
                vehicleSimulator.state.brakePedalPosition = value;
              });
            },
            onChangeEnd: (value) async {
              var update = vehicleSimulator.state;
              update.brakePedalPosition = value;
              await vehicleSimulator.update(update);
              _consoleService
                  .write('Setting Brake Pedal to ${value.toInt().toString()}%');
            },
          ),
          VehicleDataSlider(
            title: 'Steering',
            value: steeringWheelAngle,
            label: steeringWheelAngle.toStringAsFixed(1),
            min: -180,
            max: 180,
            divisions: 10,
            onChanged: (value) {
              setState(() {
                vehicleSimulator.state.steeringWheelAngle =
                    value.roundToDouble();
              });
            },
            onChangeEnd: (value) async {
              var update = vehicleSimulator.state;
              update.steeringWheelAngle = value;
              await vehicleSimulator.update(update);
              _consoleService.write(
                  'Setting Steering Wheel to ${value.round().toString()}°');
            },
          ),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Theme.of(context).primaryColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('Gear Shift'),
                SizedBox(height: 4),
                gearShiftButtons(vehicleSimulator),
              ],
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16.0,
            runSpacing: 4.0,
            children: [
              Text('Switches'),
              ToggleButtons(
                children: [
                  _selections[0] == false
                      ? Icon(Icons.lock_open)
                      : Icon(Icons.lock_outline),
                  FaIcon(FontAwesomeIcons.umbrella),
                  _selections[2] == false
                      ? Icon(Icons.brightness_low)
                      : Icon(Icons.brightness_high),
                ],
                isSelected: _selections,
                borderRadius: BorderRadius.circular(30),
                color: Colors.black45,
                borderColor: Theme.of(context).primaryColor,
                disabledBorderColor: Theme.of(context).primaryColor,
                onPressed: (int index) async {
                  final setting = !_selections[index];
                  var update = vehicleSimulator.state;

                  switch (index) {
                    case 0:
                      _consoleService.write(
                          (setting ? 'Locking' : 'Unlocking') + ' doors');
                      update.doorStatus = setting
                          ? knowgo.DoorStatus.all_locked
                          : knowgo.DoorStatus.all_unlocked;
                      break;
                    case 1:
                      _consoleService.write('Turning windshield wipers ' +
                          (setting ? 'on' : 'off'));
                      update.windshieldWiperStatus = setting;
                      break;
                    case 2:
                      _consoleService.write(
                          'Turning headlamp ' + (setting ? 'on' : 'off'));
                      update.headlampStatus = setting;
                      break;
                  }
                  await vehicleSimulator.update(update);
                  setState(() {
                    _selections[index] = setting;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: simulatorButton(vehicleSimulator),
          ),
        ],
      ),
    );
  }
}
