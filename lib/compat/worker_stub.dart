// Stubbed implementation of the dart:html Worker class, to enable co-existence
// in code that can be used either in Web or non-Web targets.
class Worker {
  final String scriptUrl;

  Worker(this.scriptUrl);

  Stream<dynamic> get onMessage => Stream.empty();

  void postMessage(dynamic data) {}
  void terminate() {}
}
