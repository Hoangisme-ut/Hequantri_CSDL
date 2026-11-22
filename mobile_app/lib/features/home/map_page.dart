import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../shared/config/api_config.dart';
import '../../theme/app_theme.dart';
import '../data/visitor_api_service.dart';
import '../sites/site_detail_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, this.siteApi, this.enableMapTiles = true});

  final SiteApi? siteApi;

  // Disable network tile requests in widget tests.
  @visibleForTesting
  final bool enableMapTiles;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final SiteApi _siteApi;
  HttpVisitorApi? _ownedApi;

  List<VisitorSite> _sites = const [];
  VisitorSite? _selectedSite;

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

      VisitorSite? updatedSelection;
      final selectedId = _selectedSite?.id;

      for (final site in page.items) {
        if (site.id == selectedId) {
          updatedSelection = site;
          break;
        }
      }

      setState(() {
        _sites = page.items;
        _selectedSite = updatedSelection;
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

  LatLng? _coordinates(VisitorSite site) {
    final latitude = site.latitude;
    final longitude = site.longitude;

    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;

    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;

    return LatLng(latitude, longitude);
  }

  void _selectSite(VisitorSite site) {
    setState(() {
      _selectedSite = site;
    });
  }

  void _closeSelectedSite() {
    setState(() {
      _selectedSite = null;
    });
  }

  void _openSite(VisitorSite site) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SiteDetailPage(site: site, siteApi: _siteApi),
      ),
    );
  }

  Uri? _coverUri(VisitorSite site) {
    final raw = site.coverImageUrl?.trim();

    if (raw == null || raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);

    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }

    return uri;
  }

  Widget _buildMap(bool isEn) {
    final positionedSites = _sites
        .where((site) => _coordinates(site) != null)
        .toList();

    if (positionedSites.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: Text(
          isEn
              ? 'No heritage sites have valid map coordinates.'
              : 'Chưa có địa điểm di sản với tọa độ hợp lệ.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final points = positionedSites.map((site) => _coordinates(site)!).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: SizedBox(
        height: 270,
        child: FlutterMap(
          key: ValueKey(
            'heritage-map-${_languageCode ?? 'vi'}-${points.length}',
          ),
          options: MapOptions(
            initialCenter: points.first,
            initialZoom: 14,
            initialCameraFit: points.length > 1
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(45),
                    maxZoom: 15,
                  )
                : null,
          ),
          children: [
            if (widget.enableMapTiles)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
              ),

            MarkerLayer(
              markers: [
                for (final site in positionedSites)
                  Marker(
                    point: _coordinates(site)!,
                    width: 52,
                    height: 52,
                    child: IconButton(
                      key: ValueKey('map-marker-${site.id}'),
                      tooltip: site.name,
                      onPressed: () => _selectSite(site),
                      icon: Icon(
                        Icons.location_on,
                        size: _selectedSite?.id == site.id ? 44 : 38,
                        color: _selectedSite?.id == site.id
                            ? HeritagePalette.actionBlue
                            : HeritagePalette.primaryNavy,
                      ),
                    ),
                  ),
              ],
            ),

            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSiteCard(VisitorSite site, bool isEn, ThemeData theme) {
    final imageUri = _coverUri(site);

    return Card(
      key: const ValueKey('selected-site-card'),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 105,
                height: 115,
                child: imageUri == null
                    ? _mapImagePlaceholder()
                    : Image.network(
                        imageUri.toString(),
                        key: ValueKey('map-cover-${site.id}'),
                        width: 105,
                        height: 115,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;

                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Failed to load map site image: $error');
                          return _mapImagePlaceholder();
                        },
                      ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          site.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: HeritagePalette.primaryNavy,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          key: const ValueKey('close-site-card'),
                          tooltip: isEn ? 'Close' : 'Đóng',
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                          iconSize: 19,
                          icon: const Icon(Icons.close),
                          onPressed: _closeSelectedSite,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 15,
                        color: HeritagePalette.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          site.address?.trim().isNotEmpty == true
                              ? site.address!
                              : (isEn
                                    ? 'Address unavailable'
                                    : 'Chưa có địa chỉ'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  TextButton.icon(
                    key: const ValueKey('selected-site-details'),
                    onPressed: () => _openSite(site),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(isEn ? 'View details' : 'Xem chi tiết'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapImagePlaceholder() {
    return Container(
      color: HeritagePalette.primaryNavy.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: const Icon(
        Icons.account_balance_outlined,
        size: 36,
        color: HeritagePalette.secondaryText,
      ),
    );
  }

  Widget _buildMessage(BuildContext context, String message, {Widget? action}) {
    return Center(
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
  }

  Widget _buildSiteTile(
    BuildContext context,
    VisitorSite site,
    bool isEn,
    ThemeData theme,
  ) {
    final hasCoordinates = _coordinates(site) != null;
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
        onTap: () => _openSite(site),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        title: Text(isEn ? 'Heritage Map' : 'Bản đồ di sản'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? _buildMessage(
              context,
              isEn ? 'Could not load Sites. Check your connection and retry.' : 'Không tải được địa điểm. Hãy kiểm tra kết nối rồi thử lại.',
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: _buildMap(isEn),
                ),

                // Show preview when tapping a map marker.
                if (_selectedSite != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.medium,
                      0,
                      AppSpacing.medium,
                      AppSpacing.small,
                    ),
                    child: _buildSelectedSiteCard(_selectedSite!, isEn, theme),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEn
                              ? 'Explore heritage sites'
                              : 'Khám phá địa điểm di sản',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text('${_sites.length}'),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.medium,
                      0,
                      AppSpacing.medium,
                      AppSpacing.large,
                    ),
                    itemCount: _sites.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildSiteTile(context, _sites[index], isEn, theme),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _ownedApi?.close();
    super.dispose();
  }
}
