import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knowgo/api.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/widgets.dart';
import 'package:provider/provider.dart';

class VehicleOuterView extends StatefulWidget {
  const VehicleOuterView({Key? key}) : super(key: key);

  @override
  _VehicleOuterViewState createState() => _VehicleOuterViewState();
}

class _VehicleOuterViewState extends State<VehicleOuterView>
    with WidgetsBindingObserver {
  double? width, height;
  double? origWidth, origHeight;
  var wiperChipBottomPosition = 300.0;
  var wiperChipLeftPosition = 300.0;
  var doorChipBottomPosition = 225.0;
  var doorChipLeftPosition = 400.0;
  var gearChipBottomPosition = 175.0;
  var gearChipLeftPosition = 300.0;
  var headlampChipBottomPosition = 225.0;
  var headlampChipLeftPosition = 150.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addPostFrameCallback((_) => recalculateSize());
    WidgetsBinding.instance?.addObserver(this);
  }

  // Fix up relative positioning of labels in line with RenderBox size changes
  void recalculateSize() {
    final box = context.findRenderObject();
    if (box is RenderBox) {
      setState(() {
        width = box.size.width;
        height = box.size.height;

        if (origWidth == null || origHeight == null) {
          origWidth = width;
          origHeight = height;
        }
      });
    }
  }

  @override
  void didChangeMetrics() {
    if (mounted) {
      recalculateSize();
    }
    super.didChangeMetrics();
  }

  @override
  Widget build(BuildContext context) {
    final box = context.findRenderObject();
    var vehicleSimulator = context.watch<VehicleSimulator>();
    var state = vehicleSimulator.state;

    if (width != null && height != null && box is RenderBox) {
      final heightDelta = box.size.height - origHeight!;
      final widthDelta = box.size.width - origWidth!;

      wiperChipLeftPosition = (width! * 0.3125) + (widthDelta / 2);
      wiperChipBottomPosition = (height! * 0.6822) - (heightDelta / 2);

      gearChipLeftPosition = wiperChipLeftPosition;
      gearChipBottomPosition = wiperChipBottomPosition - (height! / 3);

      headlampChipLeftPosition = (gearChipLeftPosition / 2);
      headlampChipBottomPosition = gearChipBottomPosition +
          (wiperChipBottomPosition - gearChipBottomPosition) / 2;

      doorChipLeftPosition = wiperChipLeftPosition +
          (wiperChipLeftPosition - headlampChipLeftPosition);
      doorChipBottomPosition = headlampChipBottomPosition;
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
          bottom: wiperChipBottomPosition,
          left: wiperChipLeftPosition,
          child: VehicleInfoChip(
            label: 'wipers',
            value: state.windshieldWiperStatus! ? 'on' : 'off',
          ),
        ),
        Positioned(
          bottom: doorChipBottomPosition,
          left: doorChipLeftPosition,
          child: VehicleInfoChip(
            label: 'doors',
            value: describeEnum(state.doorStatus!),
          ),
        ),
        Positioned(
          bottom: headlampChipBottomPosition,
          left: headlampChipLeftPosition,
          child: VehicleInfoChip(
            label: 'headlamp',
            value: state.headlampStatus! ? 'on' : 'off',
          ),
        ),
        Positioned(
          bottom: gearChipBottomPosition,
          left: gearChipLeftPosition,
          child: VehicleInfoChip(
            label: 'gear',
            value: state.transmissionGearPosition!.gearNumber.toString(),
          ),
        ),
      ],
    );
  }
}
