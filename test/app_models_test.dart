import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw_companion/app/models.dart';

void main() {
  test('CompanionConfig round-trips through json', () {
    const config = CompanionConfig(
      manualUrl: 'wss://gateway.example:8443',
      authMode: CompanionAuthMode.password,
      token: 'unused',
      password: 'secret',
      autoConnect: false,
      preferredSessionKey: 'work',
      thinking: 'medium',
      lastConnection: CompanionLastConnection.discovered(
        stableId: 'gateway.example',
      ),
    );

    final decoded = CompanionConfig.fromJson(config.toJson());
    expect(decoded.manualUrl, config.manualUrl);
    expect(decoded.authMode, config.authMode);
    expect(decoded.password, config.password);
    expect(decoded.autoConnect, isFalse);
    expect(decoded.preferredSessionKey, 'work');
    expect(decoded.thinking, 'medium');
    expect(decoded.lastConnection?.stableId, 'gateway.example');
  });

  test('setup code decoder accepts raw json and base64', () {
    final payload = jsonEncode(<String, Object?>{
      'host': 'gateway.example',
      'port': 8443,
      'tls': true,
      'token': 'abc123',
    });
    final encoded = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');

    final direct = decodeCompanionSetupPayload(payload);
    final wrapped = decodeCompanionSetupPayload(encoded);

    expect(direct?.toUri()?.toString(), 'wss://gateway.example:8443');
    expect(wrapped?.token, 'abc123');
  });
}
