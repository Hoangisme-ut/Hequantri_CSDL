import 'package:flutter/material.dart';

import 'features/auth/auth_service.dart';
import 'features/beacon/beacon_content_controller.dart';
import 'features/beacon/beacon_content_service.dart';
import 'shared/config/api_config.dart';

class SimulatedBeacon {
  const SimulatedBeacon({
    required this.name,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.distance,
  });

  final String name;
  final String uuid;
  final int major;
  final int minor;
  final double distance;

  String get key => '${uuid.toLowerCase()}:$major:$minor';
}

class BeaconSimulationPage extends StatefulWidget {
  const BeaconSimulationPage({
    super.key,
    this.readToken,
    this.languageCode = 'vi',
  });

  // P5 cung cấp hàm đọc token từ phiên đăng nhập.
  final AuthToken? Function()? readToken;
  final String languageCode;

  @override
  State<BeaconSimulationPage> createState() => _BeaconSimulationPageState();
}

class _BeaconSimulationPageState extends State<BeaconSimulationPage> {
  static const _beaconA = SimulatedBeacon(
    name: 'Beacon A',
    uuid: '11111111-2222-3333-4444-555555555555',
    major: 1,
    minor: 1,
    distance: 1.5,
  );

  static const _beaconB = SimulatedBeacon(
    name: 'Beacon B',
    uuid: '11111111-2222-3333-4444-555555555555',
    major: 1,
    minor: 2,
    distance: 2.0,
  );

  BeaconContentService? _service;
  BeaconContentController? _controller;
  String? _configurationError;

  SimulatedBeacon? _currentBeacon;
  String? _lastNotifiedKey;

  int _notificationCount = 0;
  int _duplicateCount = 0;

  String _status = 'Select a beacon to simulate detection.';

  @override
  void initState() {
    super.initState();

    try {
      final service = BeaconContentService(baseUrl: ApiConfig.baseUrl);

      _service = service;
      _controller = BeaconContentController(
        service: service,
        readToken: () => widget.readToken?.call(),
      );
    } on StateError catch (error) {
      _configurationError = error.message.toString();
    }
  }

  void _receiveBeacon(SimulatedBeacon beacon) {
    final isDuplicate = beacon.key == _lastNotifiedKey;

    setState(() {
      _currentBeacon = beacon;

      if (isDuplicate) {
        _duplicateCount++;
        _status =
            '${beacon.name} detected again. '
            'Duplicate notification suppressed.';
      } else {
        _lastNotifiedKey = beacon.key;
        _notificationCount++;
        _status =
            'Changed to ${beacon.name}. '
            'Requesting associated content from backend.';
      }
    });

    // Controller tự chặn gọi API lặp và giới hạn tần suất.
    _controller?.receiveBeacon(
      proximityUuid: beacon.uuid,
      major: beacon.major,
      minor: beacon.minor,
      languageCode: widget.languageCode,
    );

    debugPrint(
      '[SIMULATION] ${beacon.name} | '
      'UUID: ${beacon.uuid} | '
      'Major: ${beacon.major} | '
      'Minor: ${beacon.minor} | '
      'Simulated distance: ${beacon.distance} m | '
      'Duplicate: $isDuplicate',
    );

    if (isDuplicate) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('New beacon: ${beacon.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetSimulation() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    _controller?.reset();

    setState(() {
      _currentBeacon = null;
      _lastNotifiedKey = null;
      _notificationCount = 0;
      _duplicateCount = 0;
      _status = 'Simulation reset. Select a beacon.';
    });
  }

  Widget _buildBackendContent() {
    final controller = _controller;

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
                const Text('Đang hiển thị ngôn ngữ thay thế.'),
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
    _controller?.dispose();
    _service?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beacon = _currentBeacon;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Task 4 — iBeacon Simulation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'SIMULATION MODE',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Beacon data and distances are simulated. '
              'These buttons do not transmit or scan Bluetooth signals.',
            ),
            const SizedBox(height: 8),
            const Text('Nội dung hiện vật được lấy từ backend.'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _receiveBeacon(_beaconA),
                  child: const Text('Simulate Beacon A'),
                ),
                FilledButton(
                  onPressed: () => _receiveBeacon(_beaconB),
                  child: const Text('Simulate Beacon B'),
                ),
                OutlinedButton(
                  onPressed: _resetSimulation,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(_status),
            const SizedBox(height: 16),
            Text('Notifications triggered: $_notificationCount'),
            Text('Duplicate detections suppressed: $_duplicateCount'),
            const SizedBox(height: 20),
            if (beacon == null)
              const Text('No simulated beacon detected yet.')
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(beacon.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      SelectableText(
                        'UUID: ${beacon.uuid}\n'
                        'Major: ${beacon.major}\n'
                        'Minor: ${beacon.minor}\n'
                        'Simulated distance: '
                        '${beacon.distance.toStringAsFixed(2)} m',
                      ),
                      const Divider(height: 28),
                      Text('Content', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _buildBackendContent(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
