import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import 'beacon_content_service.dart';

class BeaconContentController extends ChangeNotifier {
  BeaconContentController({
    required this.service,
    required this.readToken,
    this.minRequestInterval = const Duration(seconds: 3),
  }) : assert(!minRequestInterval.isNegative);

  final BeaconContentService service;
  final AuthToken? Function() readToken;
  final Duration minRequestInterval;

  _BeaconRequest? _selected;
  BeaconContent? _content;
  String? _errorMessage;

  Timer? _cooldownTimer;

  bool _loading = false;
  bool _requestRunning = false;
  bool _pending = false;
  bool _disposed = false;

  int _revision = 0;
  int _requestCount = 0;

  BeaconContent? get content => _content;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loading;
  int get requestCount => _requestCount;
  String? get currentBeaconKey => _selected?.key;

  /// Gọi khi đã xác nhận beacon đang được chọn.
  /// Dùng được cho cả quét thật và Simulation.
  void receiveBeacon({
    required String proximityUuid,
    required int major,
    required int minor,
    String? languageCode,
  }) {
    if (_disposed) return;

    final request = _BeaconRequest(
      proximityUuid: proximityUuid.trim(),
      major: major,
      minor: minor,
      languageCode: languageCode?.trim(),
    );

    // Cùng beacon và cùng ngôn ngữ: không gọi API lại.
    if (request.key == _selected?.key) return;

    _selected = request;
    _queueRequest();
  }

  /// Thử lại khi gặp lỗi hoặc sau khi đã có token đăng nhập.
  void retry() {
    if (_disposed || _selected == null || _loading) return;
    _queueRequest();
  }

  void _queueRequest() {
    _revision++;
    _pending = true;
    _loading = true;
    _content = null;
    _errorMessage = null;

    notifyListeners();
    _scheduleRequest();
  }

  void _scheduleRequest() {
    if (_disposed ||
        !_pending ||
        _selected == null ||
        _requestRunning ||
        (_cooldownTimer?.isActive ?? false)) {
      return;
    }

    unawaited(_loadContent());
  }

  Future<void> _loadContent() async {
    final request = _selected!;
    final revision = _revision;

    _pending = false;
    _requestRunning = true;

    try {
      // Đọc token mới nhất từ phần đăng nhập.
      final token = readToken();

      if (token == null || token.accessToken.trim().isEmpty) {
        throw const BeaconApiException(
          'Cần đăng nhập để tải nội dung beacon.',
          statusCode: 401,
        );
      }

      _requestCount++;

      // Giới hạn khoảng cách giữa hai lần bắt đầu gọi API.
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(minRequestInterval, () {
        _cooldownTimer = null;
        _scheduleRequest();
      });

      final result = await service.resolve(
        proximityUuid: request.proximityUuid,
        major: request.major,
        minor: request.minor,
        token: token,
        languageCode: request.languageCode,
      );

      // Người dùng đã chuyển beacon thì bỏ kết quả cũ.
      if (_isCurrent(revision)) {
        _content = result;
        _errorMessage = null;
      }
    } on BeaconApiException catch (error) {
      if (_isCurrent(revision)) {
        _content = null;
        _errorMessage = error.message;
      }
    } catch (_) {
      if (_isCurrent(revision)) {
        _content = null;
        _errorMessage = 'Không tải được nội dung. Vui lòng thử lại.';
      }
    } finally {
      _requestRunning = false;

      if (!_disposed) {
        if (_isCurrent(revision)) {
          _loading = false;
          notifyListeners();
        }

        // Xử lý beacon mới nhất đang chờ.
        _scheduleRequest();
      }
    }
  }

  bool _isCurrent(int revision) {
    return !_disposed && revision == _revision;
  }

  /// Xóa trạng thái và bỏ qua kết quả của yêu cầu cũ.
  void reset() {
    if (_disposed) return;

    _revision++;
    _selected = null;
    _pending = false;
    _loading = false;
    _content = null;
    _errorMessage = null;

    // Giữ thời gian chờ để reset không vượt giới hạn gọi API.
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _pending = false;
    _cooldownTimer?.cancel();

    // Service do nơi tạo controller quản lý và đóng riêng.
    super.dispose();
  }
}

class _BeaconRequest {
  const _BeaconRequest({
    required this.proximityUuid,
    required this.major,
    required this.minor,
    this.languageCode,
  });

  final String proximityUuid;
  final int major;
  final int minor;
  final String? languageCode;

  String get key {
    return '${proximityUuid.toLowerCase()}:'
        '$major:$minor:${languageCode ?? ''}';
  }
}
