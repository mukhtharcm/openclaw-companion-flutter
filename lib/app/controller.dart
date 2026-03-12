import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openclaw_companion/app/models.dart';
import 'package:openclaw_companion/app/node_support.dart';
import 'package:openclaw_companion/app/store.dart';
import 'package:openclaw_gateway/openclaw_gateway.dart';

class CompanionController extends ChangeNotifier {
  CompanionController._({
    required CompanionConfigStore configStore,
    required GatewayJsonAuthStateStore authStateStore,
    required Future<void> Function() resetStoredState,
  }) : _configStore = configStore,
       _authStateStore = authStateStore,
       _resetStoredState = resetStoredState;

  final CompanionConfigStore _configStore;
  final GatewayJsonAuthStateStore _authStateStore;
  final Future<void> Function() _resetStoredState;

  GatewayClient? _client;
  StreamSubscription<GatewayConnectionState>? _connectionSubscription;
  StreamSubscription<GatewayEventFrame>? _eventSubscription;
  StreamSubscription<List<GatewayDiscoveredGateway>>? _discoverySubscription;
  StreamSubscription<GatewayNodeInvokeRequest>? _nodeInvokeSubscription;

  CompanionConfig _config = const CompanionConfig();
  bool _loading = true;
  bool _busy = false;
  String? _errorText;
  String? _serverVersion;
  String? _connectedGatewayTitle;
  String? _activeStableId;
  String? _activeRunId;
  String? _streamingAssistantText;
  bool _autoConnectFired = false;
  CompanionTrustPrompt? _pendingTrustPrompt;
  GatewayConnectionState _connectionState = const GatewayConnectionState(
    phase: GatewayConnectionPhase.disconnected,
  );
  GatewayHealthSummary? _health;
  GatewayStatusSnapshot? _status;
  GatewayChannelsStatusResult? _channelsStatus;
  GatewaySessionsListResult? _sessionsList;
  GatewaySessionsPreviewResult? _sessionsPreview;
  GatewayModelsListResult? _models;
  GatewayToolsCatalogResult? _tools;
  GatewayUsageStatusResult? _usage;
  GatewayVoiceWakeConfig? _voiceWake;
  GatewayCronStatusSummary? _cronStatus;
  List<GatewayNodeSummary> _nodes = const <GatewayNodeSummary>[];
  List<GatewayChatMessage> _transcript = const <GatewayChatMessage>[];
  List<GatewayDiscoveredGateway> _discoveredGateways =
      const <GatewayDiscoveredGateway>[];
  GatewayNodeCapabilityRegistry? _nodeRegistry;
  GatewayNodeConnectSnapshot? _nodeSnapshot;
  String? _nodePairingRequestId;
  final List<CompanionNodeInvokeLine> _nodeInvokes =
      <CompanionNodeInvokeLine>[];
  final List<CompanionEventLine> _eventLines = <CompanionEventLine>[];
  final List<String> _activityLog = <String>[];

  static Future<CompanionController> bootstrap() async {
    final stores = await CompanionConfigStore.open();
    final controller = CompanionController._(
      configStore: stores.configStore,
      authStateStore: stores.authStateStore,
      resetStoredState: stores.resetAll,
    );
    await controller._initialize();
    return controller;
  }

  CompanionConfig get config => _config;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get errorText => _errorText;
  String? get serverVersion => _serverVersion;
  String? get connectedGatewayTitle => _connectedGatewayTitle;
  String? get activeStableId => _activeStableId;
  String? get activeRunId => _activeRunId;
  String? get streamingAssistantText => _streamingAssistantText;
  GatewayClient? get client => _client;
  CompanionTrustPrompt? get pendingTrustPrompt => _pendingTrustPrompt;
  GatewayConnectionState get connectionState => _connectionState;
  GatewayHealthSummary? get health => _health;
  GatewayStatusSnapshot? get status => _status;
  GatewayChannelsStatusResult? get channelsStatus => _channelsStatus;
  GatewaySessionsListResult? get sessionsList => _sessionsList;
  GatewaySessionsPreviewResult? get sessionsPreview => _sessionsPreview;
  GatewayModelsListResult? get models => _models;
  GatewayToolsCatalogResult? get tools => _tools;
  GatewayUsageStatusResult? get usage => _usage;
  GatewayVoiceWakeConfig? get voiceWake => _voiceWake;
  GatewayCronStatusSummary? get cronStatus => _cronStatus;
  CompanionWorkspaceMode get workspaceMode => _config.workspaceMode;
  bool get nodeMode => _config.workspaceMode == CompanionWorkspaceMode.node;
  List<GatewayNodeSummary> get nodes => _nodes;
  GatewayNodeConnectSnapshot? get nodeSnapshot => _nodeSnapshot;
  String? get nodePairingRequestId => _nodePairingRequestId;
  List<CompanionNodeInvokeLine> get nodeInvokes =>
      List.unmodifiable(_nodeInvokes);
  List<GatewayChatMessage> get transcript => _transcript;
  List<GatewayDiscoveredGateway> get discoveredGateways => _discoveredGateways;
  List<CompanionEventLine> get eventLines => List.unmodifiable(_eventLines);
  List<String> get activityLog => List.unmodifiable(_activityLog);
  bool get connected => _connectionState.isConnected;
  bool get needsInitialConnectionSetup =>
      !connected &&
      _config.manualUrl.trim().isEmpty &&
      _config.lastConnection == null &&
      _config.token.trim().isEmpty &&
      _config.password.trim().isEmpty;

  Future<void> _initialize() async {
    final loadedConfig = await _configStore.load();
    _config = _normalizeConfig(loadedConfig);
    if (_config.authMode != loadedConfig.authMode) {
      await _persistConfig();
    }
    _loading = false;
    notifyListeners();
    _startDiscovery();
    await _attemptAutoConnect();
  }

  void _startDiscovery() {
    _discoverySubscription?.cancel();
    final discovery = GatewayMdnsDiscoveryClient();
    _discoverySubscription = discovery
        .watch(
          options: const GatewayDiscoveryOptions(
            timeout: Duration(milliseconds: 900),
            pollInterval: Duration(seconds: 8),
          ),
        )
        .listen(
          (gateways) {
            _discoveredGateways = gateways;
            notifyListeners();
            unawaited(_attemptAutoConnect());
          },
          onError: (Object error) {
            _appendLog('discovery error: ${_describeUnknownError(error)}');
          },
        );
  }

  Future<void> _attemptAutoConnect() async {
    if (_autoConnectFired || !_config.autoConnect) {
      return;
    }
    final last = _config.lastConnection;
    if (last == null) {
      return;
    }

    if (last.kind == CompanionConnectionKind.discovered) {
      final stableId = last.stableId;
      if (stableId == null) {
        return;
      }
      final gateway = _discoveredGateways
          .cast<GatewayDiscoveredGateway?>()
          .firstWhere(
            (candidate) => candidate?.stableId == stableId,
            orElse: () => null,
          );
      if (gateway == null) {
        return;
      }
      _autoConnectFired = true;
      await connectDiscovered(gateway);
      return;
    }

    final url = last.url?.trim();
    if (url == null || url.isEmpty) {
      return;
    }
    _autoConnectFired = true;
    await connectManual(url);
  }

  Future<CompanionConfig?> importSetupCode(
    String raw, {
    CompanionWorkspaceMode? workspaceMode,
  }) async {
    final payload = decodeCompanionSetupPayload(raw);
    if (payload == null) {
      _setError('Setup code is not valid JSON or base64 JSON.');
      return null;
    }

    final uri = payload.toUri();
    if (uri == null) {
      _setError('Setup code is missing a valid gateway URL or host.');
      return null;
    }

    final nextAuthMode = payload.token?.trim().isNotEmpty == true
        ? CompanionAuthMode.token
        : payload.password?.trim().isNotEmpty == true
        ? CompanionAuthMode.password
        : _config.authMode;
    _config = _config.copyWith(
      manualUrl: uri.toString(),
      workspaceMode: workspaceMode ?? _config.workspaceMode,
      authMode: nextAuthMode,
      token: payload.token?.trim() ?? _config.token,
      password: payload.password?.trim() ?? _config.password,
    );
    await _persistConfig();
    _appendLog('imported setup code for ${uri.host}');
    notifyListeners();
    return _config;
  }

  Future<void> setAutoConnect(bool value) async {
    _config = _config.copyWith(autoConnect: value);
    await _persistConfig();
    notifyListeners();
  }

  Future<void> setWorkspaceMode(CompanionWorkspaceMode value) async {
    if (_config.workspaceMode == value) {
      return;
    }
    _config = _config.copyWith(workspaceMode: value);
    await _persistConfig();
    notifyListeners();
  }

  Future<void> setPreferredSessionKey(String value) async {
    final trimmed = value.trim();
    _config = _config.copyWith(
      preferredSessionKey: trimmed.isEmpty ? 'main' : trimmed,
    );
    await _persistConfig();
    notifyListeners();
  }

  Future<void> setThinking(String value) async {
    _config = _config.copyWith(
      thinking: value.trim().isEmpty ? 'default' : value.trim(),
    );
    await _persistConfig();
    notifyListeners();
  }

  Future<void> connectManual(
    String url, {
    CompanionWorkspaceMode? workspaceMode,
    CompanionAuthMode? authMode,
    String? token,
    String? password,
    bool? autoConnect,
  }) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
      _setError('Enter a valid ws:// or wss:// gateway URL.');
      return;
    }

    _config = _config.copyWith(
      manualUrl: trimmed,
      workspaceMode: workspaceMode ?? _config.workspaceMode,
      authMode: authMode ?? _config.authMode,
      token: token ?? _config.token,
      password: password ?? _config.password,
      autoConnect: autoConnect ?? _config.autoConnect,
      lastConnection: CompanionLastConnection.manual(url: trimmed),
    );
    await _persistConfig();

    final request = CompanionConnectionRequest(
      title: uri.host.isEmpty ? trimmed : uri.host,
      uri: uri,
      stableId: _manualStableId(uri),
      workspaceMode: _config.workspaceMode,
      authMode: _config.authMode,
      token: _config.token,
      password: _config.password,
      lastConnection: CompanionLastConnection.manual(url: trimmed),
    );
    await _prepareConnection(request);
  }

  Future<void> connectDiscovered(
    GatewayDiscoveredGateway gateway, {
    CompanionWorkspaceMode? workspaceMode,
    CompanionAuthMode? authMode,
    String? token,
    String? password,
    bool? autoConnect,
  }) async {
    _config = _config.copyWith(
      workspaceMode: workspaceMode ?? _config.workspaceMode,
      authMode: authMode ?? _config.authMode,
      token: token ?? _config.token,
      password: password ?? _config.password,
      autoConnect: autoConnect ?? _config.autoConnect,
      lastConnection: CompanionLastConnection.discovered(
        stableId: gateway.stableId,
      ),
    );
    await _persistConfig();

    final storedFingerprint = await _authStateStore.readFingerprint(
      stableId: gateway.stableId,
    );
    final requireTls = gateway.tlsEnabled || storedFingerprint != null;
    if (!requireTls) {
      _setError(
        'Discovered gateway ${gateway.displayName} is missing TLS and has not been trusted yet.',
      );
      return;
    }

    final uri = storedFingerprint != null && !gateway.tlsEnabled
        ? Uri(scheme: 'wss', host: gateway.targetHost, port: gateway.port)
        : gateway.primaryUri;

    final request = CompanionConnectionRequest(
      title: gateway.displayName,
      uri: uri,
      stableId: gateway.stableId,
      workspaceMode: _config.workspaceMode,
      authMode: _config.authMode,
      token: _config.token,
      password: _config.password,
      lastConnection: CompanionLastConnection.discovered(
        stableId: gateway.stableId,
      ),
    );
    await _prepareConnection(request);
  }

  Future<void> acceptTrustPrompt() async {
    final prompt = _pendingTrustPrompt;
    if (prompt == null) {
      return;
    }
    await _authStateStore.writeFingerprint(
      GatewayStoredTlsFingerprint(
        stableId: prompt.stableId,
        fingerprint: prompt.fingerprint,
        observedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _appendLog('trusted ${prompt.title} (${prompt.fingerprint})');
    _pendingTrustPrompt = null;
    notifyListeners();
    await _openConnection(prompt.request);
  }

  void declineTrustPrompt() {
    if (_pendingTrustPrompt == null) {
      return;
    }
    _appendLog('dismissed TLS trust prompt');
    _pendingTrustPrompt = null;
    notifyListeners();
  }

  Future<void> _prepareConnection(CompanionConnectionRequest request) async {
    if (request.uri.scheme == 'wss') {
      final stored = await _authStateStore.readFingerprint(
        stableId: request.stableId,
      );
      if (stored == null) {
        try {
          final fingerprint = await GatewayTlsProbe.probeFingerprint(
            request.uri,
          );
          if (fingerprint == null) {
            _setError('Failed to read a TLS fingerprint from ${request.uri}.');
            return;
          }
          _pendingTrustPrompt = CompanionTrustPrompt(
            title: request.title,
            uri: request.uri,
            stableId: request.stableId,
            fingerprint: fingerprint,
            request: request,
          );
          notifyListeners();
          return;
        } catch (error) {
          _setError(_describeUnknownError(error));
          return;
        }
      }
    }
    await _openConnection(request);
  }

  Future<void> _openConnection(CompanionConnectionRequest request) async {
    final auth = _resolveAuth(
      mode: request.authMode,
      token: request.token,
      password: request.password,
    );
    if (auth == null) {
      return;
    }

    _busy = true;
    _errorText = null;
    notifyListeners();
    await disconnect(quiet: true);

    try {
      final tlsPolicy = request.uri.scheme == 'wss'
          ? GatewayTlsPolicy(
              stableId: request.stableId,
              fingerprintStore: _authStateStore,
            )
          : null;
      final clientInfo = buildCompanionClientInfo(
        workspaceMode: request.workspaceMode,
      );

      GatewayClient client;
      GatewayNodeCapabilityRegistry? nodeRegistry;
      GatewayNodeConnectSnapshot? nodeSnapshot;
      if (request.workspaceMode == CompanionWorkspaceMode.node) {
        nodeRegistry = buildCompanionNodeRegistry();
        nodeSnapshot = await nodeRegistry.snapshot();
        final identity = await _authStateStore.readOrCreateIdentity();
        final options = await nodeRegistry.buildConnectOptions(
          uri: request.uri,
          auth: auth,
          clientInfo: clientInfo,
          deviceIdentity: identity,
          deviceTokenStore: _authStateStore,
          autoReconnect: true,
          tlsPolicy: tlsPolicy,
        );
        client = await GatewayClient.connectWithOptions(options);
      } else {
        client = await GatewayClient.connect(
          uri: request.uri,
          auth: auth,
          clientInfo: clientInfo,
          autoReconnect: true,
          tlsPolicy: tlsPolicy,
        );
      }

      _client = client;
      _nodeRegistry = nodeRegistry;
      _nodeSnapshot = nodeSnapshot;
      _nodePairingRequestId = null;
      _nodeInvokes.clear();
      _serverVersion = client.hello.server.version;
      _connectionState = client.connectionState;
      _connectedGatewayTitle = request.title;
      _activeStableId = request.stableId;
      _config = _config.copyWith(lastConnection: request.lastConnection);
      await _persistConfig();

      _connectionSubscription = client.connectionStates.listen((state) {
        _connectionState = state;
        if (state.phase == GatewayConnectionPhase.reconnecting) {
          _appendLog('reconnecting to ${request.title}');
        }
        if (state.phase == GatewayConnectionPhase.connected) {
          _appendLog('connected to ${request.title}');
          if (request.workspaceMode == CompanionWorkspaceMode.node) {
            unawaited(_refreshNodeState(includeLog: false));
          } else {
            unawaited(refresh());
          }
        }
        if (state.error != null) {
          _appendLog('connection error: ${_describeError(state.error!)}');
        }
        notifyListeners();
      });

      _eventSubscription = client.events.listen(_handleEventFrame);
      if (request.workspaceMode == CompanionWorkspaceMode.node &&
          nodeRegistry != null) {
        _nodeInvokeSubscription = client.node.invokeRequests.listen(
          (invoke) {
            unawaited(_handleNodeInvoke(client, nodeRegistry!, invoke));
          },
        );
      }
      _appendLog(
        'connected to ${request.title} (${request.workspaceMode.label.toLowerCase()} · ${client.hello.server.version})',
      );
      if (request.workspaceMode == CompanionWorkspaceMode.node) {
        await _refreshNodeState(includeLog: false);
      } else {
        await refresh();
      }
    } on GatewayResponseException catch (error) {
      final detailCode = readGatewayConnectErrorDetailCode(error.details);
      if (request.workspaceMode == CompanionWorkspaceMode.node &&
          detailCode == GatewayConnectErrorDetailCodes.pairingRequired) {
        _nodePairingRequestId = _readResponseDetailString(
          error.details,
          'requestId',
        );
        _errorText = null;
        _appendLog(
          'node pairing required${_nodePairingRequestId == null ? '' : ' ($_nodePairingRequestId)'}',
        );
        notifyListeners();
      } else {
        _setError(_describeUnknownError(error));
      }
    } catch (error) {
      _setError(_describeUnknownError(error));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final client = _client;
    if (client == null) {
      _setError('Connect first.');
      return;
    }
    if (nodeMode) {
      await _refreshNodeState();
      return;
    }

    _busy = true;
    _errorText = null;
    notifyListeners();

    try {
      final healthFuture = client.query.health();
      final statusFuture = client.query.status();
      final sessionsFuture = client.query.sessionsList(
        limit: 18,
        includeDerivedTitles: true,
        includeLastMessage: true,
      );
      final channelsFuture = _loadOptional(client.query.channelsStatus);
      final modelsFuture = _loadOptional(client.query.modelsList);
      final toolsFuture = _loadOptional(
        () => client.query.toolsCatalog(includePlugins: true),
      );
      final usageFuture = _loadOptional(client.query.usageStatus);
      final voiceWakeFuture = _loadOptional(client.query.voiceWakeGet);
      final cronStatusFuture = _loadOptional(client.query.cronStatus);
      final nodesFuture = _loadOptional(client.nodes.list);

      final health = await healthFuture;
      final status = await statusFuture;
      final sessions = await sessionsFuture;
      final previewKeys = sessions.sessions
          .take(6)
          .map((session) => session.key)
          .toList(growable: false);
      final previewsFuture = previewKeys.isEmpty
          ? Future<GatewaySessionsPreviewResult?>.value(null)
          : _loadOptional(
              () => client.query.sessionsPreview(
                keys: previewKeys,
                limit: 3,
                maxChars: 180,
              ),
            );
      final historyFuture = _fetchHistory(_config.preferredSessionKey);

      _health = health;
      _status = status;
      _sessionsList = sessions;
      _channelsStatus = await channelsFuture;
      _models = await modelsFuture;
      _tools = await toolsFuture;
      _usage = await usageFuture;
      _voiceWake = await voiceWakeFuture;
      _cronStatus = await cronStatusFuture;
      _nodes = await nodesFuture ?? const <GatewayNodeSummary>[];
      _sessionsPreview = await previewsFuture;
      _transcript = (await historyFuture).messages;
      _streamingAssistantText = null;
      _appendLog('refreshed gateway state');
    } catch (error) {
      _setError(_describeUnknownError(error));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _refreshNodeState({bool includeLog = true}) async {
    final registry = _nodeRegistry;
    if (registry == null) {
      return;
    }

    _busy = true;
    _errorText = null;
    notifyListeners();
    try {
      _nodeSnapshot = await registry.snapshot();
      if (includeLog) {
        _appendLog('refreshed node state');
      }
    } catch (error) {
      _setError(_describeUnknownError(error));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _handleNodeInvoke(
    GatewayClient client,
    GatewayNodeCapabilityRegistry registry,
    GatewayNodeInvokeRequest request,
  ) async {
    _appendLog('node invoke requested: ${request.command}');
    final result = await registry.dispatch(client, request);
    final status = result.ok
        ? CompanionNodeInvokeStatus.success
        : CompanionNodeInvokeStatus.error;
    var summary = _summarizeNodeInvokeResult(result);
    try {
      await client.node.sendInvokeResult(
        id: request.id,
        nodeId: request.nodeId,
        ok: result.ok,
        payload: result.payload,
        payloadJson: result.payloadJson,
        error: result.error,
      );
    } catch (error) {
      summary = 'Failed to send node result: ${_describeUnknownError(error)}';
      _appendLog(summary);
      _recordNodeInvoke(
        command: request.command,
        summary: summary,
        status: CompanionNodeInvokeStatus.error,
      );
      return;
    }

    _recordNodeInvoke(
      command: request.command,
      summary: summary,
      status: status,
    );
    _appendLog(
      result.ok
          ? 'node invoke handled: ${request.command}'
          : 'node invoke failed: ${request.command}',
    );
  }

  Future<void> reloadHistory() async {
    try {
      final history = await _fetchHistory(_config.preferredSessionKey);
      _transcript = history.messages;
      if (_activeRunId == null) {
        _streamingAssistantText = null;
      }
      notifyListeners();
    } catch (error) {
      _appendLog('history load failed: ${_describeUnknownError(error)}');
    }
  }

  Future<GatewayChatHistoryResult> _fetchHistory(String sessionKey) async {
    final client = _client;
    if (client == null || sessionKey.trim().isEmpty) {
      return GatewayChatHistoryResult.fromJson(<String, Object?>{
        'sessionKey': sessionKey,
        'messages': const <Object?>[],
      });
    }

    return client.query.chatHistory(sessionKey: sessionKey.trim(), limit: 24);
  }

  Future<void> sendPrompt(String prompt) async {
    final client = _client;
    if (client == null) {
      _setError('Connect first.');
      return;
    }

    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      _setError('Enter a prompt first.');
      return;
    }

    _busy = true;
    _errorText = null;
    final previousTranscript = List<GatewayChatMessage>.of(_transcript);
    final optimisticTranscript = List<GatewayChatMessage>.of(previousTranscript)
      ..add(_buildOptimisticUserMessage(trimmed));
    _transcript = optimisticTranscript;
    _streamingAssistantText = null;
    notifyListeners();

    try {
      final payload = await client.admin.chatSend(
        sessionKey: _config.preferredSessionKey,
        message: trimmed,
        thinking: _config.thinking == 'default' ? null : _config.thinking,
      );
      _activeRunId = payload.runId;
      _appendLog('chat.send accepted: ${payload.status} (${payload.runId})');
    } catch (error) {
      _transcript = previousTranscript;
      _setError(_describeUnknownError(error));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> abortRun() async {
    final client = _client;
    final runId = _activeRunId;
    if (client == null || runId == null) {
      return;
    }
    try {
      final result = await client.admin.chatAbort(
        sessionKey: _config.preferredSessionKey,
        runId: runId,
      );
      _appendLog(
        result.aborted
            ? 'requested chat abort for $runId'
            : 'chat abort skipped; run was already finished',
      );
    } catch (error) {
      _setError(_describeUnknownError(error));
    }
  }

  Future<void> forgetCurrentTrust() async {
    final stableId =
        _activeStableId ??
        (_config.lastConnection?.kind == CompanionConnectionKind.discovered
            ? _config.lastConnection?.stableId
            : _config.lastConnection?.url == null
            ? null
            : _manualStableId(Uri.parse(_config.lastConnection!.url!)));
    if (stableId == null) {
      return;
    }
    await _authStateStore.deleteFingerprint(stableId: stableId);
    _appendLog('forgot trusted fingerprint for $stableId');
    notifyListeners();
  }

  Future<void> clearSavedCredentials() async {
    _config = _config.copyWith(
      token: '',
      password: '',
      authMode: CompanionAuthMode.token,
    );
    await _persistConfig();
    _appendLog('cleared saved shared credentials');
    notifyListeners();
  }

  Future<void> resetAllState() async {
    await disconnect(quiet: true);
    await _resetStoredState();
    _config = const CompanionConfig();
    _errorText = null;
    _pendingTrustPrompt = null;
    _activeStableId = null;
    _autoConnectFired = false;
    _nodePairingRequestId = null;
    _eventLines.clear();
    _nodeInvokes.clear();
    _activityLog.clear();
    _appendLog('debug reset: cleared saved app state');
    notifyListeners();
  }

  Future<void> disconnect({bool quiet = false}) async {
    final client = _client;
    _client = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _nodeInvokeSubscription?.cancel();
    _nodeInvokeSubscription = null;
    if (client != null) {
      await client.close();
      if (!quiet) {
        _appendLog('disconnected');
      }
    }

    _activeRunId = null;
    _streamingAssistantText = null;
    _serverVersion = null;
    _connectedGatewayTitle = null;
    _connectionState = const GatewayConnectionState(
      phase: GatewayConnectionPhase.disconnected,
    );
    _nodeRegistry = null;
    _nodeSnapshot = null;
    _nodePairingRequestId = null;
    _nodeInvokes.clear();
    _health = null;
    _status = null;
    _channelsStatus = null;
    _sessionsList = null;
    _sessionsPreview = null;
    _models = null;
    _tools = null;
    _usage = null;
    _voiceWake = null;
    _cronStatus = null;
    _nodes = const <GatewayNodeSummary>[];
    _transcript = const <GatewayChatMessage>[];
    notifyListeners();
  }

  void selectSession(String key) {
    unawaited(setPreferredSessionKey(key));
    _appendLog('session selected: $key');
    _activeRunId = null;
    _streamingAssistantText = null;
    unawaited(reloadHistory());
  }

  void _handleEventFrame(GatewayEventFrame frame) {
    _eventLines.insert(
      0,
      CompanionEventLine(
        timeLabel: _clockNow(),
        name: frame.event,
        summary: _summarizeEvent(frame),
      ),
    );
    if (_eventLines.length > 120) {
      _eventLines.removeRange(120, _eventLines.length);
    }

    if (frame.event == 'chat') {
      final event = GatewayChatEvent.fromEventFrame(frame);
      if (_matchesSelectedChatSession(
        sessionKey: event.sessionKey,
        runId: event.runId,
      )) {
        if (event.isTerminal) {
          _activeRunId = null;
          _streamingAssistantText = null;
          if (event.state == 'error' && event.errorMessage != null) {
            _setError(event.errorMessage!);
          } else {
            unawaited(reloadHistory());
          }
        } else {
          _activeRunId = event.runId;
          final eventText = _extractChatText(event.message);
          if (eventText != null) {
            _streamingAssistantText = eventText;
          }
        }
      }
    }

    if (frame.event == 'agent') {
      final event = GatewayAgentEvent.fromEventFrame(frame);
      if (_matchesSelectedChatSession(
        sessionKey: event.sessionKey,
        runId: event.runId,
      )) {
        if (event.streamName == 'assistant') {
          final data = event.assistantData;
          if (data?.text?.trim().isNotEmpty == true) {
            _streamingAssistantText = data!.text;
          } else if (data?.delta?.isNotEmpty == true) {
            _streamingAssistantText =
                (_streamingAssistantText ?? '') + data!.delta!;
          }
        }
      }
    }

    if (frame.event == 'health') {
      try {
        _health = GatewayHealthSummary.fromJson(
          _asJsonMap(frame.payload, 'health event payload'),
        );
      } catch (_) {
        // Keep the UI resilient if the payload shape changes.
      }
    }

    notifyListeners();
  }

  bool _matchesSelectedChatSession({
    required String? sessionKey,
    required String? runId,
  }) {
    if (runId != null && runId == _activeRunId) {
      return true;
    }
    if (sessionKey == null || sessionKey.trim().isEmpty) {
      return false;
    }
    return gatewayChatSessionKeysMatch(
      incoming: sessionKey,
      current: _config.preferredSessionKey,
    );
  }

  GatewayChatMessage _buildOptimisticUserMessage(String text) {
    return GatewayChatMessage(
      role: 'user',
      content: <GatewayChatMessageContent>[
        GatewayChatMessageContent.text(text),
      ],
      timestamp: DateTime.now().millisecondsSinceEpoch.toDouble(),
      raw: <String, Object?>{
        'role': 'user',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'content': <Object?>[
          <String, Object?>{'type': 'text', 'text': text},
        ],
      },
    );
  }

  String? _extractChatText(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    if (value is Map<Object?, Object?>) {
      try {
        final message = GatewayChatMessage.fromJson(
          value.map((key, entry) => MapEntry(key.toString(), entry)),
        );
        return message.hasVisibleText ? message.primaryText : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<T?> _loadOptional<T>(Future<T> Function() loader) async {
    try {
      return await loader();
    } catch (error) {
      _appendLog('optional load failed: ${_describeUnknownError(error)}');
      return null;
    }
  }

  GatewayAuth? _resolveAuth({
    required CompanionAuthMode mode,
    required String token,
    required String password,
  }) {
    switch (mode) {
      case CompanionAuthMode.token:
        if (token.trim().isEmpty) {
          _setError('Enter a gateway token first.');
          return null;
        }
        return GatewayAuth.token(token.trim());
      case CompanionAuthMode.password:
        if (password.trim().isEmpty) {
          _setError('Enter a gateway password first.');
          return null;
        }
        return GatewayAuth.password(password.trim());
      case CompanionAuthMode.none:
        return const GatewayAuth.none();
    }
  }

  Future<void> _persistConfig() async {
    await _configStore.save(_config);
  }

  CompanionConfig _normalizeConfig(CompanionConfig config) {
    if (config.authMode != CompanionAuthMode.none) {
      return config;
    }
    if (config.token.trim().isNotEmpty) {
      return config.copyWith(authMode: CompanionAuthMode.token);
    }
    if (config.password.trim().isNotEmpty) {
      return config.copyWith(authMode: CompanionAuthMode.password);
    }
    return config.copyWith(authMode: CompanionAuthMode.token);
  }

  void _recordNodeInvoke({
    required String command,
    required String summary,
    required CompanionNodeInvokeStatus status,
  }) {
    _nodeInvokes.insert(
      0,
      CompanionNodeInvokeLine(
        timeLabel: _clockNow(),
        command: command,
        summary: summary,
        status: status,
      ),
    );
    if (_nodeInvokes.length > 60) {
      _nodeInvokes.removeRange(60, _nodeInvokes.length);
    }
    notifyListeners();
  }

  String _summarizeNodeInvokeResult(GatewayNodeCommandResult result) {
    if (!result.ok) {
      return result.error?.message?.trim().isNotEmpty == true
          ? result.error!.message!
          : 'Command failed';
    }
    if (result.payload != null) {
      return summarizeChatValue(result.payload, maxLength: 180);
    }
    if (result.payloadJson?.trim().isNotEmpty == true) {
      return _truncateText(result.payloadJson!, 180);
    }
    return 'ok';
  }

  void _setError(String message) {
    _errorText = message;
    _appendLog('error: $message');
    notifyListeners();
  }

  void _appendLog(String line) {
    _activityLog.insert(0, '[${_clockNow()}] $line');
    if (_activityLog.length > 120) {
      _activityLog.removeRange(120, _activityLog.length);
    }
    notifyListeners();
  }

  String _describeUnknownError(Object error) {
    if (error is GatewayException) {
      return _describeError(error);
    }
    return error.toString();
  }

  String _describeError(GatewayException error) {
    final parts = <String>[error.toString()];
    Object? cause = error.cause;
    while (cause != null) {
      parts.add('caused by: $cause');
      if (cause is GatewayException) {
        cause = cause.cause;
      } else {
        break;
      }
    }
    return parts.join('\n');
  }

  String _summarizeEvent(GatewayEventFrame frame) {
    return summarizeGatewayEventFrame(frame);
  }

  Future<void> shutdown() async {
    await disconnect(quiet: true);
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    super.dispose();
  }

  static String _manualStableId(Uri uri) {
    final port = uri.hasPort
        ? uri.port
        : uri.scheme == 'wss'
        ? 443
        : 80;
    return 'manual|${uri.host}:$port';
  }
}

String _clockNow() {
  final now = DateTime.now();
  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  final ss = now.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

String _truncateText(String value, int maxLength) {
  if (value.length <= maxLength) {
    return value;
  }
  return '${value.substring(0, maxLength - 1)}…';
}

String? _readResponseDetailString(Object? details, String key) {
  if (details is! Map<Object?, Object?>) {
    return null;
  }
  final value = details[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

JsonMap _asJsonMap(Object? value, String context) {
  if (value is Map<Object?, Object?>) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
  throw FormatException('Expected object for $context.');
}
