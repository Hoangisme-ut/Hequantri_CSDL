import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_session.dart';
import '../auth/auth_service.dart';
import '../data/visitor_api_service.dart';

class ArtifactFeedbackForm extends StatefulWidget {
  const ArtifactFeedbackForm({
    super.key,
    required this.artifactId,
    required this.api,
  });

  final String artifactId;
  final VisitorApi? api;

  @override
  State<ArtifactFeedbackForm> createState() => _ArtifactFeedbackFormState();
}

class _ArtifactFeedbackFormState extends State<ArtifactFeedbackForm> {
  final _commentController = TextEditingController();
  AuthToken? _observedToken;
  bool _hasObservedToken = false;
  bool _submitting = false;
  bool _submitted = false;
  bool _alreadySubmitted = false;
  bool _isEditing = false;
  String? _submittedStatus;
  VisitorFeedback? _submittedFeedback;
  int _rating = 0;
  int _requestGeneration = 0;
  String? _error;

  @override
  void didUpdateWidget(covariant ArtifactFeedbackForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artifactId != widget.artifactId) {
      // Invalidate an in-flight request before resetting visible state. The
      // HTTP request may finish normally, but its result must not affect the
      // form now showing a different artifact.
      _requestGeneration++;
      _rating = 0;
      _commentController.clear();
      _submitting = false;
      _submitted = false;
      _alreadySubmitted = false;
      _isEditing = false;
      _submittedStatus = null;
      _submittedFeedback = null;
      _error = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = AuthSessionScope.maybeOf(context)?.readToken();
    if (_hasObservedToken && !_sameToken(_observedToken, token)) {
      _requestGeneration++;
      _rating = 0;
      _commentController.clear();
      _submitting = false;
      _submitted = false;
      _alreadySubmitted = false;
      _isEditing = false;
      _submittedStatus = null;
      _submittedFeedback = null;
      _error = null;
    }
    _observedToken = token;
    _hasObservedToken = true;
  }

  bool _sameToken(AuthToken? first, AuthToken? second) {
    if (first == null || second == null) return first == second;
    return first.accessToken == second.accessToken &&
        first.tokenType.toLowerCase() == second.tokenType.toLowerCase();
  }

  String? _errorFor(VisitorApiException error, AppStrings strings) {
    switch (error.statusCode) {
      case 401:
        return strings.feedbackSignInRequired;
      case 403:
        return strings.feedbackPermissionError;
      case 404:
        return strings.feedbackArtifactMissing;
      case 409:
        return strings.feedbackAlreadySubmitted;
      case 422:
        return strings.feedbackValidationError;
      default:
        if (error.statusCode == null) return strings.feedbackNetworkError;
        if (error.statusCode! >= 500) return strings.feedbackServerError;
        return strings.feedbackUnexpectedError;
    }
  }

  Future<void> _submit(AuthToken token, AppStrings strings) async {
    if (_submitting || _submitted || _alreadySubmitted) return;
    if (_rating < 1 || _rating > 5) {
      setState(() => _error = strings.feedbackRatingRequired);
      return;
    }
    if (!_uuidPattern.hasMatch(widget.artifactId)) {
      setState(() => _error = strings.feedbackValidationError);
      return;
    }
    final api = widget.api;
    if (api == null) {
      setState(() => _error = strings.feedbackApiUnavailable);
      return;
    }

    final generation = ++_requestGeneration;
    final session = AuthSessionScope.maybeOf(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final feedback = await api.submitFeedback(
        token: token,
        artifactId: widget.artifactId,
        rating: _rating,
        comment: _commentController.text,
      );
      if (!_isCurrentRequest(generation, token, session)) return;
      if (feedback.artifactId != widget.artifactId ||
          !{'pending', 'approved'}.contains(feedback.status)) {
        throw const FormatException('Unexpected Feedback response.');
      }
      setState(() {
        _submitted = true;
        _submittedStatus = feedback.status;
        _submittedFeedback = feedback;
      });
    } on VisitorApiException catch (error) {
      if (!_isCurrentRequest(generation, token, session)) return;
      setState(() {
        _alreadySubmitted = error.statusCode == 409;
        _error = _errorFor(error, strings);
      });
    } catch (_) {
      if (!_isCurrentRequest(generation, token, session)) return;
      setState(() => _error = strings.feedbackUnexpectedError);
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _update(AuthToken token, AppStrings strings) async {
    if (_submitting) return;
    if (_rating < 1 || _rating > 5) {
      setState(() => _error = strings.feedbackRatingRequired);
      return;
    }
    final api = widget.api;
    final feedbackId = _submittedFeedback?.id;
    if (api == null || feedbackId == null) {
      setState(() => _error = strings.feedbackApiUnavailable);
      return;
    }

    final generation = ++_requestGeneration;
    final session = AuthSessionScope.maybeOf(context);
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final updated = await api.updateFeedback(
        token: token,
        feedbackId: feedbackId,
        rating: _rating,
        comment: _commentController.text,
      );
      if (!_isCurrentRequest(generation, token, session)) return;
      setState(() {
        _submitted = true;
        _submittedStatus = updated.status;
        _submittedFeedback = updated;
        _isEditing = false;
      });
    } on VisitorApiException catch (error) {
      if (!_isCurrentRequest(generation, token, session)) return;
      setState(() {
        _error = _errorFor(error, strings);
      });
    } catch (_) {
      if (!_isCurrentRequest(generation, token, session)) return;
      setState(() => _error = strings.feedbackUnexpectedError);
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _isCurrentRequest(
    int generation,
    AuthToken token,
    AuthSession? session,
  ) =>
      mounted &&
      generation == _requestGeneration &&
      _sameToken(session?.readToken(), token);

  @override
  void dispose() {
    _requestGeneration++;
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final token = AuthSessionScope.maybeOf(context)?.readToken();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const ValueKey('artifact-feedback-form'),
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: HeritagePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.feedbackTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: HeritagePalette.primaryNavy,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xSmall),
          if (_submitted && !_isEditing) ...[
            _StatusMessage(
              key: const ValueKey('feedback-submitted'),
              text: _submittedStatus == 'approved'
                  ? strings.feedbackSubmittedApproved
                  : strings.feedbackSubmittedPending,
              color: colors.primary,
            ),
            if (_submittedFeedback != null) ...[
              const SizedBox(height: AppSpacing.xSmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < _submittedFeedback!.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 20,
                        color: index < _submittedFeedback!.rating
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFD1D5DB),
                      );
                    }),
                  ),
                  TextButton.icon(
                    key: const ValueKey('feedback-edit-button'),
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                        _rating = _submittedFeedback!.rating;
                        _commentController.text = _submittedFeedback!.comment ?? '';
                        _error = null;
                      });
                    },
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text(strings.feedbackEditTitle),
                  ),
                ],
              ),
            ],
          ] else if (_isEditing && token != null) ...[
            Text(strings.feedbackEditTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.small),
            Text(strings.feedbackRatingLabel, style: theme.textTheme.labelLarge),
            Row(
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  key: ValueKey('edit-feedback-rating-$value'),
                  tooltip: '$value/5',
                  onPressed: _submitting ? null : () => setState(() => _rating = value),
                  icon: Icon(
                    value <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: value <= _rating ? const Color(0xFFF4B400) : HeritagePalette.secondaryText,
                    size: 30,
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.xSmall),
            TextField(
              key: const ValueKey('edit-feedback-comment'),
              controller: _commentController,
              maxLength: 2000,
              maxLines: 4,
              minLines: 2,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: strings.feedbackCommentLabel,
                hintText: strings.feedbackCommentHint,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              _StatusMessage(text: _error!, color: colors.error),
              const SizedBox(height: AppSpacing.xSmall),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => setState(() => _isEditing = false),
                    child: Text(strings.isEnglish ? 'Cancel' : 'Hủy'),
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('feedback-update-submit'),
                    onPressed: _submitting ? null : () => _update(token, strings),
                    icon: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_rounded),
                    label: Text(strings.feedbackSaveChanges),
                  ),
                ),
              ],
            ),
          ] else if (token == null)
            _StatusMessage(
              key: const ValueKey('feedback-sign-in-required'),
              text: strings.feedbackSignInRequired,
              color: HeritagePalette.secondaryText,
            )
          else ...[
            Text(strings.feedbackPrompt, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.small),
            Text(
              strings.feedbackRatingLabel,
              style: theme.textTheme.labelLarge,
            ),
            Row(
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  key: ValueKey('feedback-rating-$value'),
                  tooltip: '$value/5',
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                          _rating = value;
                          _error = null;
                        }),
                  icon: Icon(
                    value <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: value <= _rating
                        ? const Color(0xFFF4B400)
                        : HeritagePalette.secondaryText,
                    size: 30,
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.xSmall),
            TextField(
              key: const ValueKey('feedback-comment'),
              controller: _commentController,
              maxLength: 2000,
              maxLines: 4,
              minLines: 2,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: strings.feedbackCommentLabel,
                hintText: strings.feedbackCommentHint,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              _StatusMessage(text: _error!, color: colors.error),
              const SizedBox(height: AppSpacing.xSmall),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('feedback-submit'),
                onPressed: _submitting ? null : () => _submit(token, strings),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _submitting
                      ? strings.feedbackSubmitting
                      : strings.feedbackSubmit,
                ),
              ),
            ),
          ],
          if (_error != null && (token == null || _submitted))
            _StatusMessage(text: _error!, color: colors.error),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
    ),
  );
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
