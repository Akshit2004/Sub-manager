import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dashboard/dashboard_controller.dart';
import '../landing_page.dart';
import '../../services/shorebird_updater.dart';

class SettingsPage extends StatefulWidget {
  final DashboardController controller;
  const SettingsPage({super.key, required this.controller});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditingName = false;
  int _notificationThreshold = 2; // Default to 2 days
  int? _patchNumber;
  bool _isShorebirdActive = false;
  bool _isLoading = true;
  String _appVersion = '1.0.0+3';

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.controller.userName;
    _loadPreferences();
    _checkShorebird();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      debugPrint('Error loading app version: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationThreshold = prefs.getInt('notification_threshold_days') ?? 2;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings preferences: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNotificationThreshold(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notification_threshold_days', days);
      setState(() {
        _notificationThreshold = days;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notifications set to remind you $days days before renewal.'),
            backgroundColor: const Color(0xFF1A1A2E),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving notification threshold: $e');
    }
  }

  Future<void> _checkShorebird() async {
    final updater = SubManagerShorebirdService();
    final isAvail = updater.isShorebirdAvailable();
    if (isAvail) {
      final patch = await updater.currentPatchNumber();
      if (mounted) {
        setState(() {
          _isShorebirdActive = true;
          _patchNumber = patch;
        });
      }
    }
  }

  Future<void> _saveName() async {
    if (_formKey.currentState!.validate()) {
      await widget.controller.updateUserName(_nameController.text);
      setState(() {
        _isEditingName = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile name updated successfully.'),
            backgroundColor: Color(0xFF1A1A2E),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Log Out',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of Sub Manager Pro? You will need to log back in to manage your subscriptions.',
          style: TextStyle(color: Color(0xFF6B6B80), fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B6B80), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626), // Premium red alert color
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_email');
        await prefs.remove('user_name');
      } catch (e) {
        debugPrint('Error clearing session: $e');
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingPage()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userInitials = widget.controller.userName.isNotEmpty
        ? widget.controller.userName.trim().substring(0, 1).toUpperCase()
        : widget.controller.userEmail.trim().substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F1),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4593A)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Profile Card ─────────────────────────────────────────
                    _buildSectionHeader('Profile'),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: const Color(0xFFD4593A).withValues(alpha: 0.1),
                                  child: Text(
                                    userInitials,
                                    style: const TextStyle(
                                      color: Color(0xFFD4593A),
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!_isEditingName) ...[
                                        Text(
                                          widget.controller.userName.isNotEmpty
                                              ? widget.controller.userName
                                              : 'Set your name',
                                          style: TextStyle(
                                            color: const Color(0xFF1A1A2E),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            fontStyle: widget.controller.userName.isEmpty
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                          ),
                                        ),
                                      ] else ...[
                                        TextFormField(
                                          controller: _nameController,
                                          autofocus: true,
                                          style: const TextStyle(
                                            color: Color(0xFF1A1A2E),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Enter your name',
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xFFFAF9F6),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFFE8E4DE)),
                                            ),
                                          ),
                                          validator: (val) {
                                            if (val == null || val.trim().isEmpty) {
                                              return 'Name cannot be empty';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.controller.userEmail,
                                        style: const TextStyle(
                                          color: Color(0xFF6B6B80),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _isEditingName ? Icons.check_circle_rounded : Icons.edit_rounded,
                                    color: const Color(0xFFD4593A),
                                    size: 22,
                                  ),
                                  onPressed: _isEditingName ? _saveName : () => setState(() => _isEditingName = true),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── App Preferences ──────────────────────────────────────
                    _buildSectionHeader('App Preferences'),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          // Base Currency Selector
                          _buildPreferenceItem(
                            icon: Icons.currency_exchange_rounded,
                            title: 'Base Currency',
                            subtitle: 'Convert all prices dynamically',
                            trailing: DropdownButton<String>(
                              value: widget.controller.baseCurrency.toUpperCase(),
                              underline: const SizedBox(),
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              items: ['INR', 'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY']
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  widget.controller.saveBaseCurrency(val);
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE8E4DE)),
                          // Notification Reminder Threshold
                          _buildPreferenceItem(
                            icon: Icons.notifications_active_rounded,
                            title: 'Reminder Window',
                            subtitle: 'Days before renewal alert',
                            trailing: DropdownButton<int>(
                              value: _notificationThreshold,
                              underline: const SizedBox(),
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              items: [1, 2, 3, 5, 7]
                                  .map((day) => DropdownMenuItem(value: day, child: Text('$day Day${day > 1 ? 's' : ''}')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  _saveNotificationThreshold(val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── App Updates & Version ────────────────────────────────
                    _buildSectionHeader('System Info'),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              icon: Icons.info_outline_rounded,
                              label: 'App Version',
                              value: _appVersion,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              icon: Icons.bolt_rounded,
                              label: 'Shorebird Update Engine',
                              value: _isShorebirdActive ? 'Active' : 'Not Loaded',
                            ),
                            if (_isShorebirdActive) ...[
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                icon: Icons.extension_rounded,
                                label: 'Active Patch Number',
                                value: _patchNumber != null ? 'Patch #$_patchNumber' : 'Base Version',
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFE8E4DE)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isShorebirdActive
                                        ? 'Automatic background hot updates are enabled.'
                                        : 'Running production build on current stable environment.',
                                    style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Danger Zone / Logout ─────────────────────────────────
                    _buildSectionHeader('Danger Zone'),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFFCA5A5), width: 1), // Gentle red border
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFDC2626),
                            size: 18,
                          ),
                        ),
                        title: const Text(
                          'Log Out',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          'Sign out of Sub Manager Pro',
                          style: TextStyle(color: Color(0xFF6B6B80), fontSize: 12),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFDC2626), size: 14),
                        onTap: _handleLogout,
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF6B6B80),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildPreferenceItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6F1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF6B6B80), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6B6B80), size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B6B80),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
