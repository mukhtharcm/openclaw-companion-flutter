import 'dart:io';

import 'package:openclaw_companion/app/models.dart';
import 'package:openclaw_gateway/openclaw_gateway.dart';

class CompanionNodeCommandDescriptor {
  const CompanionNodeCommandDescriptor({
    required this.name,
    required this.summary,
    required this.handler,
    this.capabilities = const <String>[],
    this.isAvailable,
  });

  final String name;
  final String summary;
  final List<String> capabilities;
  final GatewayNodeAvailabilityResolver? isAvailable;
  final GatewayNodeCommandHandler handler;

  GatewayNodeCommand toGatewayCommand() {
    return GatewayNodeCommand(
      name: name,
      capabilities: capabilities,
      isAvailable: isAvailable,
      handler: handler,
    );
  }
}

List<CompanionNodeCommandDescriptor> buildCompanionNodeCommandCatalog() {
  return <CompanionNodeCommandDescriptor>[
    CompanionNodeCommandDescriptor(
      name: 'system.notify',
      summary: 'Show a native desktop notification on this host.',
      capabilities: const <String>['system'],
      isAvailable: _supportsDesktopSystemCommands,
      handler: _handleSystemNotify,
    ),
    CompanionNodeCommandDescriptor(
      name: 'system.which',
      summary: 'Resolve executable paths from the current PATH.',
      capabilities: const <String>['system'],
      isAvailable: _supportsDesktopSystemCommands,
      handler: _handleSystemWhich,
    ),
    CompanionNodeCommandDescriptor(
      name: 'device.status',
      summary: 'Report runtime and environment details for this desktop node.',
      capabilities: const <String>['device'],
      isAvailable: _supportsDesktopDeviceCommands,
      handler: _handleDeviceStatus,
    ),
    CompanionNodeCommandDescriptor(
      name: 'device.info',
      summary: 'Describe the current desktop host and companion app build.',
      capabilities: const <String>['device'],
      isAvailable: _supportsDesktopDeviceCommands,
      handler: _handleDeviceInfo,
    ),
  ];
}

GatewayNodeCapabilityRegistry buildCompanionNodeRegistry() {
  final commandCatalog = buildCompanionNodeCommandCatalog();
  return GatewayNodeCapabilityRegistry(
    capabilities: <GatewayNodeCapability>[
      GatewayNodeCapability(
        name: 'system',
        isEnabled: _supportsDesktopSystemCommands,
      ),
      GatewayNodeCapability(
        name: 'device',
        isEnabled: _supportsDesktopDeviceCommands,
      ),
    ],
    commands: commandCatalog
        .map((command) => command.toGatewayCommand())
        .toList(growable: false),
    permissionsResolver: () async => <String, bool>{
      'notifications': await _supportsDesktopSystemCommands(),
      'device': await _supportsDesktopDeviceCommands(),
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

Map<String, String> resolveCompanionSystemBins(
  Iterable<String> bins, {
  String? pathEnv,
  String? pathExt,
}) {
  final resolved = <String, String>{};
  final extensions = _windowsPathExt(pathExt);
  final directories = _resolvedPathEntries(pathEnv);
  for (final original in bins) {
    final bin = original.trim();
    if (bin.isEmpty) {
      continue;
    }
    final located = _resolveCompanionExecutable(
      bin,
      directories: directories,
      extensions: extensions,
    );
    if (located != null) {
      resolved[bin] = located;
    }
  }
  return resolved;
}

Future<bool> _supportsDesktopSystemCommands() async {
  return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
}

Future<bool> _supportsDesktopDeviceCommands() async {
  return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
}

Future<GatewayNodeCommandResult> _handleSystemNotify(
  GatewayNodeCommandContext context,
) async {
  final params = _asJsonMap(context.params);
  final title =
      _firstNonEmptyString(params, const <String>['title', 'summary']) ??
      'OpenClaw Companion';
  final body =
      _firstNonEmptyString(params, const <String>['body', 'message', 'text']) ??
      'A node notification was requested.';

  if (Platform.isMacOS) {
    final script =
        'display notification ${_osascriptLiteral(body)} with title ${_osascriptLiteral(title)}';
    final result = await Process.run('osascript', <String>['-e', script]);
    if (result.exitCode != 0) {
      return GatewayNodeCommandResult.error(
        code: 'notify_failed',
        message: _readProcessError(result),
      );
    }
  } else if (Platform.isLinux) {
    final result = await Process.run('notify-send', <String>[title, body]);
    if (result.exitCode != 0) {
      return GatewayNodeCommandResult.error(
        code: 'notify_failed',
        message: _readProcessError(result),
      );
    }
  } else if (Platform.isWindows) {
    final escapedTitle = title.replaceAll("'", "''");
    final escapedBody = body.replaceAll("'", "''");
    final script =
        '''
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
}

Future<GatewayNodeCommandResult> _handleSystemWhich(
  GatewayNodeCommandContext context,
) async {
  final params = _asJsonMap(context.params);
  final bins = _readStringList(params, 'bins').toList(growable: true);
  if (bins.isEmpty) {
    final single = _firstNonEmptyString(params, const <String>['bin']);
    if (single == null) {
      return GatewayNodeCommandResult.error(
        code: 'invalid_request',
        message: 'system.which requires a non-empty "bins" list.',
      );
    }
    bins.add(single);
  }

  return GatewayNodeCommandResult.ok(
    payload: <String, Object?>{
      'bins': resolveCompanionSystemBins(
        bins,
        pathEnv: context.client.options.pathEnv,
      ),
    },
  );
}

Future<GatewayNodeCommandResult> _handleDeviceStatus(
  GatewayNodeCommandContext context,
) async {
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
}

Future<GatewayNodeCommandResult> _handleDeviceInfo(
  GatewayNodeCommandContext context,
) async {
  return GatewayNodeCommandResult.ok(
    payload: <String, Object?>{
      'deviceName': Platform.localHostname,
      'modelIdentifier': Platform.operatingSystem,
      'systemName': _titleCaseOperatingSystem(),
      'systemVersion': Platform.operatingSystemVersion,
      'appVersion': context.client.options.clientInfo.version,
      'appBuild': context.client.options.clientInfo.version,
      'locale': context.client.options.locale ?? Platform.localeName,
    },
  );
}

Map<String, Object?>? _asJsonMap(Object? value) {
  if (value is Map<Object?, Object?>) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  return null;
}

String? _firstNonEmptyString(Map<String, Object?>? json, List<String> keys) {
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

List<String> _readStringList(Map<String, Object?>? json, String key) {
  final raw = json?[key];
  if (raw is! List<Object?>) {
    return const <String>[];
  }
  return raw
      .map((value) => value?.toString().trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

String _titleCaseOperatingSystem() {
  final os = Platform.operatingSystem;
  return '${os[0].toUpperCase()}${os.substring(1)}';
}

List<String> _resolvedPathEntries(String? pathEnv) {
  final resolved = (pathEnv ?? Platform.environment['PATH'] ?? '').trim();
  if (resolved.isEmpty) {
    return const <String>[];
  }
  return resolved
      .split(Platform.isWindows ? ';' : ':')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
}

List<String> _windowsPathExt(String? pathExt) {
  if (!Platform.isWindows) {
    return const <String>[''];
  }
  final value = (pathExt ?? Platform.environment['PATHEXT'] ?? '').trim();
  if (value.isEmpty) {
    return const <String>['', '.exe', '.cmd', '.bat', '.ps1'];
  }
  return <String>{
    '',
    ...value
        .split(';')
        .map((extension) => extension.trim().toLowerCase())
        .where((extension) => extension.isNotEmpty),
  }.toList(growable: false);
}

String? _resolveCompanionExecutable(
  String bin, {
  required List<String> directories,
  required List<String> extensions,
}) {
  final file = File(bin);
  if (file.isAbsolute && file.existsSync()) {
    return file.path;
  }
  for (final directory in directories) {
    for (final extension in extensions) {
      final suffix = extension.isEmpty || bin.toLowerCase().endsWith(extension)
          ? ''
          : extension;
      final candidate = File('$directory${Platform.pathSeparator}$bin$suffix');
      if (candidate.existsSync()) {
        return candidate.path;
      }
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
