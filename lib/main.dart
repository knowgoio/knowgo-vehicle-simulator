import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:knowgo_vehicle_simulator/server.dart';
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/utils.dart';
import 'package:knowgo_vehicle_simulator/views.dart';
import 'package:provider/provider.dart';

Future<void> main(List<String> arguments) async {
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
    var port = int.parse(portString);
    var parser = ArgParser();
    var usage = 'Usage: knowgo_vehicle_simulator [OPTIONS]...\n\nOptions:\n';

    parser.addFlag('allow-unauthenticated',
        abbr: 'u',
        defaultsTo: true,
        help: 'Allow unauthenticated REST API access');
    parser.addOption('port',
        abbr: 'p',
        defaultsTo: '8086',
        valueHelp: 'PORT',
        help: 'Port to bind HTTP server to');
    parser.addFlag('help',
        abbr: 'h', negatable: false, help: 'Show usage information');

    // Append indented parser generated usage information to usage text
    usage += '    ' +
        parser.usage.replaceAllMapped('\n', (match) {
          return '\n    ';
        });

    try {
      var results = parser.parse(arguments);
      var settingsService = serviceLocator.get<SettingsService>();

      if (results['help']) {
        stdout.writeln(usage);
        exit(0);
      }

      if (results['allow-unauthenticated'] != null) {
        settingsService.allowUnauthenticated = results['allow-unauthenticated'];
      }

      if (results['port'] != null) {
        port = int.parse(results['port']);
      }
    } on FormatException catch (e) {
      stderr.writeln('Error: ${e.message}');
      stderr.writeln(
          'Try \'knowgo_vehicle_simulator --help\' for more information.');
      exit(1);
    }

    // Kick off the HTTP Server Isolate
    final simulatorHttpServer = SimulatorHttpServer(port);

    // Instantiate the Vehicle Simulator, with linkage to the HTTP Server
    vehicleSimulator =
        VehicleSimulator(simulatorHttpServer: simulatorHttpServer);

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
            create: (_) => serviceLocator.get<SettingsService>()),
        ChangeNotifierProvider(
            create: (_) => serviceLocator.get<ConsoleService>()),
        ChangeNotifierProvider.value(value: vehicleSimulator),
        ChangeNotifierProvider.value(value: vehicleSimulator.notificationModel),
        ChangeNotifierProvider(
          create: (_) => EventInjectorModel(),
        ),
      ],
      child: VehicleSimulatorApp(),
    ),
  );
}

class VehicleSimulatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var settingsService = context.watch<SettingsService>();
    return MaterialApp(
      title: 'KnowGo Vehicle Simulator',
      themeMode: settingsService.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        primarySwatch: createMaterialColor(Color(0xff7ace56)),
        primaryColor: const Color(0xff7ace56),
        brightness: Brightness.light,
        indicatorColor: Colors.white,
        textTheme: TextTheme(
          headline6: TextStyle(color: Colors.white),
        ),
        colorScheme: ColorScheme.light(
          primary: const Color(0xff6ab44c),
          onPrimary: Colors.white,
          secondary: const Color(0xff599942),
          onSecondary: Colors.white,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        primarySwatch: createMaterialColor(Color(0xff599942)),
        primaryColor: const Color(0xff599942),
        brightness: Brightness.dark,
        indicatorColor: Colors.white,
        textTheme: TextTheme(
          headline6: TextStyle(color: Colors.white),
        ),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xff599942),
          onPrimary: Colors.white,
          secondary: const Color(0xff50883e),
          onSecondary: Colors.white,
        ),
        appBarTheme: AppBarTheme(color: const Color(0xff599942)),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: FutureBuilder(
        future: serviceLocator.allReady(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            return VehicleSimulatorHome();
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
