import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class VehicleOuterView extends StatefulWidget {
  @override
  _VehicleOuterViewState createState() => _VehicleOuterViewState();
}

class _VehicleOuterViewState extends State<VehicleOuterView> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(child:
        Container(
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
      ],
    );
  }
}
