import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../shared/config/api_config.dart';
import '../../theme/app_theme.dart';
import '../data/visitor_api_service.dart';
import '../sites/site_detail_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, this.siteApi});

  final SiteApi? siteApi;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final SiteApi _siteApi;
  HttpVisitorApi? _ownedApi;
  List<VisitorSite> _sites = const [];
  bool _loading = true;
  bool _failed = false;
  int _generation = 0;
  String? _languageCode;

  @override
  void initState() {
    super.initState();
    if (widget.siteApi case final api?) {
      _siteApi = api;
    } else {
      final api = HttpVisitorApi(baseUrl: ApiConfig.baseUrl);
      _siteApi = api;
      _ownedApi = api;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'vi';
    if (_languageCode == code) return;
    _languageCode = code;
    unawaited(_loadSites());
  }

  Future<void> _loadSites() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await _siteApi.loadSites(
        languageCode: _languageCode ?? 'vi',
        skip: 0,
        limit: 100,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _sites = page.items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _ownedApi?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        title: Text(isEn ? 'Heritage Sites' : 'Địa điểm di sản'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: HeritagePalette.primaryNavy,
        actions: [
          IconButton(
            tooltip: isEn ? 'Refresh sites' : 'Tải lại địa điểm',
            onPressed: _loading ? null : _loadSites,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(AppSpacing.medium),
            padding: const EdgeInsets.all(AppSpacing.medium),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.medium),
              border: Border.all(color: HeritagePalette.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.map_outlined,
                  color: HeritagePalette.primaryNavy,
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Text(
                    isEn
                        ? 'Map tiles and live location are not connected yet. The list below uses Sites returned by the backend.'
                        : 'Bản đồ nền và vị trí trực tiếp chưa được kết nối. Danh sách bên dưới lấy Site từ Backend.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed
                ? _buildMessage(
                    context,
                    isEn
                        ? 'Could not load Sites. Check your connection and retry.'
                        : 'Không tải được địa điểm. Hãy kiểm tra kết nối rồi thử lại.',
                    action: OutlinedButton.icon(
                      onPressed: _loadSites,
                      icon: const Icon(Icons.refresh),
                      label: Text(isEn ? 'Retry' : 'Thử lại'),
                    ),
                  )
                : _sites.isEmpty
                ? _buildMessage(
                    context,
                    isEn
                        ? 'No heritage Sites are available yet.'
                        : 'Chưa có địa điểm di sản nào.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.medium,
                      0,
                      AppSpacing.medium,
                      AppSpacing.large,
                    ),
                    itemCount: _sites.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.small),
                    itemBuilder: (context, index) =>
                        _buildSiteTile(context, _sites[index], isEn, theme),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context,
    String message, {
    Widget? action,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.small),
            action,
          ],
        ],
      ),
    ),
  );

  Widget _buildSiteTile(
    BuildContext context,
    VisitorSite site,
    bool isEn,
    ThemeData theme,
  ) {
    final hasCoordinates = site.latitude != null && site.longitude != null;
    final address = site.address?.trim();
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: HeritagePalette.background,
          child: Icon(Icons.place_outlined, color: HeritagePalette.primaryNavy),
        ),
        title: Text(
          site.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: HeritagePalette.primaryNavy,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (site.isFallback)
              Text(AppStrings.of(context).siteTranslationFallback),
            if (address?.isNotEmpty == true) Text(address!),
            Text(
              hasCoordinates
                  ? '${site.latitude}, ${site.longitude}'
                  : (isEn ? 'Coordinates unavailable' : 'Chưa có tọa độ'),
            ),
          ],
        ),
        isThreeLine: address?.isNotEmpty == true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SiteDetailPage(site: site, siteApi: _siteApi),
          ),
        ),
      ),
    );
  }
}
