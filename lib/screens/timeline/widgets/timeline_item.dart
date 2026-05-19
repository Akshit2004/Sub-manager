import 'package:flutter/material.dart';
import '../../../utils/currency_utils.dart';

class TimelineItem extends StatelessWidget {
  final Map<String, dynamic> subscription;
  final String baseCurrency;

  const TimelineItem({
    super.key,
    required this.subscription,
    required this.baseCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    final name = s['name'] ?? 'Subscription';
    final plan = s['plan'] ?? 'Recurring Plan';
    final price = (s['price'] as num?)?.toDouble() ?? 0.0;
    final category = s['category'] ?? 'Other';
    final hexColor = s['color'] ?? 'FFD4593A';
    final color = Color(int.tryParse(hexColor, radix: 16) ?? 0xFFD4593A);

    final subCurrency = (s['currency'] ?? 'USD').toString().toUpperCase();
    final subSymbol = CurrencyUtils.currencySymbols[subCurrency] ?? '\$';
    final baseSymbol = CurrencyUtils.currencySymbols[baseCurrency] ?? '\$';

    final isDifferentCurrency = subCurrency != baseCurrency;
    final convertedValue = CurrencyUtils.convert(price, subCurrency, baseCurrency);

    // Get date string & day of the week from parsedRenewalDate
    final parsedDate = s['parsedRenewalDate'] as DateTime?;
    final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final dateStr = parsedDate != null ? '${months[parsedDate.month - 1]} ${parsedDate.day}' : 'RENEW';
    final weekdayStr = parsedDate != null ? weekdays[parsedDate.weekday % 7] : 'Plan';

    IconData getCategoryIcon(String cat) {
      final clean = cat.toLowerCase();
      if (clean.contains('entertainment')) return Icons.movie_outlined;
      if (clean.contains('software')) return Icons.cloud_outlined;
      if (clean.contains('utility')) return Icons.offline_bolt_outlined;
      return Icons.receipt_long_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E4DE), width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: Date info ─────────────────────────────────
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: Color(0xFF6B6B80),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  weekdayStr,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ── Middle: Icon ────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(
              getCategoryIcon(category),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          // ── Center-Right: Title & details ───────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (s['groupId'] != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4593A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Family',
                          style: TextStyle(
                            color: Color(0xFFD4593A),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  s['groupId'] != null && s['email'] != null ? 'Shared by ${s['email']}' : '$plan • $category',
                  style: const TextStyle(
                    color: Color(0xFF6B6B80),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ── Right: Price & conversion ───────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$subSymbol${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (isDifferentCurrency) ...[
                const SizedBox(height: 3),
                Text(
                  '≈ $baseSymbol${convertedValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFD4593A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'AUTO-RENEWS',
                style: TextStyle(
                  color: Color(0xFFD4593A),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
