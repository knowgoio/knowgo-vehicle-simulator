import 'dart:io';

import 'package:yaml/yaml.dart';

class SettingsService {
  File _configFile;

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
  }

  Map<String, dynamic> configToJson() {
    final data = Map<String, dynamic>();
    data['sessionLogging'] = _loggingEnabled;

    data['knowgo'] = Map<String, dynamic>();
    data['knowgo']['server'] = _server;
    data['knowgo']['apiKey'] = _apiKey;

    return data;
  }

  // Save the updated configuration settings to the config file
  void saveConfig() {
    var file = _configFile;

    // truncate existing configuration
    file.writeAsStringSync('');

    // Write out new YAML document from JSON map
    final config = configToJson();
    config.forEach((key, value) {
      if (value is Map) {
        file.writeAsStringSync('\n$key:\n', mode: FileMode.writeOnlyAppend);
        value.forEach((subkey, subvalue) {
          file.writeAsStringSync('  $subkey: $subvalue\n',
              mode: FileMode.writeOnlyAppend);
        });
      } else {
        file.writeAsStringSync('$key: $value\n',
            mode: FileMode.writeOnlyAppend);
      }
    });
  }
}
