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
