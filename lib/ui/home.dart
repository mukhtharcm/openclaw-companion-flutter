import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:openclaw_companion/app/controller.dart';
import 'package:openclaw_companion/app/models.dart';
import 'package:openclaw_gateway/openclaw_gateway.dart';

class CompanionHome extends StatefulWidget {
  const CompanionHome({
    super.key,
    required this.controller,
  });

  final CompanionController controller;

  @override
  State<CompanionHome> createState() => _CompanionHomeState();
}

class _CompanionHomeState extends State<CompanionHome> {
  final GlobalKey<ScaffoldState> _mobileScaffoldKey =
      GlobalKey<ScaffoldState>();
  final TextEditingController _setupCodeController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _sessionController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  int _selectedSection = 0;
  CompanionAuthMode _draftAuthMode = CompanionAuthMode.token;
  bool _draftAutoConnect = true;
  String _draftThinking = 'default';
  String? _shownPromptStableId;

  static const List<_SectionItem> _sections = <_SectionItem>[
    _SectionItem('Overview', Icons.dashboard_outlined, Icons.dashboard),
    _SectionItem('Sessions', Icons.forum_outlined, Icons.forum),
    _SectionItem('Explore', Icons.travel_explore_outlined, Icons.travel_explore),
    _SectionItem('Events', Icons.bolt_outlined, Icons.bolt),
  ];

  @override
  void initState() {
    super.initState();
    _applyConfig(widget.controller.config);
  }

  @override
  void dispose() {
    _setupCodeController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _sessionController.dispose();
    _promptController.dispose();
    unawaited(widget.controller.shutdown());
    super.dispose();
  }

  void _applyConfig(CompanionConfig config) {
    _urlController.text = config.manualUrl;
    _tokenController.text = config.token;
    _passwordController.text = config.password;
    _sessionController.text = config.preferredSessionKey;
    _draftAuthMode = config.authMode;
    _draftAutoConnect = config.autoConnect;
    _draftThinking = config.thinking;
  }

  Future<void> _connectManual() async {
    await widget.controller.connectManual(
      _urlController.text,
      authMode: _draftAuthMode,
      token: _tokenController.text,
      password: _passwordController.text,
      autoConnect: _draftAutoConnect,
    );
  }

  Future<void> _importSetupCode() async {
    final config = await widget.controller.importSetupCode(
      _setupCodeController.text,
    );
    if (config == null || !mounted) {
      return;
    }
    setState(() {
      _applyConfig(config);
      _setupCodeController.clear();
    });
  }

  void _maybeShowTrustPrompt(CompanionController controller) {
    final prompt = controller.pendingTrustPrompt;
    if (prompt == null) {
      _shownPromptStableId = null;
      return;
    }
    if (_shownPromptStableId == prompt.stableId) {
      return;
    }
    _shownPromptStableId = prompt.stableId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text('Trust ${prompt.title}?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'This gateway presented a new TLS fingerprint. Compare it before trusting.',
                ),
                const SizedBox(height: 16),
                SelectableText(
                  prompt.fingerprint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  prompt.uri.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Trust and connect'),
              ),
            ],
          );
        },
      );
      if (!mounted) {
        return;
      }
      if (accepted == true) {
        await controller.acceptTrustPrompt();
      } else {
        controller.declineTrustPrompt();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        _maybeShowTrustPrompt(controller);

        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1120;
            final connectionPanel = _ConnectionPanel(
              controller: controller,
              setupCodeController: _setupCodeController,
              urlController: _urlController,
              tokenController: _tokenController,
              passwordController: _passwordController,
              authMode: _draftAuthMode,
              autoConnect: _draftAutoConnect,
              onAuthModeChanged: (value) {
                setState(() {
                  _draftAuthMode = value;
                });
              },
              onAutoConnectChanged: (value) {
                setState(() {
                  _draftAutoConnect = value;
                });
                unawaited(controller.setAutoConnect(value));
              },
              onImportSetupCode: _importSetupCode,
              onConnectManual: _connectManual,
              onConnectDiscovered: (gateway) {
                unawaited(
                  controller.connectDiscovered(
                    gateway,
                    authMode: _draftAuthMode,
                    token: _tokenController.text,
                    password: _passwordController.text,
                    autoConnect: _draftAutoConnect,
                  ),
                );
              },
              onDisconnect: () => unawaited(controller.disconnect()),
              onForgetTrust: () => unawaited(controller.forgetCurrentTrust()),
              onClearSavedCredentials: () async {
                await controller.clearSavedCredentials();
                if (!mounted) {
                  return;
                }
                setState(() {
                  _tokenController.clear();
                  _passwordController.clear();
                  _draftAuthMode = CompanionAuthMode.none;
                });
              },
            );

            final body = _CompanionBody(
              controller: controller,
              selectedSection: _selectedSection,
              sessionController: _sessionController,
              promptController: _promptController,
              thinking: _draftThinking,
              onThinkingChanged: (value) {
                setState(() {
                  _draftThinking = value;
                });
                unawaited(controller.setThinking(value));
              },
              onSessionChanged: (value) {
                _sessionController.text = value;
                unawaited(controller.setPreferredSessionKey(value));
              },
              onSessionSelected: (key) {
                _sessionController.text = key;
                controller.selectSession(key);
              },
              onReloadHistory: () {
                final value = _sessionController.text.trim();
                if (value.isNotEmpty) {
                  unawaited(controller.setPreferredSessionKey(value));
                }
                unawaited(controller.reloadHistory());
              },
              onSendPrompt: () async {
                final value = _sessionController.text.trim();
                if (value.isNotEmpty) {
                  await controller.setPreferredSessionKey(value);
                }
                await controller.sendPrompt(_promptController.text);
                if (!mounted || controller.errorText != null) {
                  return;
                }
                _promptController.clear();
              },
              onAbortRun: () => unawaited(controller.abortRun()),
            );

            if (desktop) {
              return Scaffold(
                body: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[Color(0xFFF4F6F2), Color(0xFFE7ECE7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: <Widget>[
                          SizedBox(width: 340, child: connectionPanel),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _DesktopShell(
                              selectedSection: _selectedSection,
                              onSectionSelected: (value) {
                                setState(() {
                                  _selectedSection = value;
                                });
                              },
                              body: body,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return Scaffold(
              key: _mobileScaffoldKey,
              appBar: AppBar(
                title: const Text('OpenClaw Companion'),
                actions: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.settings_input_component_outlined),
                    onPressed: () {
                      _mobileScaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                ],
              ),
              endDrawer: Drawer(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: connectionPanel,
                  ),
                ),
              ),
              body: body,
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedSection,
                onDestinationSelected: (value) {
                  setState(() {
                    _selectedSection = value;
                  });
                },
                destinations: _sections
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: item.label,
                      ),
                    )
                    .toList(growable: false),
              ),
            );
          },
        );
      },
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.selectedSection,
    required this.onSectionSelected,
    required this.body,
  });

  final int selectedSection;
  final ValueChanged<int> onSectionSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFD9E3DD)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: NavigationRail(
                selectedIndex: selectedSection,
                onDestinationSelected: onSectionSelected,
                labelType: NavigationRailLabelType.all,
                destinations: _CompanionHomeSections.sections
                    .map(
                      (item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionHomeSections {
  static const List<_SectionItem> sections = <_SectionItem>[
    _SectionItem('Overview', Icons.dashboard_outlined, Icons.dashboard),
    _SectionItem('Sessions', Icons.forum_outlined, Icons.forum),
    _SectionItem('Explore', Icons.travel_explore_outlined, Icons.travel_explore),
    _SectionItem('Events', Icons.bolt_outlined, Icons.bolt),
  ];
}

class _CompanionBody extends StatelessWidget {
  const _CompanionBody({
    required this.controller,
    required this.selectedSection,
    required this.sessionController,
    required this.promptController,
    required this.thinking,
    required this.onThinkingChanged,
    required this.onSessionChanged,
    required this.onSessionSelected,
    required this.onReloadHistory,
    required this.onSendPrompt,
    required this.onAbortRun,
  });

  final CompanionController controller;
  final int selectedSection;
  final TextEditingController sessionController;
  final TextEditingController promptController;
  final String thinking;
  final ValueChanged<String> onThinkingChanged;
  final ValueChanged<String> onSessionChanged;
  final ValueChanged<String> onSessionSelected;
  final VoidCallback onReloadHistory;
  final Future<void> Function() onSendPrompt;
  final VoidCallback onAbortRun;

  @override
  Widget build(BuildContext context) {
    final title = _CompanionHomeSections.sections[selectedSection].label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PageHeader(
          title: title,
          subtitle: controller.connectedGatewayTitle == null
              ? 'Operator-side gateway companion'
              : '${controller.connectedGatewayTitle} · ${controller.connectionState.phase.name}',
          errorText: controller.errorText,
        ),
        const SizedBox(height: 20),
        Expanded(
          child: switch (selectedSection) {
            0 => _OverviewPage(controller: controller),
            1 => _SessionsPage(
                controller: controller,
                sessionController: sessionController,
                promptController: promptController,
                thinking: thinking,
                onThinkingChanged: onThinkingChanged,
                onSessionChanged: onSessionChanged,
                onSessionSelected: onSessionSelected,
                onReloadHistory: onReloadHistory,
                onSendPrompt: onSendPrompt,
                onAbortRun: onAbortRun,
              ),
            2 => _ExplorePage(controller: controller),
            _ => _EventsPage(controller: controller),
          },
        ),
      ],
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({
    required this.controller,
    required this.setupCodeController,
    required this.urlController,
    required this.tokenController,
    required this.passwordController,
    required this.authMode,
    required this.autoConnect,
    required this.onAuthModeChanged,
    required this.onAutoConnectChanged,
    required this.onImportSetupCode,
    required this.onConnectManual,
    required this.onConnectDiscovered,
    required this.onDisconnect,
    required this.onForgetTrust,
    required this.onClearSavedCredentials,
  });

  final CompanionController controller;
  final TextEditingController setupCodeController;
  final TextEditingController urlController;
  final TextEditingController tokenController;
  final TextEditingController passwordController;
  final CompanionAuthMode authMode;
  final bool autoConnect;
  final ValueChanged<CompanionAuthMode> onAuthModeChanged;
  final ValueChanged<bool> onAutoConnectChanged;
  final Future<void> Function() onImportSetupCode;
  final Future<void> Function() onConnectManual;
  final ValueChanged<GatewayDiscoveredGateway> onConnectDiscovered;
  final VoidCallback onDisconnect;
  final VoidCallback onForgetTrust;
  final VoidCallback onClearSavedCredentials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD9E3DD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Connection',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _StatusChip(controller: controller),
              const SizedBox(height: 18),
              Text(
                'Setup code',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: setupCodeController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Paste JSON or base64 setup code',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: controller.busy
                    ? null
                    : () {
                        unawaited(onImportSetupCode());
                      },
                child: const Text('Import setup code'),
              ),
              const SizedBox(height: 20),
              Text(
                'Manual endpoint',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  hintText: 'wss://gateway.example:8443 or ws://127.0.0.1:18789',
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<CompanionAuthMode>(
                segments: CompanionAuthMode.values
                    .map(
                      (mode) => ButtonSegment<CompanionAuthMode>(
                        value: mode,
                        label: Text(mode.label),
                      ),
                    )
                    .toList(growable: false),
                selected: <CompanionAuthMode>{authMode},
                onSelectionChanged: (value) {
                  onAuthModeChanged(value.first);
                },
              ),
              const SizedBox(height: 12),
              if (authMode == CompanionAuthMode.token)
                TextField(
                  controller: tokenController,
                  decoration: const InputDecoration(
                    hintText: 'Shared gateway token',
                  ),
                ),
              if (authMode == CompanionAuthMode.password)
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Gateway password',
                  ),
                ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: autoConnect,
                contentPadding: EdgeInsets.zero,
                title: const Text('Reconnect on launch'),
                subtitle: const Text('Reuse the last manual or discovered target'),
                onChanged: onAutoConnectChanged,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: controller.busy
                          ? null
                          : () {
                              unawaited(onConnectManual());
                            },
                      child: const Text('Connect'),
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
              const SizedBox(height: 22),
              Text(
                'Discovered gateways',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (controller.discoveredGateways.isEmpty)
                _HintCard(
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
                            onConnect: () => onConnectDiscovered(gateway),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              const SizedBox(height: 22),
              Text(
                'Maintenance',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({
    required this.controller,
  });

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            _MetricCard(
              title: 'Gateway',
              value: controller.serverVersion ?? 'Disconnected',
              subtitle: controller.connectedGatewayTitle ?? 'No active endpoint',
            ),
            _MetricCard(
              title: 'Auth state',
              value: controller.client?.hello.auth?.role ?? 'offline',
              subtitle: controller.client?.hello.auth?.scopes.join(', ') ??
                  'No granted scopes yet',
            ),
            _MetricCard(
              title: 'Sessions',
              value: '${controller.sessionsList?.count ?? 0}',
              subtitle: controller.config.preferredSessionKey,
            ),
            _MetricCard(
              title: 'Nodes',
              value: '${controller.nodes.length}',
              subtitle: controller.nodes.isEmpty ? 'No paired nodes' : 'Paired nodes available',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            SizedBox(
              width: 420,
              child: _InfoCard(
                title: 'Health',
                child: controller.health == null
                    ? const _EmptyState('Connect and refresh to load health.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _InfoLine('OK', controller.health!.ok ? 'yes' : 'no'),
                          _InfoLine('Default agent', controller.health!.defaultAgentId ?? '—'),
                          _InfoLine(
                            'Heartbeat',
                            controller.health!.heartbeatSeconds?.toString() ?? '—',
                          ),
                          const SizedBox(height: 10),
                          ...controller.health!.channelOrder.map((id) {
                            final channel = controller.health!.channels[id];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${controller.health!.channelLabels[id] ?? id}: ${channel ?? 'unknown'}',
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ),
            SizedBox(
              width: 420,
              child: _InfoCard(
                title: 'Usage and cron',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _InfoLine(
                      'Usage providers',
                      controller.usage == null
                          ? '—'
                          : '${controller.usage!.providers.length}',
                    ),
                    _InfoLine(
                      'Models tracked',
                      '${controller.models?.models.length ?? 0}',
                    ),
                    _InfoLine(
                      'Cron enabled',
                      controller.cronStatus?.enabled == true ? 'yes' : 'no',
                    ),
                    _InfoLine('Cron jobs', '${controller.cronStatus?.jobs ?? 0}'),
                    _InfoLine(
                      'Voice wake triggers',
                      controller.voiceWake?.triggers.join(', ') ?? '—',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Status snapshot',
          child: controller.status == null
              ? const _EmptyState('No status snapshot loaded yet.')
              : SelectableText(
                  const JsonEncoder.withIndent('  ').convert(controller.status!.raw),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
        ),
      ],
    );
  }
}

class _SessionsPage extends StatelessWidget {
  const _SessionsPage({
    required this.controller,
    required this.sessionController,
    required this.promptController,
    required this.thinking,
    required this.onThinkingChanged,
    required this.onSessionChanged,
    required this.onSessionSelected,
    required this.onReloadHistory,
    required this.onSendPrompt,
    required this.onAbortRun,
  });

  final CompanionController controller;
  final TextEditingController sessionController;
  final TextEditingController promptController;
  final String thinking;
  final ValueChanged<String> onThinkingChanged;
  final ValueChanged<String> onSessionChanged;
  final ValueChanged<String> onSessionSelected;
  final VoidCallback onReloadHistory;
  final Future<void> Function() onSendPrompt;
  final VoidCallback onAbortRun;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final sessionList = _InfoCard(
          title: 'Sessions',
          child: controller.sessionsList == null
              ? const _EmptyState('No session list loaded yet.')
              : Column(
                  children: controller.sessionsList!.sessions
                      .map(
                        (session) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(session.displayName ??
                              session.derivedTitle ??
                              session.label ??
                              session.key),
                          subtitle: Text(
                            session.lastMessagePreview ?? session.kind,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: session.key == controller.config.preferredSessionKey
                              ? const Icon(Icons.check_circle, color: Color(0xFF16423C))
                              : null,
                          onTap: () => onSessionSelected(session.key),
                        ),
                      )
                      .toList(growable: false),
                ),
        );

        final chatPanel = Column(
          children: <Widget>[
            _InfoCard(
              title: 'Compose',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: sessionController,
                          decoration: const InputDecoration(
                            labelText: 'Session key',
                          ),
                          onSubmitted: onSessionChanged,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: thinking,
                          decoration: const InputDecoration(
                            labelText: 'Thinking',
                          ),
                          items: const <String>[
                            'default',
                            'low',
                            'medium',
                            'high',
                          ]
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              onThinkingChanged(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'Send a message to the selected session',
                    ),
                  ),
                  if (controller.streamingSummary != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _HintCard(text: controller.streamingSummary!),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      FilledButton(
                        onPressed: controller.busy
                            ? null
                            : () {
                                unawaited(onSendPrompt());
                              },
                        child: const Text('Send'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed:
                            controller.activeRunId == null ? null : onAbortRun,
                        child: const Text('Abort run'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: controller.busy ? null : onReloadHistory,
                        child: const Text('Reload history'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _InfoCard(
                title: 'History',
                child: controller.history.isEmpty
                    ? const _EmptyState('No chat history loaded yet.')
                    : ListView.separated(
                        itemCount: controller.history.length,
                        separatorBuilder: (_, _) => const Divider(height: 18),
                        itemBuilder: (context, index) {
                          final message = controller.history[index];
                          return _HistoryTile(message: message);
                        },
                      ),
              ),
            ),
          ],
        );

        if (!wide) {
          return ListView(
            children: <Widget>[
              SizedBox(height: 340, child: sessionList),
              const SizedBox(height: 16),
              SizedBox(height: 760, child: chatPanel),
            ],
          );
        }

        return Row(
          children: <Widget>[
            SizedBox(width: 320, child: sessionList),
            const SizedBox(width: 16),
            Expanded(child: chatPanel),
          ],
        );
      },
    );
  }
}

class _ExplorePage extends StatelessWidget {
  const _ExplorePage({
    required this.controller,
  });

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            SizedBox(
              width: 420,
              child: _InfoCard(
                title: 'Channels',
                child: controller.channelsStatus == null
                    ? const _EmptyState('No channel snapshot yet.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: controller.channelsStatus!.channelOrder
                            .map(
                              (channelId) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  '${controller.channelsStatus!.channelLabels[channelId] ?? channelId}: ${controller.channelsStatus!.channels[channelId] ?? 'unknown'}',
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
            ),
            SizedBox(
              width: 420,
              child: _InfoCard(
                title: 'Nodes',
                child: controller.nodes.isEmpty
                    ? const _EmptyState('No paired nodes reported.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: controller.nodes
                            .map(
                              (node) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  '${node.displayName ?? node.nodeId} · ${node.connected ? 'connected' : 'offline'}',
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Models',
          child: controller.models == null
              ? const _EmptyState('No model catalog loaded.')
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: controller.models!.models
                      .map(
                        (model) => Chip(
                          label: Text('${model.provider} · ${model.name}'),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Tools',
          child: controller.tools == null
              ? const _EmptyState('No tool catalog loaded.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: controller.tools!.groups
                      .map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                group.label,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: group.tools
                                    .map(
                                      (tool) => Chip(
                                        label: Text(tool.label),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }
}

class _EventsPage extends StatelessWidget {
  const _EventsPage({
    required this.controller,
  });

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final eventFeed = _InfoCard(
          title: 'Gateway events',
          child: controller.eventLines.isEmpty
              ? const _EmptyState('No events yet.')
              : ListView.separated(
                  itemCount: controller.eventLines.length,
                  separatorBuilder: (_, _) => const Divider(height: 18),
                  itemBuilder: (context, index) {
                    final line = controller.eventLines[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${line.timeLabel} · ${line.name}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(line.summary),
                      ],
                    );
                  },
                ),
        );

        final activityFeed = _InfoCard(
          title: 'Activity log',
          child: controller.activityLog.isEmpty
              ? const _EmptyState('No activity yet.')
              : ListView.builder(
                  itemCount: controller.activityLog.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SelectableText(
                        controller.activityLog[index],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    );
                  },
                ),
        );

        if (!wide) {
          return ListView(
            children: <Widget>[
              SizedBox(height: 420, child: eventFeed),
              const SizedBox(height: 16),
              SizedBox(height: 420, child: activityFeed),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: eventFeed),
            const SizedBox(width: 16),
            Expanded(child: activityFeed),
          ],
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.errorText,
  });

  final String title;
  final String subtitle;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF4A665F),
              ),
        ),
        if (errorText != null) ...<Widget>[
          const SizedBox(height: 12),
          _HintCard(
            text: errorText!,
            tint: const Color(0xFFFFE4E1),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.controller,
  });

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    final phase = controller.connectionState.phase;
    final color = switch (phase) {
      GatewayConnectionPhase.connected => const Color(0xFF17594E),
      GatewayConnectionPhase.connecting => const Color(0xFF9A6700),
      GatewayConnectionPhase.reconnecting => const Color(0xFF9A6700),
      GatewayConnectionPhase.closed => const Color(0xFFB42318),
      GatewayConnectionPhase.disconnected => const Color(0xFF667A74),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 8),
            Text(
              '${phase.name}${controller.serverVersion == null ? '' : ' · ${controller.serverVersion}'}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    required this.onConnect,
  });

  final GatewayDiscoveredGateway gateway;
  final bool busy;
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
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF4A665F),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.text,
    this.tint = const Color(0xFFE7EEEA),
  });

  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF4A665F),
            ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF4A665F),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.message,
  });

  final JsonMap message;

  @override
  Widget build(BuildContext context) {
    final role = message['role']?.toString() ?? 'message';
    final text = _extractMessageText(message);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          role,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF4A665F),
              ),
        ),
        const SizedBox(height: 6),
        SelectableText(text),
      ],
    );
  }
}

class _SectionItem {
  const _SectionItem(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

String _extractMessageText(JsonMap json) {
  final content = json['content'];
  if (content is String && content.trim().isNotEmpty) {
    return content;
  }
  if (content is List) {
    final parts = <String>[];
    for (final entry in content) {
      if (entry is Map<Object?, Object?>) {
        final type = entry['type'];
        if (type == 'text') {
          final text = entry['text'];
          if (text is String && text.trim().isNotEmpty) {
            parts.add(text.trim());
          }
        }
      }
    }
    if (parts.isNotEmpty) {
      return parts.join('\n\n');
    }
  }
  return const JsonEncoder.withIndent('  ').convert(json);
}
