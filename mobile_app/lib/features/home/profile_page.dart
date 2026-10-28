import 'package:flutter/material.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.large),
        ),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.large,
            horizontal: AppSpacing.medium,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEn ? 'Select Language' : 'Chọn ngôn ngữ',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: HeritagePalette.primaryNavy,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              ListTile(
                leading: const Text('🇻🇳', style: TextStyle(fontSize: 24)),
                title: Text(
                  'Tiếng Việt',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: !isEn
                    ? const Icon(
                        Icons.check_circle,
                        color: HeritagePalette.primaryNavy,
                      )
                    : null,
                onTap: () {
                  onLocaleChanged(const Locale('vi'));
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                title: Text(
                  'English',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: isEn
                    ? const Icon(
                        Icons.check_circle,
                        color: HeritagePalette.primaryNavy,
                      )
                    : null,
                onTap: () {
                  onLocaleChanged(const Locale('en'));
                  Navigator.pop(ctx);
                },
              ),
            ],
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
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          title: Text(isEn ? 'Log Out' : 'Đăng xuất'),
          content: Text(
            isEn
                ? 'Are you sure you want to log out of the application?'
                : 'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?',
          ),
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
                  borderRadius: BorderRadius.circular(AppRadii.small),
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
              child: Text(isEn ? 'Log Out' : 'Đăng xuất'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        // Profile page mang nội dung "Cài đặt & Cá nhân"
        title: Text(
          isEn ? 'Profile & Settings' : 'Cá nhân & Cài đặt',
          style: theme.textTheme.titleLarge?.copyWith(
            color: HeritagePalette.primaryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          children: [
            // User Profile Card
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: HeritagePalette.primaryNavy,
                  child: Icon(Icons.person, size: 36, color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nguyễn Văn A',
                        style: theme.textTheme.titleMedium?.copyWith(
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
                          horizontal: AppSpacing.xSmall,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: HeritagePalette.background,
                          borderRadius: BorderRadius.circular(AppRadii.small),
                        ),
                        child: Text(
                          isEn ? 'Demo Account' : 'Tài khoản Demo',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: HeritagePalette.primaryNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.large),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.small),

            // Settings Options List
            _buildSettingTile(
              icon: Icons.history,
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
            _buildSettingTile(
              icon: Icons.bluetooth_searching,
              title: isEn
                  ? 'iBeacon Smart Tour'
                  : 'Thuyết minh iBeacon tự động',
              subtitle: isEn
                  ? 'Simulate audio guide detection'
                  : 'Trải nghiệm nhận diện hiện vật qua iBeacon',
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
            _buildSettingTile(
              icon: Icons.person_outline,
              title: isEn ? 'Personal Information' : 'Thông tin cá nhân',
              onTap: () => _showDemoNotice(context, isEn),
              theme: theme,
            ),
            _buildSettingTile(
              icon: Icons.shield_outlined,
              title: isEn ? 'Security' : 'Bảo mật',
              onTap: () => _showDemoNotice(context, isEn),
              theme: theme,
            ),
            _buildSettingTile(
              icon: Icons.language,
              title: isEn ? 'Language' : 'Ngôn ngữ',
              subtitle: isEn ? 'English' : 'Tiếng Việt',
              onTap: () => _showLanguageSelector(context, isEn),
              theme: theme,
            ),
            _buildSettingTile(
              icon: Icons.notifications_none_outlined,
              title: isEn ? 'Notifications' : 'Thông báo',
              onTap: () => _showDemoNotice(context, isEn),
              theme: theme,
            ),
            _buildSettingTile(
              icon: Icons.help_outline,
              title: isEn ? 'Help & Support' : 'Trợ giúp & Hỗ trợ',
              onTap: () => _showDemoNotice(context, isEn),
              theme: theme,
            ),
            _buildSettingTile(
              icon: Icons.info_outline,
              title: isEn ? 'About Application' : 'Giới thiệu ứng dụng',
              onTap: () => _showDemoNotice(context, isEn),
              theme: theme,
            ),

            const SizedBox(height: AppSpacing.xLarge),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, isEn),
                icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                label: Text(
                  isEn ? 'Log Out' : 'Đăng xuất',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFEF4444),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(icon, color: HeritagePalette.primaryNavy, size: 22),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitle != null)
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: HeritagePalette.secondaryText,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right,
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
