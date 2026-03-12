part of '../home.dart';

class _NodePage extends StatelessWidget {
  const _NodePage({required this.controller});

  final CompanionController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.nodeSnapshot;
    final loadingSnapshot = controller.busy && snapshot == null;
    final invokes = controller.nodeInvokes;

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
                _InfoLine(
                  'Stable target',
                  controller.activeStableId ?? '—',
                ),
              ],
            ),
    );

    final capabilitiesCard = _InfoCard(
      title: 'Declared capabilities',
      child: loadingSnapshot
          ? const _SkeletonChipWrap(count: 5)
          : snapshot == null || snapshot.capabilities.isEmpty
          ? const _EmptyState('No capabilities declared for this platform yet.')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.capabilities
                  .map(
                    (capability) => _StatePill(
                      label: capability,
                      tint: const Color(0xFFE8E1D1),
                      icon: Icons.widgets_rounded,
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
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.commands
                  .map(
                    (command) => _StatePill(
                      label: command,
                      tint: const Color(0xFFE6EBE3),
                      icon: Icons.terminal_rounded,
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
                      label: '${entry.key} · ${entry.value ? 'granted' : 'blocked'}',
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

String _nodeInvokeStatusLabel(CompanionNodeInvokeStatus status) {
  return switch (status) {
    CompanionNodeInvokeStatus.pending => 'Pending',
    CompanionNodeInvokeStatus.success => 'Handled',
    CompanionNodeInvokeStatus.error => 'Error',
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
