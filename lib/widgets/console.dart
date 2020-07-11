import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:knowgo_simulator_desktop/services.dart';
import 'package:knowgo_simulator_desktop/widgets/vehicle_data_card.dart';
import 'package:provider/provider.dart';

class ConsoleLog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var consoleService = context.watch<ConsoleService>();

    return VehicleDataCard(
      title: 'Console',
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: consoleService.messages.length,
        itemBuilder: (BuildContext context, int index) {
          var last = consoleService.messages.length - index - 1;
          var msg = consoleService.messages[last];
          var timeStr = DateFormat('yyyy-MM-dd hh:mm:ss').format(msg.timestamp);

          return RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.blueGrey),
              children: [
                TextSpan(
                  text: '[$timeStr] ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: msg.message,
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
