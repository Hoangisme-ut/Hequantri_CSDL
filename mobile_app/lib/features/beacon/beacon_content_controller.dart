import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../visits/visit_log_service.dart';
import 'beacon_content_service.dart';

class BeaconContentController extends ChangeNotifier {
  BeaconContentController({
    required this.service,
    required this.readToken,
    this.visitLogService,
    this.minRequestInterval = const Duration(seconds: 3),
  }) : assert(!minRequestInterval.isNegative);

  final BeaconContentService service;
  final AuthToken? Function() readToken;
  final VisitLogService? visitLogService;
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

  int _visitEpoch = 0;
  int? _recordedVisitEpoch;
  String? _recordedArtifactId;
  String? _contentAccessToken;
  String? _visitError;
  bool _savingVisit = false;
  VisitRecordResult? _visitResult;
  final Set<int> _visitsInFlight = {};

  bool get canRecordVisits => visitLogService != null;
  bool get isSavingVisit => _savingVisit;
  String? get visitError => _visitError;
  VisitRecordResult? get visitResult => _visitResult;

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

    // A language change reloads content, but is not a new beacon entry.
    if (request.identity != _selected?.identity) _clearVisitSelection();
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
    _contentAccessToken = null;
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
        _contentAccessToken = token.accessToken;
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

  /// Called by the visible content panel after a frame displays this result.
  /// Resolving content alone, hidden tabs and raw ranging callbacks do not log.
  Future<void> recordDisplayedContent(
    BeaconContent displayed, {
    int? rssi,
  }) async {
    final visits = visitLogService;
    final epoch = _visitEpoch;
    if (_disposed ||
        visits == null ||
        _loading ||
        !identical(displayed, _content) ||
        _selected == null ||
        _visitsInFlight.contains(epoch) ||
        _visitError != null ||
        (_recordedVisitEpoch == epoch &&
            _recordedArtifactId == displayed.artifactId)) {
      return;
    }

    final token = readToken();
    if (token == null ||
        token.accessToken.trim().isEmpty ||
        token.accessToken != _contentAccessToken) {
      _visitError = 'Cần tải lại nội dung bằng phiên đăng nhập hiện tại.';
      notifyListeners();
      return;
    }

    _visitsInFlight.add(epoch);
    _savingVisit = true;
    notifyListeners();

    bool stillSelected() =>
        !_disposed &&
        epoch == _visitEpoch &&
        readToken()?.accessToken == token.accessToken;

    try {
      final result = await visits.record(
        artifactId: displayed.artifactId,
        beaconId: displayed.beaconId,
        token: token,
        rssi: rssi,
      );
      if (stillSelected()) {
        _recordedVisitEpoch = epoch;
        _recordedArtifactId = displayed.artifactId;
        _visitResult = result;
        _visitError = null;
      }
    } on VisitLogException catch (error) {
      if (stillSelected()) _visitError = error.message;
    } catch (_) {
      if (stillSelected()) {
        _visitError = 'Chưa lưu được lượt xem. Vui lòng thử lại.';
      }
    } finally {
      _visitsInFlight.remove(epoch);
      if (!_disposed && epoch == _visitEpoch) {
        _savingVisit = false;
        notifyListeners();
      }
    }
  }

  void retryVisitLog({int? rssi}) {
    final displayed = _content;
    if (_disposed || _savingVisit || displayed == null) return;
    _visitError = null;
    unawaited(recordDisplayedContent(displayed, rssi: rssi));
  }

  void _clearVisitSelection() {
    _visitEpoch++;
    _recordedVisitEpoch = null;
    _recordedArtifactId = null;
    _visitError = null;
    _visitResult = null;
    _savingVisit = false;
  }

  /// Xóa trạng thái và bỏ qua kết quả của yêu cầu cũ.
  void reset() {
    if (_disposed) return;

    _revision++;
    _clearVisitSelection();
    _selected = null;
    _pending = false;
    _loading = false;
    _content = null;
    _contentAccessToken = null;
    _errorMessage = null;

    // Giữ thời gian chờ để reset không vượt giới hạn gọi API.
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _visitEpoch++;
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

  String get identity => '${proximityUuid.toLowerCase()}:$major:$minor';

  String get key {
    return '${proximityUuid.toLowerCase()}:'
        '$major:$minor:${languageCode ?? ''}';
  }
}
