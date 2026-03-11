part of '../home.dart';

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

class _SnapshotMetric extends StatelessWidget {
  const _SnapshotMetric({
    required this.label,
    required this.value,
    this.icon = Icons.insights_rounded,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
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
              Icon(icon, size: 18, color: const Color(0xFF5A4A3B)),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5E706B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.tint, this.icon});

  final String label;
  final Color tint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = Color.lerp(tint, const Color(0xFF20342F), 0.72)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
            Expanded(
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: const Color(0xFFD4E0DC),
                  fontFamily: 'monospace',
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsoleLoadingList extends StatelessWidget {
  const _ConsoleLoadingList({this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        count,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == count - 1 ? 0 : 14),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SkeletonBox(height: 12, width: 160),
              SizedBox(height: 8),
              _SkeletonBox(height: 12),
            ],
          ),
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

class _LoadingBanner extends StatelessWidget {
  const _LoadingBanner({required this.label, this.detail});

  final String label;
  final String? detail;

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
            const SizedBox(width: 18, height: 18, child: _LoadingSpinner()),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (detail?.trim().isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      detail!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF5E706B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSpinner extends StatefulWidget {
  const _LoadingSpinner();

  @override
  State<_LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<_LoadingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(painter: _SpinnerPainter()),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7A5C38);
    canvas.drawArc(rect.deflate(1), 0.1, 4.6, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({required this.height, this.width, this.radius = 12});

  final double height;
  final double? width;
  final double radius;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.42, end: 0.9).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFD7CCBC),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class _SkeletonMetricStrip extends StatelessWidget {
  const _SkeletonMetricStrip({this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: List<Widget>.generate(
        count,
        (_) => SizedBox(
          width: 240,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  _SkeletonBox(height: 12, width: 74),
                  SizedBox(height: 10),
                  _SkeletonBox(height: 28, width: 120),
                  SizedBox(height: 8),
                  _SkeletonBox(height: 14, width: 164),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonInfoRows extends StatelessWidget {
  const _SkeletonInfoRows({this.rowCount = 4});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ...List<Widget>.generate(
          rowCount,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == rowCount - 1 ? 0 : 10),
            child: Row(
              children: const <Widget>[
                Expanded(child: _SkeletonBox(height: 12)),
                SizedBox(width: 12),
                _SkeletonBox(height: 12, width: 88),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonCardList extends StatelessWidget {
  const _SkeletonCardList({this.count = 3, this.minHeight = 72});

  final int count;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        count,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == count - 1 ? 0 : 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3DBCF)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: _SkeletonBox(height: 14, width: 144)),
                        SizedBox(width: 12),
                        _SkeletonBox(height: 26, width: 72, radius: 999),
                      ],
                    ),
                    SizedBox(height: 10),
                    _SkeletonBox(height: 12),
                    SizedBox(height: 8),
                    _SkeletonBox(height: 12, width: 168),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonChipWrap extends StatelessWidget {
  const _SkeletonChipWrap({this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(
        count,
        (index) => _SkeletonBox(
          height: 30,
          width: 92 + ((index % 3) * 28),
          radius: 999,
        ),
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

class _SectionItem {
  const _SectionItem(
    this.label,
    this.icon,
    this.selectedIcon, {
    required this.subtitle,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String subtitle;
}
