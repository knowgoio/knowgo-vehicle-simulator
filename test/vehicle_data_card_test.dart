import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowgo_vehicle_simulator/widgets.dart';

void main() {
  testWidgets('VehicleDataCard contains title and child',
      (WidgetTester tester) async {
    // Create an instance of the VehicleDataCard with a DummyWidget child
    await tester
        .pumpWidget(VehicleDataCardTest(title: 'Title', child: DummyWidget()));

    // Search for matching title
    final titleFinder = find.text('Title');
    expect(titleFinder, findsOneWidget);

    // Search for matching child
    expect(find.byType(DummyWidget), findsOneWidget);
  });
}

// Create a Dummy widget to discover
class DummyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class VehicleDataCardTest extends StatelessWidget {
  final String title;
  final Widget child;

  const VehicleDataCardTest({
    Key key,
    @required this.title,
    @required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VehicleDataCard Widget Test',
      home: Scaffold(
        body: Center(child: VehicleDataCard(title: title, child: child)),
      ),
    );
  }
}
