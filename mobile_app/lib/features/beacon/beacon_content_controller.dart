import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../visits/visit_log_service.dart';
import 'beacon_content_service.dart';
import 'visit_deduplicator.dart';

class BeaconContentController extends ChangeNotifier {
  BeaconContentController({
    required this.service,
    required this.readToken,
    this.visitLogService,
    this.allowVisitLogging = true,
    this.acceptResolvedContent,
    DateTime Function()? clock,
    this.minRequestInterval = const Duration(seconds: 3),
  }) : _visitDeduplicator = VisitDeduplicator(clock: clock ?? DateTime.now),
       assert(!minRequestInterval.isNegative);

  final BeaconContentService service;
  final AuthToken? Function() readToken;
  final VisitLogService? visitLogService;
  final bool allowVisitLogging;

  /// Màn quét thật dùng callback này để kiểm tra ngưỡng RSSI.
  /// Simulation không có RSSI đo thực tế nên không truyền callback.
  final bool Function(BeaconContent content)? acceptResolvedContent;

  final Duration minRequestInterval;
  final VisitDeduplicator _visitDeduplicator;

  _BeaconRequest? _selected;
  BeaconContent? _content;
  AuthToken? _contentToken;
  String? _errorMessage;
  int? _errorStatusCode;

  Timer? _cooldownTimer;

  bool _loading = false;
  bool _requestRunning = false;
  bool _pending = false;
  bool _disposed = false;

  int _revision = 0;
  int _requestCount = 0;
  int _visitRequestsRunning = 0;

  String? _visitSessionKey;
  String? _visitError;
  String? _visitErrorArtifactId;
  int? _visitErrorStatusCode;
  VisitRecordResult? _visitResult;

  bool get canRecordVisits => allowVisitLogging && visitLogService != null;
  bool get isSavingVisit => _visitRequestsRunning > 0;
  String? get visitError => _visitError;
  int? get visitErrorStatusCode => _visitErrorStatusCode;

  bool get visitErrorIsForCurrentContent =>
      _content != null && _visitErrorArtifactId == _content!.artifactId;

  VisitRecordResult? get visitResult => _visitResult;

  bool get visitResultIsForCurrentContent =>
      _content != null &&
      _visitResult?.visit.artifactId == _content!.artifactId;

  BeaconContent? get content => _content;
  AuthToken? get contentToken => _contentToken;
  String? get errorMessage => _errorMessage;
  int? get errorStatusCode => _errorStatusCode;
  bool get isLoading => _loading;
  int get requestCount => _requestCount;
  String? get currentBeaconKey => _selected?.key;

  /// Nhận beacon đã được màn quét xác nhận.
  /// Đổi ngôn ngữ không xóa cửa sổ chống ghi lượt xem trùng.
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

    if (request.key == _selected?.key) return;

    _selected = request;
    _queueRequest();
  }

  void retry() {
    if (_disposed || _selected == null || _loading) return;
    _queueRequest();
  }

  void _queueRequest() {
    _revision++;
    _pending = true;
    _loading = true;
    _content = null;
    _contentToken = null;
    _errorMessage = null;
    _errorStatusCode = null;

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
      final token = readToken();

      if (!_isUsableBearer(token)) {
        throw const BeaconApiException(
          'Cần đăng nhập để tải nội dung beacon.',
          statusCode: 401,
        );
      }

      _requestCount++;

      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(minRequestInterval, () {
        _cooldownTimer = null;
        _scheduleRequest();
      });

      final result = await service.resolve(
        proximityUuid: request.proximityUuid,
        major: request.major,
        minor: request.minor,
        token: token!,
        languageCode: request.languageCode,
      );

      if (_isCurrent(revision)) {
        if (!_sameBearer(readToken(), token)) {
          _content = null;
          _contentToken = null;
          _errorMessage = 'Phiên đăng nhập đã thay đổi. Vui lòng tải lại.';
          _errorStatusCode = 401;
        } else if (!(acceptResolvedContent?.call(result) ?? true)) {
          // Chưa đủ ngưỡng: không đưa nội dung ra giao diện.
          // Cho phép cùng beacon tải lại khi tín hiệu đủ mạnh.
          _content = null;
          _contentToken = null;
          _selected = null;
          _errorMessage = null;
          _errorStatusCode = null;
        } else {
          _content = result;
          _contentToken = token;
          _errorMessage = null;
          _errorStatusCode = null;

          if (_visitErrorArtifactId != result.artifactId) {
            _visitError = null;
            _visitErrorArtifactId = null;
            _visitErrorStatusCode = null;
          }

          if (_visitResult?.visit.artifactId != result.artifactId) {
            _visitResult = null;
          }
        }
      }
    } on BeaconApiException catch (error) {
      if (_isCurrent(revision)) {
        _content = null;
        _contentToken = null;
        _errorMessage = error.message;
        _errorStatusCode = error.statusCode;
      }
    } catch (_) {
      if (_isCurrent(revision)) {
        _content = null;
        _contentToken = null;
        _errorMessage = 'Không tải được nội dung. Vui lòng thử lại.';
      }
    } finally {
      _requestRunning = false;

      if (!_disposed) {
        if (_isCurrent(revision)) {
          _loading = false;
          notifyListeners();
        }

        _scheduleRequest();
      }
    }
  }

  bool _isCurrent(int revision) => !_disposed && revision == _revision;

  /// Chỉ gọi sau khi nội dung đã được hiển thị.
  Future<void> recordDisplayedContent(
    BeaconContent displayed, {
    int? rssi,
  }) async {
    final visits = visitLogService;
    final resolvedToken = _contentToken;

    if (_disposed ||
        !canRecordVisits ||
        visits == null ||
        _loading ||
        !identical(displayed, _content)) {
      return;
    }

    final currentToken = readToken();
    _syncVisitSession(currentToken);

    if (resolvedToken == null || !_sameBearer(currentToken, resolvedToken)) {
      _visitError = 'Vui lòng tải lại nội dung bằng phiên đăng nhập hiện tại.';
      _visitErrorArtifactId = displayed.artifactId;
      _visitErrorStatusCode = 401;
      notifyListeners();
      return;
    }

    if (_visitErrorArtifactId == displayed.artifactId && _visitError != null) {
      return;
    }

    final reservation = _visitDeduplicator.reserve(displayed.artifactId);
    if (reservation == null) return;

    _visitRequestsRunning++;
    _visitError = null;
    _visitErrorArtifactId = null;
    _visitErrorStatusCode = null;
    notifyListeners();

    try {
      final result = await visits.record(
        artifactId: displayed.artifactId,
        beaconId: displayed.beaconId,
        token: resolvedToken,
        rssi: rssi != null && rssi < 0 ? rssi : null,
      );

      _visitDeduplicator.complete(
        reservation,
        succeeded: true,
        visitedAt: result.visit.visitedAt,
        wasCreated: !result.alreadyRecorded,
      );

      if (_isCurrentVisitContent(displayed, resolvedToken)) {
        _visitResult = result;
        _visitError = null;
        _visitErrorArtifactId = null;
        _visitErrorStatusCode = null;
      }
    } on VisitLogException catch (error) {
      _visitDeduplicator.complete(reservation, succeeded: false);

      if (_isCurrentVisitContent(displayed, resolvedToken)) {
        _visitError = error.message;
        _visitErrorArtifactId = displayed.artifactId;
        _visitErrorStatusCode = error.statusCode;
      }
    } catch (_) {
      _visitDeduplicator.complete(reservation, succeeded: false);

      if (_isCurrentVisitContent(displayed, resolvedToken)) {
        _visitError = 'Chưa lưu được lượt xem. Vui lòng thử lại.';
        _visitErrorArtifactId = displayed.artifactId;
        _visitErrorStatusCode = null;
      }
    } finally {
      if (_visitRequestsRunning > 0) {
        _visitRequestsRunning--;
      }

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  bool _isCurrentVisitContent(BeaconContent displayed, AuthToken token) =>
      !_disposed &&
      identical(displayed, _content) &&
      identical(_contentToken, token) &&
      _sameBearer(readToken(), token);

  void _syncVisitSession(AuthToken? token) {
    final nextKey = _isUsableBearer(token) ? token!.accessToken : null;

    if (nextKey == _visitSessionKey) return;

    _visitSessionKey = nextKey;
    _visitDeduplicator.reset();
    _visitError = null;
    _visitErrorArtifactId = null;
    _visitErrorStatusCode = null;
    _visitResult = null;
  }

  void retryVisitLog({int? rssi}) {
    final displayed = _content;

    if (_disposed ||
        _visitRequestsRunning > 0 ||
        displayed == null ||
        _visitErrorArtifactId != displayed.artifactId) {
      return;
    }

    _visitError = null;
    _visitErrorArtifactId = null;
    _visitErrorStatusCode = null;

    unawaited(recordDisplayedContent(displayed, rssi: rssi));
  }

  /// Dừng hoặc hết hạn lựa chọn sẽ xóa nội dung.
  /// Vẫn giữ cửa sổ chống ghi lượt xem trùng trong 300 giây.
  void reset() {
    if (_disposed) return;

    _revision++;
    _selected = null;
    _pending = false;
    _loading = false;
    _content = null;
    _contentToken = null;
    _errorMessage = null;
    _errorStatusCode = null;
    _visitError = null;
    _visitErrorArtifactId = null;
    _visitErrorStatusCode = null;
    _visitResult = null;

    notifyListeners();
  }

  static bool _isUsableBearer(AuthToken? token) =>
      token != null &&
      token.accessToken.trim().isNotEmpty &&
      token.tokenType.trim().toLowerCase() == 'bearer';

  static bool _sameBearer(AuthToken? a, AuthToken? b) =>
      _isUsableBearer(a) &&
      _isUsableBearer(b) &&
      a!.accessToken == b!.accessToken;

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _pending = false;
    _cooldownTimer?.cancel();
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

  String get key =>
      '${proximityUuid.toLowerCase()}:$major:$minor:${languageCode ?? ''}';
}
