import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:yaml/yaml.dart';

class SettingsService extends ChangeNotifier {
  File? _configFile;

  // User-defined auto configuration
  knowgo.Auto autoConfig = knowgo.Auto();

  // Initial vehicle event setting
  knowgo.Event initEvent = knowgo.Event();

  // Optional Webhook configuration
  WebhookSubscription? webhookSubscription;

  // Optional Notification Endpoint
  String? _notificationEndpoint;
  String? get notificationEndpoint => _notificationEndpoint;

  set notificationEndpoint(String? endpoint) {
    if (endpoint != null) {
      _notificationEndpoint = endpoint;
      saveConfig();
    }
  }

  // Optional KnowGo Car Backend Configuration
  bool _knowgoEnabled = false;
  bool get knowgoEnabled => _knowgoEnabled;

  set knowgoEnabled(bool value) {
    _knowgoEnabled = value;
    saveConfig();
  }

  String? _knowgoServer;
  String? get knowgoServer => _knowgoServer;

  set knowgoServer(String? serverAddress) {
    if (serverAddress != null) {
      _knowgoServer = serverAddress;
      saveConfig();
    }
  }

  String? _knowgoApiKey;
  String? get knowgoApiKey => _knowgoApiKey;

  set knowgoApiKey(String? key) {
    _knowgoApiKey = key;
    saveConfig();
  }

  // Optional MQTT Configuration
  bool _mqttEnabled = false;
  bool get mqttEnabled => _mqttEnabled;

  set mqttEnabled(bool value) {
    _mqttEnabled = value;
    saveConfig();
  }

  String? _mqttBroker;
  String? get mqttBroker => _mqttBroker;

  set mqttBroker(String? brokerAddress) {
    _mqttBroker = brokerAddress;
    saveConfig();
  }

  String? _mqttTopic;
  String? get mqttTopic => _mqttTopic;

  set mqttTopic(String? topic) {
    _mqttTopic = topic;
    saveConfig();
  }

  // Optional Kafka configuration
  bool _kafkaEnabled = false;
  bool get kafkaEnabled => _kafkaEnabled;

  set kafkaEnabled(bool value) {
    _kafkaEnabled = value;
    saveConfig();
  }

  String? _kafkaBroker;
  String? get kafkaBroker => _kafkaBroker;

  set kafkaBroker(String? brokerAddress) {
    _kafkaBroker = brokerAddress;
    saveConfig();
  }

  String? _kafkaTopic;
  String? get kafkaTopic => _kafkaTopic;

  set kafkaTopic(String? topic) {
    _kafkaTopic = topic;
    saveConfig();
  }

  bool _loggingEnabled = false;
  bool get loggingEnabled => _loggingEnabled;

  set loggingEnabled(bool value) {
    _loggingEnabled = value;
    saveConfig();
  }

  // Log event notifications to console
  bool _eventLoggingEnabled = true;
  bool get eventLoggingEnabled => _eventLoggingEnabled;

  set eventLoggingEnabled(bool value) {
    _eventLoggingEnabled = value;
    saveConfig();
  }

  // Allow unauthenticated requests to REST API
  bool _allowUnauthenticated = true;
  bool get allowUnauthenticated => _allowUnauthenticated;

  set allowUnauthenticated(bool value) {
    _allowUnauthenticated = value;
    saveConfig();
  }

  // Light or dark mode UI
  bool _darkMode = false;
  bool get darkMode => _darkMode;

  set darkMode(bool value) {
    _darkMode = value;
    saveConfig();
  }

  SettingsService([File? yamlConfig]) {
    if (yamlConfig != null) {
      _configFile = yamlConfig;
    }
  }

  SettingsService.fromYaml(File yamlConfig) {
    var yamlString = yamlConfig.readAsStringSync();
    var doc = loadYaml(yamlString);

    if (doc == null) {
      return;
    }

    _configFile = yamlConfig;

    if (doc['darkMode'] != null) {
      _darkMode = doc['darkMode'];
    }

    if (doc['sessionLogging'] != null) {
      _loggingEnabled = doc['sessionLogging'];
    }

    if (doc['eventLogging'] != null) {
      _eventLoggingEnabled = doc['eventLogging'];
    }

    if (doc['allowUnauthenticated'] != null) {
      _allowUnauthenticated = doc['allowUnauthenticated'];
    }

    if (doc['notificationUrl'] != null) {
      _notificationEndpoint = doc['notificationUrl'];
    }

    if (doc['knowgo'] != null) {
      _knowgoServer = doc['knowgo']['server'];
      _knowgoApiKey = doc['knowgo']['apiKey'];
      _knowgoEnabled = true;
    }

    if (doc['mqtt'] != null) {
      _mqttBroker = doc['mqtt']['broker'];
      _mqttTopic = doc['mqtt']['topic'];
      _mqttEnabled = true;
    }

    if (doc['kafka'] != null) {
      _kafkaBroker = doc['kafka']['broker'];
      _kafkaTopic = doc['kafka']['topic'];
      _kafkaEnabled = true;
    }

    if (doc['vehicle'] != null) {
      autoConfig.autoID = doc['vehicle']['autoId'];
      autoConfig.driverID = doc['vehicle']['driverId'];
      autoConfig.name = doc['vehicle']['name'];
      autoConfig.licensePlate = doc['vehicle']['licensePlate'];
      if (doc['vehicle']['odometer'] != null) {
        autoConfig.odometer = doc['vehicle']['odometer'].toDouble();
      }
    }
  }

  Map<String, dynamic> configToJson() {
    final data = Map<String, dynamic>();
    data['darkMode'] = _darkMode;
    data['sessionLogging'] = _loggingEnabled;
    data['eventLogging'] = _eventLoggingEnabled;
    data['allowUnauthenticated'] = _allowUnauthenticated;

    if (_notificationEndpoint != null) {
      data['notificationUrl'] = _notificationEndpoint;
    }

    if (_knowgoEnabled == true) {
      data['knowgo'] = Map<String, dynamic>();
      data['knowgo']['server'] = _knowgoServer;
      data['knowgo']['apiKey'] = _knowgoApiKey;
    }

    if (_mqttEnabled == true) {
      data['mqtt'] = Map<String, dynamic>();
      data['mqtt']['broker'] = _mqttBroker;
      data['mqtt']['topic'] = _mqttTopic;
    }

    if (_kafkaEnabled == true) {
      data['kafka'] = Map<String, dynamic>();
      data['kafka']['broker'] = _kafkaBroker;
      data['kafka']['topic'] = _kafkaTopic;
    }

    if (autoConfig.name != null) {
      data['vehicle'] = Map<String, dynamic>();
      data['vehicle']['name'] = autoConfig.name;
      data['vehicle']['odometer'] = autoConfig.odometer;
      data['vehicle']['driverId'] = autoConfig.driverID;
      data['vehicle']['autoId'] = autoConfig.autoID;
      data['vehicle']['licensePlate'] = autoConfig.licensePlate;
    }

    return data;
  }

  String _generateEmptyString(int length) =>
      String.fromCharCodes(List.generate(length, (_) => 32));

  void writeMapToYamlFile(File file, Map<dynamic, dynamic> map,
      {int depth = 0}) {
    var parentPadding = _generateEmptyString(depth * 2);
    var childPadding = _generateEmptyString((depth + 1) * 2);

    map.forEach((key, value) {
      if (value is Map) {
        file.writeAsStringSync('\n$parentPadding$key:\n',
            mode: FileMode.writeOnlyAppend);
        value.forEach((subkey, subvalue) {
          if (subvalue is Map) {
            // Recurse over nested maps
            file.writeAsStringSync('\n$childPadding$subkey:\n',
                mode: FileMode.writeOnlyAppend);
            writeMapToYamlFile(file, subvalue, depth: ++depth);
          } else if (subvalue is String) {
            file.writeAsStringSync('$childPadding$subkey: \"$subvalue\"\n',
                mode: FileMode.writeOnlyAppend);
          } else {
            file.writeAsStringSync('$childPadding$subkey: $subvalue\n',
                mode: FileMode.writeOnlyAppend);
          }
        });
      } else {
        file.writeAsStringSync('$parentPadding$key: $value\n',
            mode: FileMode.writeOnlyAppend);
      }
    });
  }

  // Save the updated configuration settings to the config file
  void saveConfig() {
    // Handle cases where the config file is not persisted, as in Flutter web.
    if (_configFile == null) {
      notifyListeners();
      return;
    }

    // truncate existing configuration
    _configFile!.writeAsStringSync('');

    // Write out new YAML document from JSON map
    writeMapToYamlFile(_configFile!, configToJson());

    notifyListeners();
  }
}
