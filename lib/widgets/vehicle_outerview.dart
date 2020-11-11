import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:knowgo/api.dart';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'package:knowgo_simulator_desktop/widgets.dart';
import 'package:provider/provider.dart';

class VehicleOuterView extends StatefulWidget {
  const VehicleOuterView({Key key}) : super(key: key);

  @override
  _VehicleOuterViewState createState() => _VehicleOuterViewState();
}

class _VehicleOuterViewState extends State<VehicleOuterView>
    with WidgetsBindingObserver {
  double width, height;
  double origWidth, origHeight;
  var wiperChipTopPosition = 125.0;
  var wiperChipLeftPosition = 300.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => recalculateSize());
    WidgetsBinding.instance.addObserver(this);
  }

  // Fix up relative positioning of labels in line with RenderBox size changes
  void recalculateSize() {
    final RenderBox box = context.findRenderObject();
    setState(() {
      width = box.size.width;
      height = box.size.height;

      if (origWidth == null || origHeight == null) {
        origWidth = width;
        origHeight = height;
      }
    });
  }

  @override
  void didChangeMetrics() {
    recalculateSize();
    super.didChangeMetrics();
  }

  @override
  Widget build(BuildContext context) {
    final RenderBox box = context.findRenderObject();
    var vehicleSimulator = context.watch<VehicleSimulator>();
    var state = vehicleSimulator.state;

    if (width != null && height != null) {
      final heightDelta = box.size.height - origHeight;
      final widthDelta = box.size.width - origWidth;

      wiperChipLeftPosition = (width * 0.3125) + (widthDelta / 2);
      wiperChipTopPosition = (height * 0.2822) + heightDelta;
/*
      print('Adjusting chip left position to $wiperChipLeftPosition');
      print('Adjusting chip top position to $wiperChipTopPosition');

      print('Redraw Height: ${box.size.height}, Width: ${box.size.width}');

 */
    }

    return Stack(
      children: [
        Card(
          child: Container(
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
        Positioned(
          top: wiperChipTopPosition,
          left: wiperChipLeftPosition,
          child: VehicleInfoChip(
            label: 'wipers',
            value: state.windshieldWiperStatus ? 'on' : 'off',
          ),
        ),
        Positioned(
          bottom: 225,
          left: 400,
          child: VehicleInfoChip(
            label: 'doors',
            value: describeEnum(state.doorStatus),
          ),
        ),
        Positioned(
          bottom: 225,
          left: 150,
          child: VehicleInfoChip(
            label: 'headlamp',
            value: state.headlampStatus ? 'on' : 'off',
          ),
        ),
        Positioned(
          bottom: 175,
          left: 300,
          child: VehicleInfoChip(
            label: 'gear',
            value: state.transmissionGearPosition.gearNumber.toString(),
          ),
        ),
      ],
    );
  }
}
