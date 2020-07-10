import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'package:knowgo_simulator_desktop/widgets/vehicle_data_card.dart';
import 'package:provider/provider.dart';

class EventLog extends StatefulWidget {
  @override
  _EventLogState createState() => _EventLogState();
}

class _EventLogState extends State<EventLog> {
  Widget generateVehicleEventList(VehicleSimulator vehicleSimulator) {
    var events = vehicleSimulator.journey.events;

    if (vehicleSimulator.running == false) {
      return Text('Waiting for simulator to start..');
    } else {
      return ListView.builder(
        shrinkWrap: true,
        itemCount: events.length,
        itemBuilder: (BuildContext context, int index) {
          var last = events.length - index - 1;
          var jsonStr = jsonEncode(events[last]);
          return Text(jsonStr);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var vehicleSimulator = context.watch<VehicleSimulator>();
    return VehicleDataCard(
      title: 'Vehicle Event Log',
      child: generateVehicleEventList(vehicleSimulator),
    );
  }
}
