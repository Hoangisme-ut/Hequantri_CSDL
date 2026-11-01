import 'package:flutter/material.dart';

import '../../shared/config/api_config.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../auth/auth_session.dart';
import '../visits/visit_log_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    @visibleForTesting this.service,
    @visibleForTesting this.readToken,
  });

  final VisitLogService? service;
  final AuthToken? Function()? readToken;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  VisitLogService? _service;
  AuthSession? _session;
  String? _configurationError;
  String? _loadedToken;
  String _language = '';
  bool _initialized = false;
  bool _loading = false;
  bool _hasMore = false;
  int _revision = 0;
  int _count = 0;
  int _nextSkip = 0;
  String? _error;
  final List<VisitHistoryEntry> _entries = [];

  bool get _isEn => _language == 'en';
  AuthToken? _readToken() =>
      widget.readToken != null ? widget.readToken!() : _session?.readToken();

  @override
  void initState() {
    super.initState();
    try {
      _service = widget.service ?? VisitLogService(baseUrl: ApiConfig.baseUrl);
    } on StateError catch (error) {
      _configurationError = error.message.toString();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session = AuthSessionScope.maybeOf(context);
    final language = Localizations.localeOf(context).languageCode;
    final token = _readToken()?.accessToken;
    if (!_initialized || token != _loadedToken || language != _language) {
      _initialized = true;
      _loadedToken = token;
      _language = language;
      _load(reset: true);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final revision = ++_revision;
    final token = _readToken();
    final service = _service;
    final skip = reset ? 0 : _nextSkip;

    setState(() {
      _error = null;
      _loading = true;
      if (reset) {
        _entries.clear();
        _count = 0;
        _nextSkip = 0;
        _hasMore = false;
      }
    });

    bool isCurrent() =>
        mounted &&
        revision == _revision &&
        token?.accessToken == _readToken()?.accessToken;

    try {
      if (token == null || token.accessToken.trim().isEmpty) {
        throw VisitLogException(
          _isEn
              ? 'Sign in to view your visit history.'
              : 'Vui lòng đăng nhập để xem lịch sử tham quan.',
        );
      }
      if (service == null) {
        throw VisitLogException(
          _configurationError ?? 'Chưa cấu hình máy chủ.',
        );
      }
      final result = await service.history(
        token: token,
        languageCode: _language,
        skip: skip,
      );
      if (!isCurrent()) return;
      setState(() {
        final ids = _entries.map((entry) => entry.visit.id).toSet();
        _entries.addAll(
          result.entries.where((entry) => ids.add(entry.visit.id)),
        );
        _nextSkip = skip + result.entries.length;
        _count = result.count;
        _hasMore = result.entries.isNotEmpty && _nextSkip < result.count;
      });
    } on VisitLogException catch (error) {
      if (isCurrent()) setState(() => _error = error.message);
    } catch (_) {
      if (isCurrent()) {
        setState(
          () => _error = _isEn
              ? 'Could not load visit history. Please try again.'
              : 'Không tải được lịch sử. Vui lòng thử lại.',
        );
      }
    } finally {
      if (isCurrent()) setState(() => _loading = false);
    }
  }

  String _timeText(DateTime? time) {
    if (time == null) return _isEn ? 'Time unavailable' : 'Chưa có thời gian';
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  void dispose() {
    _revision++;
    if (widget.service == null) _service?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(_isEn ? 'Visit History' : 'Lịch sử tham quan'),
        actions: [
          IconButton(
            tooltip: _isEn ? 'Refresh' : 'Làm mới',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.medium),
          children: [
            if (_entries.isNotEmpty) ...[
              Text(_isEn ? 'Total visits: $_count' : 'Tổng lượt xem: $_count'),
              const SizedBox(height: AppSpacing.small),
            ],
            for (final entry in _entries)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.history,
                    color: HeritagePalette.primaryNavy,
                  ),
                  title: Text(
                    entry.title?.trim().isNotEmpty ?? false
                        ? entry.title!
                        : entry.code,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.code),
                      if (entry.era?.isNotEmpty ?? false) Text(entry.era!),
                      Text(_timeText(entry.visit.visitedAt)),
                      if (entry.isFallback)
                        Text(_isEn ? 'Fallback language' : 'Ngôn ngữ dự phòng'),
                    ],
                  ),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null) ...[
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              TextButton(
                onPressed: () => _load(reset: _entries.isEmpty),
                child: Text(_isEn ? 'Retry' : 'Thử lại'),
              ),
            ] else if (_entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    _isEn
                        ? 'No visit history yet'
                        : 'Chưa có lịch sử tham quan',
                  ),
                ),
              ),
            if (_hasMore && !_loading && _error == null)
              OutlinedButton(
                onPressed: () => _load(reset: false),
                child: Text(_isEn ? 'Load more' : 'Xem thêm'),
              ),
          ],
        ),
      ),
    );
  }
}
