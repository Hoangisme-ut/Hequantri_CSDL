import 'package:flutter/material.dart';

import 'beacon_content_controller.dart';

/// Resolved beacon preview. Discovery/preview alone never starts a visit.
class BeaconContentPanel extends StatefulWidget {
  const BeaconContentPanel({
    super.key,
    required this.controller,
    this.isActive = true,
    this.rssi,
  });

  final BeaconContentController controller;
  final bool isActive;
  final int? rssi;

  @override
  State<BeaconContentPanel> createState() => _BeaconContentPanelState();
}

class _BeaconContentPanelState extends State<BeaconContentPanel> {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      final controller = widget.controller;
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
            if (controller.canRecordVisits) ...[
              const SizedBox(height: 12),
              if (controller.isSavingVisit)
                const Text('Đang lưu lượt xem...')
              else if (controller.visitError != null) ...[
                Text(
                  controller.visitError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () =>
                        controller.retryVisitLog(rssi: widget.rssi),
                    child: const Text('Thử lưu lượt xem lại'),
                  ),
                ),
              ] else if (controller.visitResult != null)
                Text(
                  controller.visitResult!.alreadyRecorded
                      ? 'Lượt xem đã có trong lịch sử gần đây.'
                      : 'Đã lưu vào lịch sử tham quan.',
                ),
            ],
          ] else
            const Text('Chưa có nội dung từ backend.'),
        ],
      );
    },
  );
}
