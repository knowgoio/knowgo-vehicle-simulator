import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowgo_vehicle_simulator/widgets.dart';

void main() {
  testWidgets('VehicleInfoChip contains label and value',
      (WidgetTester tester) async {
    // Create an instance of the VehicleInfoChip
    await tester
        .pumpWidget(VehicleInfoChipTest(label: 'label', value: 'value'));

    // Ensure that only a single RichText widget is created
    expect(find.byType(RichText), findsOneWidget);

    // Text finders do not work on RichText widgets, so we must convert the
    // widget text to plaintext for matching.
    final richText = find.byType(RichText).evaluate().first.widget;
    if (richText is RichText) {
      final richTextText = richText.text.toPlainText();

      expect(richTextText, 'label: value');
    }
  });
}

class VehicleInfoChipTest extends StatelessWidget {
  final String label;
  final String value;

  const VehicleInfoChipTest({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VehicleInfoChip Widget Test',
      home: Scaffold(
        body: Center(
          child: VehicleInfoChip(label: label, value: value),
        ),
      ),
    );
  }
}
