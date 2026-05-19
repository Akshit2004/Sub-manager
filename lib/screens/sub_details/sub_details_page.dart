import 'package:flutter/material.dart';
import 'sub_details_controller.dart';
import '../../../utils/currency_utils.dart';

class SubDetailsPage extends StatefulWidget {
  final String userEmail;
  final Map<String, dynamic> subscription;
  final VoidCallback onDataChanged;

  const SubDetailsPage({
    super.key,
    required this.userEmail,
    required this.subscription,
    required this.onDataChanged,
  });

  @override
  State<SubDetailsPage> createState() => _SubDetailsPageState();
}

class _SubDetailsPageState extends State<SubDetailsPage> with TickerProviderStateMixin {
  late final SubDetailsController _controller;
  late final AnimationController _pulseController;
  late final FocusNode _notesFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = SubDetailsController(
      userEmail: widget.userEmail,
      subscription: widget.subscription,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _notesFocusNode = FocusNode();
    _notesFocusNode.addListener(_onNotesFocusChange);
  }

  void _onNotesFocusChange() {
    if (!_notesFocusNode.hasFocus) {
      _controller.saveNotes().then((_) {
        widget.onDataChanged();
      });
    }
  }

  @override
  void dispose() {
    _notesFocusNode.removeListener(_onNotesFocusChange);
    _notesFocusNode.dispose();
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final s = _controller.subscription;
        final name = s['name'] ?? 'Subscription';
        final plan = s['plan'] ?? 'Recurring Plan';
        final price = (s['price'] as num?)?.toDouble() ?? 0.0;
        final category = s['category'] ?? 'Other';
        final hexColor = s['color'] ?? 'FFD4593A';
        final color = Color(int.tryParse(hexColor, radix: 16) ?? 0xFFD4593A);
        final letter = name.isNotEmpty ? name[0].toUpperCase() : 'S';

        final subCurrency = (s['currency'] ?? 'USD').toString().toUpperCase();
        final subSymbol = CurrencyUtils.currencySymbols[subCurrency] ?? '\$';

        final renewalStr = s['renewalDate'] ?? 'Monthly';
        final createdAtStr = s['createdAt'] != null
            ? s['createdAt'].toString().substring(0, 10)
            : 'Recently';

        return Scaffold(
          backgroundColor: const Color(0xFFF8F6F1),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF8F6F1),
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A1A2E)),
                onPressed: () {
                  // Future: open edit panel
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Section ─────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            letter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '$subSymbol${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Active indicator pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE8E4DE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFD4593A).withValues(alpha: _pulseController.value * 0.8 + 0.2),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Active',
                              style: TextStyle(
                                color: Color(0xFF6B6B80),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // ── Bento Grid Details ───────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8E4DE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RENEWAL PLAN',
                              style: TextStyle(
                                color: Color(0xFF6B6B80),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, color: Color(0xFFD4593A), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    renewalStr,
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A2E),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Renews automatically.',
                              style: TextStyle(
                                color: Color(0xFFACA8A1),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8E4DE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CATEGORY',
                              style: TextStyle(
                                color: Color(0xFF6B6B80),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.label_outline_rounded, color: Color(0xFF1A1A2E), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    category,
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A2E),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Organized tag.',
                              style: TextStyle(
                                color: Color(0xFFACA8A1),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Plan Details List ────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'PLAN DETAILS',
                    style: TextStyle(
                      color: Color(0xFF6B6B80),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8E4DE)),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Plan Name', plan, true),
                      _buildDetailRow('Currency Config', subCurrency, true),
                      _buildDetailRow('Subscription Start', createdAtStr, false),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Price History (Visual Timeline) ──────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'PRICE HISTORY',
                    style: TextStyle(
                      color: Color(0xFF6B6B80),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8E4DE)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFD4593A),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Billing Tier',
                                  style: TextStyle(
                                    color: Color(0xFF1A1A2E),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Configured on $createdAtStr',
                                  style: const TextStyle(color: Color(0xFFACA8A1), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$subSymbol${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Notes Section (Autosave!) ────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'NOTES',
                    style: TextStyle(
                      color: Color(0xFF6B6B80),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8E4DE)),
                  ),
                  child: TextField(
                    controller: _controller.notesController,
                    focusNode: _notesFocusNode,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Add important notes, billing cards, account logins...',
                      hintStyle: TextStyle(color: const Color(0xFFACA8A1).withValues(alpha: 0.8), fontSize: 13.5),
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                      suffixIcon: _controller.savingNotes
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4593A)),
                              ),
                            )
                          : null,
                    ),
                    style: const TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 14,
                    ),
                  ),
                ),

              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, bool showBorder) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showBorder ? const Border(bottom: BorderSide(color: Color(0xFFE8E4DE), width: 0.5)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B6B80),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
