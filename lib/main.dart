import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:knowgo_vehicle_simulator/server.dart';
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/utils.dart';
import 'package:knowgo_vehicle_simulator/views.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  VehicleSimulator vehicleSimulator;

  // Kick off any supporting services
  setupServices();
  await serviceLocator.allReady();

  // In Flutter web instances, we do not expose the REST server
  if (kIsWeb) {
    vehicleSimulator = VehicleSimulator();
  } else {
    const String portString = String.fromEnvironment(
        'KNOWGO_VEHICLE_SIMULATOR_PORT',
        defaultValue: '8086');
    final port = int.parse(portString);

    // Kick off the HTTP Server Isolate
    final simulatorHttpServer = SimulatorHttpServer(port);

    // Instantiate the Vehicle Simulator, and hand it a ReceivePort to
    // communicate with the HTTP Server.
    vehicleSimulator = VehicleSimulator(simulatorHttpServer.receivePort);

    // Start up the HTTP server, and hand it a ReceivePort to communicate with
    // the Vehicle Simulator.
    await simulatorHttpServer.start(vehicleSimulator.simulatorReceivePort);

    // Establish bi-directional communication and state synchronization between
    // the Vehicle Simulator and the HTTP Server.
    await vehicleSimulator.initHttpSync();
  }

  Provider.debugCheckInvalidValueType = null;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => serviceLocator.get<ConsoleService>()),
        ChangeNotifierProvider.value(value: vehicleSimulator),
        ChangeNotifierProvider.value(value: vehicleSimulator.notificationModel),
      ],
      child: VehicleSimulatorApp(),
    ),
  );
}

class VehicleSimulatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bool useMobileLayout = getDeviceType() == DeviceType.phone;

    return MaterialApp(
      title: 'KnowGo Vehicle Simulator',
      theme: ThemeData(
        primarySwatch: createMaterialColor(Color(0xff7ace56)),
        primaryColor: const Color(0xff7ace56),
        accentColor: const Color(0xff599942),
        brightness: Brightness.light,
        indicatorColor: Colors.white,
        textTheme: TextTheme(
          headline6: TextStyle(color: Colors.white),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: FutureBuilder(
        future: serviceLocator.allReady(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            return VehicleSimulatorHome(useMobileLayout: useMobileLayout);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
