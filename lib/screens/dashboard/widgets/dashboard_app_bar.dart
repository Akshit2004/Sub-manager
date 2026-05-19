import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../dashboard_controller.dart';
import '../../landing_page.dart';
import '../../../services/notification_service.dart';

class DashboardAppBar extends StatelessWidget {
  final DashboardController controller;

  const DashboardAppBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.isSelectionMode) {
      final allSelected = controller.selectedIds.length == controller.subscriptions.length && controller.subscriptions.isNotEmpty;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFFF0EDE8),
          border: Border(bottom: BorderSide(color: Color(0xFFE8E4DE), width: 0.5)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: controller.cancelSelection,
              icon: const Icon(Icons.close_rounded, color: Color(0xFF1A1A2E), size: 24),
            ),
            const SizedBox(width: 8),
            Text(
              '${controller.selectedIds.length} Selected',
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: controller.selectAll,
              icon: Icon(
                allSelected ? Icons.select_all_rounded : Icons.library_add_check_outlined,
                color: const Color(0xFFD4593A),
                size: 22,
              ),
              tooltip: allSelected ? 'Deselect All' : 'Select All',
            ),
            IconButton(
              onPressed: controller.selectedIds.isEmpty 
                  ? null 
                  : () => controller.confirmBulkDelete(context),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: controller.selectedIds.isEmpty ? const Color(0xFF6B6B80).withValues(alpha: 0.4) : const Color(0xFFD4593A),
                size: 22,
              ),
              tooltip: 'Delete Selected',
            ),
          ],
        ),
      );
    }

    final initials = controller.userName.isNotEmpty
        ? controller.userName[0].toUpperCase()
        : controller.userEmail[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E4DE), width: 0.5)),
      ),
      child: Row(
        children: [
          // avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFD4593A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8E4DE)),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SubManager',
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Workspace for ${controller.userName.isNotEmpty ? controller.userName : controller.userEmail}',
                style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () async {
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('user_email');
                await prefs.remove('user_name');
              } catch (e) {
                debugPrint('Error clearing session storage: $e');
              }
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingPage()),
                  (_) => false,
                );
              }
            },
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF6B6B80), size: 20),
          ),
        ],
      ),
    );
  }
}
