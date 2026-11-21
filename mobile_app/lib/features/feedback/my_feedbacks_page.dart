import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../shared/config/api_config.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../auth/auth_session.dart';
import '../auth/login_page.dart';
import '../data/visitor_api_service.dart';

class MyFeedbacksPage extends StatefulWidget {
  const MyFeedbacksPage({super.key, this.api});

  final VisitorApi? api;

  @override
  State<MyFeedbacksPage> createState() => MyFeedbacksPageState();
}

class MyFeedbacksPageState extends State<MyFeedbacksPage> {
  VisitorApi? _api;
  bool _ownsApi = false;
  bool _loading = false;
  String? _error;
  List<VisitorFeedback> _feedbacks = const [];
  Map<String, String> _artifactTitles = const {};

  AuthToken? _token;
  String? _lastToken;
  String? _lastTokenType;
  int _requestGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _token = AuthSessionScope.maybeOf(context)?.readToken();
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
    if (tokenValue != _lastToken || tokenType != _lastTokenType) {
      _lastToken = tokenValue;
      _lastTokenType = tokenType;
      _requestGeneration++;
      _feedbacks = const [];
      _error = null;
      if (_token != null) {
        _loadFeedbacks();
      } else {
        _loading = false;
      }
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    if (_ownsApi) {
      final api = _api;
      if (api is HttpVisitorApi) {
        api.close();
      }
    }
    super.dispose();
  }

  Future<void> _loadFeedbacks() async {
    final token = _token;
    final api = _api;
    if (token == null || api == null) {
      setState(() => _loading = false);
      return;
    }

    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await api.loadUserFeedbacks(
        token: token,
        skip: 0,
        limit: 100,
        includeInactive: true,
      );

      if (!mounted || generation != _requestGeneration) return;

      setState(() {
        _feedbacks = page.items;
        _loading = false;
      });

      _loadArtifactTitles(api);
    } on VisitorApiException catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      final strings = AppStrings.of(context);
      setState(() {
        _loading = false;
        _error = strings.visitorApiError(e.statusCode);
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      final strings = AppStrings.of(context);
      setState(() {
        _loading = false;
        _error = strings.feedbackNetworkError;
      });
    }
  }

  Future<void> _loadArtifactTitles(VisitorApi api) async {
    final language = AppStrings.of(context).locale.languageCode;
    try {
      final artifactsPage = await api.loadArtifacts(
        languageCode: language,
        skip: 0,
        limit: 100,
      );
      if (!mounted) return;
      final map = <String, String>{};
      for (final a in artifactsPage.items) {
        if (a.title != null) {
          map[a.id] = a.title!;
        }
      }
      setState(() {
        _artifactTitles = map;
      });
    } catch (_) {
      // Optional artifact title decoration; ignore failures
    }
  }

  void _openEditModal(VisitorFeedback feedback) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditFeedbackSheet(
        feedback: feedback,
        artifactTitle: _artifactTitles[feedback.artifactId],
        api: _api,
        token: _token,
        onSuccess: (updated) {
          setState(() {
            _feedbacks = _feedbacks.map((f) => f.id == updated.id ? updated : f).toList();
          });
          final strings = AppStrings.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.feedbackUpdateSuccess),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final isEn = strings.isEnglish;

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        title: Text(
          strings.myFeedbacksTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: HeritagePalette.primaryNavy,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: HeritagePalette.primaryNavy,
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: _buildBody(strings, theme, isEn),
    );
  }

  Widget _buildBody(AppStrings strings, ThemeData theme, bool isEn) {
    if (_token == null) {
      return _buildGuestView(strings, theme, isEn);
    }

    if (_loading && _feedbacks.isEmpty) {
      return const Center(
        key: Key('my-feedbacks-loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null && _feedbacks.isEmpty) {
      return Center(
        key: const Key('my-feedbacks-error'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: AppSpacing.medium),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: HeritagePalette.secondaryText),
              ),
              const SizedBox(height: AppSpacing.medium),
              FilledButton.icon(
                key: const Key('my-feedbacks-retry'),
                onPressed: _loadFeedbacks,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isEn ? 'Retry' : 'Thử lại'),
                style: FilledButton.styleFrom(
                  backgroundColor: HeritagePalette.primaryNavy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_feedbacks.isEmpty) {
      return Center(
        key: const Key('my-feedbacks-empty'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: HeritagePalette.actionBlue.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rate_review_outlined, size: 36, color: HeritagePalette.actionBlue),
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                strings.feedbackEmptyTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
              const SizedBox(height: AppSpacing.xSmall),
              Text(
                strings.feedbackEmptySubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: HeritagePalette.secondaryText),
              ),
              const SizedBox(height: AppSpacing.large),
              FilledButton.icon(
                key: const Key('my-feedbacks-explore'),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.museum_outlined, size: 18),
                label: Text(strings.feedbackExploreArtifacts),
                style: FilledButton.styleFrom(
                  backgroundColor: HeritagePalette.primaryNavy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeedbacks,
      child: ListView.separated(
        key: const Key('my-feedbacks-list'),
        padding: const EdgeInsets.all(AppSpacing.medium),
        itemCount: _feedbacks.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.small),
        itemBuilder: (context, index) {
          final feedback = _feedbacks[index];
          return _FeedbackCard(
            feedback: feedback,
            artifactTitle: _artifactTitles[feedback.artifactId],
            strings: strings,
            theme: theme,
            onEdit: () => _openEditModal(feedback),
          );
        },
      ),
    );
  }

  Widget _buildGuestView(AppStrings strings, ThemeData theme, bool isEn) {
    return Center(
      key: const Key('my-feedbacks-guest'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: HeritagePalette.primaryNavy.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 36, color: HeritagePalette.primaryNavy),
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              isEn ? 'Sign in to view your reviews' : 'Đăng nhập để xem đánh giá',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: HeritagePalette.primaryNavy,
              ),
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Text(
              isEn
                  ? 'Your reviews and ratings will be synced with your account.'
                  : 'Đánh giá và nhận xét của bạn sẽ được đồng bộ theo tài khoản.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: HeritagePalette.secondaryText),
            ),
            const SizedBox(height: AppSpacing.large),
            FilledButton.icon(
              key: const Key('my-feedbacks-login-button'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              icon: const Icon(Icons.login_rounded, size: 18),
              label: Text(isEn ? 'Sign In' : 'Đăng nhập'),
              style: FilledButton.styleFrom(
                backgroundColor: HeritagePalette.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.feedback,
    required this.artifactTitle,
    required this.strings,
    required this.theme,
    required this.onEdit,
  });

  final VisitorFeedback feedback;
  final String? artifactTitle;
  final AppStrings strings;
  final ThemeData theme;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: HeritagePalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Artifact Title & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  artifactTitle ?? 'Hiện vật #${feedback.artifactId.substring(0, 8)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: HeritagePalette.primaryNavy,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xSmall),
              _buildStatusChip(feedback.status, strings),
            ],
          ),
          const SizedBox(height: AppSpacing.small),

          // Rating Stars
          Row(
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < feedback.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 20,
                  color: index < feedback.rating ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
                );
              }),
              const SizedBox(width: 8),
              Text(
                '${feedback.rating}/5',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),

          // Comment
          if (feedback.comment != null && feedback.comment!.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(AppRadii.small),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Text(
                feedback.comment!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: HeritagePalette.bodyText,
                  height: 1.4,
                ),
              ),
            )
          else
            Text(
              strings.feedbackNoComment,
              style: theme.textTheme.bodySmall?.copyWith(
                color: HeritagePalette.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: AppSpacing.small),

          // Footer: Timestamp & Edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(feedback.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: HeritagePalette.secondaryText,
                ),
              ),
              OutlinedButton.icon(
                key: Key('edit-feedback-${feedback.id}'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: Text(strings.feedbackEditTitle),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HeritagePalette.primaryNavy,
                  side: BorderSide(color: HeritagePalette.border),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, AppStrings strings) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status.toLowerCase()) {
      case 'approved':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        icon = Icons.check_circle_outline_rounded;
        label = strings.feedbackStatusApproved;
        break;
      case 'hidden':
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        icon = Icons.visibility_off_outlined;
        label = strings.feedbackStatusHidden;
        break;
      case 'pending':
      default:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        icon = Icons.schedule_rounded;
        label = strings.feedbackStatusPending;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

class _EditFeedbackSheet extends StatefulWidget {
  const _EditFeedbackSheet({
    required this.feedback,
    required this.artifactTitle,
    required this.api,
    required this.token,
    required this.onSuccess,
  });

  final VisitorFeedback feedback;
  final String? artifactTitle;
  final VisitorApi? api;
  final AuthToken? token;
  final ValueChanged<VisitorFeedback> onSuccess;

  @override
  State<_EditFeedbackSheet> createState() => _EditFeedbackSheetState();
}

class _EditFeedbackSheetState extends State<_EditFeedbackSheet> {
  late int _rating;
  late final TextEditingController _commentController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rating = widget.feedback.rating;
    _commentController = TextEditingController(text: widget.feedback.comment ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final api = widget.api;
    final token = widget.token;
    final strings = AppStrings.of(context);

    if (api == null || token == null) {
      setState(() => _error = strings.feedbackApiUnavailable);
      return;
    }

    if (_rating < 1 || _rating > 5) {
      setState(() => _error = strings.feedbackRatingRequired);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await api.updateFeedback(
        token: token,
        feedbackId: widget.feedback.id,
        rating: _rating,
        comment: _commentController.text,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess(updated);
    } on VisitorApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = strings.visitorApiError(e.statusCode);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = strings.feedbackUpdateError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.large,
        AppSpacing.medium,
        AppSpacing.large,
        AppSpacing.large + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.medium),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Title
            Text(
              strings.feedbackEditTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: HeritagePalette.primaryNavy,
              ),
            ),
            if (widget.artifactTitle != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.artifactTitle!,
                style: theme.textTheme.bodySmall?.copyWith(color: HeritagePalette.secondaryText),
              ),
            ],
            const SizedBox(height: AppSpacing.medium),

            // Rating Stars Picker
            Text(
              strings.feedbackRatingLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: HeritagePalette.primaryNavy,
              ),
            ),
            const SizedBox(height: AppSpacing.xSmall),
            Row(
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  key: Key('edit-rating-star-$starValue'),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    starValue <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: starValue <= _rating ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
                  ),
                  onPressed: _saving ? null : () => setState(() => _rating = starValue),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.medium),

            // Comment TextField
            Text(
              strings.feedbackCommentLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: HeritagePalette.primaryNavy,
              ),
            ),
            const SizedBox(height: AppSpacing.xSmall),
            TextField(
              key: const Key('edit-feedback-comment-field'),
              controller: _commentController,
              enabled: !_saving,
              maxLength: 2000,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                hintText: strings.feedbackCommentHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  borderSide: BorderSide(color: HeritagePalette.border),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: AppSpacing.xSmall),

            // Notice about moderation
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(AppRadii.small),
                border: Border.all(color: const Color(0xFFFEF3C7)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.feedbackEditNotice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF92400E),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Error display
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.small),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.medium),

            // Action Buttons (Cancel / Save)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: HeritagePalette.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    child: Text(
                      strings.isEnglish ? 'Cancel' : 'Hủy',
                      style: TextStyle(color: HeritagePalette.secondaryText),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: FilledButton(
                    key: const Key('feedback-save-button'),
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: HeritagePalette.primaryNavy,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(strings.feedbackSaveChanges),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
