import 'dart:io';

import 'package:knowgo/api.dart' as knowgo;
import 'package:yaml/yaml.dart';

class SettingsService {
  File _configFile;

  // User-defined auto configuration
  knowgo.Auto autoConfig = knowgo.Auto();

  // Initial vehicle event setting
  knowgo.Event initEvent = knowgo.Event();

  String _server;
  String get server => _server;

  set server(String serverAddress) {
    _server = serverAddress;
    saveConfig();
  }

  // Optional MQTT Configuration
  bool _mqttEnabled = false;
  bool get mqttEnabled => _mqttEnabled;

  set mqttEnabled(bool value) {
    _mqttEnabled = value;
    saveConfig();
  }

  String _mqttBroker;
  String get mqttBroker => _mqttBroker;

  set mqttBroker(String brokerAddress) {
    _mqttBroker = brokerAddress;
    saveConfig();
  }

  String _mqttTopic;
  String get mqttTopic => _mqttTopic;

  set mqttTopic(String topic) {
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

  String _kafkaBroker;
  String get kafkaBroker => _kafkaBroker;

  set kafkaBroker(String brokerAddress) {
    _kafkaBroker = brokerAddress;
    saveConfig();
  }

  String _kafkaTopic;
  String get kafkaTopic => _kafkaTopic;

  set kafkaTopic(String topic) {
    _kafkaTopic = topic;
    saveConfig();
  }

  String _apiKey;
  String get apiKey => _apiKey;

  set apiKey(String key) {
    _apiKey = key;
    saveConfig();
  }

  bool _loggingEnabled;
  bool get loggingEnabled => _loggingEnabled;

  set loggingEnabled(bool value) {
    _loggingEnabled = value;
    saveConfig();
  }

  SettingsService([File yamlConfig]) {
    _loggingEnabled = true;
    _server = "https://api.adaptant.io";
    _apiKey = "ra-adaptation-demo";

    if (yamlConfig != null) {
      _configFile = yamlConfig;
    }
  }

  SettingsService.fromYaml(File yamlConfig) {
    var yamlString = yamlConfig.readAsStringSync();
    var doc = loadYaml(yamlString);

    _loggingEnabled = doc['sessionLogging'];
    _server = doc['knowgo']['server'];
    _apiKey = doc['knowgo']['apiKey'];

    _configFile = yamlConfig;

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
      autoConfig.odometer = doc['vehicle']['odometer'].toDouble();
    }
  }

  Map<String, dynamic> configToJson() {
    final data = Map<String, dynamic>();
    data['sessionLogging'] = _loggingEnabled;

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

    data['knowgo'] = Map<String, dynamic>();
    data['knowgo']['server'] = _server;
    data['knowgo']['apiKey'] = _apiKey;

    data['vehicle'] = Map<String, dynamic>();
    data['vehicle']['name'] = autoConfig.name;
    data['vehicle']['odometer'] = autoConfig.odometer;
    data['vehicle']['driverId'] = autoConfig.driverID;
    data['vehicle']['autoId'] = autoConfig.autoID;
    data['vehicle']['licensePlate'] = autoConfig.licensePlate;

    return data;
  }

  String _generateEmptyString(int length) =>
      String.fromCharCodes(List.generate(length, (_) => 32));

  void writeMapToYamlFile(File file, Map<String, dynamic> map,
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
      return;
    }

    // truncate existing configuration
    _configFile.writeAsStringSync('');

    // Write out new YAML document from JSON map
    writeMapToYamlFile(_configFile, configToJson());
  }
}
