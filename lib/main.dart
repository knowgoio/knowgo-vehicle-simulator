import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:knowgo_vehicle_simulator/icons.dart';
import 'package:knowgo_vehicle_simulator/server.dart';
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/utils.dart';
import 'package:knowgo_vehicle_simulator/widgets.dart';
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
            return VehicleSimulatorHome();
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class VehicleSimulatorHome extends StatefulWidget {
  VehicleSimulatorHome({Key? key}) : super(key: key);

  @override
  _VehicleSimulatorHomeState createState() => _VehicleSimulatorHomeState();
}

class _VehicleSimulatorHomeState extends State<VehicleSimulatorHome> {
  var settingsService = serviceLocator.get<SettingsService>();

  @override
  void initState() {
    super.initState();

    var model = Provider.of<VehicleNotificationModel>(context, listen: false);
    model.addListener(_vehicleNotificationListener);
  }

  void _vehicleNotificationListener() {
    var model = Provider.of<VehicleNotificationModel>(context, listen: false);
    var consoleService = serviceLocator.get<ConsoleService>();

    model.notifications.forEach((notification) {
      consoleService
          .write('Received vehicle notification: ${notification.text}');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(notification.text)));
    });

    model.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            AppBar(
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title:
                  Text('Configuration', style: TextStyle(color: Colors.white)),
              actions: [
                Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.settings, color: Colors.white),
                ),
              ],
            ),
            CheckboxListTile(
              title: const Text('Event Logging'),
              subtitle: const Text('Log generated events'),
              value: settingsService.eventLoggingEnabled,
              onChanged: (bool? value) {
                if (value != null) {
                  setState(() {
                    settingsService.eventLoggingEnabled = value;
                  });
                }
              },
            ),
            CheckboxListTile(
              title: const Text('Session Logging'),
              subtitle: const Text('Save session log'),
              value: settingsService.loggingEnabled,
              onChanged: (bool? value) {
                if (value != null) {
                  setState(() {
                    settingsService.loggingEnabled = value;
                  });
                }
              },
            ),
            ListTile(
              title: const Text('Event Notification Endpoint'),
              subtitle: Text(settingsService.notificationEndpoint ?? ''),
              trailing: IconButton(
                icon: Icon(Icons.edit),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext buildContext) {
                      return TextFieldAlertDialog(
                        title: 'Event Notification Endpoint',
                        initialValue:
                            settingsService.notificationEndpoint ?? '',
                        onSubmitted: (value) {
                          setState(() {
                            settingsService.notificationEndpoint = value;
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            CheckboxListTile(
              title: const Text('KnowGo Backend Support'),
              value: settingsService.knowgoEnabled,
              onChanged: (bool? value) {
                if (value != null) {
                  setState(() {
                    settingsService.knowgoEnabled = value;
                  });
                }
              },
            ),
            Visibility(
              visible: settingsService.knowgoEnabled,
              child: ListTile(
                title: const Text('KnowGo Server'),
                subtitle: Text(settingsService.knowgoServer ?? ''),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext buildContext) {
                        return TextFieldAlertDialog(
                          title: 'KnowGo Server',
                          initialValue: settingsService.knowgoServer ?? '',
                          onSubmitted: (value) {
                            setState(() {
                              settingsService.knowgoServer = value;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            Visibility(
              visible: settingsService.knowgoEnabled,
              child: ListTile(
                title: const Text('KnowGo API Key'),
                subtitle: Text(settingsService.knowgoApiKey ?? ''),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext buildContext) {
                        return TextFieldAlertDialog(
                          title: 'KnowGo API Key',
                          initialValue: settingsService.knowgoApiKey ?? '',
                          onSubmitted: (value) {
                            setState(() {
                              settingsService.knowgoApiKey = value;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            CheckboxListTile(
              title: const Text('MQTT Support'),
              value: settingsService.mqttEnabled,
              onChanged: (bool? value) {
                if (value != null) {
                  setState(() {
                    settingsService.mqttEnabled = value;
                  });
                }
              },
            ),
            Visibility(
              visible: settingsService.mqttEnabled,
              child: ListTile(
                title: const Text('MQTT Broker'),
                subtitle: Text(settingsService.mqttBroker ?? ''),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext buildContext) {
                        return TextFieldAlertDialog(
                          title: 'MQTT Broker',
                          initialValue: settingsService.mqttBroker ?? '',
                          onSubmitted: (value) {
                            setState(() {
                              settingsService.mqttBroker = value;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            Visibility(
              visible: settingsService.mqttEnabled,
              child: ListTile(
                title: const Text('MQTT Topic'),
                subtitle: Text(settingsService.mqttTopic ?? ''),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext buildContext) {
                        return TextFieldAlertDialog(
                          title: 'MQTT Topic',
                          initialValue: settingsService.mqttTopic ?? '',
                          onSubmitted: (value) {
                            setState(() {
                              settingsService.mqttTopic = value;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            Visibility(
              // TODO: Re-enable for web once kafka support has migrated
              visible: !kIsWeb,
              child: CheckboxListTile(
                title: const Text('Kafka Support'),
                value: settingsService.kafkaEnabled,
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      settingsService.kafkaEnabled = value;
                    });
                  }
                },
              ),
            ),
            Visibility(
              visible: settingsService.kafkaEnabled,
              child: ListTile(
                title: const Text('Kafka Broker'),
                subtitle: Text(settingsService.kafkaBroker ?? ''),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext buildContext) {
                        return TextFieldAlertDialog(
                          title: 'Kafka Broker',
                          initialValue: settingsService.kafkaBroker ?? '',
                          onSubmitted: (value) {
                            setState(() {
                              settingsService.kafkaBroker = value;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            Visibility(
              visible: settingsService.kafkaEnabled,
              child: ListTile(
                title: const Text('Kafka Topic'),
                subtitle: Text(settingsService.kafkaTopic ?? ''),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext buildContext) {
                        return TextFieldAlertDialog(
                          title: 'Kafka Topic',
                          initialValue: settingsService.kafkaTopic ?? '',
                          onSubmitted: (value) {
                            setState(() {
                              settingsService.kafkaTopic = value;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(KnowGoIcons.knowgo, color: Colors.white),
            onPressed: () {
              return showAboutDialog(
                context: context,
                applicationIcon: Icon(
                  KnowGoIcons.knowgo,
                  color: Theme.of(context).primaryColor,
                ),
                applicationName: 'KnowGo Vehicle Simulator',
                applicationVersion: '1.1.0',
                applicationLegalese: '© 2020-2021 Adaptant Solutions AG',
              );
            },
          ),
        ],
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
