class SettingsService {
  Future<SettingsService> init() async {
    return this;
  }

  String server;
  String apiKey;
  bool loggingEnabled;

  SettingsService() {
    loggingEnabled = true;
    server = "https://api.adaptant.io";
    apiKey = "ra-adaptation-demo";
  }
}
