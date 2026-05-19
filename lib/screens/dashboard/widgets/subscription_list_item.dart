import 'package:flutter/material.dart';
import '../dashboard_controller.dart';
import '../../../utils/currency_utils.dart';
import '../../sub_details/sub_details_page.dart';

class SubscriptionListItem extends StatelessWidget {
  final Map<String, dynamic> subscription;
  final bool isNext;
  final DashboardController controller;

  const SubscriptionListItem({
    super.key,
    required this.subscription,
    required this.isNext,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    final id = (s['_id'] != null)
        ? s['_id'].toString().replaceAll('ObjectId("', '').replaceAll('")', '')
        : (s['id'] ?? s['createdAt'] ?? '').toString();
    final name = s['name'] ?? 'Subscription';
    final plan = s['plan'] ?? 'Recurring Plan';
    final price = (s['price'] as num?)?.toDouble() ?? 0.0;
    final renewalStr = s['renewalDate'] ?? 'Monthly';
    final hexColor = s['color'] ?? 'FFD4593A';
    final color = Color(int.tryParse(hexColor, radix: 16) ?? 0xFFD4593A);
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    final subCurrency = (s['currency'] ?? 'USD').toString().toUpperCase();
    final subSymbol = CurrencyUtils.currencySymbols[subCurrency] ?? '\$';
    final baseSymbol = CurrencyUtils.currencySymbols[controller.baseCurrency] ?? '\$';

    final isDifferentCurrency = subCurrency != controller.baseCurrency;
    final convertedValue = CurrencyUtils.convert(price, subCurrency, controller.baseCurrency);
    final isSelected = controller.selectedIds.contains(id);

    return InkWell(
      onTap: () {
        if (controller.isSelectionMode) {
          controller.toggleSelection(id);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SubDetailsPage(
                userEmail: controller.userEmail,
                subscription: s,
                onDataChanged: () {
                  controller.loadSubscriptions();
                },
              ),
            ),
          );
        }
      },
      onLongPress: () {
        if (!controller.isSelectionMode) {
          controller.toggleSelectionMode();
          controller.toggleSelection(id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE8E4DE), width: 0.5)),
        ),
        child: Row(
          children: [
            if (controller.isSelectionMode) ...[
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? const Color(0xFFD4593A) : const Color(0xFF6B6B80),
                size: 22,
              ),
              const SizedBox(width: 12),
            ],
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plan,
                    style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13.5),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$subSymbol${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                if (isDifferentCurrency) ...[
                  Text(
                    '≈ $baseSymbol${convertedValue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFD4593A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  renewalStr.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF6B6B80),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isNext ? const Color(0xFFD4593A) : const Color(0xFFF0EDE8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
