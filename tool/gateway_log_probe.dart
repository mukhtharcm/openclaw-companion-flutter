import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:openclaw_gateway/openclaw_gateway.dart';

Future<void> main(List<String> args) async {
  final options = _ProbeOptions.parse(args);
  if (options.showHelp ||
      options.url == null ||
      (!options.allowNoAuth &&
          options.token == null &&
          options.password == null)) {
    stdout.writeln(_ProbeOptions.usage);
    exit(options.showHelp ? 0 : 64);
  }

  final uri = Uri.tryParse(options.url!);
  if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
    stderr.writeln('Expected a valid ws:// or wss:// URL.');
    exit(64);
  }

  final auth = switch ((options.token, options.password, options.allowNoAuth)) {
    (final token?, _, _) => GatewayAuth.token(token),
    (_, final password?, _) => GatewayAuth.password(password),
    (_, _, true) => const GatewayAuth.none(),
    _ => throw StateError('Auth should have been validated before connect.'),
  };

  stdout.writeln('Connecting to $uri');
  final client = await GatewayClient.connect(
    uri: uri,
    auth: auth,
    autoReconnect: true,
    clientInfo: const GatewayClientInfo(
      id: GatewayClientIds.cli,
      version: '0.1.0',
      platform: 'dart',
      mode: GatewayClientModes.cli,
      displayName: 'OpenClaw Companion Log Probe',
    ),
  );

  final subscriptions = <StreamSubscription<Object?>>[
    client.connectionStates.listen((state) {
      stdout.writeln(
        '[state] ${state.phase.name}${state.error == null ? '' : ' :: ${state.error}'}',
      );
    }),
    client.events.listen((frame) {
      stdout.writeln('[event] ${frame.event} :: ${_summarize(frame.payload)}');
    }),
  ];

  try {
    stdout.writeln(
      '[hello] server=${client.hello.server.version} role=${client.hello.auth?.role ?? 'unknown'}',
    );

    final health = await client.query.health();
    stdout.writeln(
      '[rpc] health ok=${health.ok} channels=${health.channelOrder.length}',
    );

    final sessions = await client.query.sessionsList(
      limit: 8,
      includeDerivedTitles: true,
      includeLastMessage: true,
    );
    stdout.writeln('[rpc] sessions count=${sessions.count}');

    final seconds = options.seconds;
    stdout.writeln(
      'Listening for events for ${seconds.inSeconds}s. Press Ctrl+C to stop sooner.',
    );
    await Future<void>.delayed(seconds);
  } finally {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await client.close();
  }
}

class _ProbeOptions {
  const _ProbeOptions({
    required this.showHelp,
    required this.url,
    required this.token,
    required this.password,
    required this.allowNoAuth,
    required this.seconds,
  });

  static const String usage = '''
Usage:
  dart run tool/gateway_log_probe.dart --url ws://127.0.0.1:18789 --token <token>

Options:
  --url <ws://...|wss://...>    Gateway URL
  --token <token>               Shared gateway token
  --password <password>         Gateway password
  --allow-no-auth               Connect without auth
  --seconds <n>                 How long to listen for events (default: 20)
  --help                        Show this help

Environment fallbacks:
  OPENCLAW_GATEWAY_URL
  OPENCLAW_GATEWAY_TOKEN
  OPENCLAW_GATEWAY_PASSWORD
  OPENCLAW_GATEWAY_SECONDS
''';

  final bool showHelp;
  final String? url;
  final String? token;
  final String? password;
  final bool allowNoAuth;
  final Duration seconds;

  factory _ProbeOptions.parse(List<String> args) {
    String? url = Platform.environment['OPENCLAW_GATEWAY_URL'];
    String? token = Platform.environment['OPENCLAW_GATEWAY_TOKEN'];
    String? password = Platform.environment['OPENCLAW_GATEWAY_PASSWORD'];
    var allowNoAuth = false;
    var showHelp = false;
    var seconds = int.tryParse(
      Platform.environment['OPENCLAW_GATEWAY_SECONDS'] ?? '',
    );

    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      switch (arg) {
        case '--help':
        case '-h':
          showHelp = true;
        case '--allow-no-auth':
          allowNoAuth = true;
        case '--url':
          url = _readValue(args, ++index, '--url');
        case '--token':
          token = _readValue(args, ++index, '--token');
        case '--password':
          password = _readValue(args, ++index, '--password');
        case '--seconds':
          final value = _readValue(args, ++index, '--seconds');
          seconds = int.tryParse(value);
          if (seconds == null || seconds < 1) {
            throw FormatException('Expected a positive integer for --seconds.');
          }
        default:
          if (arg.startsWith('-')) {
            throw FormatException('Unknown argument: $arg');
          }
      }
    }

    return _ProbeOptions(
      showHelp: showHelp,
      url: url?.trim().isEmpty == true ? null : url?.trim(),
      token: token?.trim().isEmpty == true ? null : token?.trim(),
      password: password?.trim().isEmpty == true ? null : password?.trim(),
      allowNoAuth: allowNoAuth,
      seconds: Duration(seconds: seconds ?? 20),
    );
  }

  static String _readValue(List<String> args, int index, String option) {
    if (index >= args.length) {
      throw FormatException('Missing value for $option');
    }
    return args[index];
  }
}

String _summarize(Object? payload) {
  if (payload == null) {
    return '(no payload)';
  }
  try {
    final encoded = jsonEncode(payload);
    if (encoded.length <= 180) {
      return encoded;
    }
    return '${encoded.substring(0, 179)}…';
  } catch (_) {
    final text = payload.toString();
    if (text.length <= 180) {
      return text;
    }
    return '${text.substring(0, 179)}…';
  }
}
