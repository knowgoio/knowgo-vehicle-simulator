import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'dart:async';

class EventLog extends StatefulWidget {
  @override
  _EventLogState createState() => _EventLogState();
}

class _EventLogState extends State<EventLog> {
  Timer _tick;

  void initState() {
    super.initState();
    _tick = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  void dispose() {
    super.dispose();
    _tick.cancel();
  }

  @override
  Widget build(BuildContext context) {
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
                  itemCount: vehicleSimulator.events.length,
                  itemBuilder: (BuildContext context, int index) {
                    var last = vehicleSimulator.events.length - index - 1;
                    var jsonStr = jsonEncode(vehicleSimulator.events[last]);
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
