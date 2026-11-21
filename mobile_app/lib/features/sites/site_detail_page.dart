import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import '../data/visitor_api_service.dart';

class SiteDetailPage extends StatefulWidget {
  const SiteDetailPage({super.key, required this.site, required this.siteApi});

  final VisitorSite site;
  final SiteApi siteApi;

  @override
  State<SiteDetailPage> createState() => _SiteDetailPageState();
}

class _SiteDetailPageState extends State<SiteDetailPage> {
  late VisitorSite _site = widget.site;

  bool _loading = true;
  int? _errorStatusCode;
  bool _genericError = false;
  int _requestGeneration = 0;
  String? _languageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final code = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'vi';

    if (_languageCode == code) return;

    _languageCode = code;
    _loadSite();
  }

  Future<void> _loadSite() async {
    final generation = ++_requestGeneration;

    setState(() {
      _loading = true;
      _errorStatusCode = null;
      _genericError = false;
    });

    try {
      final site = await widget.siteApi.loadSite(
        siteId: widget.site.id,
        languageCode: _languageCode ?? 'vi',
      );

      if (!mounted || generation != _requestGeneration) return;

      setState(() {
        _site = site;
        _loading = false;
      });
    } on VisitorApiException catch (error) {
      if (!mounted || generation != _requestGeneration) return;

      setState(() {
        _errorStatusCode = error.statusCode;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;

      setState(() {
        _genericError = true;
        _loading = false;
      });
    }
  }

  Widget _buildCoverImage(bool isEnglish) {
    final imageUrl = _site.coverImageUrl?.trim() ?? '';
    final uri = Uri.tryParse(imageUrl);

    final hasValidUrl =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    if (!hasValidUrl) {
      return _imagePlaceholder(
        isEnglish ? 'No heritage image available' : 'Chưa có ảnh di sản',
      );
    }

    return Image.network(
      imageUrl,
      key: ValueKey('site-cover-$imageUrl'),
      width: double.infinity,
      height: 230,
      fit: BoxFit.cover,

      // Loading image.
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }

        final total = progress.expectedTotalBytes;
        final value = total != null && total > 0
            ? progress.cumulativeBytesLoaded / total
            : null;

        return Container(
          width: double.infinity,
          height: 230,
          color: HeritagePalette.primaryNavy.withValues(alpha: 0.06),
          alignment: Alignment.center,
          child: CircularProgressIndicator(value: value),
        );
      },

      // Image URL missing, blocked, or unavailable.
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Failed to load site image: $error');

        return _imagePlaceholder(
          isEnglish
              ? 'Could not load heritage image'
              : 'Không tải được ảnh di sản',
        );
      },
    );
  }

  Widget _imagePlaceholder(String message) {
    return Container(
      width: double.infinity,
      height: 230,
      color: HeritagePalette.primaryNavy.withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.account_balance_outlined,
            size: 64,
            color: HeritagePalette.secondaryText,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HeritagePalette.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isEnglish = strings.isEnglish;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        title: Text(isEnglish ? 'Site details' : 'Chi tiết địa điểm'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          // Heritage cover image.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.large),
            child: _buildCoverImage(isEnglish),
          ),

          const SizedBox(height: AppSpacing.medium),

          // Heritage site name.
          Text(
            _site.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: HeritagePalette.primaryNavy,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (_loading) ...[
            const SizedBox(height: AppSpacing.small),
            const LinearProgressIndicator(),
          ],

          // Language fallback notice.
          if (_site.isFallback) ...[
            const SizedBox(height: AppSpacing.small),
            Text(
              strings.siteTranslationFallback,
              style: theme.textTheme.bodySmall?.copyWith(
                color: HeritagePalette.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // API error and retry.
          if (_errorStatusCode != null || _genericError) ...[
            const SizedBox(height: AppSpacing.medium),
            Container(
              padding: const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                border: Border.all(color: HeritagePalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _genericError
                        ? (isEnglish
                              ? 'Could not refresh site details.'
                              : 'Không tải được chi tiết địa điểm.')
                        : strings.visitorApiError(_errorStatusCode),
                  ),
                  TextButton.icon(
                    onPressed: _loadSite,
                    icon: const Icon(Icons.refresh),
                    label: Text(isEnglish ? 'Retry' : 'Thử lại'),
                  ),
                ],
              ),
            ),
          ],

          // Site address.
          if (_site.address?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.medium),
            _detailRow(
              icon: Icons.location_on_outlined,
              label: isEnglish ? 'Address' : 'Địa chỉ',
              value: _site.address!,
              theme: theme,
            ),
          ],

          // Site description.
          if (_site.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.large),
            Text(
              isEnglish ? 'About this site' : 'Giới thiệu',
              style: theme.textTheme.titleMedium?.copyWith(
                color: HeritagePalette.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              _site.description!,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: HeritagePalette.actionBlue),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: HeritagePalette.secondaryText,
                ),
              ),
              Text(value, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
