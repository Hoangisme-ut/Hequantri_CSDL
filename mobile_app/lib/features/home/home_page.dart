import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import '../artifacts/artifact.dart';
import '../artifacts/artifact_detail_page.dart';
import '../data/heritage_repository.dart';
import '../heritage/beacon_simulation_page.dart';
import '../heritage/heritage_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final filteredLocations = mockLocations.where((loc) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = loc.getName(isEn ? 'en' : 'vi').toLowerCase();
      final city = loc.city.toLowerCase();
      final address = loc.address.toLowerCase();
      return name.contains(q) || city.contains(q) || address.contains(q);
    }).toList();

    final filteredArtifacts = sampleArtifacts.where((art) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final title = art.getTitle(isEn ? 'en' : 'vi').toLowerCase();
      final period = art.period.toLowerCase();
      final location = art.location.toLowerCase();
      final category = art.category.toLowerCase();
      return title.contains(q) ||
          period.contains(q) ||
          location.contains(q) ||
          category.contains(q);
    }).toList();

    final hasNoResults = _searchQuery.isNotEmpty &&
        filteredLocations.isEmpty &&
        filteredArtifacts.isEmpty;

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: HeritagePalette.primaryNavy,
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: const Icon(
                Icons.account_balance,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Smart Heritage',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: HeritagePalette.primaryNavy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isEn ? 'iBeacon Smart Tour' : 'Thuyết minh iBeacon',
            icon: const Icon(
              Icons.bluetooth_searching,
              color: HeritagePalette.primaryNavy,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BeaconSimulationPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_none_outlined,
              color: HeritagePalette.primaryNavy,
            ),
            tooltip: isEn ? 'Notifications' : 'Thông báo',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isEn
                        ? 'No new notifications'
                        : 'Chưa có thông báo mới',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: isEn
                      ? 'Search heritage, artifacts...'
                      : 'Tìm kiếm di sản, hiện vật...',
                  hintStyle: const TextStyle(
                    color: HeritagePalette.secondaryText,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: HeritagePalette.secondaryText,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: HeritagePalette.secondaryText,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    borderSide: const BorderSide(color: HeritagePalette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    borderSide: const BorderSide(color: HeritagePalette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    borderSide: const BorderSide(
                      color: HeritagePalette.actionBlue,
                      width: 1.8,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.large),

            // Empty State when search returns no match
            if (hasNoResults)
              _buildEmptySearchResults(theme, isEn)
            else ...[
              // Hero Banner
              _buildHeroBanner(isEn, theme),
              const SizedBox(height: AppSpacing.large),

              // Featured Destinations
              if (filteredLocations.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        isEn ? 'Featured Destinations' : 'Địa điểm nổi bật',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: HeritagePalette.primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: HeritagePalette.actionBlue,
                      ),
                      child: Text(isEn ? 'See All' : 'Xem tất cả'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.small),

                // Horizontal Destination Cards
                SizedBox(
                  height: 215,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredLocations.length,
                    itemBuilder: (context, index) {
                      final locationObj = filteredLocations[index];
                      return _buildDestinationCard(
                        context,
                        locationObj,
                        isEn,
                        theme,
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
              ],

              // Highlighted Artifacts
              if (filteredArtifacts.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        isEn ? 'Highlighted Artifacts' : 'Hiện vật tiêu biểu',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: HeritagePalette.primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${filteredArtifacts.length} ${isEn ? 'items' : 'hiện vật'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: HeritagePalette.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.small),

                // Artifact List
                ...filteredArtifacts.map((artifact) {
                  return _buildArtifactCard(context, artifact, isEn, theme);
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchResults(ThemeData theme, bool isEn) {
    return Container(
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
            decoration: BoxDecoration(
              color: HeritagePalette.background,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 32,
              color: HeritagePalette.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            isEn ? 'No results found' : 'Không tìm thấy kết quả',
            style: theme.textTheme.titleMedium?.copyWith(
              color: HeritagePalette.primaryNavy,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xSmall),
          Text(
            isEn
                ? 'No heritage sites or artifacts match "$_searchQuery".'
                : 'Không có di tích hay hiện vật nào khớp với "$_searchQuery".',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: HeritagePalette.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          OutlinedButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(isEn ? 'Clear search' : 'Xóa tìm kiếm'),
            style: OutlinedButton.styleFrom(
              foregroundColor: HeritagePalette.actionBlue,
              side: const BorderSide(color: HeritagePalette.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(bool isEn, ThemeData theme) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.large),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BeaconSimulationPage()),
        );
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 156),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.large),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HeritagePalette.primaryNavy, Color(0xFF2C3970)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x181E2A5A),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              top: 0,
              width: 170,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(AppRadii.large),
                  bottomRight: Radius.circular(AppRadii.large),
                ),
                child: Opacity(
                  opacity: 0.32,
                  child: Image.asset(
                    'assets/images/onboarding/'
                    'welcome_temple_of_literature.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sensors,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isEn ? 'iBeacon Smart Tour' : 'Thuyết minh tự động',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isEn
                        ? 'Explore Smart Heritage'
                        : 'Trải nghiệm Smart Heritage',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEn
                        ? 'Automatic iBeacon audio guide when visiting sites.'
                        : 'Tự động phát thuyết minh iBeacon khi tham quan di tích.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.35,
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

  Widget _buildDestinationCard(
    BuildContext context,
    HeritageLocation locationObj,
    bool isEn,
    ThemeData theme,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HeritageDetailPage(location: locationObj),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Container(
          width: 220,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            border: Border.all(color: HeritagePalette.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.medium),
                ),
                child: Image.asset(
                  locationObj.imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    color: HeritagePalette.background,
                    child: const Center(
                      child: Icon(
                        Icons.account_balance_outlined,
                        color: HeritagePalette.secondaryText,
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.small),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationObj.getName(isEn ? 'en' : 'vi'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HeritagePalette.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: HeritagePalette.secondaryText,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            locationObj.city,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: HeritagePalette.secondaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${locationObj.rating}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtifactCard(
    BuildContext context,
    Artifact artifact,
    bool isEn,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: HeritagePalette.border),
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
                builder: (_) => ArtifactDetailPage(artifact: artifact),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.small),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: Image.network(
                    artifact.imageUrl,
                    width: 66,
                    height: 66,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 66,
                      height: 66,
                      color: HeritagePalette.background,
                      child: const Icon(
                        Icons.museum_outlined,
                        color: HeritagePalette.secondaryText,
                        size: 28,
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
                          AppStrings.of(context)
                              .artifactCategory(artifact.category),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: HeritagePalette.actionBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artifact.getTitle(isEn ? 'en' : 'vi'),
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
                            Icons.schedule_rounded,
                            size: 13,
                            color: HeritagePalette.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${artifact.period} • ${artifact.location}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: HeritagePalette.secondaryText,
                                fontSize: 12,
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
                const SizedBox(width: 8),
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
}
