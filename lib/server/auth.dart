import 'dart:collection';
import 'dart:core';
import 'dart:io' show Platform;

import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:path_to_regexp/path_to_regexp.dart';
import 'package:uuid/uuid.dart';

class AuthScope {
  final String scope;
  final String description;
  final List<String> paths;
  final List<String> methods;

  AuthScope(
      {required this.scope,
      required this.description,
      required this.paths,
      required this.methods});

  @override
  String toString() {
    return 'AuthScope[scope=$scope, description=$description, paths=$paths, methods=$methods]';
  }
}

final List<AuthScope> _authScopes = [
  AuthScope(
      scope: 'simulator:read',
      description: 'View information about the Simulator',
      paths: ['/simulator/info'],
      methods: ['GET']),
  AuthScope(
      scope: 'simulator:write',
      description: 'Control and update Simulator state',
      paths: ['/simulator/start', '/simulator/stop'],
      methods: ['POST']),
  AuthScope(
      scope: 'raw_events:read',
      description: 'Read raw vehicle event telemetry',
      paths: ['/simulator/events'],
      methods: ['GET']),
  AuthScope(
      scope: 'raw_events:write',
      description: 'Submit raw vehicle event telemetry',
      paths: ['/simulator/events'],
      methods: ['POST']),
  AuthScope(
      scope: 'notifications',
      description: 'Send notifications to the vehicle',
      paths: [
        '/simulator/notification',
        '/exve/vehicles/:vehicleId/notification'
      ],
      methods: [
        'POST'
      ]),
  AuthScope(
      scope: 'webhooks',
      description: 'Manage webhook subscriptions',
      paths: ['/simulator/webhooks', '/simulator/webhooks/:subscriptionId'],
      methods: ['GET', 'POST', 'PUT', 'DELETE']),
  AuthScope(
      scope: 'exve.vehicles:read',
      description: 'Read vehicle information from ExVe APIs',
      paths: ['/exve/vehicles', '/exve/vehicles/:vehicleId'],
      methods: ['GET']),
  AuthScope(
      scope: 'exve.fleets:read',
      description: 'Read fleet information from ExVe APIs',
      paths: ['/exve/fleets', '/exve/fleets/:fleetId'],
      methods: ['GET']),
];

typedef AuthToken = String;

abstract class AuthService {
  static final _uuid = Uuid();
  static final _signingKey =
      Platform.environment['KNOWGO_SIGNING_KEY'] ?? 'secret-key';
  static const String _issuer =
      'https://knowgoio.github.com/knowgo-vehicle-simulator';
  static const String _namespace = 'knowgo.io';

  static UnmodifiableListView<AuthScope?> get scopes =>
      UnmodifiableListView(_authScopes);

  static AuthScope? matchAuthScopePath(String requestPath) {
    for (var scope in scopes) {
      for (var path in scope!.paths) {
        final regExp = pathToRegExp(path, prefix: true);
        if (regExp.hasMatch(requestPath)) {
          return scope;
        }
      }
    }

    return null;
  }

  static AuthScope? matchAuthScopeName(String scopeName) {
    return scopes.singleWhere((scope) => scope!.scope == scopeName,
        orElse: () => null);
  }

  static List<AuthScope> matchAuthScopeNames(List<String> scopeNames) {
    var authScopes = <AuthScope>[];
    for (var scope in scopeNames) {
      final authScope = matchAuthScopeName(scope);
      if (authScope != null) {
        authScopes.add(authScope);
      }
    }

    return authScopes;
  }

  static String generateApiKey(List<String> scopeNames) {
    final authScopes = matchAuthScopeNames(scopeNames);
    final claimSet = JwtClaim(
      issuer: _issuer,
      jwtId: _uuid.v5(Uuid.NAMESPACE_URL, _namespace),
      otherClaims: <String, dynamic>{
        'scope': authScopes.map((scope) => scope.scope).toList().join(' '),
      },
    );

    return issueJwtHS256(claimSet, _signingKey);
  }

  static bool validateApiKey(AuthToken token) {
    try {
      final claimSet =
          verifyJwtHS256Signature(token, _signingKey, defaultIatExp: false);
      claimSet.validate(issuer: _issuer);
    } catch (e) {
      return false;
    }

    return true;
  }

  static Map<dynamic, dynamic> introspectApiKey(AuthToken token) {
    return verifyJwtHS256Signature(token, _signingKey).toJson();
  }
}

extension ScopeValidation on AuthToken {
  List<String> get scopes {
    final claims = AuthService.introspectApiKey(this);
    if (claims['scope'] != null) {
      return claims['scope'].split(' ');
    }
    return [];
  }

  bool containsScope(String scope) {
    return this.scopes.contains(scope);
  }

  bool accessOk(String path, String method) {
    final authScope = AuthService.matchAuthScopePath(path);

    if (authScope != null) {
      return this.scopes.contains(authScope.scope) &&
          authScope.methods.contains(method);
    }

    return false;
  }
}
