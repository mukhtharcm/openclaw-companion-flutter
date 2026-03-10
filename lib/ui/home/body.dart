part of '../home.dart';

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
    final loadingLabel = switch (controller.connectionState.phase) {
      GatewayConnectionPhase.connecting => 'Connecting to the gateway',
      GatewayConnectionPhase.reconnecting => 'Reconnecting to the gateway',
      _ when controller.busy => 'Refreshing gateway data',
      _ => null,
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
        if (!controller.needsInitialConnectionSetup &&
            loadingLabel != null) ...<Widget>[
          _LoadingBanner(
            label: loadingLabel,
            detail: controller.connectedGatewayTitle,
          ),
          const SizedBox(height: 12),
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

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.controller});

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    final sessionItems =
        controller.sessionsList?.sessions ?? const <GatewaySessionRow>[];
    final featuredSessions = sessionItems.take(5).toList(growable: false);
    final health = controller.health;
    final loadingOverview = controller.busy && health == null;
    final loadingRuntime = controller.busy && controller.status == null;
    final loadingSessions = controller.busy && controller.sessionsList == null;
    final loadingActivity = controller.busy && controller.activityLog.isEmpty;

    final healthCard = _InfoCard(
      title: 'Health snapshot',
      child: loadingOverview
          ? const Column(
              children: <Widget>[
                _SkeletonMetricStrip(count: 4),
                SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _SkeletonBox(height: 12, width: 96),
                ),
                SizedBox(height: 10),
                _SkeletonChipWrap(count: 6),
              ],
            )
          : health == null
          ? const _EmptyState('Connect and refresh to load gateway health.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _SnapshotMetric(
                      label: 'Healthy',
                      value: health.ok ? 'Yes' : 'No',
                      icon: health.ok
                          ? Icons.health_and_safety_rounded
                          : Icons.warning_amber_rounded,
                    ),
                    _SnapshotMetric(
                      label: 'Channels',
                      value: '${health.channelOrder.length}',
                      icon: Icons.hub_rounded,
                    ),
                    _SnapshotMetric(
                      label: 'Heartbeat',
                      value: health.heartbeatSeconds == null
                          ? '—'
                          : '${health.heartbeatSeconds}s',
                      icon: Icons.favorite_rounded,
                    ),
                    _SnapshotMetric(
                      label: 'Default agent',
                      value: health.defaultAgentId ?? '—',
                      icon: Icons.smart_toy_rounded,
                    ),
                  ],
                ),
                if (health.channelOrder.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  Text(
                    'Channel pulse',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF5E706B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: health.channelOrder
                        .take(8)
                        .map((id) {
                          final state = health.channels[id];
                          final label = health.channelLabels[id] ?? id;
                          return _StatePill(
                            label: '$label • ${_channelStateLabel(state)}',
                            tint: _channelStateTint(state),
                            icon: _channelStateIcon(state),
                          );
                        })
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
    );

    final runtimeCard = _InfoCard(
      title: 'Runtime',
      child: loadingRuntime
          ? const _SkeletonInfoRows(rowCount: 6)
          : Column(
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
                _InfoLine(
                  'Tools',
                  '${controller.tools?.groups.length ?? 0} groups',
                ),
                _InfoLine('Nodes', '${controller.nodes.length}'),
              ],
            ),
    );

    final sessionsCard = _InfoCard(
      title: 'Session snapshot',
      child: loadingSessions
          ? const _SkeletonCardList(count: 4)
          : featuredSessions.isEmpty
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
      child: loadingActivity
          ? const _SkeletonInfoRows(rowCount: 5)
          : controller.activityLog.isEmpty
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
        final metricStrip = controller.busy && controller.serverVersion == null
            ? const _SkeletonMetricStrip(count: 4)
            : Wrap(
                spacing: 16,
                runSpacing: 16,
                children: <Widget>[
                  _MetricCard(
                    title: 'Gateway',
                    value: controller.serverVersion ?? 'Disconnected',
                    subtitle:
                        controller.connectedGatewayTitle ??
                        'No active endpoint',
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

class _ExplorePage extends StatelessWidget {
  const _ExplorePage({required this.controller});

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    final loadingChannels =
        controller.busy && controller.channelsStatus == null;
    final loadingNodes = controller.busy && controller.nodes.isEmpty;
    final loadingModels = controller.busy && controller.models == null;
    final loadingTools = controller.busy && controller.tools == null;
    final channelsCard = _InfoCard(
      title: 'Channels',
      child: loadingChannels
          ? const _SkeletonCardList(count: 4)
          : controller.channelsStatus == null
          ? const _EmptyState('No channel snapshot yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: controller.channelsStatus!.channelOrder
                  .map((channelId) {
                    final state =
                        controller.channelsStatus!.channels[channelId];
                    final accounts =
                        controller.channelsStatus!.channelAccounts[channelId] ??
                        const <GatewayChannelAccountSnapshot>[];
                    final detail = controller
                        .channelsStatus!
                        .channelDetailLabels[channelId];
                    final defaultAccount = controller
                        .channelsStatus!
                        .channelDefaultAccountId[channelId];
                    final accountLabel =
                        '${accounts.length} account${accounts.length == 1 ? '' : 's'}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFCF8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE3DBCF)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final header = Text(
                                    controller
                                            .channelsStatus!
                                            .channelLabels[channelId] ??
                                        channelId,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  );
                                  final statusPill = _StatePill(
                                    label: _channelStateLabel(state),
                                    tint: _channelStateTint(state),
                                    icon: _channelStateIcon(state),
                                  );
                                  if (constraints.maxWidth < 360) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        header,
                                        const SizedBox(height: 10),
                                        statusPill,
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Expanded(child: header),
                                      const SizedBox(width: 12),
                                      statusPill,
                                    ],
                                  );
                                },
                              ),
                              if (detail?.trim().isNotEmpty == true) ...[
                                const SizedBox(height: 6),
                                Text(
                                  detail!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF5E706B),
                                      ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  _StatePill(
                                    label: accountLabel,
                                    tint: const Color(0xFFE8E1D1),
                                    icon: Icons.alternate_email_rounded,
                                  ),
                                  if (defaultAccount?.trim().isNotEmpty == true)
                                    _StatePill(
                                      label: 'Default $defaultAccount',
                                      tint: const Color(0xFFE6EBE3),
                                      icon: Icons.star_rounded,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
    );

    final nodesCard = _InfoCard(
      title: 'Nodes',
      child: loadingNodes
          ? const _SkeletonCardList(count: 3)
          : controller.nodes.isEmpty
          ? const _EmptyState('No paired nodes reported.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: controller.nodes
                  .map(
                    (node) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFCF8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE3DBCF)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      node.displayName ?? node.nodeId,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  _StatePill(
                                    label: node.connected
                                        ? 'Connected'
                                        : 'Offline',
                                    tint: node.connected
                                        ? const Color(0xFFE6EBE3)
                                        : const Color(0xFFE9E7E4),
                                    icon: node.connected
                                        ? Icons.link_rounded
                                        : Icons.link_off_rounded,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                [node.platform, node.deviceFamily, node.version]
                                    .whereType<String>()
                                    .where((value) => value.isNotEmpty)
                                    .join(' • '),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xFF5E706B)),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  _StatePill(
                                    label:
                                        '${node.caps.length} ${node.caps.length == 1 ? 'capability' : 'capabilities'}',
                                    tint: const Color(0xFFE8E1D1),
                                    icon: Icons.widgets_rounded,
                                  ),
                                  _StatePill(
                                    label:
                                        '${node.commands.length} command${node.commands.length == 1 ? '' : 's'}',
                                    tint: const Color(0xFFE6EBE3),
                                    icon: Icons.terminal_rounded,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );

    final providerCounts = <String, int>{};
    for (final model
        in controller.models?.models ?? const <GatewayModelChoice>[]) {
      providerCounts.update(
        model.provider,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final modelsCard = _InfoCard(
      title: 'Models',
      child: loadingModels
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SkeletonMetricStrip(count: 2),
                SizedBox(height: 16),
                _SkeletonChipWrap(count: 7),
              ],
            )
          : controller.models == null
          ? const _EmptyState('No model catalog loaded.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _SnapshotMetric(
                      label: 'Available models',
                      value: '${controller.models!.models.length}',
                      icon: Icons.model_training_rounded,
                    ),
                    _SnapshotMetric(
                      label: 'Providers',
                      value: '${providerCounts.length}',
                      icon: Icons.account_tree_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: providerCounts.entries
                      .map(
                        (entry) => _StatePill(
                          label: '${entry.key} • ${entry.value}',
                          tint: const Color(0xFFE8E1D1),
                          icon: Icons.memory_rounded,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
    );

    final toolsCard = _InfoCard(
      title: 'Tools',
      child: loadingTools
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SkeletonMetricStrip(count: 3),
                SizedBox(height: 16),
                _SkeletonCardList(count: 3, minHeight: 56),
              ],
            )
          : controller.tools == null
          ? const _EmptyState('No tool catalog loaded.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _SnapshotMetric(
                      label: 'Tool groups',
                      value: '${controller.tools!.groups.length}',
                      icon: Icons.grid_view_rounded,
                    ),
                    _SnapshotMetric(
                      label: 'Profiles',
                      value: '${controller.tools!.profiles.length}',
                      icon: Icons.tune_rounded,
                    ),
                    _SnapshotMetric(
                      label: 'Agent',
                      value: controller.tools!.agentId,
                      icon: Icons.smart_toy_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...controller.tools!.groups.map(
                  (group) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE3DBCF)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    group.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    group.source,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF5E706B),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _StatePill(
                              label:
                                  '${group.tools.length} tool${group.tools.length == 1 ? '' : 's'}',
                              tint: const Color(0xFFE6EBE3),
                              icon: Icons.build_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
        final loadingEvents = controller.busy && controller.eventLines.isEmpty;
        final loadingActivity =
            controller.busy && controller.activityLog.isEmpty;
        final eventFeed = _ConsoleCard(
          title: 'Gateway events',
          child: loadingEvents
              ? const _ConsoleLoadingList(count: 5)
              : controller.eventLines.isEmpty
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
          child: loadingActivity
              ? const _ConsoleLoadingList(count: 6)
              : controller.activityLog.isEmpty
              ? const _EmptyState('No activity yet.')
              : ListView.builder(
                  itemCount: controller.activityLog.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SelectableText(
                        controller.activityLog[index],
                        style: DefaultTextStyle.of(context).style.copyWith(
                          fontFamily: 'monospace',
                          color: const Color(0xFFD4E0DC),
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

String _channelStateLabel(Object? value) {
  if (value == null) {
    return 'Unknown';
  }
  if (value is bool) {
    return value ? 'Ready' : 'Offline';
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return 'Unknown';
  }
  final normalized = text.toLowerCase();
  return switch (normalized) {
    'ok' => 'Ready',
    'online' => 'Ready',
    'healthy' => 'Ready',
    'ready' => 'Ready',
    'connected' => 'Connected',
    'disconnected' => 'Offline',
    'offline' => 'Offline',
    _ => text,
  };
}

Color _channelStateTint(Object? value) {
  final normalized = _channelStateLabel(value).toLowerCase();
  if (normalized == 'ready' || normalized == 'connected') {
    return const Color(0xFFE6EBE3);
  }
  if (normalized == 'offline') {
    return const Color(0xFFE9E7E4);
  }
  return const Color(0xFFE8E1D1);
}

IconData _channelStateIcon(Object? value) {
  final normalized = _channelStateLabel(value).toLowerCase();
  if (normalized == 'ready' || normalized == 'connected') {
    return Icons.check_circle_rounded;
  }
  if (normalized == 'offline') {
    return Icons.pause_circle_rounded;
  }
  return Icons.radio_button_checked_rounded;
}
