import 'package:flutter/material.dart';
import '../dashboard_controller.dart';
import '../../../utils/currency_utils.dart';

class SpendSummaryCard extends StatelessWidget {
  final DashboardController controller;
  final AnimationController entrance;

  const SpendSummaryCard({
    super.key,
    required this.controller,
    required this.entrance,
  });

  @override
  Widget build(BuildContext context) {
    final baseSymbol = CurrencyUtils.currencySymbols[controller.baseCurrency] ?? '\$';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E4DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MONTHLY OVERHEAD SPEND',
                style: TextStyle(
                  color: Color(0xFF6B6B80),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              _buildCurrencyPicker(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _CountUpText(
                target: controller.totalSpend,
                entrance: entrance,
                currencySymbol: baseSymbol,
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 46,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -2,
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4593A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.analytics_outlined, color: Color(0xFFD4593A), size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '${controller.subscriptions.length} recurring',
                      style: const TextStyle(
                        color: Color(0xFFD4593A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Entertainment', '$baseSymbol${controller.entSpend.toStringAsFixed(2)}', const Color(0xFFE50914)),
              _chip('Software', '$baseSymbol${controller.softSpend.toStringAsFixed(2)}', const Color(0xFFA259FF)),
              _chip('Utility', '$baseSymbol${controller.utilSpend.toStringAsFixed(2)}', const Color(0xFF3395FF)),
              if (controller.otherSpend > 0)
                _chip('Other', '$baseSymbol${controller.otherSpend.toStringAsFixed(2)}', const Color(0xFF6B6B80)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyPicker() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E4DE)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: controller.baseCurrency,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF6B6B80)),
          style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 11.5),
          dropdownColor: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          alignment: Alignment.centerRight,
          onChanged: (val) {
            if (val != null) {
              controller.saveBaseCurrency(val);
            }
          },
          items: CurrencyUtils.currencySymbols.keys.map((String cur) {
            final symbol = CurrencyUtils.currencySymbols[cur] ?? '';
            return DropdownMenuItem<String>(
              value: cur,
              child: Text('$symbol $cur  '),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _chip(String label, String amount, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8E4DE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ($amount)',
            style: const TextStyle(
              color: Color(0xFF6B6B80),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountUpText extends StatelessWidget {
  final double target;
  final AnimationController entrance;
  final TextStyle style;
  final String currencySymbol;
  const _CountUpText({
    required this.target,
    required this.entrance,
    required this.style,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: entrance,
      curve: const Interval(0.10, 0.65, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final value = anim.value * target;
        return Text('$currencySymbol${value.toStringAsFixed(2)}', style: style);
      },
    );
  }
}
