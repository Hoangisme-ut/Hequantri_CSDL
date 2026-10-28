import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Dùng import tương đối để test luôn tìm thấy Widget
import 'beacon_simulation_page.dart';
import 'features/artifacts/artifact.dart';
import 'features/auth/auth_config.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/home/main_navigation_scaffold.dart';
import 'features/welcome/welcome_page.dart';
import 'l10n/app_strings.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, @visibleForTesting this.appShell});

  final AppShell? appShell;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  Locale _locale = const Locale('vi');

  void _changeLocale(Locale locale) => setState(() => _locale = locale);

  void _enterMainApp() {
    _navigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => MainNavigationScaffold(
          onLocaleChanged: _changeLocale,
          onLogout: () {
            _navigatorKey.currentState!.pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => LoginPage(
                  onDemoContinue: _enterMainApp,
                  onLoginSuccess: _enterMainApp,
                  authService: AuthService(
                    baseUrl: AuthConfig.apiBaseUrl,
                    client: IoAuthHttpClient(),
                  ),
                ),
              ),
              (_) => false,
            );
          },
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Heritage',
      navigatorKey: _navigatorKey,
      locale: _locale,
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home:
          widget.appShell ??
          WelcomePage(
            onLocaleChanged: _changeLocale,
            onDemoContinue: _enterMainApp,
          ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.catalog,
    this.onLocaleChanged,
    this.isDemoSession = false,
    this.stopScanning,
  });

  final ArtifactCatalog? catalog;
  final ValueChanged<Locale>? onLocaleChanged;
  final Future<bool> Function()? stopScanning;
  final bool isDemoSession;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  Future<void> _onDestinationSelected(int index) async {
    if (index == _selectedIndex) return;

    if (widget.stopScanning != null) {
      final canSwitch = await widget.stopScanning!();
      if (!canSwitch) return;
    }

    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [BeaconTestPage(), BeaconSimulationPage()],
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
  const BeaconTestPage({super.key});

  @override
  State<BeaconTestPage> createState() => BeaconTestPageState();
}

class BeaconTestPageState extends State<BeaconTestPage> {
  StreamSubscription<RangingResult>? _subscription;

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

      await _subscription?.cancel();
      _subscription = null;

      if (!mounted) return;

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

      _subscription = flutterBeacon
          .ranging(regions)
          .listen(
            (result) {
              if (!mounted || !_scanning) return;
              debugPrint('RANGING: ${result.beacons.length} beacon');

              _updateBeaconDisplay(result.beacons);
              _handleBeaconDetection(result.beacons);
            },
            onError: (Object error) {
              if (!mounted) return;

              setState(() {
                _scanning = false;
                _status = 'Lỗi quét: $error';
              });

              unawaited(_subscription?.cancel());
            },
            onDone: () {
              if (!mounted) return;

              setState(() {
                _scanning = false;
                _status = 'Luồng quét đã kết thúc';
              });
            },
          );
    } catch (error) {
      if (!mounted) return;

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

    setState(() => _busy = true);

    try {
      await _subscription?.cancel();
      _subscription = null;

      if (!mounted) return false;
      await flutterBeacon.setScanPeriod(1000);
      await flutterBeacon.setBetweenScanPeriod(500);

      if (!mounted) return false;

      setState(() {
        _scanning = false;
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

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét iBeacon')),
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
