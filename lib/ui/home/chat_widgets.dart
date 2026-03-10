part of '../home.dart';

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
    required this.onThinkingChanged,
    required this.activeRunId,
    required this.onReloadHistory,
    required this.onAbortRun,
    this.onBrowseSessions,
  });

  final String title;
  final String sessionKey;
  final String thinking;
  final ValueChanged<String> onThinkingChanged;
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
        final thinkingButton = _ThinkingMenuButton(
          value: thinking,
          onSelected: onThinkingChanged,
        );
        if (compact) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (onBrowseSessions != null)
                _ConversationActionButton(
                  tooltip: 'Sessions',
                  onPressed: onBrowseSessions,
                  icon: const Icon(Icons.toc_rounded),
                ),
              thinkingButton,
              _ConversationActionButton(
                tooltip: 'Refresh',
                onPressed: onReloadHistory,
                icon: const Icon(Icons.sync_rounded),
              ),
              if (activeRunId != null)
                _ConversationActionButton(
                  tooltip: 'Abort run',
                  onPressed: onAbortRun,
                  icon: const Icon(Icons.stop_rounded),
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
              _ConversationActionButton(
                tooltip: 'Sessions',
                onPressed: onBrowseSessions,
                icon: const Icon(Icons.toc_rounded),
              ),
            thinkingButton,
            _ConversationActionButton(
              tooltip: 'Refresh',
              onPressed: onReloadHistory,
              icon: const Icon(Icons.sync_rounded),
            ),
            if (activeRunId != null)
              _ConversationActionButton(
                tooltip: 'Abort run',
                onPressed: onAbortRun,
                icon: const Icon(Icons.stop_rounded),
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
            const SizedBox(height: 6),
            Text(
              activeRunId == null ? sessionKey : '$sessionKey  •  Live run',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5E706B),
                fontWeight: FontWeight.w700,
              ),
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

class _ConversationActionButton extends StatelessWidget {
  const _ConversationActionButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _ConversationActionSurface(
        child: IconButton(
          onPressed: onPressed,
          icon: icon,
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          iconSize: 18,
          splashRadius: 20,
        ),
      ),
    );
  }
}

class _ConversationActionSurface extends StatelessWidget {
  const _ConversationActionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCCFBE)),
      ),
      child: child,
    );
  }
}

class _ThinkingMenuButton extends StatelessWidget {
  const _ThinkingMenuButton({required this.value, required this.onSelected});

  final String value;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Thinking: $value',
      child: PopupMenuButton<String>(
        tooltip: '',
        padding: EdgeInsets.zero,
        onSelected: onSelected,
        itemBuilder: (context) =>
            const <String>['default', 'low', 'medium', 'high']
                .map(
                  (option) =>
                      PopupMenuItem<String>(value: option, child: Text(option)),
                )
                .toList(growable: false),
        child: const _ConversationActionSurface(
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(child: Icon(Icons.auto_awesome_rounded, size: 18)),
          ),
        ),
      ),
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

class _ConversationLoadingState extends StatelessWidget {
  const _ConversationLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      children: const <Widget>[
        _TranscriptLoadingCard(outbound: false, lines: 3),
        SizedBox(height: 12),
        _TranscriptLoadingCard(outbound: true, lines: 2),
        SizedBox(height: 12),
        _TranscriptLoadingCard(outbound: false, lines: 4),
      ],
    );
  }
}

class _TranscriptLoadingCard extends StatelessWidget {
  const _TranscriptLoadingCard({required this.outbound, required this.lines});

  final bool outbound;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: outbound ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: outbound ? 0.68 : 0.76,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: outbound ? const Color(0xFFE8E1D1) : const Color(0xFFF3EEE5),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDCCFBE)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List<Widget>.generate(lines, (index) {
                final widthFactor = switch (index % 3) {
                  0 => 1.0,
                  1 => 0.82,
                  _ => 0.58,
                };
                return Padding(
                  padding: EdgeInsets.only(bottom: index == lines - 1 ? 0 : 10),
                  child: FractionallySizedBox(
                    widthFactor: widthFactor,
                    child: const _PulseLine(),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseLine extends StatefulWidget {
  const _PulseLine();

  @override
  State<_PulseLine> createState() => _PulseLineState();
}

class _PulseLineState extends State<_PulseLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.95).animate(_controller),
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFCFC5B5),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _ScrollToLatestButton extends StatelessWidget {
  const _ScrollToLatestButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF162220),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: IconButton(
        tooltip: 'Scroll to latest',
        onPressed: onPressed,
        icon: const Icon(
          Icons.vertical_align_bottom_rounded,
          color: Colors.white,
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
    final attachmentParts = message.attachmentParts;
    final toolCallParts = message.toolCallParts;
    final toolResultParts = message.toolResultParts;
    final thinkingParts = message.thinkingParts;
    final showStructuredFallback =
        !message.hasVisibleText &&
        attachmentParts.isEmpty &&
        toolCallParts.isEmpty &&
        toolResultParts.isEmpty &&
        thinkingParts.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (message.hasVisibleText)
          _MarkdownTextBlock(text: message.primaryText)
        else if (showStructuredFallback)
          _StructuredChatFallback(message: message),
        if (attachmentParts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attachmentParts
                .map(
                  (part) => Chip(
                    label: Text(part.displayLabel),
                    avatar: const Icon(Icons.attachment_rounded, size: 16),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (toolCallParts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          ...toolCallParts.map(
            (part) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StructuredPayloadCard(
                icon: Icons.handyman_outlined,
                title: part.name ?? message.toolName ?? 'Tool call',
                subtitle: part.id ?? message.toolCallId,
                payload: part.structuredPayload,
                emptyLabel: 'No tool arguments attached.',
                preview: part.structuredPreview,
              ),
            ),
          ),
        ],
        if (toolResultParts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          ...toolResultParts.map(
            (part) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StructuredPayloadCard(
                icon: Icons.data_object_rounded,
                title: part.name ?? message.toolName ?? 'Tool result',
                subtitle: part.id,
                payload: part.structuredPayload,
                emptyLabel: 'No structured tool result attached.',
                preview: part.text?.trim().isNotEmpty == true
                    ? part.text!.trim()
                    : part.structuredPreview,
              ),
            ),
          ),
        ],
        if (thinkingParts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: thinkingParts
                .map(
                  (part) => _StatePill(
                    label:
                        'Thinking${part.thinkingSignature?.trim().isNotEmpty == true ? ' • signed' : ''}',
                    tint: const Color(0xFFE8E1D1),
                    icon: Icons.psychology_alt_rounded,
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (message.usage?.total != null ||
            message.stopReason?.trim().isNotEmpty == true) ...<Widget>[
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

class _StructuredChatFallback extends StatelessWidget {
  const _StructuredChatFallback({required this.message});

  final GatewayChatMessage message;

  @override
  Widget build(BuildContext context) {
    final hasToolCall = message.content.any((part) => part.isToolCall);
    final hasToolResult = message.content.any((part) => part.isToolResult);
    final hasAttachment = message.content.any((part) => part.isAttachment);
    final hasThinking = message.content.any(
      (part) => part.thinking?.trim().isNotEmpty == true,
    );

    final label = switch ((
      hasToolCall,
      hasToolResult,
      hasAttachment,
      hasThinking,
    )) {
      (true, _, _, _) => 'Tool activity',
      (_, true, _, _) => 'Tool result',
      (_, _, true, _) => 'Attachment message',
      (_, _, _, true) => 'Reasoning update',
      _ => 'Structured message',
    };

    final detailParts = <String>[
      if (message.toolName?.trim().isNotEmpty == true) message.toolName!,
      if (message.toolCallId?.trim().isNotEmpty == true)
        'call ${message.toolCallId!}',
      if (message.content.isNotEmpty)
        '${message.content.length} part${message.content.length == 1 ? '' : 's'}',
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2D8C8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF5A4A3B),
                fontWeight: FontWeight.w800,
              ),
            ),
            if (detailParts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                detailParts.join(' • '),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5E706B)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StructuredPayloadCard extends StatefulWidget {
  const _StructuredPayloadCard({
    required this.icon,
    required this.title,
    required this.payload,
    required this.emptyLabel,
    required this.preview,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Object? payload;
  final String emptyLabel;
  final String preview;

  @override
  State<_StructuredPayloadCard> createState() => _StructuredPayloadCardState();
}

class _StructuredPayloadCardState extends State<_StructuredPayloadCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F4ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2D8C8)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E1D1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          widget.icon,
                          size: 18,
                          color: const Color(0xFF7A5C38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: const Color(0xFF5A4A3B),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (widget.subtitle?.trim().isNotEmpty ==
                              true) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF5E706B)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.payload != null)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _expanded = !_expanded;
                          });
                        },
                        tooltip: _expanded ? 'Hide details' : 'Show details',
                        icon: Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.preview.trim().isNotEmpty == true
                      ? widget.preview
                      : widget.emptyLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5E706B),
                    height: 1.45,
                  ),
                ),
                if (_expanded && widget.payload != null) ...<Widget>[
                  const SizedBox(height: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE3DBCF)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        prettyChatValue(widget.payload),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF1B2220),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
