part of '../home.dart';

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({
    required this.controller,
    required this.setupCodeController,
    required this.urlController,
    required this.tokenController,
    required this.passwordController,
    required this.workspaceMode,
    required this.authMode,
    required this.embedded,
    required this.autoConnect,
    required this.onWorkspaceModeChanged,
    required this.onAuthModeChanged,
    required this.onAutoConnectChanged,
    required this.onImportSetupCode,
    required this.onConnectManual,
    required this.onConnectDiscovered,
    required this.onDisconnect,
    required this.onForgetTrust,
    required this.onClearSavedCredentials,
    required this.onResetAllDebug,
  });

  final CompanionController controller;
  final TextEditingController setupCodeController;
  final TextEditingController urlController;
  final TextEditingController tokenController;
  final TextEditingController passwordController;
  final CompanionWorkspaceMode workspaceMode;
  final CompanionAuthMode authMode;
  final bool embedded;
  final bool autoConnect;
  final ValueChanged<CompanionWorkspaceMode> onWorkspaceModeChanged;
  final ValueChanged<CompanionAuthMode> onAuthModeChanged;
  final ValueChanged<bool> onAutoConnectChanged;
  final Future<void> Function() onImportSetupCode;
  final Future<void> Function() onConnectManual;
  final ValueChanged<GatewayDiscoveredGateway> onConnectDiscovered;
  final VoidCallback onDisconnect;
  final VoidCallback onForgetTrust;
  final VoidCallback onClearSavedCredentials;
  final Future<void> Function() onResetAllDebug;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleAuthMode = authMode == CompanionAuthMode.none
        ? CompanionAuthMode.token
        : authMode;
    final visibleAuthModes = CompanionAuthMode.values
        .where((mode) => mode != CompanionAuthMode.none)
        .toList(growable: false);
    final connectionLabel = switch (controller.connectionState.phase) {
      GatewayConnectionPhase.connecting => 'Connecting to the gateway',
      GatewayConnectionPhase.reconnecting => 'Reconnecting to the gateway',
      _ when controller.busy => 'Working on your connection',
      _ => null,
    };
    final pairRequestId = workspaceMode == CompanionWorkspaceMode.node
        ? controller.nodePairingRequestId
        : null;
    final connectLabel = pairRequestId != null
        ? 'Reconnect after approval'
        : workspaceMode == CompanionWorkspaceMode.node
        ? 'Connect as node'
        : 'Connect';

    final panel = Column(
      children: <Widget>[
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFD8D1C5))),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Gateway access',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Import, discover, or connect manually. Saved auth, identity, and TLS trust are reused automatically.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF5E706B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusChip(state: controller.connectionState),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (connectionLabel != null) ...<Widget>[
                  _LoadingBanner(
                    label: connectionLabel,
                    detail: controller.connectedGatewayTitle,
                  ),
                  const SizedBox(height: 16),
                ],
                if (pairRequestId != null) ...<Widget>[
                  _SheetSection(
                    title: 'Pairing approval required',
                    subtitle:
                        'Approve this pending node device request from an operator client, then reconnect.',
                    child: _PairingApprovalCard(
                      requestId: pairRequestId,
                      url: urlController.text.trim(),
                      authMode: visibleAuthMode,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _SheetSection(
                  title: 'Quick start',
                  subtitle: 'Paste a setup code or pick a local gateway.',
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: setupCodeController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Paste JSON or base64 setup code',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: controller.busy
                              ? null
                              : () {
                                  unawaited(onImportSetupCode());
                                },
                          child: const Text('Import setup code'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (controller.busy &&
                          controller.discoveredGateways.isEmpty)
                        const _SkeletonCardList(count: 2, minHeight: 84)
                      else if (controller.discoveredGateways.isEmpty)
                        const _HintCard(
                          text: 'No gateways found on the local network yet.',
                        )
                      else
                        Column(
                          children: controller.discoveredGateways
                              .map(
                                (gateway) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _DiscoveredGatewayTile(
                                    gateway: gateway,
                                    busy: controller.busy,
                                    connectLabel: connectLabel,
                                    onConnect: () =>
                                        onConnectDiscovered(gateway),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SheetSection(
                  title: 'Manual connection',
                  subtitle:
                      'Choose operator or node mode, then use a direct URL for local, remote, or tunneled setups.',
                  child: Column(
                    children: <Widget>[
                      SegmentedButton<CompanionWorkspaceMode>(
                        segments: CompanionWorkspaceMode.values
                            .map(
                              (mode) =>
                                  ButtonSegment<CompanionWorkspaceMode>(
                                    value: mode,
                                    label: Text(mode.label),
                                  ),
                            )
                            .toList(growable: false),
                        selected: <CompanionWorkspaceMode>{workspaceMode},
                        onSelectionChanged: (value) {
                          onWorkspaceModeChanged(value.first);
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          workspaceMode.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF5E706B),
                          ),
                        ),
                      ),
                      if (workspaceMode == CompanionWorkspaceMode.node) ...<
                        Widget
                      >[
                        const SizedBox(height: 12),
                        const _HintCard(
                          text:
                              'The first node connect may require approval from an operator client. This companion currently exposes a small safe desktop command set.',
                          tint: Color(0xFFF4EEE3),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          hintText:
                              'wss://gateway.example:8443 or ws://127.0.0.1:18789',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<CompanionAuthMode>(
                        segments: visibleAuthModes
                            .map(
                              (mode) => ButtonSegment<CompanionAuthMode>(
                                value: mode,
                                label: Text(mode.label),
                              ),
                            )
                            .toList(growable: false),
                        selected: <CompanionAuthMode>{visibleAuthMode},
                        onSelectionChanged: (value) {
                          onAuthModeChanged(value.first);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (visibleAuthMode == CompanionAuthMode.token)
                        TextField(
                          controller: tokenController,
                          decoration: const InputDecoration(
                            hintText: 'Shared gateway token',
                          ),
                        ),
                      if (visibleAuthMode == CompanionAuthMode.password)
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Gateway password',
                          ),
                        ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: autoConnect,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reconnect on launch'),
                        subtitle: const Text(
                          'Reuse the last manual or discovered target',
                        ),
                        onChanged: onAutoConnectChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SheetSection(
                  title: 'Maintenance',
                  subtitle: 'Clear saved trust or credentials when re-testing.',
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onForgetTrust,
                              child: const Text('Forget trust'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onClearSavedCredentials,
                              child: const Text('Clear auth'),
                            ),
                          ),
                        ],
                      ),
                      if (kDebugMode) ...<Widget>[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () {
                                    unawaited(onResetAllDebug());
                                  },
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Reset app state'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFD8D1C5))),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: controller.busy
                        ? null
                        : () {
                            unawaited(onConnectManual());
                          },
                    child: Text(controller.busy ? 'Working…' : connectLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.client == null ? null : onDisconnect,
                    child: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (embedded) {
      return panel;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E3DD)),
      ),
      child: panel,
    );
  }
}

class _ConnectionsSheet extends StatelessWidget {
  const _ConnectionsSheet({required this.desktop, required this.child});

  final bool desktop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = desktop
        ? const BorderRadius.only(
            topLeft: Radius.circular(28),
            bottomLeft: Radius.circular(28),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
          )
        : const BorderRadius.vertical(top: Radius.circular(28));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EC),
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0xFFD8D1C5)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!desktop)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D1C5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Connections',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure endpoints, auth, discovery, and TLS trust.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5E706B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2DBD0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5E706B)),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _DiscoveredGatewayTile extends StatelessWidget {
  const _DiscoveredGatewayTile({
    required this.gateway,
    required this.busy,
    required this.connectLabel,
    required this.onConnect,
  });

  final GatewayDiscoveredGateway gateway;
  final bool busy;
  final String connectLabel;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    gateway.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(label: Text(gateway.tlsEnabled ? 'TLS' : 'No TLS')),
              ],
            ),
            const SizedBox(height: 4),
            Text('${gateway.targetHost}:${gateway.port}'),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: busy ? null : onConnect,
              child: Text(connectLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairingApprovalCard extends StatelessWidget {
  const _PairingApprovalCard({
    required this.requestId,
    required this.url,
    required this.authMode,
  });

  final String requestId;
  final String url;
  final CompanionAuthMode authMode;

  @override
  Widget build(BuildContext context) {
    final hostCommand = 'openclaw devices approve $requestId';
    final remoteCommand = _buildRemoteApproveCommand(
      requestId: requestId,
      url: url,
      authMode: authMode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _HintCard(
          text:
              'Pending request: $requestId. Approve it from any operator session, then come back here and reconnect.',
          tint: const Color(0xFFF4EEE3),
        ),
        const SizedBox(height: 12),
        _CommandSnippet(
          title: 'On the gateway host',
          command: hostCommand,
        ),
        if (remoteCommand != null) ...<Widget>[
          const SizedBox(height: 12),
          _CommandSnippet(
            title: 'From another machine with explicit gateway access',
            command: remoteCommand,
          ),
        ],
      ],
    );
  }
}

class _CommandSnippet extends StatelessWidget {
  const _CommandSnippet({
    required this.title,
    required this.command,
  });

  final String title;
  final String command;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF162220),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _copyCommand(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFD4E0DC),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy command',
                    onPressed: () => _copyCommand(context),
                    icon: const Icon(
                      Icons.content_copy_rounded,
                      size: 18,
                      color: Color(0xFFD4E0DC),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SelectableText(
                command,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyCommand(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: command));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied command to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

String? _buildRemoteApproveCommand({
  required String requestId,
  required String url,
  required CompanionAuthMode authMode,
}) {
  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) {
    return null;
  }

  final authFragment = switch (authMode) {
    CompanionAuthMode.token => '--token <gateway-token>',
    CompanionAuthMode.password => '--password <gateway-password>',
    CompanionAuthMode.none => null,
  };

  final pieces = <String>[
    'openclaw devices approve $requestId',
    "--url '$trimmedUrl'",
    ...?authFragment == null ? null : <String>[authFragment],
  ];
  return pieces.join(' ');
}
