import 'package:flutter/material.dart';

// VehicleInfoChip provides a stylized label:value pair for positioning over
// the outer view of the vehicle.
class VehicleInfoChip extends StatelessWidget {
  final String label;
  final String value;

  VehicleInfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.all(Radius.circular(4.0)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.white),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
