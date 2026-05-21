import 'package:flutter/material.dart';
import 'analytics_controller.dart';
import '../../../utils/currency_utils.dart';
import '../../services/mongodb_service.dart';

class AnalyticsPage extends StatefulWidget {
  final String userName;
  final String userEmail;

  const AnalyticsPage({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with TickerProviderStateMixin {
  late final AnalyticsController _controller;
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _controller = AnalyticsController(userName: widget.userName, userEmail: widget.userEmail);
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _entrance.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() {});
      }
    });
    
    _entrance.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _stagger(double s, double e) => CurvedAnimation(
        parent: _entrance,
        curve: Interval(s, e, curve: Curves.easeOutCubic),
      );

  Widget _fade(double s, double e, {required Widget child}) {
    if (_entrance.isCompleted) {
      return child;
    }
    final a = _stagger(s, e);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  // Parse renewal date into weekday index (1 = Mon, 7 = Sun)
  int _getRenewalDayOfWeek(String renewalDate, String createdAtStr) {
    final months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };
    try {
      final cleaned = renewalDate.toLowerCase().trim();
      final parts = cleaned.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        int? month;
        int? day;
        for (final part in parts) {
          if (months.containsKey(part.substring(0, 3))) {
            month = months[part.substring(0, 3)];
          } else {
            day = int.tryParse(part);
          }
        }
        if (month != null && day != null) {
          final now = DateTime.now();
          final date = DateTime(now.year, month, day);
          return date.weekday;
        }
      }
    } catch (_) {}

    try {
      if (createdAtStr.isNotEmpty) {
        final parsed = DateTime.parse(createdAtStr);
        return parsed.weekday;
      }
    } catch (_) {}

    return (renewalDate.hashCode % 7) + 1;
  }

  // Generate interactive optimization candidates
  List<Map<String, dynamic>> _getUnusedCandidates() {
    final List<Map<String, dynamic>> candidates = [];
    final categoriesSeen = <String>{};
    
    // 1. Group multiple services in the same category as optimization targets
    for (final s in _controller.subscriptions) {
      final cat = (s['category'] ?? '').toString().toLowerCase();
      if (categoriesSeen.contains(cat)) {
        candidates.add(s);
      } else {
        categoriesSeen.add(cat);
      }
    }

    // 2. Fallback: if no duplicate categories but has >= 3 subscriptions, suggest the cheapest one
    if (candidates.isEmpty && _controller.subscriptions.length >= 3) {
      final sorted = List<Map<String, dynamic>>.from(_controller.subscriptions)
        ..sort((a, b) => ((a['price'] as num?)?.toDouble() ?? 0.0)
            .compareTo((b['price'] as num?)?.toDouble() ?? 0.0));
      candidates.add(sorted.first);
    }
    
    return candidates;
  }

  void _showReviewAndCancelSheet(BuildContext context, List<Map<String, dynamic>> candidates, String baseSymbol) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F6F1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Optimize Services',
                            style: TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Unused or duplicate services found',
                            style: TextStyle(
                              color: Color(0xFF6B6B80),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6B80)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (candidates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'All services successfully optimized!',
                          style: TextStyle(
                            color: Color(0xFF6B6B80),
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: candidates.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final sub = candidates[index];
                          final name = sub['name'] ?? 'Subscription';
                          final price = (sub['price'] as num?)?.toDouble() ?? 0.0;
                          final currency = sub['currency'] ?? 'USD';
                          final cat = sub['category'] ?? 'Other';
                          final colorHex = sub['color'] ?? 'FF6B6B80';
                          final subColor = Color(int.parse(colorHex, radix: 16));
                          final convertedPrice = CurrencyUtils.convert(price, currency, _controller.baseCurrency);
                          final id = (sub['id'] ?? sub['createdAt'] ?? '').toString();

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE8E4DE)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: subColor.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          cat.toString().toLowerCase().contains('entertainment')
                                              ? Icons.movie_rounded
                                              : cat.toString().toLowerCase().contains('software')
                                                  ? Icons.terminal_rounded
                                                  : cat.toString().toLowerCase().contains('utility')
                                                      ? Icons.electric_bolt_rounded
                                                      : Icons.category_rounded,
                                          color: subColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                color: Color(0xFF1A1A2E),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              cat,
                                              style: const TextStyle(
                                                color: Color(0xFF6B6B80),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '$baseSymbol${convertedPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF1A1A2E),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () async {
                                        final success = await MongoDbService().deleteSubscriptions(widget.userEmail, [id]);
                                        if (success) {
                                          setSheetState(() {
                                            candidates.removeAt(index);
                                          });
                                          await _controller.loadSubscriptions();
                                          
                                          if (candidates.isEmpty && ctx.mounted) {
                                            Navigator.of(ctx).pop();
                                          }
                                          
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(
                                              SnackBar(
                                                content: Text('Cancelled $name subscription successfully!'),
                                                backgroundColor: const Color(0xFF1A1A2E),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFFD4593A),
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(50, 30),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.loading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD4593A)),
          );
        }

        final baseSymbol = CurrencyUtils.currencySymbols[_controller.baseCurrency] ?? '\$';

        // Calculate dynamic weekly distribution spends
        final weekdaySpends = List<double>.filled(7, 0.0);
        for (final s in _controller.subscriptions) {
          final price = (s['price'] as num?)?.toDouble() ?? 0.0;
          final currency = s['currency'] ?? 'USD';
          final converted = CurrencyUtils.convert(price, currency, _controller.baseCurrency);
          
          final day = _getRenewalDayOfWeek(s['renewalDate'] ?? '', s['createdAt'] ?? '');
          weekdaySpends[day - 1] += converted;
        }

        // Find the day index with the highest spend
        int maxSpendDayIndex = 3; // Thursday (index 3) default like HTML
        double maxVal = 0.0;
        for (int i = 0; i < 7; i++) {
          if (weekdaySpends[i] > maxVal) {
            maxVal = weekdaySpends[i];
            maxSpendDayIndex = i;
          }
        }
        if (maxVal == 0.0) {
          // Fallback: use today's weekday index
          maxSpendDayIndex = DateTime.now().weekday - 1;
        }

        // Calculate Category Subscription Counts
        int entCount = 0;
        int softCount = 0;
        int utilCount = 0;
        int otherCount = 0;
        for (final s in _controller.subscriptions) {
          final cat = (s['category'] ?? 'Other').toString().toLowerCase();
          if (cat.contains('entertainment')) {
            entCount++;
          } else if (cat.contains('software')) {
            softCount++;
          } else if (cat.contains('utility')) {
            utilCount++;
          } else {
            otherCount++;
          }
        }

        // Calculate optimization candidates
        final unusedCandidates = _getUnusedCandidates();
        final potentialSaving = unusedCandidates.fold<double>(0.0, (sum, s) {
          final p = (s['price'] as num?)?.toDouble() ?? 0.0;
          return sum + CurrencyUtils.convert(p, s['currency'] ?? 'USD', _controller.baseCurrency);
        });

        // Find lowest and highest subscriptions
        Map<String, dynamic>? lowestSub;
        Map<String, dynamic>? highestSub;
        if (_controller.subscriptions.isNotEmpty) {
          lowestSub = _controller.subscriptions.first;
          highestSub = _controller.subscriptions.first;
          
          double lowestConverted = CurrencyUtils.convert(
            (lowestSub['price'] as num?)?.toDouble() ?? 0.0,
            lowestSub['currency'] ?? 'USD',
            _controller.baseCurrency,
          );
          double highestConverted = lowestConverted;

          for (final s in _controller.subscriptions) {
            final conv = CurrencyUtils.convert(
              (s['price'] as num?)?.toDouble() ?? 0.0,
              s['currency'] ?? 'USD',
              _controller.baseCurrency,
            );
            if (conv < lowestConverted) {
              lowestSub = s;
              lowestConverted = conv;
            }
            if (conv > highestConverted) {
              highestSub = s;
              highestConverted = conv;
            }
          }
        }

        return RefreshIndicator(
          onRefresh: _controller.loadSubscriptions,
          color: const Color(0xFFD4593A),
          backgroundColor: const Color(0xFFFFFFFF),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                _fade(0.0, 0.25, child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics',
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Dynamic distribution and renewal analysis.',
                      style: TextStyle(
                        color: Color(0xFF6B6B80),
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 24),

                // ── Monthly Spend Glass Card & Interactive Bar Chart ──
                _fade(0.06, 0.35, child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE8E4DE), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4593A).withValues(alpha: 0.04),
                        blurRadius: 24,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MONTHLY SPENDING',
                                  style: TextStyle(
                                    color: Color(0xFFACA8A1),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '$baseSymbol${_controller.totalSpend.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A2E),
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _controller.trendPositive 
                                  ? const Color(0xFFD4593A).withValues(alpha: 0.08)
                                  : const Color(0xFFACA8A1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _controller.trendPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                  color: _controller.trendPositive ? const Color(0xFFD4593A) : const Color(0xFF6B6B80),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_controller.trendPositive ? '+' : ''}${_controller.spendTrend.toStringAsFixed(1)}% vs last mo',
                                  style: TextStyle(
                                    color: _controller.trendPositive ? const Color(0xFFD4593A) : const Color(0xFF6B6B80),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Custom interactive bar chart
                      InteractiveBarChart(
                        spends: weekdaySpends,
                        currencySymbol: baseSymbol,
                        maxIndex: maxSpendDayIndex,
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 24),

                // ── Unused Subscriptions Optimizer Glass Card ─────────
                if (unusedCandidates.isNotEmpty)
                  _fade(0.12, 0.42, child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFD4593A).withValues(alpha: 0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4593A).withValues(alpha: 0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4593A).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.visibility_off_outlined,
                                color: Color(0xFFD4593A),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Optimization Targets',
                                    style: TextStyle(
                                      color: Color(0xFF1A1A2E),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${unusedCandidates.length} service${unusedCandidates.length > 1 ? 's' : ''} renewing soon could be cancelled.',
                                    style: const TextStyle(
                                      color: Color(0xFF6B6B80),
                                      fontSize: 13.5,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '-$baseSymbol${potentialSaving.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Color(0xFFD4593A),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  'SAVINGS / MO',
                                  style: TextStyle(
                                    color: Color(0xFFACA8A1),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _showReviewAndCancelSheet(context, unusedCandidates, baseSymbol),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A2E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'REVIEW AND OPTIMIZE',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                if (unusedCandidates.isNotEmpty) const SizedBox(height: 24),

                // ── Category Breakdown ──────────────────────────────
                _fade(0.18, 0.48, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'CATEGORY BREAKDOWN',
                        style: TextStyle(
                          color: Color(0xFFACA8A1),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8E4DE), width: 1),
                      ),
                      child: Column(
                        children: [
                          _buildCategoryRow(
                            'Entertainment',
                            entCount,
                            _controller.entSpend,
                            _controller.entPercentage,
                            const Color(0xFFE50914),
                            Icons.movie_rounded,
                            baseSymbol,
                            showDivider: true,
                          ),
                          _buildCategoryRow(
                            'SaaS & DevTools',
                            softCount,
                            _controller.softSpend,
                            _controller.softPercentage,
                            const Color(0xFFA259FF),
                            Icons.terminal_rounded,
                            baseSymbol,
                            showDivider: true,
                          ),
                          _buildCategoryRow(
                            'Utilities & Bills',
                            utilCount,
                            _controller.utilSpend,
                            _controller.utilPercentage,
                            const Color(0xFF3395FF),
                            Icons.electric_bolt_rounded,
                            baseSymbol,
                            showDivider: true,
                          ),
                          _buildCategoryRow(
                            'Other Payments',
                            otherCount,
                            _controller.otherSpend,
                            _controller.otherPercentage,
                            const Color(0xFF6B6B80),
                            Icons.category_rounded,
                            baseSymbol,
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 24),

                // ── Insights Bento Grid ─────────────────────────────
                _fade(0.24, 0.54, child: Row(
                  children: [
                    // Lowest Price Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        height: 124,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8E4DE), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3395FF).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.trending_down_rounded,
                                    color: Color(0xFF3395FF),
                                    size: 16,
                                  ),
                                ),
                                const Text(
                                  'LOWEST COST',
                                  style: TextStyle(
                                    color: Color(0xFFACA8A1),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lowestSub != null ? lowestSub['name'] ?? 'None' : 'None',
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A2E),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lowestSub != null
                                      ? '$baseSymbol${CurrencyUtils.convert((lowestSub['price'] as num?)?.toDouble() ?? 0.0, lowestSub['currency'] ?? 'USD', _controller.baseCurrency).toStringAsFixed(2)}/mo'
                                      : '${baseSymbol}0.00/mo',
                                  style: const TextStyle(
                                    color: Color(0xFF3395FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Highest Price Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        height: 124,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8E4DE), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4593A).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.trending_up_rounded,
                                    color: Color(0xFFD4593A),
                                    size: 16,
                                  ),
                                ),
                                const Text(
                                  'HIGHEST COST',
                                  style: TextStyle(
                                    color: Color(0xFFACA8A1),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  highestSub != null ? highestSub['name'] ?? 'None' : 'None',
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A2E),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  highestSub != null
                                      ? '$baseSymbol${CurrencyUtils.convert((highestSub['price'] as num?)?.toDouble() ?? 0.0, highestSub['currency'] ?? 'USD', _controller.baseCurrency).toStringAsFixed(2)}/mo'
                                      : '${baseSymbol}0.00/mo',
                                  style: const TextStyle(
                                    color: Color(0xFFD4593A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryRow(
    String title,
    int count,
    double amount,
    double percent,
    Color categoryColor,
    IconData icon,
    String currencySymbol, {
    required bool showDivider,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8E4DE), width: 0.5)),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: categoryColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count subscription${count != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF6B6B80),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currencySymbol${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              // Beautiful horizontal progress bar
              SizedBox(
                width: 96,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percent,
                    backgroundColor: const Color(0xFFFAF9F6),
                    valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InteractiveBarChart extends StatefulWidget {
  final List<double> spends;
  final String currencySymbol;
  final int maxIndex;

  const InteractiveBarChart({
    super.key,
    required this.spends,
    required this.currencySymbol,
    required this.maxIndex,
  });

  @override
  State<InteractiveBarChart> createState() => _InteractiveBarChartState();
}

class _InteractiveBarChartState extends State<InteractiveBarChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    
    double maxSpend = widget.spends.reduce((a, b) => a > b ? a : b);
    if (maxSpend == 0.0) maxSpend = 1.0;

    return SizedBox(
      height: 172,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final spend = widget.spends[index];
          final isMax = index == widget.maxIndex;
          final isHovered = _hoveredIndex == index;
          
          final double targetHeight = 16 + (spend / maxSpend) * 104;
          
          return Expanded(
            child: GestureDetector(
              onTapDown: (_) => setState(() => _hoveredIndex = index),
              onTapUp: (_) => setState(() => _hoveredIndex = null),
              onTapCancel: () => setState(() => _hoveredIndex = null),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hoveredIndex = index),
                onExit: (_) => setState(() => _hoveredIndex = null),
                cursor: SystemMouseCursors.click,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: (isHovered && spend > 0) ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${widget.currencySymbol}${spend.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      width: 22,
                      height: isHovered ? (targetHeight + 8).clamp(16.0, 136.0) : targetHeight,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        gradient: isMax
                            ? const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Color(0xFFD4593A),
                                  Color(0xFFFF8A65),
                                ],
                              )
                            : null,
                        color: isMax
                            ? null
                            : (isHovered
                                ? const Color(0xFFD4593A).withValues(alpha: 0.15)
                                : const Color(0xFFFAF9F6)),
                        border: Border.all(
                          color: isMax
                              ? Colors.transparent
                              : (isHovered
                                  ? const Color(0xFFD4593A).withValues(alpha: 0.3)
                                  : const Color(0xFFE8E4DE)),
                          width: 1,
                        ),
                        boxShadow: isMax
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFD4593A).withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      weekdays[index],
                      style: TextStyle(
                        color: isMax ? const Color(0xFFD4593A) : const Color(0xFFACA8A1),
                        fontSize: 9,
                        fontWeight: isMax ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
