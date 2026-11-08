import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_session.dart';
import '../auth/auth_service.dart';
import '../data/visitor_api_service.dart';
import '../media/backend_media_player.dart';
import 'artifact.dart';
import 'artifact_feedback_form.dart';

class ArtifactDetailPage extends StatefulWidget {
  const ArtifactDetailPage({
    super.key,
    required this.artifact,
    this.visitorApi,
    this.initialIsFavorite,
    this.onFavoriteChanged,
    this.visitBeaconId,
    this.visitRssi,
  });

  final Artifact artifact;
  final VisitorApi? visitorApi;
  final bool? initialIsFavorite;
  final VoidCallback? onFavoriteChanged;
  final String? visitBeaconId;
  final int? visitRssi;

  @override
  State<ArtifactDetailPage> createState() => _ArtifactDetailPageState();
}

class _ArtifactDetailPageState extends State<ArtifactDetailPage> {
  late bool _isFav;
  bool _favoriteRequestRunning = false;
  bool _favoriteInitialized = false;
  VisitorApi? _visitorApi;
  AuthToken? _token;
  AuthToken? _observedSessionToken;
  bool _didObserveSession = false;
  int _favoriteStateGeneration = 0;
  String? _favoriteError;

  VisitorArtifactContent? _remoteContent;
  AuthToken? _remoteContentToken;
  bool _contentLoading = false;
  String? _contentError;
  String? _loadedContentLanguage;
  String? _loadedContentArtifactId;
  int _contentRequestGeneration = 0;
  int _viewRevision = 0;
  final Set<String> _completedViews = {};
  final Set<String> _pendingViews = {};
  final Map<String, int?> _failedViews = {};

  @override
  void initState() {
    super.initState();
    _isFav = widget.initialIsFavorite ?? widget.artifact.isFavorite;
    _visitorApi = widget.visitorApi;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentToken = AuthSessionScope.maybeOf(context)?.readToken();
    final sessionChanged =
        _didObserveSession &&
        !_sameAuthToken(_observedSessionToken, currentToken);

    _token = currentToken;
    _observedSessionToken = currentToken;
    _didObserveSession = true;
    _visitorApi ??= widget.visitorApi;

    final language = AppStrings.of(context).locale.languageCode;

    if (_visitorApi != null &&
        _hasBackendId &&
        (sessionChanged ||
            language != _loadedContentLanguage ||
            widget.artifact.id != _loadedContentArtifactId)) {
      _loadedContentLanguage = language;
      _loadedContentArtifactId = widget.artifact.id;
      _loadRemoteContent(language, artifactId: widget.artifact.id);
    }

    if (sessionChanged) {
      _favoriteStateGeneration++;
      _favoriteInitialized = true;
      _isFav = false;
      _favoriteError = null;

      if (currentToken != null && _hasBackendId) {
        _loadFavoriteState(currentToken);
      }
    } else if (!_favoriteInitialized) {
      _favoriteInitialized = true;

      if (widget.initialIsFavorite == null &&
          currentToken != null &&
          _hasBackendId) {
        _loadFavoriteState(currentToken);
      }
    }
  }

  @override
  void didUpdateWidget(covariant ArtifactDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.artifact.id == widget.artifact.id) return;

    _viewRevision++;
    _contentRequestGeneration++;
    _loadedContentArtifactId = null;
    _loadedContentLanguage = null;
    _remoteContent = null;
    _remoteContentToken = null;
    _contentError = null;
    _favoriteInitialized = widget.initialIsFavorite != null;
    _isFav = widget.initialIsFavorite ?? widget.artifact.isFavorite;
    _favoriteError = null;
    _favoriteStateGeneration++;

    final language = AppStrings.of(context).locale.languageCode;

    if (_visitorApi != null && _hasBackendId) {
      _loadedContentLanguage = language;
      _loadedContentArtifactId = widget.artifact.id;
      _loadRemoteContent(language, artifactId: widget.artifact.id);
    }

    if (!_favoriteInitialized && _token != null && _hasBackendId) {
      _favoriteInitialized = true;
      _loadFavoriteState(_token!);
    }
  }

  bool get _hasBackendId => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(widget.artifact.id);

  Future<void> _loadFavoriteState(AuthToken token) async {
    final api = _visitorApi;
    if (api == null) return;

    final session = AuthSessionScope.maybeOf(context);
    final generation = ++_favoriteStateGeneration;
    final artifactId = widget.artifact.id;
    final languageCode = AppStrings.of(context).locale.languageCode;

    try {
      var skip = 0;
      var count = 0;
      var isFavorite = false;

      do {
        final page = await api.loadFavorites(
          token: token,
          languageCode: languageCode,
          skip: skip,
          limit: 100,
        );

        if (!_isCurrentFavoriteStateRequest(
          generation,
          token,
          artifactId,
          session,
        )) {
          return;
        }

        count = page.count;

        if (page.items.any((item) => item.artifactId == artifactId)) {
          isFavorite = true;
          break;
        }

        if (page.items.isEmpty) break;

        skip += page.items.length;
      } while (skip < count);

      if (!_isCurrentFavoriteStateRequest(
        generation,
        token,
        artifactId,
        session,
      )) {
        return;
      }

      setState(() => _isFav = isFavorite);
    } on VisitorApiException catch (error) {
      if (_isCurrentFavoriteStateRequest(
        generation,
        token,
        artifactId,
        session,
      )) {
        setState(
          () =>
              _favoriteError = AppStrings.of(context)
                  .visitorApiError(error.statusCode),
        );
      }
    } catch (_) {
      if (_isCurrentFavoriteStateRequest(
        generation,
        token,
        artifactId,
        session,
      )) {
        setState(
          () => _favoriteError = AppStrings.of(context).favoriteStatusLoadError,
        );
      }
    }
  }

  bool _isCurrentFavoriteStateRequest(
    int generation,
    AuthToken token,
    String artifactId,
    AuthSession? session,
  ) =>
      mounted &&
      generation == _favoriteStateGeneration &&
      artifactId == widget.artifact.id &&
      _sameAuthToken(session?.readToken(), token);

  bool _sameAuthToken(AuthToken? first, AuthToken? second) {
    if (first == null || second == null) return first == second;

    return first.accessToken == second.accessToken &&
        first.tokenType.toLowerCase() == second.tokenType.toLowerCase();
  }

  Future<void> _loadRemoteContent(
    String languageCode, {
    required String artifactId,
  }) async {
    final api = _visitorApi;
    if (api == null) return;

    final generation = ++_contentRequestGeneration;
    final token = _token;

    setState(() {
      _contentLoading = true;
      _contentError = null;
    });

    try {
      final content = await api.loadArtifact(
        artifactId: artifactId,
        languageCode: languageCode,
      );

      if (_isCurrentContentRequest(generation, artifactId, languageCode)) {
        setState(() {
          _remoteContent = content;
          _remoteContentToken = token;
          _contentLoading = false;
        });
      }
    } on VisitorApiException catch (error) {
      if (_isCurrentContentRequest(generation, artifactId, languageCode)) {
        setState(() {
          _contentError = AppStrings.of(context)
              .visitorApiError(error.statusCode);
          _contentLoading = false;
        });
      }
    } catch (_) {
      if (_isCurrentContentRequest(generation, artifactId, languageCode)) {
        setState(() {
          _contentError = AppStrings.of(context).artifactDetailsLoadError;
          _contentLoading = false;
        });
      }
    }
  }

  bool _isCurrentContentRequest(
    int generation,
    String artifactId,
    String languageCode,
  ) =>
      mounted &&
      generation == _contentRequestGeneration &&
      artifactId == widget.artifact.id &&
      languageCode == AppStrings.of(context).locale.languageCode;

  String _viewKey(VisitorArtifactContent content, AuthToken token) =>
      '$_viewRevision:${token.accessToken}:${content.id}';

  bool _isVisibleView(VisitorArtifactContent content, AuthToken token) =>
      mounted &&
      _hasBackendId &&
      !_contentLoading &&
      _contentError == null &&
      content.id == widget.artifact.id &&
      identical(content, _remoteContent) &&
      _sameAuthToken(token, _remoteContentToken) &&
      _sameAuthToken(token, AuthSessionScope.maybeOf(context)?.readToken()) &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  void _scheduleOpenedView() {
    final content = _remoteContent;
    final token = _remoteContentToken;
    if (content == null || token == null) return;
    final key = _viewKey(content, token);
    if (_completedViews.contains(key) ||
        _pendingViews.contains(key) ||
        _failedViews.containsKey(key)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isVisibleView(content, token)) {
        unawaited(_recordOpenedView(content, token));
      }
    });
  }

  Future<void> _recordOpenedView(
    VisitorArtifactContent content,
    AuthToken token, {
    bool retry = false,
  }) async {
    final api = _visitorApi;
    final key = _viewKey(content, token);
    if (api == null ||
        !_isVisibleView(content, token) ||
        _completedViews.contains(key) ||
        _pendingViews.contains(key) ||
        (!retry && _failedViews.containsKey(key))) {
      return;
    }
    setState(() {
      _pendingViews.add(key);
      _failedViews.remove(key);
    });
    try {
      // Reopening a page sends a new request. SQL Server remains authoritative
      // for the temporary per-user/per-artifact 300-second window.
      await api.recordVisit(
        token: token,
        artifactId: content.id,
        beaconId: widget.visitBeaconId,
        rssi: widget.visitRssi,
      );
      _completedViews.add(key);
    } on VisitorApiException catch (error) {
      _failedViews[key] = error.statusCode;
    } catch (_) {
      _failedViews[key] = null;
    } finally {
      _pendingViews.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleFavorite(bool isEn) async {
    final token = _token;
    final api = _visitorApi;
    final session = AuthSessionScope.maybeOf(context);

    if (!_hasBackendId || api == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _hasBackendId
                ? (isEn
                      ? 'Sign in and configure the backend to save favorites.'
                      : 'Hãy đăng nhập và cấu hình backend để lưu yêu thích.')
                : (isEn
                      ? 'This sample item is not linked to a backend record.'
                      : 'Hiện vật mẫu này chưa liên kết với dữ liệu backend.'),
          ),
        ),
      );
      return;
    }

    if (_favoriteRequestRunning) return;

    final nextValue = !_isFav;

    setState(() {
      _favoriteRequestRunning = true;
      _favoriteError = null;
    });

    try {
      if (nextValue) {
        await api.addFavorite(token: token, artifactId: widget.artifact.id);
      } else {
        await api.removeFavorite(token: token, artifactId: widget.artifact.id);
      }

      if (!mounted || !_sameAuthToken(session?.readToken(), token)) return;

      setState(() => _isFav = nextValue);
      widget.onFavoriteChanged?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue
                ? (isEn
                      ? 'Saved to favorites'
                      : 'Đã lưu hiện vật vào danh sách yêu thích')
                : (isEn
                      ? 'Removed from favorites'
                      : 'Đã xóa khỏi danh sách yêu thích'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } on VisitorApiException catch (error) {
      if (mounted && _sameAuthToken(session?.readToken(), token)) {
        final message = AppStrings.of(context)
            .visitorApiError(error.statusCode);

        setState(() => _favoriteError = message);

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted && _sameAuthToken(session?.readToken(), token)) {
        final message = AppStrings.of(context).favoriteUpdateError;
        setState(() => _favoriteError = message);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEn
                  ? 'Could not update favorite. Please retry.'
                  : 'Không thể cập nhật yêu thích. Hãy thử lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _favoriteRequestRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final isEn = strings.isEnglish;
    _scheduleOpenedView();
    final viewContent = _remoteContent;
    final viewToken = _remoteContentToken;
    final viewKey = viewContent != null && viewToken != null
        ? _viewKey(viewContent, viewToken)
        : null;

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero image and top actions.
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AppRadii.large),
                      ),
                      child: Image.network(
                        _remoteContent?.coverImageUrl?.isNotEmpty == true
                            ? _remoteContent!.coverImageUrl!
                            : widget.artifact.imageUrl,
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 300,
                          color: HeritagePalette.primaryNavy,
                          child: const Center(
                            child: Icon(
                              Icons.museum_outlined,
                              size: 64,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.medium,
                          vertical: AppSpacing.xSmall,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.4,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                                tooltip: isEn ? 'Back' : 'Quay lại',
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            CircleAvatar(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.4,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: _isFav
                                      ? const Color(0xFFEF4444)
                                      : Colors.white,
                                ),
                                tooltip: isEn ? 'Favorite' : 'Yêu thích',
                                onPressed: _favoriteRequestRunning
                                    ? null
                                    : () => _toggleFavorite(isEn),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.medium),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.large,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: HeritagePalette.background,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: HeritagePalette.border),
                        ),
                        child: Text(
                          strings.artifactCategory(widget.artifact.category),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HeritagePalette.actionBlue,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.small),

                      // Title.
                      Text(
                        _remoteContent?.title ??
                            widget.artifact.getTitle(isEn ? 'en' : 'vi'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: HeritagePalette.primaryNavy,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),

                      if (_favoriteError != null)
                        Text(
                          _favoriteError!,
                          style: TextStyle(color: colorScheme.error),
                        ),

                      if (viewKey != null &&
                          _failedViews.containsKey(viewKey) &&
                          _sameAuthToken(viewToken, _token)) ...[
                        Text(
                          strings.visitorApiError(_failedViews[viewKey]),
                          style: TextStyle(color: colorScheme.error),
                        ),
                        TextButton(
                          key: const Key('retry-artifact-visit'),
                          onPressed: () => unawaited(
                            _recordOpenedView(
                              viewContent!,
                              viewToken!,
                              retry: true,
                            ),
                          ),
                          child: Text(
                            isEn
                                ? 'Retry saving visit history'
                                : 'Thử lưu lịch sử lại',
                          ),
                        ),
                      ],

                      const SizedBox(height: 6),

                      // Period.
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 15,
                            color: HeritagePalette.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _remoteContent?.era ?? widget.artifact.period,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: HeritagePalette.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.large),

                      // Real audio/video from backend media URLs.
                      if (_contentLoading)
                        const LinearProgressIndicator()
                      else if (_contentError == null)
                        BackendMediaPlayer(
                          key: ValueKey(
                            'media:${widget.artifact.id}:'
                            '${strings.locale.languageCode}',
                          ),
                          media: _remoteContent?.media ?? const [],
                          isEnglish: isEn,
                        ),

                      const SizedBox(height: AppSpacing.large),

                      // Structured information.
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                          border: Border.all(color: HeritagePalette.border),
                        ),
                        child: Column(
                          children: [
                            _buildSpecRow(
                              icon: Icons.account_balance_outlined,
                              title: isEn ? 'Location' : 'Địa điểm lưu giữ',
                              value: widget.artifact.location,
                              theme: theme,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.xSmall,
                              ),
                              child: Divider(
                                color: HeritagePalette.border,
                                height: 1,
                              ),
                            ),
                            _buildSpecRow(
                              icon: Icons.history_edu_outlined,
                              title: isEn ? 'Period' : 'Thời kỳ lịch sử',
                              value:
                                  _remoteContent?.era ?? widget.artifact.period,
                              theme: theme,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.xSmall,
                              ),
                              child: Divider(
                                color: HeritagePalette.border,
                                height: 1,
                              ),
                            ),
                            _buildSpecRow(
                              icon: Icons.category_outlined,
                              title: isEn ? 'Category' : 'Phân loại hiện vật',
                              value: strings.artifactCategory(
                                widget.artifact.category,
                              ),
                              theme: theme,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.large),

                      // Description.
                      Text(
                        isEn ? 'Description' : 'Mô tả chi tiết',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: HeritagePalette.primaryNavy,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.small),

                      Text(
                        _contentLoading
                            ? (isEn
                                  ? 'Loading artifact details…'
                                  : 'Đang tải nội dung hiện vật…')
                            : _contentError ??
                                  _remoteContent?.description ??
                                  widget.artifact.getDescription(
                                    isEn ? 'en' : 'vi',
                                  ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14.5,
                          height: 1.65,
                          color: HeritagePalette.bodyText,
                        ),
                      ),

                      if (_contentError != null)
                        TextButton.icon(
                          onPressed: () => _loadRemoteContent(
                            strings.locale.languageCode,
                            artifactId: widget.artifact.id,
                          ),
                          icon: const Icon(Icons.refresh),
                          label: Text(isEn ? 'Retry' : 'Thử lại'),
                        ),

                      if (_remoteContent?.isFallback == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            isEn
                                ? 'Fallback language content'
                                : 'Nội dung đang dùng ngôn ngữ dự phòng',
                          ),
                        ),

                      if (_remoteContent?.historyContent?.trim().isNotEmpty ==
                          true) ...[
                        const SizedBox(height: AppSpacing.medium),
                        Text(
                          isEn ? 'History' : 'Lịch sử',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: HeritagePalette.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          _remoteContent!.historyContent!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],

                      const SizedBox(height: AppSpacing.large),
                      ArtifactFeedbackForm(
                        artifactId: widget.artifact.id,
                        api: _visitorApi,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom favorite action.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
                vertical: AppSpacing.small,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: const Border(
                  top: BorderSide(color: HeritagePalette.border),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _favoriteRequestRunning
                        ? null
                        : () => _toggleFavorite(isEn),
                    icon: Icon(
                      _isFav ? Icons.favorite : Icons.favorite_border,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      _isFav
                          ? (isEn
                                ? 'Saved to Favorites'
                                : 'Đã lưu vào yêu thích')
                          : (isEn ? 'Save to Favorites' : 'Lưu vào yêu thích'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isFav
                          ? HeritagePalette.actionBlue
                          : HeritagePalette.primaryNavy,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow({
    required IconData icon,
    required String title,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: HeritagePalette.background,
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
          child: Icon(icon, color: HeritagePalette.primaryNavy, size: 18),
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: HeritagePalette.secondaryText,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
