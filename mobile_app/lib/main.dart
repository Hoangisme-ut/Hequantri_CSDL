import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';

import 'beacon_simulation_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

ThemeData _buildAppTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blueGrey.shade900,
      secondary: Colors.amber.shade700,
      tertiary: Colors.teal,
      brightness: brightness,
    ),
    useMaterial3: true,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, @visibleForTesting this.appShell});

  final AppShell? appShell;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Heritage',
      theme: _buildAppTheme(Brightness.light),
      darkTheme: _buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: appShell ?? const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, @visibleForTesting this.stopScanning});

  final Future<bool> Function()? stopScanning;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _beaconScanPageKey = GlobalKey<BeaconTestPageState>();
  int _selectedIndex = 0;

  Future<void> _selectDestination(int index) async {
    if (index == _selectedIndex) return;

    if (index == 1) {
      final scanPageState = _beaconScanPageKey.currentState;
      if (scanPageState == null || scanPageState.isBusy) return;

      final stopped = widget.stopScanning == null
          ? await scanPageState.stopScanningIfNeeded()
          : await widget.stopScanning!();
      if (!stopped || !mounted) return;
    }

    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          BeaconTestPage(key: _beaconScanPageKey),
          const BeaconSimulationPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            label: 'Quét iBeacon',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            label: 'Mô phỏng',
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
  String _status = 'Chưa bắt đầu quét';
  bool _scanning = false;
  bool _busy = false;

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

      // Android: nhận tất cả iBeacon, chưa lọc theo UUID.
      final regions = [Region(identifier: 'all-beacons')];

      await _subscription?.cancel();
      if (!mounted) return;

      setState(() {
        _beacons = [];
        _scanning = true;
        _status = 'Đang quét — chờ tín hiệu iBeacon';
      });

      _subscription = flutterBeacon
          .ranging(regions)
          .listen(
            (result) {
              if (!mounted) return;

              setState(() {
                _beacons = result.beacons;
                _status = _beacons.isEmpty
                    ? 'Đang quét — chưa phát hiện iBeacon'
                    : 'Phát hiện ${_beacons.length} beacon';
              });

              for (final beacon in result.beacons) {
                debugPrint(
                  'UUID: ${beacon.proximityUUID}, '
                  'Major: ${beacon.major}, '
                  'Minor: ${beacon.minor}, '
                  'RSSI: ${beacon.rssi}, '
                  'Estimated distance: ${beacon.accuracy} m',
                );
              }
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
    setState(() => _busy = true);

    try {
      await _subscription?.cancel();
      _subscription = null;

      if (!mounted) return false;

      setState(() {
        _scanning = false;
        _status = 'Đã dừng quét';
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
