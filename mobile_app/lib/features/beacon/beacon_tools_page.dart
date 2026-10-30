import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';

import '../../beacon_simulation_page.dart';
import '../../shared/config/api_config.dart';
import '../artifacts/artifact.dart';
import '../auth/auth_service.dart';
import '../auth/auth_session.dart';
import 'beacon_content_controller.dart';
import 'beacon_content_service.dart';

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
            readToken: readToken,
            languageCode: languageCode,
          ),
          BeaconSimulationPage(
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
    @visibleForTesting this.contentService,
    @visibleForTesting this.beaconStream,
  });

  final AuthToken? Function()? readToken;
  final String languageCode;

  final BeaconContentService? contentService;
  final Stream<List<Beacon>>? beaconStream;

  @override
  State<BeaconTestPage> createState() => BeaconTestPageState();
}

class BeaconTestPageState extends State<BeaconTestPage> {
  StreamSubscription<List<Beacon>>? _subscription;

  BeaconContentService? _service;
  BeaconContentController? _contentController;

  bool _ownsService = false;
  String? _configurationError;
  Beacon? _selectedBeacon;

  List<Beacon> _beacons = [];
  DateTime? _lastBeaconSeenAt;

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

    try {
      final service =
          widget.contentService ??
          BeaconContentService(baseUrl: ApiConfig.baseUrl);

      _service = service;
      _ownsService = widget.contentService == null;

      _contentController = BeaconContentController(
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

  void _updateBeaconDisplay(List<Beacon> detectedBeacons) {
    if (!mounted || !_scanning) return;

    setState(() {
      final now = DateTime.now();

      if (detectedBeacons.isNotEmpty) {
        _beacons = List<Beacon>.of(detectedBeacons);
        _lastBeaconSeenAt = now;
        _status = 'Phát hiện ${_beacons.length} beacon';
        return;
      }

      final lastSeen = _lastBeaconSeenAt;
      final keepPreviousData =
          lastSeen != null &&
          now.difference(lastSeen).inMilliseconds < _keepBeaconMilliseconds;

      if (_beacons.isNotEmpty && keepPreviousData) {
        _status = 'Tạm chưa nhận tín hiệu — đang giữ dữ liệu lần nhận cuối';
      } else {
        _beacons = [];
        _status = 'Đang quét — chưa phát hiện iBeacon';
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
    if (_scanning || _subscription != null) {
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

    try {
      final Stream<List<Beacon>> detections;
      final testStream = widget.beaconStream;

      if (testStream != null) {
        detections = testStream;
      } else {
        _setStatus('Đang kiểm tra quyền và dịch vụ...');

        final initialized = await flutterBeacon.initializeAndCheckScanning;
        if (!mounted) return;

        if (!initialized) {
          _setStatus('Chưa thể quét. Kiểm tra quyền Bluetooth và vị trí.');
          return;
        }

        final locationEnabled =
            await flutterBeacon.checkLocationServicesIfEnabled;
        if (!mounted) return;

        if (!locationEnabled) {
          _setStatus('Hãy bật vị trí rồi quay lại bấm Bắt đầu quét.');
          await flutterBeacon.openLocationSettings;
          return;
        }

        final regions = [Region(identifier: 'all-beacons')];

        detections = flutterBeacon
            .ranging(regions)
            .map((result) => result.beacons);
      }

      await _subscription?.cancel();
      _subscription = null;

      if (!mounted) return;

      _contentController?.reset();
      _selectedBeacon = null;

      setState(() {
        _beacons = [];
        _lastBeaconSeenAt = null;

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
          if (!mounted || !_scanning) return;

          debugPrint('RANGING: ${beacons.length} beacon');

          _updateBeaconDisplay(beacons);
          _handleBeaconDetection(beacons);
        },
        onError: (Object error) {
          if (!mounted) return;

          _contentController?.reset();
          _selectedBeacon = null;

          setState(() {
            _scanning = false;
            _status = 'Lỗi quét: $error';
          });

          unawaited(_subscription?.cancel());
        },
        onDone: () {
          if (!mounted) return;

          _contentController?.reset();
          _selectedBeacon = null;

          setState(() {
            _scanning = false;
            _status = 'Luồng quét đã kết thúc';
          });
        },
      );
    } catch (error) {
      if (!mounted) return;

      _contentController?.reset();
      _selectedBeacon = null;

      setState(() {
        _scanning = false;
        _status = 'Không thể bắt đầu quét: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _stopScanning() async {
    if (_busy) return false;
    if (!_scanning && _subscription == null) return true;

    setState(() {
      _busy = true;
      _scanning = false;
    });

    _contentController?.reset();
    _selectedBeacon = null;

    try {
      await _subscription?.cancel();
      _subscription = null;

      if (!mounted) return false;

      setState(() {
        _status = _beacons.isEmpty
            ? 'Đã dừng quét'
            : 'Đã dừng quét — hiển thị dữ liệu lần nhận cuối';
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

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final content = controller.content;
        final error = controller.errorMessage;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Số lần gọi API trong phiên: ${controller.requestCount}'),
            const SizedBox(height: 12),
            if (controller.isLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Đang chờ tải nội dung...'),
            ] else if (error != null) ...[
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: controller.retry,
                  child: const Text('Thử lại'),
                ),
              ),
            ] else if (content != null) ...[
              Text(
                content.title ?? content.code,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Mã hiện vật: ${content.code}'),
              if (content.languageCode != null)
                Text('Ngôn ngữ: ${content.languageCode}'),
              if (content.isFallback)
                const Text('Đang hiển thị ngôn ngữ dự phòng.'),
              if (content.description?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                SelectableText(content.description!),
              ],
              if (content.historyContent?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                SelectableText(content.historyContent!),
              ],
            ] else
              const Text('Chưa có nội dung từ backend.'),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _contentController?.dispose();

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
