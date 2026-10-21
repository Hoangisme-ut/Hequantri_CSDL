import 'dart:async';

import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/material.dart';

import 'beacon_simulation_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Beacon Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BeaconTestPage(),
    );
  }
}

class BeaconTestPage extends StatefulWidget {
  const BeaconTestPage({super.key});

  @override
  State<BeaconTestPage> createState() => _BeaconTestPageState();
}

class _BeaconTestPageState extends State<BeaconTestPage> {
  StreamSubscription<RangingResult>? _subscription;
  List<Beacon> _beacons = [];
  String _status = 'Chưa bắt đầu quét';
  bool _scanning = false;
  bool _busy = false;

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
      final regions = [
        Region(identifier: 'all-beacons'),
      ];

      await _subscription?.cancel();
      if (!mounted) return;

      setState(() {
        _beacons = [];
        _scanning = true;
        _status = 'Đang quét — chờ tín hiệu iBeacon';
      });

      _subscription = flutterBeacon.ranging(regions).listen(
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

  Future<void> _stopScanning() async {
    setState(() => _busy = true);

    try {
      await _subscription?.cancel();
      _subscription = null;

      if (!mounted) return;

      setState(() {
        _scanning = false;
        _status = 'Đã dừng quét';
      });
    } catch (error) {
      _setStatus('Không thể dừng quét: $error');
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
      appBar: AppBar(
        title: const Text('Task 4 — Thử quét iBeacon'),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final navigator = Navigator.of(context);

                    if (_scanning) {
                      await _stopScanning();
                    }

                    if (!mounted || !navigator.mounted) return;

                    await navigator.push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const BeaconSimulationPage(),
                      ),
                    );
                  },
            child: const Text('Simulation'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
                        onPressed:
                            _busy || _scanning ? null : _startScanning,
                        child: const Text('Bắt đầu quét'),
                      ),
                      OutlinedButton(
                        onPressed:
                            _busy || !_scanning ? null : _stopScanning,
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
            Expanded(
              child: _beacons.isEmpty
                  ? const Center(
                      child: Text('Chưa có dữ liệu beacon'),
                    )
                  : ListView.builder(
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
            ),
          ],
        ),
      ),
    );
  }
}
