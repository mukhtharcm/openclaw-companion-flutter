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
  late String _lastSessionKey;
  late int _lastTranscriptLength;
  late String? _lastStreamingAssistantText;

  @override
  void initState() {
    super.initState();
    _lastSessionKey = widget.controller.config.preferredSessionKey;
    _lastTranscriptLength = widget.controller.transcript.length;
    _lastStreamingAssistantText = widget.controller.streamingAssistantText;
    _transcriptScrollController.addListener(_handleTranscriptScroll);
  }

  @override
  void didUpdateWidget(covariant _SessionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionChanged =
        _lastSessionKey != widget.controller.config.preferredSessionKey;
    final transcriptChanged =
        _lastTranscriptLength != widget.controller.transcript.length ||
        _lastStreamingAssistantText != widget.controller.streamingAssistantText;
    if (sessionChanged) {
      _pinTranscriptToBottom = true;
      _scheduleTranscriptScroll(jump: true);
    } else if (transcriptChanged) {
      _scheduleTranscriptScroll();
    }
    _lastSessionKey = widget.controller.config.preferredSessionKey;
    _lastTranscriptLength = widget.controller.transcript.length;
    _lastStreamingAssistantText = widget.controller.streamingAssistantText;
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
        duration: const Duration(milliseconds: 160),
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
                        child: widget.controller.busy && sessions.isEmpty
                            ? const _SkeletonCardList(count: 4)
                            : filtered.isEmpty
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
    final loadingSessions =
        widget.controller.busy && widget.controller.sessionsList == null;
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
              child: loadingSessions
                  ? const _SkeletonCardList(count: 5)
                  : filteredSessions.isEmpty
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
    final showJumpToLatest = !_pinTranscriptToBottom && !transcriptEmpty;
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
              onThinkingChanged: widget.onThinkingChanged,
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
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: transcriptEmpty
                        ? widget.controller.busy
                              ? const _ConversationLoadingState()
                              : _ConversationEmptyState(
                                  sessionKey: widget
                                      .controller
                                      .config
                                      .preferredSessionKey,
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
                                      text: widget
                                          .controller
                                          .streamingAssistantText!,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  if (showJumpToLatest)
                    Positioned(
                      right: compactChat ? 14 : 22,
                      bottom: compactChat ? 14 : 18,
                      child: _ScrollToLatestButton(
                        onPressed: () {
                          _pinTranscriptToBottom = true;
                          _scheduleTranscriptScroll();
                        },
                      ),
                    ),
                ],
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
                  TextField(
                    controller: widget.promptController,
                    minLines: compactChat ? 2 : 3,
                    maxLines: compactChat ? 4 : 6,
                    decoration: const InputDecoration(
                      hintText: 'Write a prompt, note, or follow-up question',
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 520;
                      void sendAction() {
                        if (widget.controller.busy ||
                            widget.controller.activeRunId != null) {
                          return;
                        }
                        unawaited(widget.onSendPrompt());
                      }

                      final sendButton = compactChat
                          ? IconButton.filled(
                              tooltip: widget.controller.activeRunId == null
                                  ? 'Send message'
                                  : 'Run in progress',
                              onPressed:
                                  widget.controller.busy ||
                                      widget.controller.activeRunId != null
                                  ? null
                                  : sendAction,
                              icon: Icon(
                                widget.controller.activeRunId == null
                                    ? Icons.arrow_upward_rounded
                                    : Icons.timelapse_rounded,
                              ),
                            )
                          : FilledButton.icon(
                              onPressed:
                                  widget.controller.busy ||
                                      widget.controller.activeRunId != null
                                  ? null
                                  : sendAction,
                              icon: Icon(
                                widget.controller.activeRunId == null
                                    ? Icons.arrow_upward_rounded
                                    : Icons.timelapse_rounded,
                              ),
                              label: Text(
                                widget.controller.activeRunId == null
                                    ? 'Send'
                                    : 'Running',
                              ),
                            );
                      final abortButton = IconButton.filledTonal(
                        tooltip: 'Abort run',
                        onPressed: widget.controller.activeRunId == null
                            ? null
                            : widget.onAbortRun,
                        icon: const Icon(Icons.stop_rounded),
                      );

                      final helperText =
                          selectedSession?.lastMessagePreview
                                  ?.trim()
                                  .isNotEmpty ==
                              true
                          ? selectedSession!.lastMessagePreview!
                          : 'Press Enter for a new line, then send when ready.';

                      final helper = Text(
                        helperText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF5E706B),
                        ),
                      );

                      if (stacked) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            if (!compactChat) ...<Widget>[
                              Expanded(child: helper),
                              const SizedBox(width: 10),
                            ],
                            if (!compactChat)
                              Expanded(child: sendButton)
                            else
                              sendButton,
                            const SizedBox(width: 10),
                            abortButton,
                          ],
                        );
                      }

                      if (compactChat) {
                        return Row(
                          children: <Widget>[
                            const Spacer(),
                            sendButton,
                            const SizedBox(width: 10),
                            abortButton,
                          ],
                        );
                      }

                      return Row(
                        children: <Widget>[
                          Expanded(child: helper),
                          const SizedBox(width: 12),
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
