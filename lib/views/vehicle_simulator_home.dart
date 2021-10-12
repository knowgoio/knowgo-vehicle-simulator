import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:knowgo_vehicle_simulator/compat/file_downloader.dart';
import 'package:knowgo_vehicle_simulator/icons.dart';
import 'package:knowgo_vehicle_simulator/server/auth.dart';
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/views.dart';
import 'package:knowgo_vehicle_simulator/widgets.dart';
import 'package:provider/provider.dart';

class VehicleSimulatorHome extends StatefulWidget {
  VehicleSimulatorHome({Key? key}) : super(key: key);

  @override
  _VehicleSimulatorHomeState createState() => _VehicleSimulatorHomeState();
}

class _VehicleSimulatorHomeState extends State<VehicleSimulatorHome> {
  var settingsService = serviceLocator.get<SettingsService>();
  var consoleService = serviceLocator.get<ConsoleService>();
  final _webhookFormKey = GlobalKey<FormState>();
  bool _webhookSubscriptionChanged = false;
  List<bool> _webhookTriggers =
      List.generate(EventTrigger.values.length - 1, (_) => false);
  List<bool> _apiKeyScopes =
      List.generate(AuthService.scopes.length, (_) => false);
  TextEditingController? _webhookNotificationController;
  final apiKeyTextController = TextEditingController()
    ..text = 'No key generated';
  bool keyGenerated = false;

  @override
  void initState() {
    super.initState();

    var model = Provider.of<VehicleNotificationModel>(context, listen: false);
    model.addListener(_vehicleNotificationListener);

    _webhookNotificationController =
        TextEditingController(text: settingsService.notificationEndpoint ?? '');
  }

  @override
  void dispose() {
    _webhookNotificationController!.dispose();
    super.dispose();
  }

  void _vehicleNotificationListener() {
    var model = Provider.of<VehicleNotificationModel>(context, listen: false);

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
      eventData.add(vehicleSimulator.journey.events.first
          .toJson(omitNull: false)
          .keys
          .toList());
      vehicleSimulator.journey.events.forEach((element) {
        var items = element.toJson(omitNull: false).values.toList();
        // Encode null values as empty fields so they are excluded from output
        eventData.add(items.map((e) => e == null ? '' : e).toList());
      });
      return ListToCsvConverter().convert(eventData);
    } else {
      return null;
    }
  }

  void _addWebhookSubscriptionFromUI(String notificationUrl) {
    List<EventTrigger> triggers = [];
    for (int index = 0; index < _webhookTriggers.length; index++) {
      if (_webhookTriggers[index]) {
        triggers.add(EventTrigger.values[index + 1]);
      }
    }

    if (triggers.isNotEmpty) {
      var vehicleSimulator =
          Provider.of<VehicleSimulator>(context, listen: false);
      final WebhookSubscription subscription;
      if (settingsService.webhookSubscription != null) {
        subscription = WebhookSubscription.fromExisting(
            subscriptionId: settingsService.webhookSubscription!.subscriptionId,
            triggers: triggers,
            notificationUrl: notificationUrl);
      } else {
        subscription = WebhookSubscription(
            triggers: triggers, notificationUrl: notificationUrl);
      }
      settingsService.webhookSubscription = subscription;
      vehicleSimulator.webhookModel.updateSubscription(subscription);
      consoleService.write(
          'Configured Webhook notifier @ $notificationUrl, triggers: ' +
              (triggers.map((e) => describeEnum(e)).toList().join(", ")));
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

  Widget landscapeView() {
    return Container(
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
    );
  }

  Widget portraitView() {
    return Container(
      color: Colors.grey,
      child: Column(
        children: [
          Expanded(
            flex: 1,
            child: VehicleOuterView(),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: VehicleSettings(),
                ),
                Expanded(
                  flex: 1,
                  child: VehicleStats(),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: ConsoleLog(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var vehicleSimulator = context.watch<VehicleSimulator>();
    final portraitMode =
        MediaQuery.of(context).orientation == Orientation.portrait;
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
            CheckboxListTile(
              title: const Text('Unauthenticated REST API Access'),
              value: settingsService.allowUnauthenticated,
              onChanged: (bool? value) async {
                if (value != null) {
                  setState(() {
                    settingsService.allowUnauthenticated = value;
                  });

                  // As the settings service lies in a different isolate from
                  // the HTTP server, the change cannot be dynamically applied
                  // to the existing server instance - force it to restart to
                  // propagate the updated configuration settings from the main
                  // isolate. This should at some point be reworked to use an
                  // additional ReceivePort for propagating changes from the
                  // main isolate.
                  //
                  // TODO: Additional ReceivePort for propagating config changes
                  await vehicleSimulator.simulatorHttpServer?.restart();
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
            ListTile(
              title: const Text('Webhooks'),
              trailing: Icon(Icons.edit),
              onTap: () async {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext buildContext) {
                    return StatefulBuilder(builder: (context, setState) {
                      final subscription = settingsService.webhookSubscription;
                      if (subscription != null &&
                          _webhookSubscriptionChanged == false) {
                        subscription.triggers.forEach((trigger) {
                          int index = EventTrigger.values.indexOf(trigger);
                          _webhookTriggers[index - 1] = true;
                        });

                        _webhookNotificationController!.text =
                            subscription.notificationUrl;
                      }
                      return Scrollbar(
                        isAlwaysShown: true,
                        child: AlertDialog(
                          title: Text('Webhook Notifications',
                              style: TextStyle(
                                  color: Theme.of(context).primaryColor)),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () {
                                if (_webhookFormKey.currentState == null) {
                                  Navigator.of(context).pop();
                                }
                                if (_webhookFormKey.currentState!.validate()) {
                                  _webhookFormKey.currentState!.save();
                                  _addWebhookSubscriptionFromUI(
                                      _webhookNotificationController!.text);
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Text('DONE'),
                            )
                          ],
                          content: Form(
                            key: _webhookFormKey,
                            child: Container(
                              width: MediaQuery.of(context).size.width / 2,
                              height: MediaQuery.of(context).size.height / 2,
                              child: ListView(
                                children: [
                                  DataTable(
                                    columns: const <DataColumn>[
                                      DataColumn(
                                          label: const Text('Event Trigger')),
                                    ],
                                    rows: List<DataRow>.generate(
                                      EventTrigger.values.length - 1,
                                      (int index) => DataRow(
                                          cells: <DataCell>[
                                            DataCell(Text(describeEnum(
                                                EventTrigger
                                                    .values[index + 1]))),
                                          ],
                                          selected: _webhookTriggers[index],
                                          onSelectChanged: (bool? value) {
                                            setState(() {
                                              _webhookTriggers[index] =
                                                  !_webhookTriggers[index];
                                              _webhookSubscriptionChanged =
                                                  true;
                                            });
                                          }),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  TextFormField(
                                    decoration: InputDecoration(
                                      hintText: 'Webhook receiver URL',
                                      labelText: 'URL *',
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                    controller: _webhookNotificationController,
                                    validator: (String? value) {
                                      if (value != null &&
                                          Uri.tryParse(value)
                                                  ?.hasAbsolutePath ==
                                              true) {
                                        return null;
                                      }
                                      return 'Invalid URL';
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    });
                  },
                );
              },
            ),
            ListTile(
                title: const Text('API Keys'),
                trailing: Icon(Icons.edit),
                onTap: () async {
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext buildContext) {
                      return StatefulBuilder(
                          builder: (BuildContext ctx, StateSetter setState) {
                        return Scrollbar(
                          isAlwaysShown: true,
                          child: Scaffold(
                            backgroundColor: Colors.transparent,
                            body: AlertDialog(
                              title: Text('API Key Builder',
                                  style: TextStyle(
                                      color: Theme.of(context).primaryColor)),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('CLOSE'),
                                ),
                              ],
                              content: Container(
                                width: MediaQuery.of(context).size.width / 2,
                                height: MediaQuery.of(context).size.height / 2,
                                child: ListView(
                                  children: [
                                    DataTable(
                                      columns: const <DataColumn>[
                                        DataColumn(label: const Text('Scope')),
                                        DataColumn(
                                            label: const Text('Description')),
                                      ],
                                      rows: List<DataRow>.generate(
                                        _apiKeyScopes.length,
                                        (int index) => DataRow(
                                            cells: <DataCell>[
                                              DataCell(Text(AuthService
                                                  .scopes[index]!.scope)),
                                              DataCell(Text(AuthService
                                                  .scopes[index]!.description)),
                                            ],
                                            selected: _apiKeyScopes[index],
                                            onSelectChanged: (bool? value) {
                                              setState(() {
                                                _apiKeyScopes[index] =
                                                    !_apiKeyScopes[index];
                                              });
                                            }),
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    ElevatedButton(
                                      onPressed: !_apiKeyScopes.contains(true)
                                          ? null
                                          : () {
                                              final List<String> enabledScopes =
                                                  [];
                                              setState(() {
                                                if (keyGenerated == false) {
                                                  keyGenerated = true;
                                                }

                                                for (var i = 0;
                                                    i < _apiKeyScopes.length;
                                                    i++) {
                                                  if (_apiKeyScopes[i] == false)
                                                    continue;

                                                  enabledScopes.add(AuthService
                                                      .scopes[i]!.scope);
                                                }

                                                apiKeyTextController.text =
                                                    AuthService.generateApiKey(
                                                        enabledScopes);
                                              });
                                            },
                                      child: const Text('Generate'),
                                    ),
                                    SizedBox(height: 30),
                                    TextField(
                                      enabled: keyGenerated,
                                      controller: apiKeyTextController,
                                      maxLines: null,
                                      decoration: InputDecoration(
                                        label: Text('API Key',
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .primaryColor)),
                                        suffixIcon: IconButton(
                                          icon: Icon(Icons.copy,
                                              color: Theme.of(context)
                                                  .primaryColor),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(
                                                text: apiKeyTextController
                                                    .value.text));
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'API Key copied to clipboard',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                        disabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      });
                    },
                  );
                }),
            ListTile(
              title: const Text('Event Injection'),
              trailing: Icon(Icons.arrow_forward),
              onTap: () async {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => EventInjectionHome()));
              },
            ),
            ExpansionTile(
              title: const Text('Vehicle Settings'),
              children: [
                CheckboxListTile(
                  title: const Text('Manual Transmission'),
                  value: vehicleSimulator.info.transmission == 'manual',
                  onChanged: (value) {
                    setState(() {
                      vehicleSimulator.info.transmission =
                          value! ? 'manual' : 'automatic';
                    });
                  },
                ),
              ],
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
                applicationVersion: '1.1.1',
                applicationLegalese: '© 2020-2021 Adaptant Solutions AG',
              );
            },
          ),
        ],
        title: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              'KnowGo Vehicle Simulator',
              style: Theme.of(context).textTheme.headline6,
            ),
          ),
        ),
      ),
      body: portraitMode ? portraitView() : landscapeView(),
    );
  }
}
