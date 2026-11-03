import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../theme/app_theme.dart';
import '../auth/login_page.dart';
import '../heritage/beacon_simulation_page.dart';
import 'history_page.dart';
import 'main_navigation_scaffold.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.onLocaleChanged, this.onLogout});

  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback? onLogout;

  void _showLanguageSelector(BuildContext context, bool isEn) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.large),
        ),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.medium,
              horizontal: AppSpacing.medium,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: HeritagePalette.border,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    isEn ? 'Select Language' : 'Chọn ngôn ngữ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: HeritagePalette.primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                ListTile(
                  leading: const Text('🇻🇳', style: TextStyle(fontSize: 24)),
                  title: Text(
                    'Tiếng Việt',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: !isEn
                          ? HeritagePalette.primaryNavy
                          : HeritagePalette.bodyText,
                    ),
                  ),
                  subtitle: Text(
                    isEn ? 'Vietnamese' : 'Ngôn ngữ mặc định',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: HeritagePalette.secondaryText,
                    ),
                  ),
                  trailing: !isEn
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: HeritagePalette.actionBlue,
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  onTap: () {
                    onLocaleChanged(const Locale('vi'));
                    LocaleController.instance.setLocale(const Locale('vi'));
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(height: 1, color: HeritagePalette.border),
                ListTile(
                  leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                  title: Text(
                    'English',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isEn
                          ? HeritagePalette.primaryNavy
                          : HeritagePalette.bodyText,
                    ),
                  ),
                  subtitle: Text(
                    isEn ? 'Default language' : 'Tiếng Anh',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: HeritagePalette.secondaryText,
                    ),
                  ),
                  trailing: isEn
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: HeritagePalette.actionBlue,
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  onTap: () {
                    onLocaleChanged(const Locale('en'));
                    LocaleController.instance.setLocale(const Locale('en'));
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: AppSpacing.small),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, bool isEn) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
          title: Text(
            isEn ? 'Log Out' : 'Đăng xuất',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HeritagePalette.primaryNavy,
            ),
          ),
          content: Text(
            isEn
                ? 'Are you sure you want to log out of the application?'
                : 'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HeritagePalette.bodyText,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                isEn ? 'Cancel' : 'Hủy',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: HeritagePalette.secondaryText,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (onLogout != null) {
                  onLogout!();
                } else {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => LoginPage(
                        onDemoContinue: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MainNavigationScaffold(
                                onLocaleChanged: onLocaleChanged,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    (route) => false,
                  );
                }
              },
              child: Text(
                isEn ? 'Log Out' : 'Đăng xuất',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final isEn = strings.isEnglish;

    return Scaffold(
      backgroundColor: HeritagePalette.background,
      appBar: AppBar(
        title: Text(
          isEn ? 'Profile & Settings' : 'Cá nhân & Cài đặt',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: HeritagePalette.primaryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.medium),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.large),
                border: Border.all(color: HeritagePalette.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: HeritagePalette.primaryNavy,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nguyễn Văn A',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: HeritagePalette.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'nguyenvana@gmail.com',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: HeritagePalette.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: HeritagePalette.background,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(color: HeritagePalette.border),
                          ),
                          child: Text(
                            isEn ? 'Demo Account' : 'Tài khoản Demo',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: HeritagePalette.actionBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.large),

            // Group 1: Heritage Experience
            _buildSectionHeader(
              isEn ? 'TOUR EXPERIENCE' : 'TRẢI NGHIỆM THAM QUAN',
              theme,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            _buildGroupCard(
              theme: theme,
              tiles: [
                _buildSettingTile(
                  icon: Icons.history_rounded,
                  title: isEn ? 'Visit History' : 'Lịch sử tham quan',
                  subtitle: isEn
                      ? 'Viewed heritage items'
                      : 'Hiện vật và di tích đã xem',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryPage()),
                    );
                  },
                  theme: theme,
                ),
                const Divider(
                  height: 1,
                  indent: 52,
                  color: HeritagePalette.border,
                ),
                _buildSettingTile(
                  icon: Icons.sensors_rounded,
                  title: isEn
                      ? 'iBeacon Smart Tour'
                      : 'Thuyết minh iBeacon tự động',
                  subtitle: isEn
                      ? 'Simulate audio guide detection'
                      : 'Mô phỏng nhận diện hiện vật tự động',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BeaconSimulationPage(),
                      ),
                    );
                  },
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.large),

            // Group 2: Account & Preferences
            _buildSectionHeader(
              isEn ? 'ACCOUNT & PREFERENCES' : 'TÀI KHOẢN & TÙY CHỌN',
              theme,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            _buildGroupCard(
              theme: theme,
              tiles: [
                _buildSettingTile(
                  icon: Icons.person_outline_rounded,
                  title: isEn ? 'Personal Information' : 'Thông tin cá nhân',
                  onTap: () => _showDemoNotice(context, isEn),
                  theme: theme,
                ),
                const Divider(
                  height: 1,
                  indent: 52,
                  color: HeritagePalette.border,
                ),
                _buildSettingTile(
                  icon: Icons.shield_outlined,
                  title: isEn ? 'Security' : 'Bảo mật',
                  onTap: () => _showDemoNotice(context, isEn),
                  theme: theme,
                ),
                const Divider(
                  height: 1,
                  indent: 52,
                  color: HeritagePalette.border,
                ),
                _buildSettingTile(
                  icon: Icons.language_rounded,
                  title: isEn ? 'Language' : 'Ngôn ngữ',
                  trailingText: isEn ? 'English' : 'Tiếng Việt',
                  onTap: () => _showLanguageSelector(context, isEn),
                  theme: theme,
                ),
                const Divider(
                  height: 1,
                  indent: 52,
                  color: HeritagePalette.border,
                ),
                _buildSettingTile(
                  icon: Icons.notifications_none_rounded,
                  title: isEn ? 'Notifications' : 'Thông báo',
                  onTap: () => _showDemoNotice(context, isEn),
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.large),

            // Group 3: Information & Support
            _buildSectionHeader(
              isEn ? 'SUPPORT & INFORMATION' : 'HỖ TRỢ & THÔNG TIN',
              theme,
            ),
            const SizedBox(height: AppSpacing.xSmall),
            _buildGroupCard(
              theme: theme,
              tiles: [
                _buildSettingTile(
                  icon: Icons.help_outline_rounded,
                  title: isEn ? 'Help & Support' : 'Trợ giúp & Hỗ trợ',
                  onTap: () => _showDemoNotice(context, isEn),
                  theme: theme,
                ),
                const Divider(
                  height: 1,
                  indent: 52,
                  color: HeritagePalette.border,
                ),
                _buildSettingTile(
                  icon: Icons.info_outline_rounded,
                  title: isEn ? 'About Application' : 'Giới thiệu ứng dụng',
                  trailingText: 'v1.0.0',
                  onTap: () => _showDemoNotice(context, isEn),
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xLarge),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, isEn),
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
                label: Text(
                  isEn ? 'Log Out' : 'Đăng xuất',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: HeritagePalette.secondaryText,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGroupCard({
    required ThemeData theme,
    required List<Widget> tiles,
  }) {
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: const BorderSide(color: HeritagePalette.border),
      ),
      child: Column(
        children: tiles,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: 2,
      ),
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: HeritagePalette.background,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Icon(
          icon,
          color: HeritagePalette.primaryNavy,
          size: 19,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: HeritagePalette.primaryNavy,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: HeritagePalette.secondaryText,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: HeritagePalette.secondaryText,
                fontSize: 12,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: HeritagePalette.secondaryText,
            size: 20,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showDemoNotice(BuildContext context, bool isEn) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEn
              ? 'Feature available in Demo Mode'
              : 'Chức năng đang hoạt động ở chế độ Demo',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
