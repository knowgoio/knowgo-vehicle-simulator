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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        RaisedButton.icon(
          onPressed: () async {
            var update = vehicleSimulator.state;
            update.transmissionGearPosition = calculator.nextGear(update);
            await vehicleSimulator.update(update);
          },
          icon: Icon(Icons.arrow_upward),
          label: Text('Shift up'),
        ),
        RaisedButton.icon(
          onPressed: () async {
            var update = vehicleSimulator.state;
            update.transmissionGearPosition = calculator.prevGear(update);
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
          onPressed: () async {
            await vehicleSimulator.start();
            setState(() {
              simulatorRunning = true;
            });
          },
          icon: Icon(Icons.play_arrow),
          label: Text('Start Vehicle'));
    } else {
      return RaisedButton.icon(
          onPressed: () {
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

    return Column(
      children: [
        Text('Accelerator Pedal'),
        Slider(
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
          },
        ),
        gearShiftButtons(vehicleSimulator),
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
          disabledColor: Colors.grey,
          disabledBorderColor: Colors.blueGrey,
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
                _consoleService.write(
                    'Turning windshield wipers ' + (setting ? 'on' : 'off'));
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
        simulatorButton(vehicleSimulator),
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
