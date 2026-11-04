import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../auth/auth_service.dart';
import '../data/visitor_api_service.dart';
import '../../shared/config/api_config.dart';
import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import '../artifacts/artifact.dart';
import '../artifacts/artifact_detail_page.dart';
import '../data/heritage_repository.dart';
import '../heritage/heritage_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, this.api});

  @visibleForTesting
  final VisitorApi? api;

  @override
  State<FavoritesPage> createState() => FavoritesPageState();
}

class FavoritesPageState extends State<FavoritesPage> {
  int _tabIndex = 0;
  VisitorApi? _api;
  bool _ownsApi = false;
  bool _loading = true;
  bool _requestRunning = false;
  String? _error;
  List<VisitorFavorite> _favorites = const [];
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
      _favorites = const [];
      _error = null;
      _loading = _token != null;
      _loadFavorites();
    }
  }

  @override
  void dispose() {
    if (_ownsApi && _api is HttpVisitorApi) (_api as HttpVisitorApi).close();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    if (_requestRunning) {
      _reloadPending = true;
      return;
    }
    final token = _token;
    final api = _api;
    final strings = AppStrings.of(context);
    final languageCode = strings.locale.languageCode;
    final generation = _requestGeneration;
    if (token == null || api == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error ??= token == null
              ? strings.favoritesSignInRequired
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
      });
    }
    try {
      final firstPage = await api.loadFavorites(
        token: token,
        languageCode: languageCode,
        limit: 100,
      );
      final itemsByArtifactId = <String, VisitorFavorite>{};
      for (final item in firstPage.items) {
        itemsByArtifactId.putIfAbsent(item.artifactId, () => item);
      }
      var nextSkip = firstPage.items.length;
      while (nextSkip < firstPage.count) {
        if (generation != _requestGeneration) return;
        final next = await api.loadFavorites(
          token: token,
          languageCode: languageCode,
          skip: nextSkip,
          limit: 100,
        );
        if (next.items.isEmpty) break;
        nextSkip += next.items.length;
        for (final item in next.items) {
          itemsByArtifactId.putIfAbsent(item.artifactId, () => item);
        }
      }
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _favorites = itemsByArtifactId.values.toList(growable: false);
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
          _error = strings.favoritesLoadError;
          _loading = false;
        });
      }
    } finally {
      _requestRunning = false;
      if (mounted && (_reloadPending || generation != _requestGeneration)) {
        _reloadPending = false;
        unawaited(_loadFavorites());
      }
    }
  }

  Future<void> reload() => _loadFavorites();

  Artifact _artifactFor(VisitorArtifactSummary summary) => Artifact(
    id: summary.id,
    titleVi: summary.title ?? summary.code,
    titleEn: summary.title ?? summary.code,
    period: summary.era ?? '',
    category: 'Artifact',
    location: summary.code,
    descriptionVi: '',
    descriptionEn: '',
    imageUrl: summary.coverImageUrl ?? '',
    isFavorite: true,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final isEn = strings.isEnglish;

    final favoriteArtifacts = _favorites
        .map((item) => _artifactFor(item.artifact))
        .toList();

    // Di tích tương ứng với các hiện vật yêu thích hoặc danh sách di tích mẫu
    const favoriteLocations = <HeritageLocation>[];

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
          isEn ? 'Favorites' : 'Yêu thích',
          style: theme.textTheme.titleLarge?.copyWith(
            color: HeritagePalette.primaryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          // Filter Tabs (Tất cả, Hiện vật, Di tích)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.small,
              AppSpacing.medium,
              AppSpacing.xSmall,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab(
                    0,
                    isEn
                        ? 'All (${favoriteArtifacts.length + favoriteLocations.length})'
                        : 'Tất cả (${favoriteArtifacts.length + favoriteLocations.length})',
                  ),
                  const SizedBox(width: AppSpacing.xSmall),
                  _buildFilterTab(
                    1,
                    isEn
                        ? 'Artifacts (${favoriteArtifacts.length})'
                        : 'Hiện vật (${favoriteArtifacts.length})',
                  ),
                  const SizedBox(width: AppSpacing.xSmall),
                  _buildFilterTab(
                    2,
                    isEn
                        ? 'Heritage Sites (${favoriteLocations.length})'
                        : 'Di tích (${favoriteLocations.length})',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xSmall),

          // List Items
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildLoadError(theme, isEn)
                : _buildTabContent(
                    favoriteArtifacts,
                    favoriteLocations,
                    isEn,
                    theme,
                    strings,
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
            onPressed: _loadFavorites,
            icon: const Icon(Icons.refresh),
            label: Text(isEn ? 'Retry' : 'Thử lại'),
          ),
        ],
      ),
    ),
  );

  Widget _buildTabContent(
    List<Artifact> artifacts,
    List<HeritageLocation> locations,
    bool isEn,
    ThemeData theme,
    AppStrings strings,
  ) {
    if (_tabIndex == 0) {
      if (artifacts.isEmpty && locations.isEmpty) {
        return _buildEmptyState(theme, isEn);
      }
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
        children: [
          if (locations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xSmall,
                bottom: AppSpacing.small,
              ),
              child: Text(
                isEn ? 'Heritage Sites' : 'Di tích lịch sử',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
            ),
            ...locations.map((loc) => _buildLocationCard(loc, isEn, theme)),
            const SizedBox(height: AppSpacing.small),
          ],
          if (artifacts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xSmall,
                bottom: AppSpacing.small,
              ),
              child: Text(
                isEn ? 'Artifacts Collection' : 'Hiện vật lịch sử',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
            ),
            ...artifacts.map(
              (art) => _buildArtifactCard(art, isEn, theme, strings),
            ),
          ],
        ],
      );
    } else if (_tabIndex == 1) {
      if (artifacts.isEmpty) {
        return _buildEmptyState(theme, isEn);
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
        itemCount: artifacts.length,
        itemBuilder: (context, index) {
          return _buildArtifactCard(artifacts[index], isEn, theme, strings);
        },
      );
    } else {
      if (locations.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Text(
              isEn
                  ? 'The current Favorites API supports artifacts only.'
                  : 'Favorites API hiện chỉ hỗ trợ hiện vật.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: HeritagePalette.secondaryText,
              ),
            ),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
        itemCount: locations.length,
        itemBuilder: (context, index) {
          return _buildLocationCard(locations[index], isEn, theme);
        },
      );
    }
  }

  Widget _buildFilterTab(int index, String label) {
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

  Widget _buildArtifactCard(
    Artifact item,
    bool isEn,
    ThemeData theme,
    AppStrings strings,
  ) {
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
          onTap: () async {
            var didChangeFavorite = false;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ArtifactDetailPage(
                  artifact: item,
                  visitorApi: _api,
                  initialIsFavorite: true,
                  onFavoriteChanged: () => didChangeFavorite = true,
                ),
              ),
            );
            if (mounted && didChangeFavorite) await _loadFavorites();
          },
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: HeritagePalette.background,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
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
                      const SizedBox(height: 4),
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
                      Text(
                        item.period,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: HeritagePalette.secondaryText,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
                              item.location,
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
                const Icon(Icons.favorite, color: Color(0xFFEF4444), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(
    HeritageLocation location,
    bool isEn,
    ThemeData theme,
  ) {
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HeritageDetailPage(location: location),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.small),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: Image.asset(
                    location.imageUrl,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 76,
                      height: 76,
                      color: HeritagePalette.background,
                      child: const Icon(
                        Icons.account_balance_outlined,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: HeritagePalette.background,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          isEn ? 'Heritage Site' : 'Di tích',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: HeritagePalette.primaryNavy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location.getName(isEn ? 'en' : 'vi'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: HeritagePalette.primaryNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
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
                              '${location.city} • ${location.address}',
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
                const Icon(
                  Icons.bookmark_rounded,
                  color: HeritagePalette.actionBlue,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                  Icons.favorite_border_rounded,
                  size: 32,
                  color: HeritagePalette.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                isEn ? 'No favorites saved yet' : 'Chưa có mục yêu thích nào',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
              const SizedBox(height: AppSpacing.xSmall),
              Text(
                isEn
                    ? 'Save your favorite heritage sites and artifacts to find them quickly here.'
                    : 'Lưu các địa điểm và hiện vật yêu thích để tra cứu nhanh tại đây.',
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
