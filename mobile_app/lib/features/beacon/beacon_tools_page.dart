import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';

import '../../beacon_simulation_page.dart';
import '../../l10n/app_strings.dart';
import '../../shared/config/api_config.dart';
import '../../theme/app_theme.dart';
import '../artifacts/artifact.dart';
import '../artifacts/artifact_detail_page.dart';
import '../auth/auth_service.dart';
import '../auth/auth_session.dart';
import '../data/visitor_api_service.dart';
import '../sites/site_detail_page.dart';
import '../visits/visit_log_service.dart';
import 'beacon_content_controller.dart';
import 'beacon_content_service.dart';
import 'beacon_scanner.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.catalog,
    this.onLocaleChanged,
    this.isDemoSession = false,
    this.stopScanning,
    this.readToken,
    this.visitorApi,
    this.siteApi,
  });

  final ArtifactCatalog? catalog;
  final ValueChanged<Locale>? onLocaleChanged;
  final Future<bool> Function()? stopScanning;
  final AuthToken? Function()? readToken;
  final VisitorApi? visitorApi;
  final SiteApi? siteApi;
  final bool isDemoSession;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scanPageKey = GlobalKey<BeaconTestPageState>();

  int _selectedIndex = 0;
  bool _switching = false;

  Future<void> _onDestinationSelected(int index) async {
    if (index == _selectedIndex || _switching) return;

    _switching = true;

    try {
      if (_selectedIndex == 0) {
        final scanPage = _scanPageKey.currentState;

        if (scanPage?.isBusy ?? false) return;

        final canSwitch = widget.stopScanning != null
            ? await widget.stopScanning!()
            : await (scanPage?.stopScanningIfNeeded() ?? Future.value(true));

        if (!mounted || !canSwitch) return;
      }

      if (mounted) {
        setState(() => _selectedIndex = index);
      }
    } finally {
      _switching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionScope.maybeOf(context);
    final readToken = widget.readToken ?? session?.readToken;
    final languageCode = Localizations.localeOf(context).languageCode;
    final isEnglish = AppStrings.of(context).isEnglish;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          BeaconTestPage(
            key: _scanPageKey,
            isActive: _selectedIndex == 0,
            readToken: readToken,
            languageCode: languageCode,
            visitorApi: widget.visitorApi,
            siteApi: widget.siteApi,
          ),
          BeaconSimulationPage(
            isActive: _selectedIndex == 1,
            readToken: readToken,
            languageCode: languageCode,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.bluetooth_searching),
            label: isEnglish ? 'Beacon guide' : 'Quét Beacon',
          ),
          NavigationDestination(
            icon: const Icon(Icons.science_outlined),
            label: isEnglish ? 'Simulation' : 'Mô phỏng',
          ),
        ],
      ),
    );
  }
}

class BeaconTestPage extends StatefulWidget {
  const BeaconTestPage({
    super.key,
    this.readToken,
    this.languageCode = 'vi',
    this.isActive = true,
    @visibleForTesting this.visitLogService,
    @visibleForTesting this.visitorApi,
    @visibleForTesting this.siteApi,
    @visibleForTesting this.contentService,
    @visibleForTesting this.beaconStream,
    @visibleForTesting this.scanner,
    @visibleForTesting this.clock,
  });

  final AuthToken? Function()? readToken;
  final String languageCode;
  final bool isActive;
  final VisitLogService? visitLogService;
  final VisitorApi? visitorApi;
  final SiteApi? siteApi;

  final BeaconContentService? contentService;
  final Stream<List<Beacon>>? beaconStream;
  final BeaconScanner? scanner;
  final DateTime Function()? clock;

  @override
  State<BeaconTestPage> createState() => BeaconTestPageState();
}

class BeaconTestPageState extends State<BeaconTestPage>
    with WidgetsBindingObserver {
  StreamSubscription<List<Beacon>>? _subscription;
  StreamSubscription<BluetoothState>? _bluetoothSubscription;
  StreamSubscription<AuthorizationStatus>? _authorizationSubscription;
  late final BeaconScanner _scanner;
  Timer? _rawExpiryTimer;
  Timer? _selectionExpiryTimer;
  int _scanEpoch = 0;
  bool _checkingServices = false;
  String? _pendingScanProblem;

  BeaconContentService? _service;
  BeaconContentController? _contentController;

  bool _ownsService = false;
  VisitLogService? _visitService;
  bool _ownsVisitService = false;
  VisitorApi? _visitorApi;
  SiteApi? _siteApi;
  bool _ownsVisitorApi = false;
  BeaconContent? _scheduledVisitContent;
  String? _configurationError;
  Beacon? _selectedBeacon;

  List<Beacon> _beacons = [];

  String _status = 'Chưa bắt đầu quét';
  bool _scanning = false;
  bool _busy = false;

  String? _lastNotifiedBeaconKey;
  String? _candidateBeaconKey;

  int _candidateHits = 0;
  int _notificationCount = 0;
  int _suppressedCount = 0;

  String _notificationStatus = 'Chưa nhận beacon để thông báo';

  static const int _requiredCandidateHits = 3;
  static const int _keepBeaconMilliseconds = 10000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanner = widget.scanner ?? BeaconScanner();

    try {
      final service =
          widget.contentService ??
          BeaconContentService(baseUrl: ApiConfig.baseUrl);

      _service = service;
      _ownsService = widget.contentService == null;

      _visitService =
          widget.visitLogService ??
          (widget.contentService == null
              ? VisitLogService(baseUrl: ApiConfig.baseUrl)
              : null);
      _ownsVisitService =
          widget.visitLogService == null && _visitService != null;

      _contentController = BeaconContentController(
        visitLogService: _visitService,
        clock: widget.clock,
        service: service,
        readToken: () => widget.readToken?.call(),
      );
      _visitorApi = widget.visitorApi;
      _siteApi = widget.siteApi;
      if (widget.visitorApi case final SiteApi injectedSiteApi) {
        _siteApi ??= injectedSiteApi;
      }
      if (_visitorApi == null && widget.contentService == null) {
        final api = HttpVisitorApi(baseUrl: ApiConfig.baseUrl);
        _visitorApi = api;
        _siteApi ??= api;
        _ownsVisitorApi = true;
      }
    } on StateError catch (error) {
      _configurationError = error.message.toString();
    }
  }

  @override
  void didUpdateWidget(covariant BeaconTestPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    final selected = _selectedBeacon;

    if (oldWidget.languageCode != widget.languageCode && selected != null) {
      _requestContent(selected);
    }
  }

  void _requestContent(Beacon beacon) {
    _contentController?.receiveBeacon(
      proximityUuid: beacon.proximityUUID,
      major: beacon.major,
      minor: beacon.minor,
      languageCode: widget.languageCode,
    );
  }

  String _beaconKey(Beacon beacon) {
    return '${beacon.proximityUUID.toLowerCase()}:'
        '${beacon.major}:${beacon.minor}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _scanning &&
        !_busy &&
        widget.beaconStream == null) {
      unawaited(_checkServicesOnResume(_scanEpoch));
    }
  }

  Future<void> _checkServicesOnResume(int epoch) async {
    if (_checkingServices) return;
    _checkingServices = true;
    try {
      await _scanner.checkReady();
    } catch (error) {
      if (_isCurrentScan(epoch)) {
        await _stopScanning(message: _scanError(error), clearReadings: true);
      }
    } finally {
      _checkingServices = false;
    }
  }

  bool _isCurrentScan(int epoch) => mounted && _scanning && epoch == _scanEpoch;

  void _interruptScan(String message) {
    if (_busy) {
      _pendingScanProblem = message;
    } else {
      unawaited(_stopScanning(message: message, clearReadings: true));
    }
  }

  String _scanError(Object error) => error is BeaconScanException
      ? error.message
      : 'Không thể quét BLE. Kiểm tra Bluetooth, Vị trí và quyền ứng dụng rồi thử lại.';

  void _cancelExpiryTimers() {
    _rawExpiryTimer?.cancel();
    _rawExpiryTimer = null;
    _selectionExpiryTimer?.cancel();
    _selectionExpiryTimer = null;
  }

  void _armSelectionExpiry() {
    _selectionExpiryTimer?.cancel();
    final epoch = _scanEpoch;
    _selectionExpiryTimer = Timer(
      const Duration(milliseconds: _keepBeaconMilliseconds),
      () {
        if (!_isCurrentScan(epoch)) return;
        _selectedBeacon = null;
        _lastNotifiedBeaconKey = null;
        _candidateBeaconKey = null;
        _candidateHits = 0;
        _contentController?.reset();
        setState(() {
          _notificationStatus =
              'Đã mất tín hiệu beacon đang chọn. Chờ nhận lại.';
        });
      },
    );
  }

  void _updateBeaconDisplay(List<Beacon> detectedBeacons) {
    if (!mounted || !_scanning) return;

    if (detectedBeacons.isNotEmpty) {
      _rawExpiryTimer?.cancel();
      final epoch = _scanEpoch;
      _rawExpiryTimer = Timer(
        const Duration(milliseconds: _keepBeaconMilliseconds),
        () {
          if (!_isCurrentScan(epoch)) return;
          setState(() {
            _beacons = [];
            _status = 'Đang quét — chưa phát hiện iBeacon';
          });
        },
      );
    }
    if (detectedBeacons.any(
      (b) => b.rssi < 0 && _beaconKey(b) == _lastNotifiedBeaconKey,
    )) {
      _armSelectionExpiry();
    }

    setState(() {
      if (detectedBeacons.isNotEmpty) {
        _beacons = List<Beacon>.of(detectedBeacons);
        _status = 'Phát hiện ${_beacons.length} beacon';
      } else {
        _status = _beacons.isNotEmpty
            ? 'Tạm chưa nhận tín hiệu — đang giữ dữ liệu lần nhận cuối'
            : 'Đang quét — chưa phát hiện iBeacon';
      }
    });
  }

  void _handleBeaconDetection(List<Beacon> detectedBeacons) {
    if (!mounted || !_scanning) return;

    final candidates = detectedBeacons
        .where((beacon) => beacon.rssi < 0)
        .toList();

    if (candidates.isEmpty) {
      _candidateBeaconKey = null;
      _candidateHits = 0;
      return;
    }

    candidates.sort((a, b) {
      final signalOrder = b.rssi.compareTo(a.rssi);

      if (signalOrder != 0) return signalOrder;

      return _beaconKey(a).compareTo(_beaconKey(b));
    });

    final selected = candidates.first;
    final selectedKey = _beaconKey(selected);

    if (selectedKey == _lastNotifiedBeaconKey) {
      _candidateBeaconKey = null;
      _candidateHits = 0;

      setState(() {
        _suppressedCount++;
        _notificationStatus =
            'Vẫn ở beacon Major ${selected.major}, '
            'Minor ${selected.minor} — không báo lại';
      });

      return;
    }

    if (_lastNotifiedBeaconKey != null) {
      if (_candidateBeaconKey == selectedKey) {
        _candidateHits++;
      } else {
        _candidateBeaconKey = selectedKey;
        _candidateHits = 1;
      }

      if (_candidateHits < _requiredCandidateHits) {
        setState(() {
          _notificationStatus =
              'Đang xác nhận chuyển beacon '
              '($_candidateHits/$_requiredCandidateHits)';
        });

        return;
      }
    }

    _candidateBeaconKey = null;
    _candidateHits = 0;

    setState(() {
      _lastNotifiedBeaconKey = selectedKey;
      _notificationCount++;
      _notificationStatus =
          'Beacon mới: Major ${selected.major}, Minor ${selected.minor}';
    });

    _selectedBeacon = selected;
    _armSelectionExpiry();
    _requestContent(selected);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Phát hiện beacon mới\n'
          'UUID: ${selected.proximityUUID}\n'
          'Major: ${selected.major} — Minor: ${selected.minor}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    debugPrint(
      'BEACON_CHANGED: $selectedKey, '
      'notifications: $_notificationCount',
    );
  }

  bool get isBusy => _busy;

  Future<bool> stopScanningIfNeeded() async {
    if (_scanning ||
        _subscription != null ||
        _bluetoothSubscription != null ||
        _authorizationSubscription != null) {
      return _stopScanning();
    }

    return true;
  }

  void _setStatus(String message) {
    if (!mounted) return;
    setState(() => _status = message);
  }

  Future<void> _startScanning() async {
    if (_busy || _scanning) return;

    setState(() => _busy = true);
    _pendingScanProblem = null;

    try {
      await _cancelSubscriptions();
      if (!mounted) return;
      final Stream<List<Beacon>> detections;
      final testStream = widget.beaconStream;

      if (testStream != null) {
        detections = testStream;
      } else {
        _setStatus('Đang kiểm tra quyền và dịch vụ...');

        await _scanner.prepare();
        if (!mounted) return;
        detections = _scanner.detections;
      }

      if (!mounted) return;

      _cancelExpiryTimers();
      _contentController?.reset();
      _selectedBeacon = null;
      final epoch = ++_scanEpoch;

      setState(() {
        _beacons = [];

        _lastNotifiedBeaconKey = null;
        _candidateBeaconKey = null;
        _candidateHits = 0;

        _notificationCount = 0;
        _suppressedCount = 0;
        _notificationStatus = 'Chưa nhận beacon để thông báo';

        _scanning = true;
        _status = 'Đang quét — chờ tín hiệu iBeacon';
      });

      _subscription = detections.listen(
        (beacons) {
          if (!_isCurrentScan(epoch)) return;

          debugPrint('RANGING: ${beacons.length} beacon');

          _updateBeaconDisplay(beacons);
          _handleBeaconDetection(beacons);
        },
        onError: (Object error) {
          if (_isCurrentScan(epoch)) {
            _interruptScan(_scanError(error));
          }
        },
        onDone: () {
          if (_isCurrentScan(epoch)) {
            _interruptScan('Luồng quét đã kết thúc');
          }
        },
      );
      if (testStream == null) {
        _bluetoothSubscription = _scanner.bluetoothChanges.listen(
          (state) {
            if (_isCurrentScan(epoch) && state != BluetoothState.stateOn) {
              _interruptScan(BeaconScanner.bluetoothProblem(state));
            }
          },
          onError: (Object error) {
            if (_isCurrentScan(epoch)) {
              _interruptScan(_scanError(error));
            }
          },
        );
        _authorizationSubscription = _scanner.authorizationChanges.listen(
          (state) {
            if (_isCurrentScan(epoch) && !BeaconScanner.isAuthorized(state)) {
              _interruptScan(
                'Quyền quét đã bị thu hồi. Hãy kiểm tra Cài đặt ứng dụng.',
              );
            }
          },
          onError: (Object error) {
            if (_isCurrentScan(epoch)) {
              _interruptScan(_scanError(error));
            }
          },
        );
        await _scanner.checkReady();
      }
    } catch (error) {
      if (!mounted) return;
      _cancelExpiryTimers();
      _scanEpoch++;
      _contentController?.reset();
      _selectedBeacon = null;
      _scanning = false;
      try {
        await _cancelSubscriptions();
      } catch (cancelError) {
        debugPrint('BLE cancellation failed: $cancelError');
      }
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _status = _scanError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        final problem = _pendingScanProblem;
        _pendingScanProblem = null;
        if (_scanning && problem != null) _interruptScan(problem);
      }
    }
  }

  Future<void> _cancelSubscriptions() async {
    // Clear handles only after cancellation succeeds, allowing an explicit retry.
    await _subscription?.cancel();
    _subscription = null;
    await _bluetoothSubscription?.cancel();
    _bluetoothSubscription = null;
    await _authorizationSubscription?.cancel();
    _authorizationSubscription = null;
  }

  Future<bool> _stopScanning({
    String? message,
    bool clearReadings = false,
  }) async {
    if (_busy) return false;
    if (!_scanning &&
        _subscription == null &&
        _bluetoothSubscription == null &&
        _authorizationSubscription == null) {
      return true;
    }

    setState(() {
      _busy = true;
      _scanning = false;
    });

    _scanEpoch++;
    _cancelExpiryTimers();
    _contentController?.reset();
    _selectedBeacon = null;
    _lastNotifiedBeaconKey = null;
    _candidateBeaconKey = null;
    _candidateHits = 0;

    try {
      await _cancelSubscriptions();

      if (!mounted) return false;

      setState(() {
        if (clearReadings) _beacons = [];
        _status =
            message ??
            (_beacons.isEmpty
                ? 'Đã dừng quét'
                : 'Đã dừng quét — hiển thị dữ liệu lần nhận cuối');
      });

      return true;
    } catch (error) {
      _setStatus('Không thể dừng quét: $error');
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _distanceText(double distance) {
    if (!distance.isFinite || distance < 0) {
      return 'Chưa xác định';
    }

    return '${distance.toStringAsFixed(2)} m';
  }

  bool _sameBearerSession(AuthToken? current, AuthToken resolvedWith) =>
      current != null &&
      current.accessToken.trim().isNotEmpty &&
      current.accessToken == resolvedWith.accessToken &&
      current.tokenType.trim().toLowerCase() == 'bearer' &&
      resolvedWith.tokenType.trim().toLowerCase() == 'bearer';

  bool _isVisibleResolvedContent(
    BeaconContent content,
    AuthToken resolvedWith,
  ) {
    final controller = _contentController;
    return mounted &&
        widget.isActive &&
        identical(controller?.content, content) &&
        identical(controller?.contentToken, resolvedWith) &&
        controller?.isLoading == false &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        _sameBearerSession(widget.readToken?.call(), resolvedWith);
  }

  void _openArtifact(BeaconContent content) {
    final resolvedToken = _contentController?.contentToken;
    if (resolvedToken == null ||
        !_isVisibleResolvedContent(content, resolvedToken)) {
      return;
    }
    final artifact = Artifact(
      id: content.artifactId,
      titleVi: content.title ?? content.code,
      titleEn: content.title ?? content.code,
      period: '',
      category: '',
      location: '',
      descriptionVi: content.description ?? '',
      descriptionEn: content.description ?? '',
      imageUrl: content.coverImageUrl ?? '',
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ArtifactDetailPage(artifact: artifact, visitorApi: _visitorApi),
      ),
    );
  }

  Future<void> _openSite(BeaconContent content) async {
    final api = _siteApi;
    final strings = AppStrings.of(context);
    final resolvedToken = _contentController?.contentToken;
    final languageCode = strings.locale.languageCode;
    if (api == null || resolvedToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.isEnglish
                ? 'Site details are unavailable right now.'
                : 'Chưa thể mở thông tin địa điểm lúc này.',
          ),
        ),
      );
      return;
    }
    try {
      final site = await api.loadSite(
        siteId: content.siteId,
        languageCode: languageCode,
      );
      if (!mounted ||
          AppStrings.of(context).locale.languageCode != languageCode ||
          !_isVisibleResolvedContent(content, resolvedToken)) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SiteDetailPage(site: site, siteApi: api),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.isEnglish
                ? 'Could not load site details. Please try again.'
                : 'Không tải được thông tin địa điểm. Vui lòng thử lại.',
          ),
        ),
      );
    }
  }

  Widget _buildBackendContent() {
    final controller = _contentController;
    final strings = AppStrings.of(context);
    final isEnglish = strings.isEnglish;

    if (controller == null) {
      return Text(
        _configurationError ?? 'Chưa thể kết nối dịch vụ nội dung.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final content = controller.content;
        final error = controller.errorMessage;
        final contentToken = controller.contentToken;
        if (content != null &&
            contentToken != null &&
            !controller.isLoading &&
            widget.isActive &&
            !identical(_scheduledVisitContent, content)) {
          _scheduledVisitContent = content;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isVisibleResolvedContent(content, contentToken)) {
              if (identical(_scheduledVisitContent, content)) {
                _scheduledVisitContent = null;
              }
              return;
            }
            // Controller -> VisitLogService is the sole real-scan POST path.
            unawaited(
              controller.recordDisplayedContent(
                content,
                rssi: _selectedBeacon?.rssi,
              ),
            );
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.isLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                isEnglish ? 'Waiting for content…' : 'Đang chờ tải nội dung…',
              ),
            ] else if (error != null) ...[
              Text(
                controller.errorStatusCode == 401
                    ? strings.beaconSignInRequired
                    : strings.beaconContentLoadError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: controller.retry,
                  child: Text(isEnglish ? 'Retry' : 'Thử lại'),
                ),
              ),
            ] else if (content != null) ...[
              Text(
                content.title ?? content.code,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                isEnglish
                    ? 'Artifact code: ${content.code}'
                    : 'Mã hiện vật: ${content.code}',
              ),
              if (content.languageCode != null)
                Text(
                  isEnglish
                      ? 'Language: ${content.languageCode}'
                      : 'Ngôn ngữ: ${content.languageCode}',
                ),
              if (content.isFallback)
                Text(
                  isEnglish
                      ? 'Showing fallback language.'
                      : 'Đang hiển thị ngôn ngữ dự phòng.',
                ),
              if (content.description?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                SelectableText(content.description!),
              ],
              if (content.historyContent?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                SelectableText(content.historyContent!),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openArtifact(content),
                    icon: const Icon(Icons.museum_outlined),
                    label: Text(
                      isEnglish
                          ? 'Open artifact details'
                          : 'Xem chi tiết hiện vật',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openSite(content),
                    icon: const Icon(Icons.place_outlined),
                    label: Text(
                      isEnglish ? 'Open heritage site' : 'Xem địa điểm di sản',
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                isEnglish
                    ? 'No content is available from the backend.'
                    : 'Chưa có nội dung từ backend.',
              ),
            if (controller.visitError != null &&
                controller.visitErrorIsForCurrentContent) ...[
              const SizedBox(height: 8),
              Text(
                strings.visitorApiError(controller.visitErrorStatusCode),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: content == null
                    ? null
                    : () =>
                          controller.retryVisitLog(rssi: _selectedBeacon?.rssi),
                child: Text(
                  isEnglish
                      ? 'Retry saving visit history'
                      : 'Thử lưu lịch sử lại',
                ),
              ),
            ] else if (controller.isSavingVisit)
              Text(
                isEnglish
                    ? 'Saving visit history…'
                    : 'Đang lưu lịch sử tham quan…',
              )
            else if (controller.visitResult != null &&
                controller.visitResultIsForCurrentContent)
              Text(
                controller.visitResult!.alreadyRecorded
                    ? (isEnglish
                          ? 'This visit is already in your recent history.'
                          : 'Lượt xem đã có trong lịch sử gần đây.')
                    : (isEnglish
                          ? 'Visit saved to your history.'
                          : 'Đã lưu vào lịch sử tham quan.'),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanEpoch++;
    _cancelExpiryTimers();
    unawaited(_subscription?.cancel());
    unawaited(_bluetoothSubscription?.cancel());
    unawaited(_authorizationSubscription?.cancel());
    _contentController?.dispose();
    if (_ownsVisitService) _visitService?.close();
    if (_ownsVisitorApi && _visitorApi is HttpVisitorApi) {
      (_visitorApi as HttpVisitorApi).close();
    }

    if (_ownsService) {
      _service?.close();
    }

    super.dispose();
  }

  String _localizedStatus(bool isEnglish) {
    if (!isEnglish) return _status;
    if (_status == 'Chưa bắt đầu quét') return 'Ready to scan';
    if (_status == 'Đang kiểm tra quyền và dịch vụ...') {
      return 'Checking permissions and services…';
    }
    if (_status == 'Đang quét — chưa phát hiện iBeacon') {
      return 'Scanning — no iBeacon detected yet';
    }
    if (_status == 'Đang quét — chờ tín hiệu iBeacon') {
      return 'Scanning — waiting for an iBeacon signal';
    }
    if (_status.startsWith('Phát hiện ')) {
      return 'Found ${_beacons.length} beacon(s)';
    }
    if (_status.startsWith('Chưa được cấp quyền')) {
      return 'Beacon scanning permission is unavailable. Check app settings.';
    }
    if (_status.startsWith('Bluetooth')) {
      return 'Bluetooth is unavailable. Turn it on and try again.';
    }
    if (_status.startsWith('Vị trí đang tắt')) {
      return 'Location services are off. Turn them on and try again.';
    }
    if (_status.startsWith('Quét BLE cần thiết bị')) {
      return 'BLE scanning requires an Android or iOS device.';
    }
    if (_status.startsWith('Luồng quét đã kết thúc')) {
      return 'The scan stream has ended.';
    }
    if (_status.startsWith('Đã dừng quét')) {
      return 'Scanning stopped';
    }
    if (_status.startsWith('Không thể') || _status.startsWith('Lỗi')) {
      return 'Scanning failed. Check Bluetooth and app permissions.';
    }
    if (_status.startsWith('Tạm chưa nhận tín hiệu')) {
      return 'Signal temporarily unavailable — keeping the last readings';
    }
    return _status;
  }

  String _localizedNotification(bool isEnglish) {
    if (!isEnglish) return _notificationStatus;
    if (_notificationStatus == 'Chưa nhận beacon để thông báo') {
      return 'No beacon notification yet';
    }
    if (_notificationStatus.contains('không báo lại')) {
      return 'Still at the selected beacon — repeat notification suppressed';
    }
    if (_notificationStatus.startsWith('Đang xác nhận chuyển beacon')) {
      return 'Confirming beacon change ($_candidateHits/$_requiredCandidateHits)';
    }
    if (_notificationStatus.startsWith('Beacon mới:')) {
      return 'New beacon detected';
    }
    if (_notificationStatus.startsWith('Đã mất tín hiệu')) {
      return 'The selected Beacon signal was lost. Waiting to detect it again.';
    }
    return _notificationStatus;
  }

  Widget _buildScanStatusCard(String status, ThemeData theme) {
    final hasError =
        status.contains('failed') ||
        status.contains('Bluetooth đang tắt') ||
        status.contains('permission') ||
        status.contains('quyền');
    final accent = hasError
        ? theme.colorScheme.error
        : HeritagePalette.actionBlue;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            _scanning ? Icons.bluetooth_searching : Icons.bluetooth,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _scanning
                      ? (AppStrings.of(context).isEnglish
                            ? 'Scanning nearby'
                            : 'Đang quét xung quanh')
                      : (AppStrings.of(context).isEnglish
                            ? 'Ready to explore'
                            : 'Sẵn sàng khám phá'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalCard(bool isEnglish, ThemeData theme) => Container(
    padding: const EdgeInsets.all(AppSpacing.medium),
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      border: Border.all(color: HeritagePalette.border),
    ),
    child: Row(
      children: [
        Icon(
          _beacons.isEmpty ? Icons.sensors_off : Icons.sensors,
          color: HeritagePalette.actionBlue,
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Text(
            _beacons.isEmpty
                ? (isEnglish
                      ? 'Bring your phone near an active Beacon to discover heritage content.'
                      : 'Đưa điện thoại lại gần Beacon đang hoạt động để khám phá nội dung di sản.')
                : (isEnglish
                      ? 'Beacon detected. Looking up its heritage content…'
                      : 'Đã phát hiện Beacon. Đang tìm nội dung di sản…'),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isEnglish = strings.isEnglish;
    final theme = Theme.of(context);
    final status = _localizedStatus(isEnglish);
    final notification = _localizedNotification(isEnglish);
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: Text(isEnglish ? 'Beacon Guide' : 'Thuyết minh Beacon'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.large),
                      decoration: BoxDecoration(
                        color: HeritagePalette.primaryNavy,
                        borderRadius: BorderRadius.circular(AppRadii.large),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.headphones_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: AppSpacing.medium),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEnglish
                                      ? 'Discover nearby heritage'
                                      : 'Khám phá di sản quanh bạn',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isEnglish
                                      ? 'Your guide starts when this phone detects a supported Beacon.'
                                      : 'Thuyết minh bắt đầu khi điện thoại phát hiện Beacon được hỗ trợ.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    _buildScanStatusCard(status, theme),
                    const SizedBox(height: AppSpacing.medium),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: HeritagePalette.primaryNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                          ),
                        ),
                        onPressed: _busy
                            ? null
                            : _scanning
                            ? _stopScanning
                            : _startScanning,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _scanning
                                    ? Icons.bluetooth_disabled
                                    : Icons.bluetooth_searching,
                              ),
                        label: Text(
                          _busy
                              ? (isEnglish ? 'Please wait…' : 'Vui lòng chờ…')
                              : _scanning
                              ? (isEnglish ? 'Stop scanning' : 'Dừng quét')
                              : (isEnglish ? 'Start scanning' : 'Bắt đầu quét'),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    _buildSignalCard(isEnglish, theme),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isEnglish ? 'Heritage guide' : 'Nội dung thuyết minh',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildBackendContent(),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ExpansionTile(
                title: Text(
                  isEnglish ? 'Technical details' : 'Thông tin kỹ thuật',
                ),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Text(notification),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isEnglish
                          ? 'New notifications: $_notificationCount · suppressed repeats: $_suppressedCount'
                          : 'Lần báo mới: $_notificationCount · lần lặp đã chặn: $_suppressedCount',
                    ),
                  ),
                ],
              ),
            ),
            if (_beacons.isNotEmpty)
              SliverList.builder(
                itemCount: _beacons.length,
                itemBuilder: (context, index) {
                  final beacon = _beacons[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text('Major ${beacon.major}')),
                              Chip(label: Text('Minor ${beacon.minor}')),
                              Chip(label: Text('RSSI ${beacon.rssi} dBm')),
                              Chip(
                                label: Text(
                                  '${isEnglish ? 'Distance' : 'Khoảng cách'}: '
                                  '${_distanceText(beacon.accuracy)}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('UUID'),
                          SelectableText(beacon.proximityUUID),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
