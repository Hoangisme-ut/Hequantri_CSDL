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

  // Disable network map tiles in widget tests only.
  @visibleForTesting
  final bool enableMapTiles;

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

  LatLng? _coordinates(VisitorSite site) {
    final latitude = site.latitude;
    final longitude = site.longitude;

    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;

    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;

    return LatLng(latitude, longitude);
  }

  void _openSite(VisitorSite site) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SiteDetailPage(site: site, siteApi: _siteApi),
      ),
    );
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
        height: 290,
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
                      onPressed: () => _openSite(site),
                      icon: const Icon(
                        Icons.location_on,
                        size: 38,
                        color: HeritagePalette.primaryNavy,
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
