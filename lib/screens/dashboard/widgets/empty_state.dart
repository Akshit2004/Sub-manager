import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final VoidCallback onAddPressed;

  const EmptyState({super.key, required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E4DE)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFD4593A).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFD4593A), size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'No active subscriptions',
            style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Keep track of your recurring payments by adding them below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B6B80), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add your first sub'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD4593A),
              side: const BorderSide(color: Color(0xFFD4593A)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
