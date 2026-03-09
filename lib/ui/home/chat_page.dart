part of '../home.dart';

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
