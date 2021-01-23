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

  SettingsService(File yamlConfig) {
    _loggingEnabled = true;
    _server = "https://api.adaptant.io";
    _apiKey = "ra-adaptation-demo";
    _configFile = yamlConfig;
  }

  SettingsService.fromYaml(File yamlConfig) {
    var yamlString = yamlConfig.readAsStringSync();
    var doc = loadYaml(yamlString);

    _loggingEnabled = doc['sessionLogging'];
    _server = doc['knowgo']['server'];
    _apiKey = doc['knowgo']['apiKey'];

    _configFile = yamlConfig;

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
    // truncate existing configuration
    _configFile.writeAsStringSync('');

    // Write out new YAML document from JSON map
    writeMapToYamlFile(_configFile, configToJson());
  }
}
