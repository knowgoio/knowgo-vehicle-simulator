import 'package:flutter/material.dart';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'package:provider/provider.dart';

class VehicleSettings extends StatefulWidget {
  VehicleSettings();

  @override
  _VehicleSettingsState createState() => _VehicleSettingsState();
}

class _VehicleSettingsState extends State<VehicleSettings> {
  var simulatorRunning = false;

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

    return Card(
      child: Container(
        padding: EdgeInsets.all(10.0),
        child: Column(
          children: [
            Text('Vehicle Controls',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
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
            simulatorButton(vehicleSimulator),
          ],
        ),
      ),
    );
  }
}
