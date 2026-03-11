part of '../home.dart';

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
  CompanionWorkspaceMode _draftWorkspaceMode = CompanionWorkspaceMode.operator;
  CompanionAuthMode _draftAuthMode = CompanionAuthMode.token;
  bool _draftAutoConnect = true;
  String _draftThinking = 'default';
  String _sessionSearchQuery = '';
  String? _shownPromptStableId;

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
    _draftWorkspaceMode = config.workspaceMode;
    _draftAuthMode = config.authMode == CompanionAuthMode.none
        ? CompanionAuthMode.token
        : config.authMode;
    _draftAutoConnect = config.autoConnect;
    _draftThinking = config.thinking;
    final sectionCount =
        _CompanionHomeSections.sectionsFor(config.workspaceMode).length;
    if (_selectedSection >= sectionCount) {
      _selectedSection = 0;
    }
  }

  Future<void> _connectManual() async {
    final hadPrompt = widget.controller.pendingTrustPrompt != null;
    await widget.controller.connectManual(
      _urlController.text,
      workspaceMode: _draftWorkspaceMode,
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
      workspaceMode: _draftWorkspaceMode,
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
      workspaceMode: _draftWorkspaceMode,
      authMode: _draftAuthMode,
      embedded: embedded,
      autoConnect: _draftAutoConnect,
      onWorkspaceModeChanged: (value) {
        setState(() {
          _draftWorkspaceMode = value;
        });
      },
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
            workspaceMode: _draftWorkspaceMode,
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
                const Text(
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
        final sections = _CompanionHomeSections.sectionsFor(
          controller.workspaceMode,
        );
        final selectedSection = _selectedSection >= sections.length
            ? 0
            : _selectedSection;

        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 860;

            final body = _CompanionBody(
              controller: controller,
              selectedSection: selectedSection,
              sections: sections,
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
                          selectedSection: selectedSection,
                          sections: sections,
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

            final compactChatPage =
                controller.workspaceMode == CompanionWorkspaceMode.operator &&
                selectedSection == 1;
            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compactChatPage ? 12 : 16,
                    compactChatPage ? 10 : 16,
                    compactChatPage ? 12 : 16,
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
                    selectedIndex: selectedSection,
                    items: sections,
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
    required this.sections,
    required this.onOpenConnections,
    required this.onSectionSelected,
  });

  final CompanionController controller;
  final int selectedSection;
  final List<_SectionItem> sections;
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
                controller.connectedGatewayTitle ??
                    (controller.workspaceMode == CompanionWorkspaceMode.node
                        ? 'Node workspace'
                        : 'Operator workspace'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF96AAA3),
                ),
              ),
              const SizedBox(height: 20),
              ...sections.indexed.map((entry) {
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
  static const List<_SectionItem> operatorSections = <_SectionItem>[
    _SectionItem(
      'Home',
      Icons.grid_view_outlined,
      Icons.grid_view_rounded,
      subtitle: 'Gateway status, session volume, and recent activity.',
    ),
    _SectionItem(
      'Chat',
      Icons.forum_outlined,
      Icons.forum_rounded,
      subtitle: 'Stay in one session, review history, and send prompts quickly.',
    ),
    _SectionItem(
      'Inspect',
      Icons.travel_explore_outlined,
      Icons.travel_explore_rounded,
      subtitle: 'Inspect channels, models, tools, and paired nodes.',
    ),
    _SectionItem(
      'Logs',
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      subtitle: 'Watch live gateway events and the local activity log.',
    ),
  ];

  static const List<_SectionItem> nodeSections = <_SectionItem>[
    _SectionItem(
      'Node',
      Icons.developer_board_outlined,
      Icons.developer_board_rounded,
      subtitle: 'Expose declared commands and review recent node invokes.',
    ),
    _SectionItem(
      'Logs',
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      subtitle: 'Watch live gateway events and the local activity log.',
    ),
  ];

  static List<_SectionItem> sectionsFor(CompanionWorkspaceMode mode) {
    return switch (mode) {
      CompanionWorkspaceMode.operator => operatorSections,
      CompanionWorkspaceMode.node => nodeSections,
    };
  }
}
