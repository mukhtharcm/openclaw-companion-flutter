import 'dart:io';

import 'package:openclaw_companion/app/models.dart';
import 'package:openclaw_gateway/openclaw_gateway.dart';

GatewayNodeCapabilityRegistry buildCompanionNodeRegistry() {
  return GatewayNodeCapabilityRegistry(
    capabilities: <GatewayNodeCapability>[
      GatewayNodeCapability(
        name: 'system',
        isEnabled: () async =>
            Platform.isMacOS || Platform.isLinux || Platform.isWindows,
      ),
      if (Platform.isMacOS)
        const GatewayNodeCapability(name: 'device'),
    ],
    commands: <GatewayNodeCommand>[
      GatewayNodeCommand(
        name: 'system.notify',
        capabilities: const <String>['system'],
        isAvailable: () async =>
            Platform.isMacOS || Platform.isLinux || Platform.isWindows,
        handler: (context) async {
          final params = _asJsonMap(context.params);
          final title = _firstNonEmptyString(
                params,
                const <String>['title', 'summary'],
              ) ??
              'OpenClaw Companion';
          final body = _firstNonEmptyString(
                params,
                const <String>['body', 'message', 'text'],
              ) ??
              'A node notification was requested.';

          if (Platform.isMacOS) {
            final script =
                'display notification ${_osascriptLiteral(body)} with title ${_osascriptLiteral(title)}';
            final result = await Process.run('osascript', <String>[
              '-e',
              script,
            ]);
            if (result.exitCode != 0) {
              return GatewayNodeCommandResult.error(
                code: 'notify_failed',
                message: _readProcessError(result),
              );
            }
          } else if (Platform.isLinux) {
            final result = await Process.run('notify-send', <String>[
              title,
              body,
            ]);
            if (result.exitCode != 0) {
              return GatewayNodeCommandResult.error(
                code: 'notify_failed',
                message: _readProcessError(result),
              );
            }
          } else if (Platform.isWindows) {
            final escapedTitle = title.replaceAll("'", "''");
            final escapedBody = body.replaceAll("'", "''");
            final script = '''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > \$null
\$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
\$xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>$escapedTitle</text><text>$escapedBody</text></binding></visual></toast>")
\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
\$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('OpenClaw Companion')
\$notifier.Show(\$toast)
''';
            final result = await Process.run('powershell', <String>[
              '-NoProfile',
              '-NonInteractive',
              '-Command',
              script,
            ]);
            if (result.exitCode != 0) {
              return GatewayNodeCommandResult.error(
                code: 'notify_failed',
                message: _readProcessError(result),
              );
            }
          } else {
            return GatewayNodeCommandResult.error(
              code: 'unsupported_platform',
              message:
                  'system.notify is not implemented on ${Platform.operatingSystem}.',
            );
          }

          return GatewayNodeCommandResult.ok(
            payload: <String, Object?>{
              'delivered': true,
              'title': title,
              'body': body,
              'platform': Platform.operatingSystem,
            },
          );
        },
      ),
      GatewayNodeCommand(
        name: 'device.status',
        capabilities: const <String>['device'],
        isAvailable: () async => Platform.isMacOS,
        handler: (context) async {
          return GatewayNodeCommandResult.ok(
            payload: <String, Object?>{
              'platform': Platform.operatingSystem,
              'operatingSystemVersion': Platform.operatingSystemVersion,
              'hostname': Platform.localHostname,
              'locale': context.client.options.locale,
              'pathEnv': context.client.options.pathEnv,
              'role': context.client.hello.auth?.role,
              'commands': context.client.options.commands,
              'caps': context.client.options.caps,
            },
          );
        },
      ),
    ],
    permissionsResolver: () async => <String, bool>{
      'notifications': Platform.isMacOS || Platform.isLinux || Platform.isWindows,
      'device': Platform.isMacOS,
    },
  );
}

GatewayClientInfo buildCompanionClientInfo({
  required CompanionWorkspaceMode workspaceMode,
}) {
  final os = Platform.operatingSystem;
  final titleCaseOs = '${os[0].toUpperCase()}${os.substring(1)}';
  return GatewayClientInfo(
    id: workspaceMode == CompanionWorkspaceMode.node
        ? GatewayClientIds.nodeHost
        : GatewayClientIds.gatewayClient,
    version: '0.1.0',
    platform: os,
    mode: workspaceMode == CompanionWorkspaceMode.node
        ? GatewayClientModes.node
        : GatewayClientModes.ui,
    displayName: workspaceMode == CompanionWorkspaceMode.node
        ? 'OpenClaw Companion Node'
        : 'OpenClaw Companion',
    deviceFamily: '$titleCaseOs Companion',
  );
}

Map<String, Object?>? _asJsonMap(Object? value) {
  if (value is Map<Object?, Object?>) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return null;
}

String? _firstNonEmptyString(
  Map<String, Object?>? json,
  List<String> keys,
) {
  if (json == null) {
    return null;
  }
  for (final key in keys) {
    final value = json[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String _osascriptLiteral(String value) {
  return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
}

String _readProcessError(ProcessResult result) {
  final stderr = result.stderr?.toString().trim();
  if (stderr != null && stderr.isNotEmpty) {
    return stderr;
  }
  final stdout = result.stdout?.toString().trim();
  if (stdout != null && stdout.isNotEmpty) {
    return stdout;
  }
  return 'process exited with code ${result.exitCode}';
}
