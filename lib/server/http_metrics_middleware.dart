import 'package:prometheus_client/prometheus_client.dart';
import 'package:shelf/shelf.dart';

Middleware registerHttpMetrics([CollectorRegistry? registry]) {
  final http_requests_total = Counter(
      name: 'http_requests_total', help: 'Total number of HTTP requests.');

  final http_endpoint_requests = Counter(
    name: 'http_endpoint_requests_total',
    help: 'Total number of endpoint-specific HTTP requests.',
    labelNames: ['method', 'path'],
  );

  registry ??= CollectorRegistry.defaultRegistry;
  registry.register(http_requests_total);
  registry.register(http_endpoint_requests);

  return (innerHandler) {
    return (request) {
      return Future.sync(() => innerHandler(request)).then((response) {
        http_requests_total.inc();
        http_endpoint_requests
            .labels([request.method, '/' + request.url.path]).inc();
        return response;
      });
    };
  };
}
