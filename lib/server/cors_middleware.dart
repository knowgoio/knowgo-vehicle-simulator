import 'package:shelf/shelf.dart';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'DELETE, GET, PUT, POST, OPTIONS',
  'Access-Control-Allow-Headers': '*',
};

Middleware addCORSHeaders() {
  Response? updateRequest(Request request) {
    if (request.method == 'OPTIONS') {
      return Response.ok(null, headers: corsHeaders);
    }

    return null;
  }

  Response updateResponse(Response response) {
    return response.change(headers: corsHeaders);
  }

  return createMiddleware(
      requestHandler: updateRequest, responseHandler: updateResponse);
}
