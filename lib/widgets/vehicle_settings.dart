import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/widgets.dart';
import 'package:provider/provider.dart';

class VehicleSettings extends StatefulWidget {
  VehicleSettings();

  @override
  _VehicleSettingsState createState() => _VehicleSettingsState();
}

class _VehicleSettingsState extends State<VehicleSettings> {
  final calculator = VehicleDataCalculator();
  static const automationLevelsDesc = [
    'No driving automation',
    'Driver assistance',
    'Partial driving automation',
    'Conditional driving automation',
    'High driving automation',
    'Full driving automation'
  ];
  final autoSizeGroup = AutoSizeGroup();
  final sliderTextSizeGroup = AutoSizeGroup();
  List<bool> _selections = List.generate(3, (_) => false);
  final _consoleService = serviceLocator<ConsoleService>();

  Widget gearShiftButtons(VehicleSimulator vehicleSimulator) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      spacing: 10.0,
      runSpacing: 10.0,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            var update = vehicleSimulator.state;
            var prevGear = update.transmissionGearPosition;
            update.transmissionGearPosition = calculator
                .nextGear(vehicleSimulator.state.transmissionGearPosition!);
            if (prevGear != update.transmissionGearPosition) {
              _consoleService.write(
                  'Shifting up to ${describeEnum(update.transmissionGearPosition!)}');
              await vehicleSimulator.update(update);
            }
          },
          style: ElevatedButton.styleFrom(
            primary: Theme.of(context).colorScheme.secondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          icon: Icon(Icons.arrow_upward, color: Colors.white),
          label: AutoSizeText('Shift up',
              style: TextStyle(color: Colors.white), group: autoSizeGroup),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            primary: Colors.grey[300],
            onPrimary: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: () async {
            var update = vehicleSimulator.state;
            var prevGear = update.transmissionGearPosition;
            update.transmissionGearPosition =
                vehicleSimulator.state.transmissionGearPosition!.prevGear;
            if (prevGear != update.transmissionGearPosition) {
              _consoleService.write(
                  'Shifting down to ${describeEnum(update.transmissionGearPosition!)}');
              await vehicleSimulator.update(update);
            }
          },
          icon: Icon(Icons.arrow_downward),
          label: AutoSizeText('Shift down', group: autoSizeGroup, maxLines: 1),
        ),
      ],
    );
  }

  Widget simulatorButton(VehicleSimulator vehicleSimulator) {
    if (vehicleSimulator.running == false) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          primary: Theme.of(context).colorScheme.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: () async {
          await vehicleSimulator.start();
          setState(() {
            vehicleSimulator.running = true;
          });
        },
        icon: Icon(Icons.play_arrow, color: Colors.white),
        label: AutoSizeText('Start Vehicle',
            group: autoSizeGroup,
            style: TextStyle(color: Colors.white),
            minFontSize: 8,
            maxLines: 1),
      );
    } else {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: () {
          vehicleSimulator.stop();
          // Ensure the Journey is restarted
          vehicleSimulator.journey.journeyID = null;
          setState(() {
            vehicleSimulator.running = false;
          });
        },
        icon: Icon(Icons.stop),
        label: AutoSizeText('Stop Vehicle', group: autoSizeGroup, maxLines: 1),
      );
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
      child: Column(
        children: [
          Expanded(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: 10),
              children: [
                VehicleDataSlider(
                  title: 'Accelerator',
                  overflowTitle: 'Accel',
                  min: 0,
                  max: 100,
                  divisions: 10,
                  value: acceleratorPosition,
                  label: acceleratorPosition.toString(),
                  textGroup: sliderTextSizeGroup,
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
                  overflowTitle: 'Brake',
                  value: brakePosition,
                  label: brakePosition.toString(),
                  textGroup: sliderTextSizeGroup,
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
                    _consoleService.write(
                        'Setting Brake Pedal to ${value.toInt().toString()}%');
                  },
                ),
                VehicleDataSlider(
                  title: 'Steering',
                  overflowTitle: 'Steer',
                  value: steeringWheelAngle,
                  label: steeringWheelAngle.toStringAsFixed(1),
                  textGroup: sliderTextSizeGroup,
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
                Visibility(
                  visible: vehicleSimulator.info.transmission == 'manual',
                  child: SizedBox(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: Theme.of(context).primaryColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                AutoSizeText('Gear Shift',
                                    group: autoSizeGroup, maxLines: 1),
                                SizedBox(height: 4),
                                gearShiftButtons(vehicleSimulator),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16.0,
                      runSpacing: 4.0,
                      children: [
                        AutoSizeText('Switches', group: autoSizeGroup),
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
                                    (setting ? 'Locking' : 'Unlocking') +
                                        ' doors');
                                update.doorStatus = setting
                                    ? knowgo.DoorStatus.all_locked
                                    : knowgo.DoorStatus.all_unlocked;
                                break;
                              case 1:
                                _consoleService.write(
                                    'Turning windshield wipers ' +
                                        (setting ? 'on' : 'off'));
                                update.windshieldWiperStatus = setting;
                                break;
                              case 2:
                                _consoleService.write('Turning headlamp ' +
                                    (setting ? 'on' : 'off'));
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
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DropdownButton(
                      value: automationLevelsDesc[
                              vehicleSimulator.state.automationLevel!]
                          .toString(),
                      underline: Container(
                          height: 2, color: Theme.of(context).primaryColor),
                      icon: Icon(Icons.arrow_drop_down,
                          color: Theme.of(context).colorScheme.secondary),
                      items: automationLevelsDesc.map((level) {
                        return DropdownMenuItem<String>(
                          value: level,
                          child: AutoSizeText(level.toString(),
                              group: autoSizeGroup, maxLines: 1),
                        );
                      }).toList(),
                      onChanged: (String? value) async {
                        if (value != null) {
                          var update = vehicleSimulator.state;
                          update.automationLevel =
                              automationLevelsDesc.indexOf(value);
                          await vehicleSimulator.update(update);
                          _consoleService.write(
                              'Setting automation level to ${update.automationLevel}');
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: simulatorButton(vehicleSimulator)),
          ),
        ],
      ),
    );
  }
}
