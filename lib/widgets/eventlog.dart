import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'package:provider/provider.dart';

class EventLog extends StatefulWidget {
  @override
  _EventLogState createState() => _EventLogState();
}

class _EventLogState extends State<EventLog> {
  @override
  Widget build(BuildContext context) {
    var events = context.watch<VehicleSimulator>().events;
    return Card(
      child: Container(
        padding: EdgeInsets.only(top: 10, left: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vehicle Event Log',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: events.length,
                  itemBuilder: (BuildContext context, int index) {
                    var last = events.length - index - 1;
                    var jsonStr = jsonEncode(events[last]);
                    return Text(jsonStr);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
