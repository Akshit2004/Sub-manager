import 'package:flutter/material.dart';
import '../dashboard_controller.dart';

class SubscriptionListHeader extends StatelessWidget {
  final DashboardController controller;

  const SubscriptionListHeader({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E4DE), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'Active Subscriptions',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          if (controller.subscriptions.isNotEmpty)
            GestureDetector(
              onTap: controller.toggleSelectionMode,
              child: Text(
                controller.isSelectionMode ? 'CANCEL' : 'MANAGE',
                style: const TextStyle(
                  color: Color(0xFFD4593A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            )
          else
            Text(
              '${controller.subscriptions.length} ITEMS',
              style: const TextStyle(
                color: Color(0xFF6B6B80),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
        ],
      ),
    );
  }
}
