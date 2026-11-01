import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';

import '../../beacon_simulation_page.dart';
import '../../shared/config/api_config.dart';
import '../artifacts/artifact.dart';
import '../auth/auth_service.dart';
import '../auth/auth_session.dart';
import '../visits/visit_log_service.dart';
import 'beacon_content_panel.dart';
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
  });

  final ArtifactCatalog? catalog;
  final ValueChanged<Locale>? onLocaleChanged;
  final Future<bool> Function()? stopScanning;
  final AuthToken? Function()? readToken;
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

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          BeaconTestPage(
            key: _scanPageKey,
            isActive: _selectedIndex == 0,
            readToken: readToken,
            languageCode: languageCode,
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            label: 'Quét iBeacon',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            label: 'Giả lập',
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
    @visibleForTesting this.contentService,
    @visibleForTesting this.beaconStream,
    @visibleForTesting this.scanner,
  });

  final AuthToken? Function()? readToken;
  final String languageCode;
  final bool isActive;
  final VisitLogService? visitLogService;

  final BeaconContentService? contentService;
  final Stream<List<Beacon>>? beaconStream;
  final BeaconScanner? scanner;

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
        service: service,
        readToken: () => widget.readToken?.call(),
      );
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

  Widget _buildBackendContent() {
    final controller = _contentController;

    if (controller == null) {
      return Text(
        _configurationError ?? 'Chưa thể kết nối dịch vụ nội dung.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    return BeaconContentPanel(
      controller: controller,
      isActive: widget.isActive,
      rssi: _selectedBeacon?.rssi,
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

    if (_ownsService) {
      _service?.close();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        title: const Text('Quét iBeacon'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_status),
                    const SizedBox(height: 8),
                    Text(_notificationStatus),
                    const SizedBox(height: 8),
                    Text('Số lần báo mới: $_notificationCount'),
                    Text('Số lần quét lặp đã chặn: $_suppressedCount'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _busy || _scanning ? null : _startScanning,
                          child: const Text('Bắt đầu quét'),
                        ),
                        OutlinedButton(
                          onPressed: _busy || !_scanning ? null : _stopScanning,
                          child: const Text('Dừng quét'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Khoảng cách chỉ là ước lượng từ tín hiệu Bluetooth.',
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Khi tạm mất tín hiệu, dữ liệu lần nhận cuối '
                      'được giữ khoảng 10 giây.',
                    ),
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
                        'Nội dung từ backend',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildBackendContent(),
                    ],
                  ),
                ),
              ),
            ),
            if (_beacons.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Chưa có dữ liệu beacon')),
              )
            else
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
                      child: SelectableText(
                        'UUID: ${beacon.proximityUUID}\n'
                        'Major: ${beacon.major}\n'
                        'Minor: ${beacon.minor}\n'
                        'RSSI: ${beacon.rssi} dBm\n'
                        'Khoảng cách ước lượng: '
                        '${_distanceText(beacon.accuracy)}',
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
