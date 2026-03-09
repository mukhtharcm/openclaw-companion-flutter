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
