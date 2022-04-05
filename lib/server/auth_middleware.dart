import 'package:knowgo_vehicle_simulator/server/auth.dart';
import 'package:shelf/shelf.dart';

Middleware registerAuthMiddleware({bool allowUnauthenticated = false}) {
  return (innerHandler) {
    return (request) {
      return Future.sync(() => innerHandler(request)).then((response) {
        if (allowUnauthenticated) {
          return response;
        }

        final String? token = request.headers['Authorization'];
        // Authorization: Bearer <JWT token>
        final String? apiKey = token?.split(' ')[1];
        if (apiKey != null) {
          if (AuthService.validateApiKey(apiKey) == false) {
            return Response.forbidden('Invalid API Key supplied');
          }

          if (apiKey.accessOk('/' + request.url.path, request.method)) {
            return response;
          }
        }

        return Response.forbidden('Access denied');
      });
    };
  };
}
