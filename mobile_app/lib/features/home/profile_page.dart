import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/locale_controller.dart';
import '../../shared/config/api_config.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../auth/auth_session.dart';
import '../auth/login_page.dart';
import '../data/visitor_api_service.dart';
import '../heritage/beacon_simulation_page.dart';
import 'history_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.onLocaleChanged,
    this.onLogout,
    this.visitorApi,
    this.userApi,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback? onLogout;
  final VisitorApi? visitorApi;
  final UserApi? userApi;

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;
  int _requestGeneration = 0;
  String? _lastToken;

  // Notification toggles for demonstration
  bool _beaconAlerts = true;
  bool _artifactUpdates = true;

  UserApi get _resolvedUserApi {
    if (widget.userApi != null) return widget.userApi!;
    if (widget.visitorApi is UserApi) return widget.visitorApi as UserApi;
    return HttpVisitorApi(baseUrl: ApiConfig.baseUrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAuthSession();
  }

  void _syncAuthSession() {
    final session = AuthSessionScope.maybeOf(context);
    final currentToken = session?.readToken()?.accessToken;

    if (currentToken != _lastToken) {
      _lastToken = currentToken;
      if (session != null && session.isAuthenticated && currentToken != null) {
        _loadProfile(session.readToken()!);
      } else {
        // Logged out or guest: clear old profile data immediately
        _requestGeneration++;
        if (mounted) {
          setState(() {
            _profile = null;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      }
    }
  }

  Future<void> _loadProfile(AuthToken token) async {
    final generation = ++_requestGeneration;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _resolvedUserApi.loadCurrentUser(token: token);
      if (!mounted || generation != _requestGeneration) return;

      setState(() {
        _profile = user;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;

      final isEn = AppStrings.of(context).isEnglish;
      setState(() {
        _isLoading = false;
        _errorMessage = e is VisitorApiException
            ? e.message
            : (isEn
                ? 'Failed to load user profile. Tap to retry.'
                : 'Không thể tải thông tin tài khoản. Chạm để thử lại.');
      });
    }
  }

  @visibleForTesting
  Future<void> reloadProfile() async {
    final session = AuthSessionScope.maybeOf(context);
    if (session != null && session.isAuthenticated) {
      final token = session.readToken();
      if (token != null) {
        await _loadProfile(token);
      }
    }
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginPage(),
      ),
    );
  }

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
                    widget.onLocaleChanged(const Locale('vi'));
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
                    widget.onLocaleChanged(const Locale('en'));
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
                setState(() {
                  _profile = null;
                  _lastToken = null;
                  _isLoading = false;
                  _errorMessage = null;
                });
                if (widget.onLogout != null) {
                  widget.onLogout!();
                } else {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
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

  void _showPersonalInfo(BuildContext context, bool isEn) {
    final theme = Theme.of(context);
    final profile = _profile;

    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn
                ? 'Please sign in to view personal information'
                : 'Vui lòng đăng nhập để xem thông tin cá nhân',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
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
              Text(
                isEn ? 'Personal Information' : 'Thông tin cá nhân',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              _buildInfoRow(isEn ? 'Full Name' : 'Họ và tên', profile.fullName ?? (isEn ? 'Not set' : 'Chưa cập nhật'), theme),
              const Divider(color: HeritagePalette.border, height: 16),
              _buildInfoRow(isEn ? 'Email' : 'Địa chỉ email', profile.email, theme),
              const Divider(color: HeritagePalette.border, height: 16),
              _buildInfoRow(isEn ? 'Role' : 'Vai trò', _formatRoleName(profile, isEn), theme),
              const Divider(color: HeritagePalette.border, height: 16),
              _buildInfoRow(isEn ? 'Account Status' : 'Trạng thái', profile.isActive ? (isEn ? 'Active' : 'Hoạt động') : (isEn ? 'Locked' : 'Khóa'), theme),
              const Divider(color: HeritagePalette.border, height: 16),
              _buildInfoRow(isEn ? 'Account ID' : 'Mã tài khoản', profile.id, theme, isMonospace: true),
              const SizedBox(height: AppSpacing.large),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme, {bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: HeritagePalette.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: HeritagePalette.primaryNavy,
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSecurityModal(BuildContext context, bool isEn) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
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
              Text(
                isEn ? 'Account Security' : 'Bảo mật tài khoản',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              _buildInfoRow(
                isEn ? 'Auth Method' : 'Phương thức xác thực',
                'OAuth2 Bearer Token (JWT)',
                theme,
              ),
              const Divider(color: HeritagePalette.border, height: 16),
              _buildInfoRow(
                isEn ? 'Encryption' : 'Mã hóa',
                isEn ? 'TLS / HTTPS with PBKDF2' : 'TLS / HTTPS & PBKDF2',
                theme,
              ),
              const Divider(color: HeritagePalette.border, height: 16),
              _buildInfoRow(
                isEn ? 'Password' : 'Mật khẩu',
                '••••••••',
                theme,
              ),
              const SizedBox(height: AppSpacing.large),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context, bool isEn) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
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
                Text(
                  isEn ? 'Notification Preferences' : 'Tùy chọn thông báo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: HeritagePalette.primaryNavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isEn ? 'iBeacon Proximity Audio' : 'Thuyết minh tự động iBeacon',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isEn ? 'Notify when near a heritage item' : 'Báo khi đến gần hiện vật di tích',
                    style: theme.textTheme.bodySmall?.copyWith(color: HeritagePalette.secondaryText),
                  ),
                  value: _beaconAlerts,
                  activeTrackColor: HeritagePalette.actionBlue.withValues(alpha: 0.5),
                  activeThumbColor: HeritagePalette.actionBlue,
                  onChanged: (val) {
                    setSheetState(() => _beaconAlerts = val);
                    setState(() => _beaconAlerts = val);
                  },
                ),
                const Divider(color: HeritagePalette.border, height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isEn ? 'Heritage Updates' : 'Cập nhật tin tức di sản',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isEn ? 'New exhibitions and events' : 'Triển lãm và sự kiện di tích mới',
                    style: theme.textTheme.bodySmall?.copyWith(color: HeritagePalette.secondaryText),
                  ),
                  value: _artifactUpdates,
                  activeTrackColor: HeritagePalette.actionBlue.withValues(alpha: 0.5),
                  activeThumbColor: HeritagePalette.actionBlue,
                  onChanged: (val) {
                    setSheetState(() => _artifactUpdates = val);
                    setState(() => _artifactUpdates = val);
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHelpSupport(BuildContext context, bool isEn) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
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
              Text(
                isEn ? 'Help & Support' : 'Trợ giúp & Hỗ trợ',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HeritagePalette.primaryNavy,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              _buildInfoRow(isEn ? 'Email Support' : 'Email hỗ trợ', 'support@smartheritage.vn', theme),
              const Divider(color: HeritagePalette.border, height: 16),
              _buildInfoRow(isEn ? 'Hotline' : 'Đường dây nóng', '1900 6868 (8:00 - 18:00)', theme),
              const Divider(color: HeritagePalette.border, height: 16),
              _buildInfoRow(isEn ? 'Documentation' : 'Hướng dẫn', 'https://smartheritage.vn/guide', theme),
              const SizedBox(height: AppSpacing.large),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, bool isEn) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        title: Row(
          children: [
            const Icon(Icons.account_balance_rounded, color: HeritagePalette.primaryNavy),
            const SizedBox(width: 8),
            Text(
              isEn ? 'About Smart Heritage' : 'Về Smart Heritage',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEn
                  ? 'Smart Heritage Mobile Application is a digital preservation and smart tour guide solution for national cultural heritage sites.'
                  : 'Ứng dụng Di sản Thông minh (Smart Heritage Mobile) cung cấp giải pháp bảo tồn số hóa và hướng dẫn tham quan thông minh cho các di tích lịch sử.',
              style: theme.textTheme.bodyMedium?.copyWith(color: HeritagePalette.bodyText),
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              'Phiên bản / Version: 1.0.0\nBackend: FastAPI + Azure SQL Server\n© 2026 Smart Heritage Project',
              style: theme.textTheme.bodySmall?.copyWith(color: HeritagePalette.secondaryText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isEn ? 'Close' : 'Đóng'),
          ),
        ],
      ),
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
            // User / Guest Profile Card
            _buildProfileCard(context, isEn),
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
                      MaterialPageRoute(
                        builder: (_) => HistoryPage(api: widget.visitorApi),
                      ),
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
                  onTap: () => _showPersonalInfo(context, isEn),
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
                  onTap: () => _showSecurityModal(context, isEn),
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
                  onTap: () => _showNotificationSettings(context, isEn),
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
                  onTap: () => _showHelpSupport(context, isEn),
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
                  onTap: () => _showAboutDialog(context, isEn),
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xLarge),

            // Auth action (Log Out if authenticated, Sign In if guest)
            _buildAccountAction(context, isEn),
            const SizedBox(height: AppSpacing.medium),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, bool isEn) {
    final session = AuthSessionScope.maybeOf(context);
    final isAuthenticated = session?.isAuthenticated ?? false;

    if (!isAuthenticated) {
      return _buildGuestCard(context, isEn);
    }

    if (_isLoading && _profile == null) {
      return _buildLoadingCard(context, isEn);
    }

    if (_errorMessage != null && _profile == null) {
      return _buildErrorCard(context, isEn);
    }

    if (_profile != null) {
      return _buildUserCard(context, isEn, _profile!);
    }

    return _buildGuestCard(context, isEn);
  }

  Widget _buildGuestCard(BuildContext context, bool isEn) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: HeritagePalette.border.withValues(alpha: 0.6),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 32,
                  color: HeritagePalette.secondaryText,
                ),
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Guest Visitor' : 'Khách tham quan',
                      key: const Key('profile-guest-title'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HeritagePalette.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn
                          ? 'Log in to sync favorites & history'
                          : 'Đăng nhập để đồng bộ dữ liệu di sản',
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
                        isEn ? 'Guest Mode' : 'Chế độ khách',
                        key: const Key('profile-guest-badge'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: HeritagePalette.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('profile-guest-login-button'),
              style: FilledButton.styleFrom(
                backgroundColor: HeritagePalette.actionBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _navigateToLogin(context),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: Text(
                isEn ? 'Sign In / Register' : 'Đăng nhập / Đăng ký',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context, bool isEn) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('profile-loading-card'),
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: HeritagePalette.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: HeritagePalette.border.withValues(alpha: 0.3),
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Loading profile...' : 'Đang tải thông tin...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: HeritagePalette.primaryNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEn ? 'Connecting to server' : 'Đang kết nối máy chủ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: HeritagePalette.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, bool isEn) {
    final theme = Theme.of(context);

    return Container(
      key: const Key('profile-error-card'),
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage ??
                      (isEn
                          ? 'Failed to load profile'
                          : 'Không thể tải thông tin'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF991B1B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: const Key('profile-retry-button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF991B1B),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              onPressed: () {
                final session = AuthSessionScope.maybeOf(context);
                final token = session?.readToken();
                if (token != null) {
                  _loadProfile(token);
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(isEn ? 'Retry' : 'Thử lại'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, bool isEn, UserProfile profile) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayName = profile.fullName != null && profile.fullName!.trim().isNotEmpty
        ? profile.fullName!.trim()
        : profile.email.split('@').first;

    final roleLabel = _formatRoleName(profile, isEn);

    return Container(
      key: const Key('profile-user-card'),
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
            child: Text(
              _getInitials(displayName),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  key: const Key('profile-user-name'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: HeritagePalette.primaryNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  key: const Key('profile-user-email'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: HeritagePalette.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  key: const Key('profile-role-badge'),
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
                    roleLabel,
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
    );
  }

  Widget _buildAccountAction(BuildContext context, bool isEn) {
    final session = AuthSessionScope.maybeOf(context);
    final isAuthenticated = session?.isAuthenticated ?? false;

    if (!isAuthenticated) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          key: const Key('profile-bottom-login'),
          onPressed: () => _navigateToLogin(context),
          icon: const Icon(Icons.login_rounded, size: 20),
          label: Text(
            isEn ? 'Log In to Account' : 'Đăng nhập vào tài khoản',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: HeritagePalette.primaryNavy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        key: const Key('profile-logout-button'),
        onPressed: () => _confirmLogout(context, isEn),
        icon: const Icon(
          Icons.logout_rounded,
          color: Color(0xFFEF4444),
          size: 20,
        ),
        label: Text(
          isEn ? 'Log Out' : 'Đăng xuất',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
    );
  }

  String _formatRoleName(UserProfile profile, bool isEn) {
    if (profile.isSuperuser) {
      return isEn ? 'Superuser' : 'Quản trị viên';
    }
    final role = profile.roleName?.toLowerCase();
    if (role == 'admin') {
      return isEn ? 'Administrator' : 'Quản trị viên';
    }
    if (role == 'visitor' || role == null) {
      return isEn ? 'Visitor' : 'Khách tham quan';
    }
    return profile.roleName!;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
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
      child: Column(children: tiles),
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
        child: Icon(icon, color: HeritagePalette.primaryNavy, size: 19),
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
}
