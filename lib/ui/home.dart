import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:openclaw_companion/app/controller.dart';
import 'package:openclaw_companion/app/models.dart';
import 'package:openclaw_gateway/openclaw_gateway.dart';

class CompanionHome extends StatefulWidget {
  const CompanionHome({super.key, required this.controller});

  final CompanionController controller;

  @override
  State<CompanionHome> createState() => _CompanionHomeState();
}

class _CompanionHomeState extends State<CompanionHome> {
  final TextEditingController _setupCodeController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _sessionController = TextEditingController();
  final TextEditingController _sessionSearchController =
      TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  int _selectedSection = 0;
  CompanionAuthMode _draftAuthMode = CompanionAuthMode.token;
  bool _draftAutoConnect = true;
  String _draftThinking = 'default';
  String _sessionSearchQuery = '';
  String? _shownPromptStableId;

  static const List<_SectionItem> _sections = <_SectionItem>[
    _SectionItem('Home', Icons.grid_view_outlined, Icons.grid_view_rounded),
    _SectionItem('Chat', Icons.forum_outlined, Icons.forum_rounded),
    _SectionItem(
      'Inspect',
      Icons.travel_explore_outlined,
      Icons.travel_explore_rounded,
    ),
    _SectionItem(
      'Logs',
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
    ),
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
    _sessionSearchController.dispose();
    _promptController.dispose();
    unawaited(widget.controller.shutdown());
    super.dispose();
  }

  void _applyConfig(CompanionConfig config) {
    _urlController.text = config.manualUrl;
    _tokenController.text = config.token;
    _passwordController.text = config.password;
    _sessionController.text = config.preferredSessionKey;
    _draftAuthMode = config.authMode == CompanionAuthMode.none
        ? CompanionAuthMode.token
        : config.authMode;
    _draftAutoConnect = config.autoConnect;
    _draftThinking = config.thinking;
  }

  Future<void> _connectManual() async {
    final hadPrompt = widget.controller.pendingTrustPrompt != null;
    await widget.controller.connectManual(
      _urlController.text,
      authMode: _draftAuthMode,
      token: _tokenController.text,
      password: _passwordController.text,
      autoConnect: _draftAutoConnect,
    );
    if (!mounted) {
      return;
    }
    _maybeCloseConnectionsPanel(hadPrompt: hadPrompt);
  }

  Future<void> _importSetupCode() async {
    final hadPrompt = widget.controller.pendingTrustPrompt != null;
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
    _maybeCloseConnectionsPanel(hadPrompt: hadPrompt);
  }

  Widget _buildConnectionPanel({required bool embedded}) {
    return _ConnectionPanel(
      controller: widget.controller,
      setupCodeController: _setupCodeController,
      urlController: _urlController,
      tokenController: _tokenController,
      passwordController: _passwordController,
      authMode: _draftAuthMode,
      embedded: embedded,
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
        unawaited(widget.controller.setAutoConnect(value));
      },
      onImportSetupCode: _importSetupCode,
      onConnectManual: _connectManual,
      onConnectDiscovered: (gateway) {
        unawaited(() async {
          final hadPrompt = widget.controller.pendingTrustPrompt != null;
          await widget.controller.connectDiscovered(
            gateway,
            authMode: _draftAuthMode,
            token: _tokenController.text,
            password: _passwordController.text,
            autoConnect: _draftAutoConnect,
          );
          if (!mounted) {
            return;
          }
          _maybeCloseConnectionsPanel(hadPrompt: hadPrompt);
        }());
      },
      onDisconnect: () => unawaited(widget.controller.disconnect()),
      onForgetTrust: () => unawaited(widget.controller.forgetCurrentTrust()),
      onClearSavedCredentials: () async {
        await widget.controller.clearSavedCredentials();
        if (!mounted) {
          return;
        }
        setState(() {
          _tokenController.clear();
          _passwordController.clear();
          _draftAuthMode = CompanionAuthMode.token;
        });
      },
      onResetAllDebug: () async {
        await widget.controller.resetAllState();
        if (!mounted) {
          return;
        }
        setState(() {
          _setupCodeController.clear();
          _urlController.clear();
          _tokenController.clear();
          _passwordController.clear();
          _sessionController.text =
              widget.controller.config.preferredSessionKey;
          _sessionSearchController.clear();
          _sessionSearchQuery = '';
          _promptController.clear();
          _applyConfig(widget.controller.config);
        });
      },
    );
  }

  Future<void> _openConnectionsPanel({required bool desktop}) async {
    if (!mounted) {
      return;
    }
    final sheet = _ConnectionsSheet(
      desktop: desktop,
      child: _buildConnectionPanel(embedded: true),
    );
    if (desktop) {
      await showGeneralDialog<void>(
        context: context,
        barrierLabel: 'Connections',
        barrierDismissible: true,
        barrierColor: const Color(0x33000000),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 440,
                      minWidth: 380,
                      maxHeight: double.infinity,
                    ),
                    child: sheet,
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: FractionallySizedBox(heightFactor: 0.92, child: sheet),
        );
      },
    );
  }

  void _maybeCloseConnectionsPanel({required bool hadPrompt}) {
    final hasPromptNow = widget.controller.pendingTrustPrompt != null;
    if (hasPromptNow && !hadPrompt) {
      return;
    }
    if (widget.controller.connected && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
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
            final desktop = constraints.maxWidth >= 860;

            final body = _CompanionBody(
              controller: controller,
              selectedSection: _selectedSection,
              compact: !desktop,
              sessionController: _sessionController,
              sessionSearchController: _sessionSearchController,
              promptController: _promptController,
              sessionSearchQuery: _sessionSearchQuery,
              thinking: _draftThinking,
              onOpenConnections: () =>
                  unawaited(_openConnectionsPanel(desktop: desktop)),
              onRefresh: () => unawaited(controller.refresh()),
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
              onSessionSearchChanged: (value) {
                if (_sessionSearchQuery == value) {
                  return;
                }
                setState(() {
                  _sessionSearchQuery = value;
                });
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
                  decoration: const BoxDecoration(color: Color(0xFFF0F2EE)),
                  child: SafeArea(
                    child: Row(
                      children: <Widget>[
                        _DesktopSidebar(
                          controller: controller,
                          selectedSection: _selectedSection,
                          onOpenConnections: () =>
                              unawaited(_openConnectionsPanel(desktop: true)),
                          onSectionSelected: (value) {
                            setState(() {
                              _selectedSection = value;
                            });
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 24, 32, 28),
                            child: body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _selectedSection == 1 ? 12 : 16,
                    _selectedSection == 1 ? 10 : 16,
                    _selectedSection == 1 ? 12 : 16,
                    0,
                  ),
                  child: body,
                ),
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: _CompactNavBar(
                    selectedIndex: _selectedSection,
                    items: _sections,
                    onSelected: (value) {
                      setState(() {
                        _selectedSection = value;
                      });
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.controller,
    required this.selectedSection,
    required this.onOpenConnections,
    required this.onSectionSelected,
  });

  final CompanionController controller;
  final int selectedSection;
  final VoidCallback onOpenConnections;
  final ValueChanged<int> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF162220)),
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'OpenClaw',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Companion',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFFB2C1BB),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                controller.connectedGatewayTitle ?? 'Operator workspace',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF96AAA3),
                ),
              ),
              const SizedBox(height: 20),
              ..._CompanionHomeSections.sections.indexed.map((entry) {
                final index = entry.$1;
                final item = entry.$2;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _DesktopSectionButton(
                    item: item,
                    selected: index == selectedSection,
                    onPressed: () => onSectionSelected(index),
                  ),
                );
              }),
              const Spacer(),
              _SidebarStatus(controller: controller),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: onOpenConnections,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF253531),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    controller.connected ? 'Connections' : 'Connect gateway',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSectionButton extends StatelessWidget {
  const _DesktopSectionButton({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final _SectionItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? Colors.white : const Color(0xFF92A59E);
    return Material(
      color: selected ? const Color(0xFF253531) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 20,
                color: textColor,
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactNavBar extends StatelessWidget {
  const _CompactNavBar({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_SectionItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF162220),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: items.indexed
              .map((entry) {
                final index = entry.$1;
                final item = entry.$2;
                final selected = index == selectedIndex;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: selected
                          ? const Color(0xFF253531)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onSelected(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                selected ? item.selectedIcon : item.icon,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF92A59E),
                                size: 20,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF92A59E),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _CompanionHomeSections {
  static const List<_SectionItem> sections = <_SectionItem>[
    _SectionItem('Home', Icons.grid_view_outlined, Icons.grid_view_rounded),
    _SectionItem('Chat', Icons.forum_outlined, Icons.forum_rounded),
    _SectionItem(
      'Inspect',
      Icons.travel_explore_outlined,
      Icons.travel_explore_rounded,
    ),
    _SectionItem(
      'Logs',
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
    ),
  ];
}

class _CompanionBody extends StatelessWidget {
  const _CompanionBody({
    required this.controller,
    required this.selectedSection,
    required this.compact,
    required this.sessionController,
    required this.sessionSearchController,
    required this.promptController,
    required this.sessionSearchQuery,
    required this.thinking,
    required this.onOpenConnections,
    required this.onRefresh,
    required this.onThinkingChanged,
    required this.onSessionChanged,
    required this.onSessionSearchChanged,
    required this.onSessionSelected,
    required this.onReloadHistory,
    required this.onSendPrompt,
    required this.onAbortRun,
  });

  final CompanionController controller;
  final int selectedSection;
  final bool compact;
  final TextEditingController sessionController;
  final TextEditingController sessionSearchController;
  final TextEditingController promptController;
  final String sessionSearchQuery;
  final String thinking;
  final VoidCallback onOpenConnections;
  final VoidCallback onRefresh;
  final ValueChanged<String> onThinkingChanged;
  final ValueChanged<String> onSessionChanged;
  final ValueChanged<String> onSessionSearchChanged;
  final ValueChanged<String> onSessionSelected;
  final VoidCallback onReloadHistory;
  final Future<void> Function() onSendPrompt;
  final VoidCallback onAbortRun;

  @override
  Widget build(BuildContext context) {
    final page = _CompanionHomeSections.sections[selectedSection];
    final compactChat = compact && selectedSection == 1;
    final showPageHeader =
        !compactChat || controller.needsInitialConnectionSetup;
    final showCompactChatBanner =
        compactChat &&
        !controller.needsInitialConnectionSetup &&
        (!controller.connected || controller.errorText != null);
    final subtitle = switch (selectedSection) {
      0 => 'Gateway status, session volume, and recent activity.',
      1 => 'Stay in one session, review history, and send prompts quickly.',
      2 => 'Inspect channels, models, tools, and paired nodes.',
      _ => 'Watch live gateway events and the local activity log.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showPageHeader) ...<Widget>[
          _PageHeader(
            title: page.label,
            subtitle: subtitle,
            gatewayLabel: controller.connectedGatewayTitle,
            connectionState: controller.connectionState,
            errorText: controller.errorText,
            onOpenConnections: onOpenConnections,
            onRefresh: onRefresh,
          ),
          SizedBox(height: compactChat ? 14 : 24),
        ] else if (showCompactChatBanner) ...<Widget>[
          _CompactChatBanner(
            gatewayLabel: controller.connectedGatewayTitle,
            connectionState: controller.connectionState,
            errorText: controller.errorText,
            onOpenConnections: onOpenConnections,
          ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: controller.needsInitialConnectionSetup
              ? _FirstRunPrompt(
                  discoveredGateways: controller.discoveredGateways,
                  onOpenConnections: onOpenConnections,
                )
              : switch (selectedSection) {
                  0 => _OverviewPage(controller: controller),
                  1 => _SessionsPage(
                    controller: controller,
                    sessionController: sessionController,
                    sessionSearchController: sessionSearchController,
                    promptController: promptController,
                    sessionSearchQuery: sessionSearchQuery,
                    thinking: thinking,
                    onThinkingChanged: onThinkingChanged,
                    onSessionChanged: onSessionChanged,
                    onSessionSearchChanged: onSessionSearchChanged,
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

class _FirstRunPrompt extends StatelessWidget {
  const _FirstRunPrompt({
    required this.discoveredGateways,
    required this.onOpenConnections,
  });

  final List<GatewayDiscoveredGateway> discoveredGateways;
  final VoidCallback onOpenConnections;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E1D1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(
                      Icons.router_rounded,
                      size: 28,
                      color: Color(0xFF7A5C38),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Connect to a gateway first',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  discoveredGateways.isEmpty
                      ? 'Import a setup code or enter a gateway URL to start using the companion app.'
                      : 'A local gateway was discovered. Open Connections to use it, or enter a manual URL.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF4A665F),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: onOpenConnections,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Open Connections'),
                    ),
                    if (discoveredGateways.isNotEmpty)
                      _HeaderPill(
                        icon: Icons.wifi_tethering_rounded,
                        label:
                            '${discoveredGateways.length} local gateway${discoveredGateways.length == 1 ? '' : 's'} found',
                        tint: const Color(0xFFE6EBE3),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
    required this.embedded,
    required this.autoConnect,
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
  final CompanionAuthMode authMode;
  final bool embedded;
  final bool autoConnect;
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
                        'Import, discover, or connect manually. Saved auth and TLS trust are reused automatically.',
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
                      'Use a direct gateway URL for local, remote, or tunneled setups.',
                  child: Column(
                    children: <Widget>[
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

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.controller});

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    final sessionItems =
        controller.sessionsList?.sessions ?? const <GatewaySessionRow>[];
    final featuredSessions = sessionItems.take(5).toList(growable: false);

    final healthCard = _InfoCard(
      title: 'Health snapshot',
      child: controller.health == null
          ? const _EmptyState('Connect and refresh to load gateway health.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _InfoLine('Healthy', controller.health!.ok ? 'Yes' : 'No'),
                _InfoLine(
                  'Default agent',
                  controller.health!.defaultAgentId ?? '—',
                ),
                _InfoLine(
                  'Heartbeat',
                  controller.health!.heartbeatSeconds?.toString() ?? '—',
                ),
                const SizedBox(height: 12),
                ...controller.health!.channelOrder.take(6).map((id) {
                  final channel = controller.health!.channels[id];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${controller.health!.channelLabels[id] ?? id}: ${channel ?? 'unknown'}',
                    ),
                  );
                }),
              ],
            ),
    );

    final runtimeCard = _InfoCard(
      title: 'Runtime',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _InfoLine(
            'Connection',
            controller.connected ? 'Operator session active' : 'Offline',
          ),
          _InfoLine(
            'Voice wake',
            (controller.voiceWake?.triggers.isNotEmpty ?? false)
                ? 'Enabled'
                : 'Off',
          ),
          _InfoLine(
            'Cron',
            controller.cronStatus?.enabled == true
                ? '${controller.cronStatus?.jobs ?? 0} jobs'
                : 'Off',
          ),
          _InfoLine('Models', '${controller.models?.models.length ?? 0}'),
          _InfoLine('Tools', '${controller.tools?.groups.length ?? 0} groups'),
          _InfoLine('Nodes', '${controller.nodes.length}'),
        ],
      ),
    );

    final sessionsCard = _InfoCard(
      title: 'Session snapshot',
      child: featuredSessions.isEmpty
          ? const _EmptyState('No sessions loaded yet.')
          : Column(
              children: featuredSessions
                  .map(
                    (session) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  session.displayName ??
                                      session.derivedTitle ??
                                      session.label ??
                                      session.key,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  session.lastMessagePreview ?? session.kind,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (session.key ==
                              controller.config.preferredSessionKey)
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF7A5C38),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );

    final activityCard = _InfoCard(
      title: 'Recent activity',
      child: controller.activityLog.isEmpty
          ? const _EmptyState('No local activity yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: controller.activityLog
                  .take(6)
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final metricStrip = Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            _MetricCard(
              title: 'Gateway',
              value: controller.serverVersion ?? 'Disconnected',
              subtitle:
                  controller.connectedGatewayTitle ?? 'No active endpoint',
            ),
            _MetricCard(
              title: 'Role',
              value: controller.client?.hello.auth?.role ?? 'offline',
              subtitle:
                  controller.client?.hello.auth?.scopes.join(', ') ??
                  'No granted scopes',
            ),
            _MetricCard(
              title: 'Sessions',
              value: '${controller.sessionsList?.count ?? 0}',
              subtitle: controller.config.preferredSessionKey,
            ),
            _MetricCard(
              title: 'Nodes',
              value: '${controller.nodes.length}',
              subtitle: controller.nodes.isEmpty
                  ? 'No paired nodes'
                  : 'Paired nodes available',
            ),
          ],
        );

        if (!wide) {
          return ListView(
            children: <Widget>[
              metricStrip,
              const SizedBox(height: 16),
              healthCard,
              const SizedBox(height: 16),
              runtimeCard,
              const SizedBox(height: 16),
              sessionsCard,
              const SizedBox(height: 16),
              activityCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 6,
              child: ListView(
                children: <Widget>[
                  metricStrip,
                  const SizedBox(height: 16),
                  healthCard,
                  const SizedBox(height: 16),
                  runtimeCard,
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: ListView(
                children: <Widget>[
                  sessionsCard,
                  const SizedBox(height: 16),
                  activityCard,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SessionsPage extends StatefulWidget {
  const _SessionsPage({
    required this.controller,
    required this.sessionController,
    required this.sessionSearchController,
    required this.promptController,
    required this.sessionSearchQuery,
    required this.thinking,
    required this.onThinkingChanged,
    required this.onSessionChanged,
    required this.onSessionSearchChanged,
    required this.onSessionSelected,
    required this.onReloadHistory,
    required this.onSendPrompt,
    required this.onAbortRun,
  });

  final CompanionController controller;
  final TextEditingController sessionController;
  final TextEditingController sessionSearchController;
  final TextEditingController promptController;
  final String sessionSearchQuery;
  final String thinking;
  final ValueChanged<String> onThinkingChanged;
  final ValueChanged<String> onSessionChanged;
  final ValueChanged<String> onSessionSearchChanged;
  final ValueChanged<String> onSessionSelected;
  final VoidCallback onReloadHistory;
  final Future<void> Function() onSendPrompt;
  final VoidCallback onAbortRun;

  @override
  State<_SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<_SessionsPage> {
  final ScrollController _sessionListScrollController = ScrollController();
  final ScrollController _transcriptScrollController = ScrollController();
  bool _pinTranscriptToBottom = true;

  @override
  void initState() {
    super.initState();
    _transcriptScrollController.addListener(_handleTranscriptScroll);
  }

  @override
  void didUpdateWidget(covariant _SessionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged =
        oldWidget.controller.config.preferredSessionKey !=
        widget.controller.config.preferredSessionKey;
    final transcriptChanged =
        oldWidget.controller.transcript.length !=
            widget.controller.transcript.length ||
        oldWidget.controller.streamingAssistantText !=
            widget.controller.streamingAssistantText;
    if (sessionChanged) {
      _pinTranscriptToBottom = true;
      _scheduleTranscriptScroll(jump: true);
      return;
    }
    if (transcriptChanged) {
      _scheduleTranscriptScroll();
    }
  }

  @override
  void dispose() {
    _transcriptScrollController
      ..removeListener(_handleTranscriptScroll)
      ..dispose();
    _sessionListScrollController.dispose();
    super.dispose();
  }

  void _handleTranscriptScroll() {
    if (!_transcriptScrollController.hasClients) {
      return;
    }
    final position = _transcriptScrollController.position;
    _pinTranscriptToBottom = position.maxScrollExtent - position.pixels < 56;
  }

  void _scheduleTranscriptScroll({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pinTranscriptToBottom) {
        return;
      }
      if (!_transcriptScrollController.hasClients) {
        return;
      }
      final target = _transcriptScrollController.position.maxScrollExtent;
      if (jump) {
        _transcriptScrollController.jumpTo(target);
        return;
      }
      _transcriptScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openCompactSessionPicker(
    List<GatewaySessionRow> sessions,
  ) async {
    final searchController = TextEditingController(
      text: widget.sessionSearchController.text,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? sessions
                : sessions
                      .where((session) => _sessionMatchesSearch(session, query))
                      .toList(growable: false);
            return FractionallySizedBox(
              heightFactor: 0.88,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F4ED),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1C6B8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Switch session',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        onChanged: (value) => setModalState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search sessions',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: filtered.isEmpty
                            ? const _EmptyState(
                                'No sessions match that search.',
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final session = filtered[index];
                                  return _SessionListTile(
                                    session: session,
                                    selected:
                                        session.key ==
                                        widget
                                            .controller
                                            .config
                                            .preferredSessionKey,
                                    onTap: () {
                                      widget.sessionController.text =
                                          session.key;
                                      widget.onSessionSelected(session.key);
                                      Navigator.of(context).pop();
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 1180;
        final allSessions =
            List<GatewaySessionRow>.of(
              widget.controller.sessionsList?.sessions ??
                  const <GatewaySessionRow>[],
            )..sort(
              (left, right) =>
                  (right.updatedAt ?? 0).compareTo(left.updatedAt ?? 0),
            );
        final selectedSession = allSessions
            .cast<GatewaySessionRow?>()
            .firstWhere(
              (session) =>
                  session?.key == widget.controller.config.preferredSessionKey,
              orElse: () => null,
            );
        final query = widget.sessionSearchQuery.trim().toLowerCase();
        final filteredSessions = query.isEmpty
            ? allSessions
            : allSessions
                  .where((session) => _sessionMatchesSearch(session, query))
                  .toList(growable: false);
        final transcriptGroups = _buildTranscriptGroups(
          widget.controller.transcript,
        );
        final hasStreamingAssistant =
            widget.controller.streamingAssistantText?.trim().isNotEmpty == true;
        final selectedSessionLabel = selectedSession == null
            ? widget.controller.config.preferredSessionKey
            : _sessionTitle(selectedSession);
        final sessionPane = _buildSessionPane(
          context: context,
          allSessions: allSessions,
          filteredSessions: filteredSessions,
          query: query,
        );
        final chatWorkspace = _buildChatWorkspace(
          context: context,
          split: split,
          selectedSessionLabel: selectedSessionLabel,
          selectedSession: selectedSession,
          transcriptGroups: transcriptGroups,
          hasStreamingAssistant: hasStreamingAssistant,
        );

        if (!split) {
          return chatWorkspace;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 288, child: sessionPane),
            const SizedBox(width: 18),
            Expanded(child: chatWorkspace),
          ],
        );
      },
    );
  }

  Widget _buildSessionPane({
    required BuildContext context,
    required List<GatewaySessionRow> allSessions,
    required List<GatewaySessionRow> filteredSessions,
    required String query,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4ED),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCCFBE)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Threads',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                Text(
                  query.isEmpty
                      ? '${allSessions.length}'
                      : '${filteredSessions.length}/${allSessions.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF5E706B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.sessionSearchController,
              onChanged: widget.onSessionSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search sessions',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: widget.sessionController,
                    decoration: const InputDecoration(
                      labelText: 'Open key',
                      hintText: 'main',
                    ),
                    onSubmitted: widget.onSessionChanged,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonal(
                  onPressed: () {
                    final value = widget.sessionController.text.trim();
                    if (value.isNotEmpty) {
                      widget.onSessionSelected(value);
                    }
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (query.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    widget.sessionSearchController.clear();
                    widget.onSessionSearchChanged('');
                  },
                  child: const Text('Clear filter'),
                ),
              ),
            Expanded(
              child: filteredSessions.isEmpty
                  ? const Align(
                      alignment: Alignment.topLeft,
                      child: _EmptyState(
                        'No sessions match that search yet. Clear the filter or open a session key directly.',
                      ),
                    )
                  : Scrollbar(
                      controller: _sessionListScrollController,
                      thumbVisibility: true,
                      child: ListView.separated(
                        controller: _sessionListScrollController,
                        padding: const EdgeInsets.only(bottom: 4),
                        itemCount: filteredSessions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final session = filteredSessions[index];
                          final selected =
                              session.key ==
                              widget.controller.config.preferredSessionKey;
                          return _SessionListTile(
                            session: session,
                            selected: selected,
                            onTap: () => widget.onSessionSelected(session.key),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatWorkspace({
    required BuildContext context,
    required bool split,
    required String selectedSessionLabel,
    required GatewaySessionRow? selectedSession,
    required List<_TranscriptGroup> transcriptGroups,
    required bool hasStreamingAssistant,
  }) {
    final transcriptEmpty =
        widget.controller.transcript.isEmpty && !hasStreamingAssistant;
    final compactChat = !split;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCCFBE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              compactChat ? 16 : 22,
              compactChat ? 14 : 20,
              compactChat ? 16 : 22,
              compactChat ? 12 : 16,
            ),
            child: _ConversationHeader(
              title: selectedSessionLabel,
              sessionKey: widget.controller.config.preferredSessionKey,
              thinking: widget.thinking,
              activeRunId: widget.controller.activeRunId,
              onReloadHistory: widget.controller.busy
                  ? null
                  : widget.onReloadHistory,
              onAbortRun: widget.controller.activeRunId == null
                  ? null
                  : widget.onAbortRun,
              onBrowseSessions: split
                  ? null
                  : () => unawaited(
                      _openCompactSessionPicker(
                        List<GatewaySessionRow>.of(
                          widget.controller.sessionsList?.sessions ??
                              const <GatewaySessionRow>[],
                        ),
                      ),
                    ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFFFFFCF8)),
              child: transcriptEmpty
                  ? _ConversationEmptyState(
                      sessionKey: widget.controller.config.preferredSessionKey,
                    )
                  : Scrollbar(
                      controller: _transcriptScrollController,
                      thumbVisibility: true,
                      child: ListView(
                        controller: _transcriptScrollController,
                        padding: EdgeInsets.fromLTRB(
                          compactChat ? 14 : 22,
                          compactChat ? 14 : 18,
                          compactChat ? 14 : 22,
                          compactChat ? 18 : 24,
                        ),
                        children: <Widget>[
                          ...transcriptGroups.map(
                            (group) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ChatGroupCard(group: group),
                            ),
                          ),
                          if (hasStreamingAssistant)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _StreamingChatBubble(
                                text: widget.controller.streamingAssistantText!,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFF3ECDD),
              border: Border(top: BorderSide(color: Color(0xFFDCCFBE))),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compactChat ? 14 : 18,
                14,
                compactChat ? 14 : 18,
                compactChat ? 14 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (split) ...<Widget>[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 720;
                        final thinkingField = SizedBox(
                          width: stacked ? double.infinity : 164,
                          child: DropdownButtonFormField<String>(
                            initialValue: widget.thinking,
                            decoration: const InputDecoration(
                              labelText: 'Thinking',
                              isDense: true,
                            ),
                            items:
                                const <String>[
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
                                widget.onThinkingChanged(value);
                              }
                            },
                          ),
                        );
                        final summary = Text(
                          selectedSession?.lastMessagePreview
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                              ? selectedSession!.lastMessagePreview!
                              : transcriptEmpty
                              ? 'Pick a thread and send the first prompt to start the transcript.'
                              : 'Continue the conversation from here.',
                          maxLines: stacked ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF5E706B)),
                        );
                        final meta = Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _HeaderPill(
                              icon: Icons.forum_outlined,
                              label:
                                  widget.controller.config.preferredSessionKey,
                              tint: const Color(0xFFE8E1D1),
                            ),
                            if (selectedSession != null &&
                                selectedSession.label?.trim().isNotEmpty ==
                                    true)
                              _HeaderPill(
                                icon: Icons.label_outline_rounded,
                                label: selectedSession.label!,
                                tint: const Color(0xFFE6EBE3),
                              ),
                          ],
                        );

                        if (stacked) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              meta,
                              const SizedBox(height: 10),
                              summary,
                              const SizedBox(height: 12),
                              thinkingField,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  meta,
                                  const SizedBox(height: 8),
                                  summary,
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            thinkingField,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: widget.promptController,
                    minLines: 3,
                    maxLines: compactChat ? 5 : 6,
                    decoration: const InputDecoration(
                      hintText: 'Write a prompt, note, or follow-up question',
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 520;
                      final sendButton = FilledButton.icon(
                        onPressed:
                            widget.controller.busy ||
                                widget.controller.activeRunId != null
                            ? null
                            : () {
                                unawaited(widget.onSendPrompt());
                              },
                        icon: Icon(
                          widget.controller.activeRunId == null
                              ? Icons.north_east_rounded
                              : Icons.timelapse_rounded,
                        ),
                        label: Text(
                          widget.controller.activeRunId == null
                              ? 'Send prompt'
                              : 'Running…',
                        ),
                      );
                      final abortButton = OutlinedButton.icon(
                        onPressed: widget.controller.activeRunId == null
                            ? null
                            : widget.onAbortRun,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Abort'),
                      );

                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            sendButton,
                            const SizedBox(height: 10),
                            abortButton,
                          ],
                        );
                      }

                      return Row(
                        children: <Widget>[
                          Expanded(child: sendButton),
                          const SizedBox(width: 12),
                          abortButton,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplorePage extends StatelessWidget {
  const _ExplorePage({required this.controller});

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    final channelsCard = _InfoCard(
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
    );

    final nodesCard = _InfoCard(
      title: 'Nodes',
      child: controller.nodes.isEmpty
          ? const _EmptyState('No paired nodes reported.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: controller.nodes
                  .map(
                    (node) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              node.displayName ?? node.nodeId,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          _HeaderPill(
                            icon: node.connected
                                ? Icons.link_rounded
                                : Icons.link_off_rounded,
                            label: node.connected ? 'Connected' : 'Offline',
                            tint: node.connected
                                ? const Color(0xFFE6EBE3)
                                : const Color(0xFFE9E7E4),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );

    final modelsCard = _InfoCard(
      title: 'Models',
      child: controller.models == null
          ? const _EmptyState('No model catalog loaded.')
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: controller.models!.models
                  .map(
                    (model) =>
                        Chip(label: Text('${model.provider} · ${model.name}')),
                  )
                  .toList(growable: false),
            ),
    );

    final toolsCard = _InfoCard(
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
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: group.tools
                                .map((tool) => Chip(label: Text(tool.label)))
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (!wide) {
          return ListView(
            children: <Widget>[
              channelsCard,
              const SizedBox(height: 16),
              nodesCard,
              const SizedBox(height: 16),
              modelsCard,
              const SizedBox(height: 16),
              toolsCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ListView(
                children: <Widget>[
                  channelsCard,
                  const SizedBox(height: 16),
                  modelsCard,
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ListView(
                children: <Widget>[
                  nodesCard,
                  const SizedBox(height: 16),
                  toolsCard,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EventsPage extends StatelessWidget {
  const _EventsPage({required this.controller});

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final eventFeed = _ConsoleCard(
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
                        Text('${line.timeLabel} · ${line.name}'),
                        const SizedBox(height: 4),
                        Text(line.summary),
                      ],
                    );
                  },
                ),
        );

        final activityFeed = _ConsoleCard(
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

class _CompactChatBanner extends StatelessWidget {
  const _CompactChatBanner({
    required this.connectionState,
    required this.onOpenConnections,
    this.gatewayLabel,
    this.errorText,
  });

  final GatewayConnectionState connectionState;
  final VoidCallback onOpenConnections;
  final String? gatewayLabel;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4EEE3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCCFBE)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    gatewayLabel?.trim().isNotEmpty == true
                        ? gatewayLabel!
                        : 'Gateway connection',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    errorText?.trim().isNotEmpty == true
                        ? errorText!
                        : _phaseLabel(connectionState.phase),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5E706B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: onOpenConnections,
              child: const Text('Connections'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.connectionState,
    required this.onOpenConnections,
    required this.onRefresh,
    this.gatewayLabel,
    this.errorText,
  });

  final String title;
  final String subtitle;
  final GatewayConnectionState connectionState;
  final VoidCallback onOpenConnections;
  final VoidCallback onRefresh;
  final String? gatewayLabel;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final actions = Wrap(
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            if (gatewayLabel != null && gatewayLabel!.isNotEmpty)
              _HeaderPill(
                icon: Icons.hub_outlined,
                label: gatewayLabel!,
                tint: const Color(0xFFE6EBE3),
              ),
            _StatusChip(state: connectionState),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
            FilledButton.tonalIcon(
              onPressed: onOpenConnections,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Connections'),
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (compact) ...<Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF4A665F)),
              ),
              const SizedBox(height: 14),
              actions,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: const Color(0xFF4A665F)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: actions,
                  ),
                ],
              ),
            if (errorText != null) ...<Widget>[
              const SizedBox(height: 12),
              _HintCard(text: errorText!, tint: const Color(0xFFFFE4E1)),
            ],
          ],
        );
      },
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: const Color(0xFF30453F)),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF30453F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final GatewayConnectionState state;

  @override
  Widget build(BuildContext context) {
    final color = _phaseColor(state.phase);
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
              _phaseLabel(state.phase),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarStatus extends StatelessWidget {
  const _SidebarStatus({required this.controller});

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    final phase = controller.connectionState.phase;
    final color = _phaseColor(phase);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 8),
                Text(
                  _phaseLabel(phase),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              controller.serverVersion ?? 'No server snapshot yet',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF96AAA3)),
            ),
          ],
        ),
      ),
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

Color _phaseColor(GatewayConnectionPhase phase) {
  return switch (phase) {
    GatewayConnectionPhase.connected => const Color(0xFF17594E),
    GatewayConnectionPhase.connecting => const Color(0xFF9A6700),
    GatewayConnectionPhase.reconnecting => const Color(0xFF9A6700),
    GatewayConnectionPhase.closed => const Color(0xFFB42318),
    GatewayConnectionPhase.disconnected => const Color(0xFF667A74),
  };
}

String _phaseLabel(GatewayConnectionPhase phase) {
  return switch (phase) {
    GatewayConnectionPhase.connected => 'Connected',
    GatewayConnectionPhase.connecting => 'Connecting',
    GatewayConnectionPhase.reconnecting => 'Reconnecting',
    GatewayConnectionPhase.closed => 'Closed',
    GatewayConnectionPhase.disconnected => 'Offline',
  };
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
                  color: const Color(0xFF6B6359),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4A665F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ConsoleCard extends StatelessWidget {
  const _ConsoleCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF162220),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            DefaultTextStyle(
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: const Color(0xFFD4E0DC),
                fontFamily: 'monospace',
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.text, this.tint = const Color(0xFFE7EEEA)});

  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: Text(text)),
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
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4A665F)),
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
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: const Color(0xFF4A665F)),
            ),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _SessionListTile extends StatelessWidget {
  const _SessionListTile({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final GatewaySessionRow session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE8E1D1) : const Color(0xFFF7F0E5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _sessionTitle(session),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatSessionUpdatedAt(session.updatedAt),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF6A786F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                session.lastMessagePreview?.trim().isNotEmpty == true
                    ? session.lastMessagePreview!
                    : session.kind,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5E706B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.title,
    required this.sessionKey,
    required this.thinking,
    required this.activeRunId,
    required this.onReloadHistory,
    required this.onAbortRun,
    this.onBrowseSessions,
  });

  final String title;
  final String sessionKey;
  final String thinking;
  final String? activeRunId;
  final VoidCallback? onReloadHistory;
  final VoidCallback? onAbortRun;
  final VoidCallback? onBrowseSessions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final stacked = constraints.maxWidth < 920;
        if (compact) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sessionKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF5E706B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (onBrowseSessions != null)
                IconButton(
                  tooltip: 'Sessions',
                  onPressed: onBrowseSessions,
                  icon: const Icon(Icons.menu_open_rounded),
                ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: onReloadHistory,
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (activeRunId != null)
                IconButton(
                  tooltip: 'Abort run',
                  onPressed: onAbortRun,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
            ],
          );
        }

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: <Widget>[
            if (onBrowseSessions != null)
              OutlinedButton.icon(
                onPressed: onBrowseSessions,
                icon: const Icon(Icons.menu_open_rounded),
                label: const Text('Sessions'),
              ),
            OutlinedButton.icon(
              onPressed: onReloadHistory,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
            OutlinedButton.icon(
              onPressed: onAbortRun,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Abort run'),
            ),
          ],
        );

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _HeaderPill(
                  icon: Icons.psychology_alt_outlined,
                  label: thinking,
                  tint: const Color(0xFFE6EBE3),
                ),
                _HeaderPill(
                  icon: Icons.tag_rounded,
                  label: sessionKey,
                  tint: const Color(0xFFE8E1D1),
                ),
                if (activeRunId != null)
                  _HeaderPill(
                    icon: Icons.timelapse_rounded,
                    label: 'Live run',
                    tint: const Color(0xFFECE8F8),
                  ),
              ],
            ),
          ],
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[content, const SizedBox(height: 14), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: content),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }
}

class _ConversationEmptyState extends StatelessWidget {
  const _ConversationEmptyState({required this.sessionKey});

  final String sessionKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFE8E1D1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF7A5C38),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing here yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a message in $sessionKey to create a live transcript here.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5E706B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatGroupCard extends StatelessWidget {
  const _ChatGroupCard({required this.group});

  final _TranscriptGroup group;

  @override
  Widget build(BuildContext context) {
    final outbound = group.normalizedRole == 'user';
    final bubbleColor = outbound
        ? const Color(0xFFE8E1D1)
        : const Color(0xFFF8F4ED);
    final borderColor = outbound
        ? const Color(0xFFD6C7A9)
        : const Color(0xFFE3DBCF);
    final labelColor = outbound
        ? const Color(0xFF755A3A)
        : const Color(0xFF556763);

    return Align(
      alignment: outbound ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: outbound
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${group.displayRole} · ${_formatMessageTimestamp(group.latestTimestamp)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: group.messages.indexed
                      .map(
                        (entry) => Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.$1 == group.messages.length - 1
                                ? 0
                                : 16,
                          ),
                          child: _ChatMessageSection(message: entry.$2),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageSection extends StatelessWidget {
  const _ChatMessageSection({required this.message});

  final GatewayChatMessage message;

  @override
  Widget build(BuildContext context) {
    final attachmentParts = message.content
        .where((part) => part.isAttachment)
        .toList(growable: false);
    final toolCallParts = message.content
        .where((part) => part.isToolCall)
        .toList(growable: false);
    final toolResultParts = message.content
        .where((part) => part.isToolResult)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (message.hasVisibleText)
          _MarkdownTextBlock(text: message.primaryText)
        else
          SelectableText(debugChatMessage(message.raw)),
        if (attachmentParts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attachmentParts
                .map(
                  (part) => Chip(
                    label: Text(
                      part.fileName ?? part.mimeType ?? part.normalizedType,
                    ),
                    avatar: const Icon(Icons.attachment_rounded, size: 16),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (toolCallParts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: toolCallParts
                .map(
                  (part) => Chip(
                    label: Text(part.name ?? part.id ?? 'tool call'),
                    avatar: const Icon(Icons.handyman_outlined, size: 16),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (toolResultParts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          ...toolResultParts.map(
            (part) => DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1F162220)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  part.text?.trim().isNotEmpty == true
                      ? part.text!
                      : debugChatMessage(part.raw),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5E706B),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (message.usage?.total != null ||
            message.stopReason != null) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              if (message.usage?.total != null)
                Text(
                  '${message.usage!.total} tokens',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF6A786F),
                  ),
                ),
              if (message.stopReason?.trim().isNotEmpty == true)
                Text(
                  'stop: ${message.stopReason}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF6A786F),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StreamingChatBubble extends StatelessWidget {
  const _StreamingChatBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF3EFE7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0D7C9)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Assistant is responding',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF556763),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _MarkdownTextBlock(text: text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkdownTextBlock extends StatelessWidget {
  const _MarkdownTextBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = MarkdownStyleSheet.fromTheme(theme);
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: baseStyle.copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF1B2220),
          height: 1.5,
        ),
        code: theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFF162220),
          fontFamily: 'monospace',
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF1EBDD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2D8C8)),
        ),
        blockSpacing: 14,
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFD8D1C5))),
        ),
      ),
    );
  }
}

class _SectionItem {
  const _SectionItem(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _TranscriptGroup {
  const _TranscriptGroup({
    required this.role,
    required this.messages,
    required this.latestTimestamp,
  });

  final String role;
  final List<GatewayChatMessage> messages;
  final double? latestTimestamp;

  String get normalizedRole => role.trim().toLowerCase();

  String get displayRole => switch (normalizedRole) {
    'user' => 'You',
    'assistant' => 'Assistant',
    'toolresult' || 'tool_result' => 'Tool result',
    final other when other.isEmpty => 'Message',
    final other => other[0].toUpperCase() + other.substring(1),
  };
}

bool _sessionMatchesSearch(GatewaySessionRow session, String query) {
  final haystack = <String>[
    session.key,
    session.displayName ?? '',
    session.derivedTitle ?? '',
    session.label ?? '',
    session.lastMessagePreview ?? '',
    session.kind,
  ].join(' ').toLowerCase();
  return haystack.contains(query);
}

List<_TranscriptGroup> _buildTranscriptGroups(
  List<GatewayChatMessage> messages,
) {
  if (messages.isEmpty) {
    return const <_TranscriptGroup>[];
  }

  final groups = <_TranscriptGroup>[];
  var currentRole = messages.first.normalizedRole;
  var currentMessages = <GatewayChatMessage>[messages.first];
  var latestTimestamp = messages.first.timestamp;

  for (final message in messages.skip(1)) {
    final nextRole = message.normalizedRole;
    if (nextRole == currentRole) {
      currentMessages.add(message);
      latestTimestamp = message.timestamp ?? latestTimestamp;
      continue;
    }
    groups.add(
      _TranscriptGroup(
        role: currentRole,
        messages: List<GatewayChatMessage>.unmodifiable(currentMessages),
        latestTimestamp: latestTimestamp,
      ),
    );
    currentRole = nextRole;
    currentMessages = <GatewayChatMessage>[message];
    latestTimestamp = message.timestamp;
  }

  groups.add(
    _TranscriptGroup(
      role: currentRole,
      messages: List<GatewayChatMessage>.unmodifiable(currentMessages),
      latestTimestamp: latestTimestamp,
    ),
  );
  return groups;
}

String _sessionTitle(GatewaySessionRow session) {
  return session.displayName ??
      session.derivedTitle ??
      session.label ??
      session.key;
}

String _formatSessionUpdatedAt(int? value) {
  if (value == null) {
    return 'unknown';
  }
  final delta = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(value),
  );
  if (delta.inMinutes < 1) {
    return 'now';
  }
  if (delta.inHours < 1) {
    return '${delta.inMinutes}m';
  }
  if (delta.inDays < 1) {
    return '${delta.inHours}h';
  }
  return '${delta.inDays}d';
}

String _formatMessageTimestamp(double? value) {
  if (value == null) {
    return 'recently';
  }
  final timestamp = DateTime.fromMillisecondsSinceEpoch(value.toInt());
  final hh = timestamp.hour.toString().padLeft(2, '0');
  final mm = timestamp.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
