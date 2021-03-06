import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:knowgo_vehicle_simulator/compat/file_downloader.dart';
import 'package:knowgo_vehicle_simulator/icons.dart';
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/widgets.dart';
import 'package:provider/provider.dart';

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

    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

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

  String? _generateCsvData() {
    var vehicleSimulator = context.watch<VehicleSimulator>();
    if (vehicleSimulator.journey.events.isNotEmpty) {
      List<List<dynamic>> eventData = [];
      eventData
          .add(vehicleSimulator.journey.events.first.toJson().keys.toList());
      vehicleSimulator.journey.events.forEach((element) {
        eventData.add(element.toJson().values.toList());
      });
      return ListToCsvConverter().convert(eventData);
    } else {
      return null;
    }
  }

  Future<void> _exportEventsToCSV() async {
    final fileDownloader = FileDownloader();
    await fileDownloader.init();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final csvFile = 'Simulator-${DateTime.now()}.csv';
        final csvData = _generateCsvData();
        String? path = null;

        if (csvData != null) {
          path = fileDownloader.download(utf8.encode(csvData), csvFile);
        }

        String msg = path == null
            ? 'No Events to export, generate some Events first!'
            : 'Events saved to $path';
        return AlertDialog(
          title: Text('CSV Exporter',
              style: TextStyle(color: Theme.of(context).primaryColor)),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
          content: Text(msg),
        );
      },
    );
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
            icon: Icon(Icons.file_download, color: Colors.white),
            tooltip: 'Export Vehicle Events to CSV file',
            onPressed: _exportEventsToCSV,
          ),
          IconButton(
            icon: Icon(KnowGoIcons.knowgo, color: Colors.white),
            tooltip: 'About KnowGo Vehicle Simulator',
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
