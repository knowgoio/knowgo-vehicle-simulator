import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter/material.dart';
import 'package:knowgo_simulator_desktop/icons.dart';
import 'package:knowgo_simulator_desktop/server.dart';
import 'package:knowgo_simulator_desktop/services.dart';
import 'package:knowgo_simulator_desktop/simulator.dart';
import 'package:knowgo_simulator_desktop/utils.dart';
import 'package:knowgo_simulator_desktop/widgets.dart';
import 'package:provider/provider.dart';

Future<void> main(List<String> args) async {
  exitCode = 0;

  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8086', help: 'Port to bind to')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage info');
  final results = parser.parse(args);
  final showHelp = results['help'];
  final port = int.parse(results['port'].toString());

  if (showHelp) {
    print('usage: knowgo-vehicle-simulator [-ph]');
    print(parser.usage);
    exit(1);
  }

  // Kick off any supporting services
  setupServices();

  // Kick off the HTTP Server Isolate
  final simulatorHttpServer = SimulatorHttpServer(port);

  // Instantiate the Vehicle Simulator, and hand it a ReceivePort to communicate
  // with the HTTP Server.
  final vehicleSimulator = VehicleSimulator(simulatorHttpServer.receivePort);

  // Start up the HTTP server, and hand it a ReceivePort to communicate with
  // the Vehicle Simulator.
  await simulatorHttpServer.start(vehicleSimulator.simulatorReceivePort);

  // Establish bi-directional communication and state synchronization between
  // the Vehicle Simulator and the HTTP Server.
  await vehicleSimulator.initHttpSync();

  runApp(
    // Propagate ConsoleService change notifications across the UI
    ChangeNotifierProvider(
      create: (_) => serviceLocator.get<ConsoleService>(),
      child: ChangeNotifierProvider(
        child: VehicleSimulatorApp(),
        create: (_) => vehicleSimulator,
      ),
    ),
  );
}

class VehicleSimulatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
      home: VehicleSimulatorHome(),
    );
  }
}

class VehicleSimulatorHome extends StatefulWidget {
  VehicleSimulatorHome({Key key}) : super(key: key);

  @override
  _VehicleSimulatorHomeState createState() => _VehicleSimulatorHomeState();
}

class _VehicleSimulatorHomeState extends State<VehicleSimulatorHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(KnowGoIcons.knowgo, color: Colors.white),
          onPressed: () {
            return showAboutDialog(
              context: context,
              applicationIcon: Icon(
                KnowGoIcons.knowgo,
                color: Theme.of(context).primaryColor,
              ),
              applicationName: 'KnowGo Vehicle Simulator',
              applicationVersion: '1.0.0',
              applicationLegalese: '© 2020 Adaptant Solutions AG',
            );
          },
        ),
        title: Center(
          child: Text(
            'KnowGo Vehicle Simulator',
            style: Theme.of(context).textTheme.headline6,
          ),
        ),
      ),
      body: Container(
        color: Colors.grey,
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: VehicleOuterView(),
                  ),
                  Expanded(
                    flex: 1,
                    child: VehicleSettings(),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ConsoleLog(),
                  ),
                  Expanded(
                    flex: 1,
                    child: VehicleStats(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
