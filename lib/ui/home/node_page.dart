part of '../home.dart';

class _NodePage extends StatelessWidget {
  const _NodePage({required this.controller});

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.nodeSnapshot;
    final loadingSnapshot = controller.busy && snapshot == null;
    final invokes = controller.nodeInvokes;
    final commandCatalog = {
      for (final command in buildCompanionNodeCommandCatalog())
        command.name: command,
    };

    final metricStrip = loadingSnapshot
        ? const _SkeletonMetricStrip(count: 4)
        : Wrap(
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
                value: controller.client?.hello.auth?.role ?? 'node',
                subtitle: controller.nodePairingRequestId == null
                    ? 'Node session ready'
                    : 'Pairing pending',
              ),
              _MetricCard(
                title: 'Commands',
                value: '${snapshot?.commands.length ?? 0}',
                subtitle: snapshot == null
                    ? 'No node snapshot yet'
                    : 'Declared by this companion',
              ),
              _MetricCard(
                title: 'Invokes',
                value: '${invokes.length}',
                subtitle: invokes.isEmpty
                    ? 'No requests handled yet'
                    : 'Recent node requests',
              ),
            ],
          );

    final sessionCard = _InfoCard(
      title: 'Node session',
      child: loadingSnapshot
          ? const _SkeletonInfoRows(rowCount: 5)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _InfoLine(
                  'Connection',
                  controller.connected ? 'Node session active' : 'Offline',
                ),
                _InfoLine(
                  'Client',
                  controller.client?.options.clientInfo.displayName ??
                      'OpenClaw Companion Node',
                ),
                _InfoLine(
                  'Platform',
                  controller.client?.options.clientInfo.platform ?? 'Unknown',
                ),
                _InfoLine(
                  'Auth role',
                  controller.client?.hello.auth?.role ?? 'node',
                ),
                _InfoLine('Stable target', controller.activeStableId ?? '—'),
              ],
            ),
    );

    final capabilitiesCard = _InfoCard(
      title: 'Declared capabilities',
      child: loadingSnapshot
          ? const _SkeletonChipWrap(count: 5)
          : snapshot == null || snapshot.capabilities.isEmpty
          ? const _EmptyState('No capabilities declared for this platform yet.')
          : Column(
              children: snapshot.capabilities
                  .map(
                    (capability) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NodeDescriptorCard(
                        icon: Icons.widgets_rounded,
                        title: capability,
                        summary: _nodeCapabilitySummary(capability),
                        tint: const Color(0xFFE8E1D1),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );

    final commandsCard = _InfoCard(
      title: 'Declared commands',
      child: loadingSnapshot
          ? const _SkeletonCardList(count: 2, minHeight: 56)
          : snapshot == null || snapshot.commands.isEmpty
          ? const _EmptyState(
              'This build only exposes node commands on supported desktop platforms.',
            )
          : Column(
              children: snapshot.commands
                  .map(
                    (command) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NodeDescriptorCard(
                        icon: Icons.terminal_rounded,
                        title: command,
                        summary:
                            commandCatalog[command]?.summary ??
                            'Declared by this companion node.',
                        tint: const Color(0xFFE6EBE3),
                        trailing:
                            (commandCatalog[command]?.capabilities.isNotEmpty ??
                                false)
                            ? Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: commandCatalog[command]!.capabilities
                                    .map(
                                      (capability) => _StatePill(
                                        label: capability,
                                        tint: const Color(0xFFF2EBDD),
                                        icon: Icons.widgets_rounded,
                                      ),
                                    )
                                    .toList(growable: false),
                              )
                            : null,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );

    final permissionsCard = _InfoCard(
      title: 'Permissions',
      child: loadingSnapshot
          ? const _SkeletonChipWrap(count: 4)
          : snapshot == null || snapshot.permissions.isEmpty
          ? const _EmptyState('No explicit permission hints declared.')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.permissions.entries
                  .map(
                    (entry) => _StatePill(
                      label:
                          '${entry.key} · ${entry.value ? 'granted' : 'blocked'}',
                      tint: entry.value
                          ? const Color(0xFFE6EBE3)
                          : const Color(0xFFE9E7E4),
                      icon: entry.value
                          ? Icons.check_circle_rounded
                          : Icons.block_rounded,
                    ),
                  )
                  .toList(growable: false),
            ),
    );

    final invokesCard = _InfoCard(
      title: 'Recent invokes',
      child: invokes.isEmpty
          ? const _EmptyState('No node invokes handled yet.')
          : Column(
              children: invokes
                  .take(8)
                  .map(
                    (invoke) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFCF8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE3DBCF)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      invoke.command,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${invoke.timeLabel} · ${invoke.summary}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF5E706B),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _StatePill(
                                label: _nodeInvokeStatusLabel(invoke.status),
                                tint: _nodeInvokeStatusTint(invoke.status),
                                icon: _nodeInvokeStatusIcon(invoke.status),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (!wide) {
          return ListView(
            children: <Widget>[
              metricStrip,
              const SizedBox(height: 16),
              sessionCard,
              const SizedBox(height: 16),
              capabilitiesCard,
              const SizedBox(height: 16),
              commandsCard,
              const SizedBox(height: 16),
              permissionsCard,
              const SizedBox(height: 16),
              invokesCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ListView(
                children: <Widget>[
                  metricStrip,
                  const SizedBox(height: 16),
                  sessionCard,
                  const SizedBox(height: 16),
                  capabilitiesCard,
                  const SizedBox(height: 16),
                  permissionsCard,
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ListView(
                children: <Widget>[
                  commandsCard,
                  const SizedBox(height: 16),
                  invokesCard,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NodeDescriptorCard extends StatelessWidget {
  const _NodeDescriptorCard({
    required this.icon,
    required this.title,
    required this.summary,
    required this.tint,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String summary;
  final Color tint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(icon, size: 18, color: const Color(0xFF30453F)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF5E706B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(height: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

String _nodeInvokeStatusLabel(CompanionNodeInvokeStatus status) {
  return switch (status) {
    CompanionNodeInvokeStatus.pending => 'Pending',
    CompanionNodeInvokeStatus.success => 'Handled',
    CompanionNodeInvokeStatus.error => 'Error',
  };
}

String _nodeCapabilitySummary(String capability) {
  return switch (capability) {
    'system' =>
      'Desktop-safe system helpers such as notifications and PATH lookup.',
    'device' =>
      'Basic host identity and runtime details. Linux and Windows may require a gateway allowlist override.',
    _ => 'Declared by this companion node.',
  };
}

Color _nodeInvokeStatusTint(CompanionNodeInvokeStatus status) {
  return switch (status) {
    CompanionNodeInvokeStatus.pending => const Color(0xFFE8E1D1),
    CompanionNodeInvokeStatus.success => const Color(0xFFE6EBE3),
    CompanionNodeInvokeStatus.error => const Color(0xFFE9E7E4),
  };
}

IconData _nodeInvokeStatusIcon(CompanionNodeInvokeStatus status) {
  return switch (status) {
    CompanionNodeInvokeStatus.pending => Icons.schedule_rounded,
    CompanionNodeInvokeStatus.success => Icons.check_circle_rounded,
    CompanionNodeInvokeStatus.error => Icons.error_outline_rounded,
  };
}
