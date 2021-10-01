import 'package:knowgo_vehicle_simulator/server/auth.dart';
import 'package:shelf/shelf.dart';

Middleware registerAuthMiddleware({bool allowUnauthenticated = false}) {
  return (innerHandler) {
    return (request) {
      return Future.sync(() => innerHandler(request)).then((response) {
        final String? apiKey = request.headers['X-API-Key'];
        if (apiKey != null) {
          if (AuthService.validateApiKey(apiKey) == false) {
            return Response.forbidden('Invalid API Key supplied');
          }

          if (apiKey.accessOk('/' + request.url.path, request.method)) {
            return response;
          }
        }

        if (allowUnauthenticated) {
          print('Allowing unauthenticated access');
          return response;
        } else {
          return Response.forbidden('Access denied');
        }
      });
    };
  };
}
