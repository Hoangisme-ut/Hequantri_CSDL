import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../shared/config/api_config.dart';
import '../../theme/app_theme.dart';
import '../artifacts/artifact.dart';
import '../artifacts/artifact_detail_page.dart';
import '../auth/auth_session.dart';
import '../auth/auth_service.dart';
import '../data/visitor_api_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.api});

  @visibleForTesting
  final VisitorApi? api;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _tabIndex = 0;
  VisitorApi? _api;
  bool _ownsApi = false;
  bool _loading = true;
  bool _requestRunning = false;
  bool _hasMore = false;
  int _count = 0;
  int _nextSkip = 0;
  static const _pageSize = 20;
  String? _error;
  List<VisitorVisit> _visits = const [];
  AuthToken? _token;
  String? _lastToken;
  String? _lastTokenType;
  String? _lastLanguage;
  int _requestGeneration = 0;
  bool _reloadPending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _token = AuthSessionScope.maybeOf(context)?.readToken();
    final language = AppStrings.of(context).locale.languageCode;
    if (_api == null) {
      _api = widget.api;
      if (_api == null) {
        try {
          _api = HttpVisitorApi(baseUrl: ApiConfig.baseUrl);
          _ownsApi = true;
        } on StateError {
          _error = AppStrings.of(context).apiConfigurationMissing;
        }
      }
    }
    final tokenValue = _token?.accessToken;
    final tokenType = _token?.tokenType.toLowerCase();
    if (tokenValue != _lastToken ||
        tokenType != _lastTokenType ||
        language != _lastLanguage) {
      _lastToken = tokenValue;
      _lastTokenType = tokenType;
      _lastLanguage = language;
      _requestGeneration++;
      _visits = const [];
      _error = null;
      _loading = _token != null;
      _loadVisits();
    }
  }

  @override
  void dispose() {
    if (_ownsApi && _api is HttpVisitorApi) (_api as HttpVisitorApi).close();
    super.dispose();
  }

  Future<void> _loadVisits({bool reset = true}) async {
    if (!mounted) return;
    if (_requestRunning) {
      if (reset) _reloadPending = true;
      return;
    }
    if (!reset && !_hasMore) return;
    final token = _token;
    final api = _api;
    final strings = AppStrings.of(context);
    final languageCode = strings.locale.languageCode;
    final generation = _requestGeneration;
    final skip = reset ? 0 : _nextSkip;
    if (token == null || api == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error ??= token == null
              ? strings.historySignInRequired
              : strings.apiConfigurationMissing;
        });
      }
      return;
    }

    _requestRunning = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        if (reset) {
          _visits = const [];
          _count = 0;
          _nextSkip = 0;
          _hasMore = false;
        }
      });
    }
    try {
      final page = await api.loadVisits(
        token: token,
        languageCode: languageCode,
        skip: skip,
        limit: _pageSize,
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        final existingIds = _visits.map((visit) => visit.id).toSet();
        _visits = [
          ..._visits,
          ...page.items.where((visit) => existingIds.add(visit.id)),
        ];
        _count = page.count;
        _nextSkip = skip + page.items.length;
        _hasMore = page.items.isNotEmpty && _nextSkip < page.count;
        _loading = false;
      });
    } on VisitorApiException catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _error = strings.visitorApiError(error.statusCode);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _error = strings.historyLoadError;
          _loading = false;
        });
      }
    } finally {
      _requestRunning = false;
      if (mounted && (_reloadPending || generation != _requestGeneration)) {
        _reloadPending = false;
        unawaited(_loadVisits(reset: true));
      }
    }
  }

  Artifact _artifactFor(VisitorVisit visit) => Artifact(
    id: visit.artifact.id,
    titleVi: visit.artifact.title ?? visit.artifact.code,
    titleEn: visit.artifact.title ?? visit.artifact.code,
    period: visit.artifact.era ?? '',
    category: 'Artifact',
    location: visit.artifact.code,
    descriptionVi: '',
    descriptionEn: '',
    imageUrl: visit.artifact.coverImageUrl ?? '',
    viewTime: visit.visitedAt?.toLocal().toIso8601String(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final isEn = strings.isEnglish;

    final allHistory = [..._visits];

    // Tab 0: Tất cả; Tab 1: Gần đây nhất (sort viewTime desc); Tab 2: Xem trước đó (sort viewTime asc)
    final historyList = switch (_tabIndex) {
      0 => allHistory,
      1 =>
        [...allHistory]..sort(
          (a, b) => (b.visitedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.visitedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
        ),
      _ =>
        [...allHistory]..sort(
          (a, b) => (a.visitedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.visitedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
        ),
    };

    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: HeritagePalette.primaryNavy,
                ),
                tooltip: isEn ? 'Back' : 'Quay lại',
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          isEn ? 'Visit History' : 'Lịch sử tham quan',
          style: theme.textTheme.titleLarge?.copyWith(
            color: HeritagePalette.primaryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: isEn ? 'Refresh' : '\u004c\u00e0m m\u1edbi',
            onPressed: _loading ? null : () => _loadVisits(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips: Tất cả, Gần đây, Cũ hơn
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.small,
              AppSpacing.medium,
              AppSpacing.xSmall,
            ),
            child: Row(
              children: [
                _buildFilterChip(
                  0,
                  isEn
                      ? 'All (${allHistory.length})'
                      : 'Tất cả (${allHistory.length})',
                ),
                const SizedBox(width: AppSpacing.xSmall),
                _buildFilterChip(1, isEn ? 'Recently Viewed' : 'Gần đây nhất'),
                const SizedBox(width: AppSpacing.xSmall),
                _buildFilterChip(2, isEn ? 'Earlier' : 'Trước đó'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xSmall),

          // History List Items or Empty State
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadVisits(reset: true),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                ),
                itemCount:
                    historyList.length + (historyList.isEmpty ? 1 : 2),
                itemBuilder: (context, index) {
                  if (index == 0 && historyList.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.small),
                      child: Text(
                        isEn
                            ? 'Total visits: $_count'
                            : 'T\u1ed5ng l\u01b0\u1ee3t xem: $_count',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: HeritagePalette.secondaryText,
                        ),
                      ),
                    );
                  }
                  final visitIndex = index - (historyList.isEmpty ? 0 : 1);
                  if (visitIndex < historyList.length) {
                    return _buildHistoryCard(
                      _artifactFor(historyList[visitIndex]),
                      isEn,
                      theme,
                      strings,
                      visit: historyList[visitIndex],
                    );
                  }
                  if (_loading) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.large),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_error != null) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      child: historyList.isEmpty
                          ? _buildLoadError(theme, isEn)
                          : Column(
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                TextButton(
                                  onPressed: () => _loadVisits(reset: false),
                                  child: Text(
                                    isEn ? 'Retry' : 'Th\u1eed l\u1ea1i',
                                  ),
                                ),
                              ],
                            ),
                    );
                  }
                  if (historyList.isEmpty) return _buildEmptyState(theme, isEn);
                  if (_hasMore) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.large),
                      child: OutlinedButton(
                        onPressed: () => _loadVisits(reset: false),
                        child: Text(isEn ? 'Load more' : 'Xem th\u00eam'),
                      ),
                    );
                  }
                  return const SizedBox(height: AppSpacing.medium);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError(ThemeData theme, bool isEn) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.medium),
          FilledButton.icon(
            onPressed: _loadVisits,
            icon: const Icon(Icons.refresh),
            label: Text(isEn ? 'Retry' : 'Thử lại'),
          ),
        ],
      ),
    ),
  );

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _tabIndex == index;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? HeritagePalette.primaryNavy
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isSelected
                ? HeritagePalette.primaryNavy
                : HeritagePalette.border,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected ? Colors.white : HeritagePalette.bodyText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    Artifact item,
    bool isEn,
    ThemeData theme,
    AppStrings strings, {
    required VisitorVisit visit,
  }) {
    final canOpen = _uuidPattern.hasMatch(item.id);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: HeritagePalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          onTap: canOpen
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ArtifactDetailPage(artifact: item, visitorApi: _api),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.small),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: Image.network(
                    item.imageUrl,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 76,
                      height: 76,
                      color: HeritagePalette.background,
                      child: const Icon(
                        Icons.museum_outlined,
                        color: HeritagePalette.secondaryText,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HeritagePalette.background,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            child: Text(
                              strings.artifactCategory(item.category),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: HeritagePalette.actionBlue,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: HeritagePalette.secondaryText,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatVisitTime(visit.visitedAt, isEn),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: HeritagePalette.secondaryText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.getTitle(isEn ? 'en' : 'vi'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: HeritagePalette.primaryNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (visit.artifact.isFallback)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            isEn
                                ? 'Fallback language'
                                : 'Ng\u00f4n ng\u1eef d\u1ef1 ph\u00f2ng',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: HeritagePalette.secondaryText,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: HeritagePalette.secondaryText,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${item.location} • ${item.period}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: HeritagePalette.secondaryText,
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (canOpen)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: HeritagePalette.secondaryText,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatVisitTime(DateTime? timestamp, bool isEn) {
    if (timestamp == null) {
      return isEn ? 'Time unavailable' : 'Ch\u01b0a c\u00f3 th\u1eddi gian';
    }
    final local = timestamp.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _buildEmptyState(ThemeData theme, bool isEn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.xLarge,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: HeritagePalette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: HeritagePalette.background,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_toggle_off_rounded,
                  size: 32,
                  color: HeritagePalette.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                isEn ? 'No visit history yet' : 'Chưa có lịch sử tham quan',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
              const SizedBox(height: AppSpacing.xSmall),
              Text(
                isEn
                    ? 'Heritage sites and artifacts you explore will be automatically recorded here.'
                    : 'Các địa điểm di tích và hiện vật bạn đã tham quan sẽ được tự động lưu lại tại đây.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: HeritagePalette.secondaryText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
