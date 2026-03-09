import 'dart:convert';

import 'package:openclaw_gateway/openclaw_gateway.dart';

enum CompanionAuthMode {
  token,
  password,
  none,
}

extension CompanionAuthModeLabel on CompanionAuthMode {
  String get storageValue => name;

  String get label => switch (this) {
        CompanionAuthMode.token => 'Token',
        CompanionAuthMode.password => 'Password',
        CompanionAuthMode.none => 'Pairing',
      };

  static CompanionAuthMode fromStorage(String? raw) {
    return CompanionAuthMode.values.firstWhere(
      (mode) => mode.storageValue == raw,
      orElse: () => CompanionAuthMode.token,
    );
  }
}

enum CompanionConnectionKind {
  manual,
  discovered,
}

class CompanionLastConnection {
  const CompanionLastConnection.manual({
    required this.url,
  })  : kind = CompanionConnectionKind.manual,
        stableId = null;

  const CompanionLastConnection.discovered({
    required this.stableId,
  })  : kind = CompanionConnectionKind.discovered,
        url = null;

  factory CompanionLastConnection.fromJson(JsonMap json) {
    final kind = switch (_readRequiredString(
      json,
      'kind',
      context: 'CompanionLastConnection',
    )) {
      'manual' => CompanionConnectionKind.manual,
      'discovered' => CompanionConnectionKind.discovered,
      final other => throw FormatException('Unsupported connection kind $other'),
    };

    return switch (kind) {
      CompanionConnectionKind.manual => CompanionLastConnection.manual(
          url: _readRequiredString(
            json,
            'url',
            context: 'CompanionLastConnection.url',
          ),
        ),
      CompanionConnectionKind.discovered => CompanionLastConnection.discovered(
          stableId: _readRequiredString(
            json,
            'stableId',
            context: 'CompanionLastConnection.stableId',
          ),
        ),
    };
  }

  final CompanionConnectionKind kind;
  final String? url;
  final String? stableId;

  JsonMap toJson() {
    return <String, Object?>{
      'kind': kind.name,
      'url': url,
      'stableId': stableId,
    };
  }
}

class CompanionConfig {
  const CompanionConfig({
    this.manualUrl = '',
    this.authMode = CompanionAuthMode.token,
    this.token = '',
    this.password = '',
    this.autoConnect = true,
    this.preferredSessionKey = 'main',
    this.thinking = 'default',
    this.lastConnection,
  });

  factory CompanionConfig.fromJson(JsonMap json) {
    return CompanionConfig(
      manualUrl: _readNullableString(json['manualUrl']) ?? '',
      authMode: CompanionAuthModeLabel.fromStorage(
        _readNullableString(json['authMode']),
      ),
      token: _readNullableString(json['token']) ?? '',
      password: _readNullableString(json['password']) ?? '',
      autoConnect: _readNullableBool(json['autoConnect']) ?? true,
      preferredSessionKey:
          _readNullableString(json['preferredSessionKey']) ?? 'main',
      thinking: _readNullableString(json['thinking']) ?? 'default',
      lastConnection: json['lastConnection'] == null
          ? null
          : CompanionLastConnection.fromJson(
              _asJsonMap(json['lastConnection'], 'CompanionConfig.lastConnection'),
            ),
    );
  }

  final String manualUrl;
  final CompanionAuthMode authMode;
  final String token;
  final String password;
  final bool autoConnect;
  final String preferredSessionKey;
  final String thinking;
  final CompanionLastConnection? lastConnection;

  JsonMap toJson() {
    return <String, Object?>{
      'manualUrl': manualUrl,
      'authMode': authMode.storageValue,
      'token': token,
      'password': password,
      'autoConnect': autoConnect,
      'preferredSessionKey': preferredSessionKey,
      'thinking': thinking,
      'lastConnection': lastConnection?.toJson(),
    };
  }

  CompanionConfig copyWith({
    String? manualUrl,
    CompanionAuthMode? authMode,
    String? token,
    String? password,
    bool? autoConnect,
    String? preferredSessionKey,
    String? thinking,
    Object? lastConnection = _sentinel,
  }) {
    return CompanionConfig(
      manualUrl: manualUrl ?? this.manualUrl,
      authMode: authMode ?? this.authMode,
      token: token ?? this.token,
      password: password ?? this.password,
      autoConnect: autoConnect ?? this.autoConnect,
      preferredSessionKey: preferredSessionKey ?? this.preferredSessionKey,
      thinking: thinking ?? this.thinking,
      lastConnection: identical(lastConnection, _sentinel)
          ? this.lastConnection
          : lastConnection as CompanionLastConnection?,
    );
  }

  static const Object _sentinel = Object();
}

class CompanionSetupPayload {
  const CompanionSetupPayload({
    this.url,
    this.host,
    this.port,
    this.tls,
    this.token,
    this.password,
  });

  factory CompanionSetupPayload.fromJson(JsonMap json) {
    return CompanionSetupPayload(
      url: _readNullableString(json['url']),
      host: _readNullableString(json['host']),
      port: _readNullableInt(json['port']),
      tls: _readNullableBool(json['tls']),
      token: _readNullableString(json['token']),
      password: _readNullableString(json['password']),
    );
  }

  final String? url;
  final String? host;
  final int? port;
  final bool? tls;
  final String? token;
  final String? password;

  Uri? toUri() {
    final explicitUrl = url?.trim();
    if (explicitUrl != null && explicitUrl.isNotEmpty) {
      return Uri.tryParse(explicitUrl);
    }

    final resolvedHost = host?.trim();
    if (resolvedHost == null || resolvedHost.isEmpty) {
      return null;
    }

    return Uri(
      scheme: tls == true ? 'wss' : 'ws',
      host: resolvedHost,
      port: port,
    );
  }
}

CompanionSetupPayload? decodeCompanionSetupPayload(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final direct = _decodeCompanionSetupJson(trimmed);
  if (direct != null) {
    return direct;
  }

  final normalized = trimmed.replaceAll('-', '+').replaceAll('_', '/');
  final paddingLength = (4 - (normalized.length % 4)) % 4;
  final padded = normalized + '=' * paddingLength;
  try {
    final decoded = utf8.decode(base64Decode(padded));
    return _decodeCompanionSetupJson(decoded);
  } catch (_) {
    return null;
  }
}

CompanionSetupPayload? _decodeCompanionSetupJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return CompanionSetupPayload.fromJson(
      _asJsonMap(decoded, 'CompanionSetupPayload'),
    );
  } catch (_) {
    return null;
  }
}

class CompanionTrustPrompt {
  const CompanionTrustPrompt({
    required this.title,
    required this.uri,
    required this.stableId,
    required this.fingerprint,
    required this.request,
  });

  final String title;
  final Uri uri;
  final String stableId;
  final String fingerprint;
  final CompanionConnectionRequest request;
}

class CompanionConnectionRequest {
  const CompanionConnectionRequest({
    required this.title,
    required this.uri,
    required this.stableId,
    required this.authMode,
    required this.token,
    required this.password,
    required this.lastConnection,
  });

  final String title;
  final Uri uri;
  final String stableId;
  final CompanionAuthMode authMode;
  final String token;
  final String password;
  final CompanionLastConnection lastConnection;
}

class CompanionEventLine {
  const CompanionEventLine({
    required this.timeLabel,
    required this.name,
    required this.summary,
  });

  final String timeLabel;
  final String name;
  final String summary;
}

JsonMap _asJsonMap(Object? value, String context) {
  if (value is Map<Object?, Object?>) {
    return value.map(
      (key, entry) => MapEntry(key.toString(), entry),
    );
  }
  throw FormatException('Expected object for $context.');
}

String _readRequiredString(JsonMap json, String key, {required String context}) {
  final value = _readNullableString(json[key]);
  if (value == null || value.isEmpty) {
    throw FormatException('Missing $context.$key.');
  }
  return value;
}

String? _readNullableString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool? _readNullableBool(Object? value) {
  if (value is bool) {
    return value;
  }
  return null;
}

int? _readNullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
