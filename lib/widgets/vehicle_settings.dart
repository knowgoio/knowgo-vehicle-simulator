import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:knowgo_simulator_desktop/services.dart';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'package:knowgo_simulator_desktop/widgets/vehicle_data_card.dart';
import 'package:provider/provider.dart';

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
      alignment: WrapAlignment.spaceEvenly,
      children: [
        RaisedButton.icon(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          onPressed: () async {
            var update = vehicleSimulator.state;
            update.transmissionGearPosition = calculator.nextGear(update);
            _consoleService
                .write('Shifting up to ${update.transmissionGearPosition}');
            await vehicleSimulator.update(update);
          },
          color: Theme.of(context).accentColor,
          icon: Icon(Icons.arrow_upward, color: Colors.white),
          label: Text('Shift up', style: TextStyle(color: Colors.white)),
        ),
        RaisedButton.icon(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          onPressed: () async {
            var update = vehicleSimulator.state;
            update.transmissionGearPosition = calculator.prevGear(update);
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
      return RaisedButton.icon(
        color: Theme.of(context).accentColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        onPressed: () async {
          _consoleService.write('Starting vehicle');
          await vehicleSimulator.start();
          setState(() {
            simulatorRunning = true;
          });
        },
        icon: Icon(Icons.play_arrow, color: Colors.white),
        label: Text('Start Vehicle', style: TextStyle(color: Colors.white)),
      );
    } else {
      return RaisedButton.icon(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          onPressed: () {
            _consoleService.write('Stopping vehicle');
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

  Widget generateVehicleControls(VehicleSimulator vehicleSimulator) {
    var acceleratorPosition =
        vehicleSimulator.state.acceleratorPedalPosition ?? 0.0;
    var steeringWheelAngle = vehicleSimulator.state.steeringWheelAngle ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.max,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          direction: Axis.horizontal,
          children: [
            Text('Accelerator'),
            Slider.adaptive(
              value: acceleratorPosition,
              min: 0,
              max: 100,
              divisions: 10,
              label: '${acceleratorPosition.toString()}',
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
          ],
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          direction: Axis.horizontal,
          children: [
            Text('Steering Wheel Angle'),
            Slider.adaptive(
              value: steeringWheelAngle,
              min: -180,
              max: 180,
              divisions: 10,
              label: '${steeringWheelAngle.toStringAsFixed(1)}',
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
          ],
        ),
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Theme.of(context).primaryColor),
          ),
          child: Column(
            children: [
              Text('Gear Shift'),
              gearShiftButtons(vehicleSimulator),
            ],
          ),
        ),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 16.0,
          runSpacing: 4.0,
          crossAxisAlignment: WrapCrossAlignment.center,
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
                    _consoleService
                        .write((setting ? 'Locking' : 'Unlocking') + ' doors');
                    update.doorStatus = setting ? 'driver' : null;
                    break;
                  case 1:
                    _consoleService.write('Turning windshield wipers ' +
                        (setting ? 'on' : 'off'));
                    update.windshieldWiperStatus = setting.toString();
                    break;
                  case 2:
                    _consoleService
                        .write('Turning headlamp ' + (setting ? 'on' : 'off'));
                    update.headlampStatus = setting.toString();
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
        SizedBox(
          width: double.infinity,
          child: simulatorButton(vehicleSimulator),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var vehicleSimulator = context.watch<VehicleSimulator>();

    return VehicleDataCard(
      title: 'Vehicle Controls',
      child: generateVehicleControls(vehicleSimulator),
    );
  }
}
