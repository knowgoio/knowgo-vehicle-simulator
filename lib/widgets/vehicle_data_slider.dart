import 'package:flutter/material.dart';

class VehicleDataSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final String title;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  VehicleDataSlider({
    @required this.value,
    @required this.min,
    @required this.max,
    @required this.label,
    @required this.title,
    this.onChanged,
    this.onChangeEnd,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceAround,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 75,
          child: Text(title, textAlign: TextAlign.center),
        ),
        Slider.adaptive(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: (value) => (onChanged != null) ? onChanged(value) : null,
          onChangeEnd: (value) =>
              (onChangeEnd != null) ? onChangeEnd(value) : null,
        ),
      ],
    );
  }
}
