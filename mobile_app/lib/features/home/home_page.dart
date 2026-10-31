import 'package:flutter/material.dart';

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

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
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
            Expanded(
              child: Text(
                'Smart Heritage',
                maxLines: 1,
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
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isEn
                    ? 'Search heritage, artifacts...'
                    : 'Tìm kiếm di sản, hiện vật...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: HeritagePalette.secondaryText,
                ),
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
            const SizedBox(height: AppSpacing.large),
            _buildHeroBanner(isEn, theme),
            const SizedBox(height: AppSpacing.large),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEn ? 'Featured Destinations' : 'Địa điểm nổi bật',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: HeritagePalette.primaryNavy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                TextButton(
                  onPressed: () {},
                  child: Text(isEn ? 'See All' : 'Xem tất cả'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: mockLocations.length,
                itemBuilder: (context, index) {
                  final locationObj = mockLocations[index];

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              HeritageDetailPage(location: locationObj),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    child: Container(
                      width: 220,
                      margin: const EdgeInsets.only(right: 14),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        border: Border.all(color: HeritagePalette.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
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
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 120,
                                  color: HeritagePalette.background,
                                  child: const Center(
                                    child: Icon(
                                      Icons.account_balance_outlined,
                                      color: HeritagePalette.secondaryText,
                                      size: 40,
                                    ),
                                  ),
                                );
                              },
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
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: HeritagePalette.secondaryText,
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        locationObj.city,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  HeritagePalette.secondaryText,
                                            ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    Text(
                                      ' ${locationObj.rating}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
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
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.large),
            Text(
              isEn ? 'Highlighted Artifacts' : 'Hiện vật tiêu biểu',
              style: theme.textTheme.titleMedium?.copyWith(
                color: HeritagePalette.primaryNavy,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            ...sampleArtifacts.map((artifact) {
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.small),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.xSmall + 2),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    child: Image.network(
                      artifact.imageUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 54,
                          height: 54,
                          color: HeritagePalette.background,
                          child: const Icon(
                            Icons.account_balance_outlined,
                            color: HeritagePalette.secondaryText,
                          ),
                        );
                      },
                    ),
                  ),
                  title: Text(
                    artifact.getTitle(isEn ? 'en' : 'vi'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: HeritagePalette.primaryNavy,
                    ),
                  ),
                  subtitle: Text(
                    '${artifact.period} • ${artifact.location}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: HeritagePalette.secondaryText,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: HeritagePalette.secondaryText,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArtifactDetailPage(artifact: artifact),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
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
        constraints: const BoxConstraints(minHeight: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.large),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HeritagePalette.primaryNavy, Color(0xFF2C3E75)],
          ),
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
                  opacity: 0.35,
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
                  Text(
                    isEn
                        ? 'Explore Smart Heritage'
                        : 'Trải nghiệm Smart Heritage',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      isEn
                          ? 'Automatic iBeacon audio guide system.'
                          : 'Tự động phát thuyết minh iBeacon khi tham quan.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
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
}
