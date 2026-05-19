import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/mongodb_service.dart';
import 'landing_page.dart';

class DashboardPage extends StatefulWidget {
  final String userName;
  final String userEmail;
  const DashboardPage({super.key, required this.userName, required this.userEmail});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  late final AnimationController _entrance;
  int _navIndex = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _subscriptions = [];
  double _totalSpend = 0.0;
  String _baseCurrency = 'INR'; // ── Default base is now INR! ──

  // ── category spend variables ─────────────────────────────
  double _entSpend = 0.0;
  double _softSpend = 0.0;
  double _utilSpend = 0.0;
  double _otherSpend = 0.0;

  // ── dynamic currencies symbols mapping ───────────────────
  static const Map<String, String> _currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'JPY': '¥',
  };

  // ── live rates dynamic mapping (defaults to sensible baseline)
  final Map<String, double> _liveRates = {
    'USD': 1.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'INR': 83.5,
    'JPY': 156.0,
  };

  // ── warm cream + coral palette ────────────────────────────
  static const _bg = Color(0xFFF8F6F1);
  static const _surfLow = Color(0xFFFFFFFF);
  static const _surfHigh = Color(0xFFF0EDE8);
  static const _primary = Color(0xFFD4593A);
  static const _primaryContainer = Color(0xFFD4593A);
  static const _onSurface = Color(0xFF1A1A2E);
  static const _onSurfVar = Color(0xFF6B6B80);
  static const _outlineVar = Color(0xFFE8E4DE);

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _loadBaseCurrency();
  }

  Future<void> _fetchExchangeRates() async {
    try {
      final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD')).timeout(
        const Duration(seconds: 4),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;
        if (rates != null) {
          if (mounted) {
            setState(() {
              for (final key in _liveRates.keys) {
                if (rates.containsKey(key)) {
                  _liveRates[key] = (rates[key] as num).toDouble();
                }
              }
            });
            debugPrint('Live currency conversion rates loaded successfully: $_liveRates');
          }
        }
      }
    } catch (e) {
      debugPrint('Warning: Could not fetch live exchange rates, using high-quality local fallbacks. $e');
    }
  }

  Future<void> _loadBaseCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base = prefs.getString('base_currency') ?? 'INR';
      if (mounted) {
        setState(() {
          _baseCurrency = base;
        });
      }
    } catch (e) {
      debugPrint('Error loading base currency: $e');
    }
    
    // Fetch live currency exchange rates asynchronously in background
    await _fetchExchangeRates();
    _loadSubscriptions();
  }

  Future<void> _saveBaseCurrency(String cur) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('base_currency', cur);
      setState(() {
        _baseCurrency = cur;
      });
      _loadSubscriptions();
    } catch (e) {
      debugPrint('Error saving base currency: $e');
    }
  }

  // ── currency conversion math using dynamic live rates ────
  double _convert(double amount, String from, String to) {
    final cleanFrom = from.toUpperCase().trim();
    final cleanTo = to.toUpperCase().trim();

    final rateFrom = _liveRates[cleanFrom] ?? 1.0;
    final rateTo = _liveRates[cleanTo] ?? 1.0;

    // Convert amount to USD first, then convert from USD to Target currency
    final usd = amount / rateFrom;
    return usd * rateTo;
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _loading = true);

    // ── dynamic database connection check for auto-login sessions ──
    final mongo = MongoDbService();
    if (!mongo.isConnected) {
      final uri = dotenv.env['MONGO_URI'];
      final host = dotenv.env['MONGO_HOST'] ?? '127.0.0.1';
      final port = int.tryParse(dotenv.env['MONGO_PORT'] ?? '27017') ?? 27017;
      final dbName = dotenv.env['MONGO_DB_NAME'] ?? 'sub_manager';
      
      try {
        await mongo.connect(
          host: host,
          port: port,
          dbName: dbName,
          connectionString: uri,
        );
      } catch (e) {
        debugPrint('Dynamic auto-login DB connection failed: $e');
      }
    }

    final list = await mongo.getSubscriptions(widget.userEmail);

    double total = 0.0;
    double ent = 0.0;
    double soft = 0.0;
    double util = 0.0;
    double other = 0.0;

    for (final s in list) {
      final price = (s['price'] as num?)?.toDouble() ?? 0.0;
      final subCurrency = (s['currency'] ?? 'USD').toString().toUpperCase();

      // Convert sub price into base display currency
      final convertedPrice = _convert(price, subCurrency, _baseCurrency);
      total += convertedPrice;

      final cat = (s['category'] ?? 'Other').toString().toLowerCase();
      if (cat.contains('entertainment')) {
        ent += convertedPrice;
      } else if (cat.contains('software')) {
        soft += convertedPrice;
      } else if (cat.contains('utility')) {
        util += convertedPrice;
      } else {
        other += convertedPrice;
      }
    }

    if (mounted) {
      setState(() {
        _subscriptions = list;
        _totalSpend = total;
        _entSpend = ent;
        _softSpend = soft;
        _utilSpend = util;
        _otherSpend = other;
        _loading = false;
      });
      _entrance.reset();
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _stagger(double s, double e) => CurvedAnimation(
        parent: _entrance,
        curve: Interval(s, e, curve: Curves.easeOutCubic),
      );

  Widget _fade(double s, double e, {required Widget child}) {
    final a = _stagger(s, e);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── top app bar ──────────────────────────────────
          SafeArea(
            bottom: false,
            child: _fade(0.0, 0.3, child: _buildAppBar()),
          ),
          // ── body ─────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary),
                  )
                : RefreshIndicator(
                    onRefresh: _loadSubscriptions,
                    color: _primary,
                    backgroundColor: _surfLow,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _fade(0.08, 0.38, child: _buildSpendCard()),
                          const SizedBox(height: 32),
                          _fade(0.20, 0.50, child: _buildListHeader()),
                          if (_subscriptions.isEmpty)
                            _fade(0.25, 0.60, child: _buildEmptyState())
                          else
                            ..._buildSubList(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      // ── bottom nav ───────────────────────────────────────
      bottomNavigationBar: _fade(0.40, 0.80, child: _buildBottomNav()),
      // ── FAB in bottom right corner ───────────────────────
      floatingActionButton: _fade(
        0.35,
        0.75,
        child: FloatingActionButton.extended(
          onPressed: _showAddSubscriptionSheet,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text('Add subscription', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        ),
      ),
    );
  }

  // ── app bar ──────────────────────────────────────────────
  Widget _buildAppBar() {
    final initials = widget.userName.isNotEmpty
        ? widget.userName[0].toUpperCase()
        : widget.userEmail[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _outlineVar, width: 0.5)),
      ),
      child: Row(
        children: [
          // avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _outlineVar),
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
                  color: _onSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Workspace for ${widget.userName.isNotEmpty ? widget.userName : widget.userEmail}',
                style: const TextStyle(color: _onSurfVar, fontSize: 11),
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
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingPage()),
                  (_) => false,
                );
              }
            },
            icon: const Icon(Icons.logout_rounded, color: _onSurfVar, size: 20),
          ),
        ],
      ),
    );
  }

  // ── monthly spend card ───────────────────────────────────
  Widget _buildSpendCard() {
    final baseSymbol = _currencySymbols[_baseCurrency] ?? '\$';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVar),
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
                  color: _onSurfVar,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              // Base Currency Selector Dropdown
              _buildCurrencyPicker(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // animated count-up
              _CountUpText(
                target: _totalSpend,
                entrance: _entrance,
                currencySymbol: baseSymbol,
                style: const TextStyle(
                  color: _onSurface,
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
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.analytics_outlined, color: _primary, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '${_subscriptions.length} recurring',
                      style: const TextStyle(
                        color: _primary,
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
          // category chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Entertainment', '$baseSymbol${_entSpend.toStringAsFixed(2)}', const Color(0xFFE50914)),
              _chip('Software', '$baseSymbol${_softSpend.toStringAsFixed(2)}', const Color(0xFFA259FF)),
              _chip('Utility', '$baseSymbol${_utilSpend.toStringAsFixed(2)}', const Color(0xFF3395FF)),
              if (_otherSpend > 0)
                _chip('Other', '$baseSymbol${_otherSpend.toStringAsFixed(2)}', _onSurfVar),
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
        color: _surfHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _outlineVar),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _baseCurrency,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _onSurfVar),
          style: const TextStyle(color: _onSurface, fontWeight: FontWeight.w700, fontSize: 11.5),
          dropdownColor: _surfLow,
          borderRadius: BorderRadius.circular(12),
          alignment: Alignment.centerRight,
          onChanged: (val) {
            if (val != null) {
              _saveBaseCurrency(val);
            }
          },
          items: _currencySymbols.keys.map((String cur) {
            final symbol = _currencySymbols[cur] ?? '';
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
        color: _surfHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outlineVar),
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
              color: _onSurfVar,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── list header & empty state ────────────────────────────
  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _outlineVar, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'Active Subscriptions',
            style: TextStyle(
              color: _onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            '${_subscriptions.length} ITEMS',
            style: const TextStyle(
              color: _onSurfVar,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: _surfLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVar),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: _primary, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'No active subscriptions',
            style: TextStyle(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Keep track of your recurring payments by adding them below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _onSurfVar, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _showAddSubscriptionSheet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add your first sub'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: _primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSubList() {
    return List.generate(_subscriptions.length, (i) {
      return _fade(
        0.24 + i * 0.06,
        0.54 + i * 0.06,
        child: _subRow(_subscriptions[i], i == 0),
      );
    });
  }

  Widget _subRow(Map<String, dynamic> s, bool isNext) {
    final name = s['name'] ?? 'Subscription';
    final plan = s['plan'] ?? 'Recurring Plan';
    final price = (s['price'] as num?)?.toDouble() ?? 0.0;
    final renewalStr = s['renewalDate'] ?? 'Monthly';
    final hexColor = s['color'] ?? 'FFD4593A';
    final color = Color(int.tryParse(hexColor, radix: 16) ?? 0xFFD4593A);
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    final subCurrency = (s['currency'] ?? 'USD').toString().toUpperCase();
    final subSymbol = _currencySymbols[subCurrency] ?? '\$';
    final baseSymbol = _currencySymbols[_baseCurrency] ?? '\$';

    final isDifferentCurrency = subCurrency != _baseCurrency;
    final convertedValue = _convert(price, subCurrency, _baseCurrency);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _outlineVar, width: 0.5)),
      ),
      child: Row(
        children: [
          // icon
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
                    color: _onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plan,
                  style: const TextStyle(color: _onSurfVar, fontSize: 13.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Original Billed Price (e.g. ₹999.00 or €9.99)
              Text(
                '$subSymbol${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              // Converted Conversion Annotation if currency is different from base (e.g. ≈ $11.96)
              if (isDifferentCurrency) ...[
                Text(
                  '≈ $baseSymbol${convertedValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
              ],
              Text(
                renewalStr.toUpperCase(),
                style: const TextStyle(
                  color: _onSurfVar,
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
              color: isNext ? _primary : _surfHigh,
            ),
          ),
        ],
      ),
    );
  }

  // ── bottom sheets & forms ────────────────────────────────
  void _showAddSubscriptionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddSubSheet(
        userEmail: widget.userEmail,
        currencies: _currencySymbols,
        onSaved: () {
          Navigator.of(context).pop();
          _loadSubscriptions();
        },
      ),
    );
  }

  // ── bottom nav ───────────────────────────────────────────
  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.calendar_today_rounded, Icons.calendar_today_outlined, 'Timeline'),
      (Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Analytics'),
      (Icons.insights_rounded, Icons.insights_outlined, 'Insights'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _outlineVar, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = _navIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _navIndex = i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? items[i].$1 : items[i].$2,
                        color: active ? _primary : _onSurfVar,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$3,
                        style: TextStyle(
                          color: active ? _primary : _onSurfVar,
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── count-up animation widget ────────────────────────────────
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

// ── ADD SUBSCRIPTION SHEET ───────────────────────────────────
class _AddSubSheet extends StatefulWidget {
  final String userEmail;
  final Map<String, String> currencies;
  final VoidCallback onSaved;
  const _AddSubSheet({
    required this.userEmail,
    required this.currencies,
    required this.onSaved,
  });

  @override
  State<_AddSubSheet> createState() => _AddSubSheetState();
}

class _AddSubSheetState extends State<_AddSubSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  String _currency = 'USD';
  String _category = 'Entertainment';
  String _hexColor = 'FFE50914'; // Default Netflix Red
  bool _saving = false;

  final List<(String, String)> _categories = [
    ('Entertainment', 'FFE50914'),
    ('Software', 'FFA259FF'),
    ('Utility', 'FF3395FF'),
    ('Other', 'FF6B6B80'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _planCtrl.dispose();
    _priceCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD4593A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A1A2E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      setState(() {
        _dateCtrl.text = '${months[picked.month - 1]} ${picked.day}';
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final result = await MongoDbService().addSubscription(
      widget.userEmail,
      {
        'name': _nameCtrl.text.trim(),
        'plan': _planCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0.0,
        'currency': _currency,
        'renewalDate': _dateCtrl.text.trim(),
        'category': _category,
        'color': _hexColor,
      },
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result) {
      widget.onSaved();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save subscription. Check connection.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Subscription',
                    style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6B80)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Field: Name
              _input(_nameCtrl, 'Subscription Name', 'e.g. Netflix, Spotify', Icons.receipt_long_rounded),
              const SizedBox(height: 16),
              // Field: Plan Details
              _input(_planCtrl, 'Plan Details', 'e.g. Standard Plan, Premium Duo', Icons.dns_rounded),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Field: Price
                  Expanded(
                    flex: 11,
                    child: _input(
                      _priceCtrl,
                      'Price',
                      'e.g. 15.49',
                      Icons.attach_money_rounded,
                      keyboard: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Field: Currency Selector Dropdown next to Price
                  Expanded(
                    flex: 9,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF9F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8E4DE)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: const InputDecoration(
                            labelText: 'Cur',
                            labelStyle: TextStyle(color: Color(0xFF6B6B80), fontWeight: FontWeight.w500, fontSize: 11),
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF6B6B80)),
                          style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 13.5),
                          dropdownColor: const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _currency = val;
                              });
                            }
                          },
                          items: widget.currencies.keys.map((String cur) {
                            final symbol = widget.currencies[cur] ?? '';
                            return DropdownMenuItem<String>(
                              value: cur,
                              child: Text('$symbol $cur'),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Field: Renewal Date
              GestureDetector(
                onTap: _selectDate,
                child: AbsorbPointer(
                  child: _input(
                    _dateCtrl,
                    'Renewal Date',
                    'e.g. Jun 15',
                    Icons.calendar_month_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Category Choice Chips
              const Text(
                'Category & Theme',
                style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final active = _category == cat.$1;
                  final chipColor = Color(int.parse(cat.$2, radix: 16));
                  return ChoiceChip(
                    label: Text(cat.$1),
                    selected: active,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _category = cat.$1;
                          _hexColor = cat.$2;
                        });
                      }
                    },
                    selectedColor: chipColor.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: active ? chipColor : const Color(0xFF6B6B80),
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: active ? chipColor : const Color(0xFFE8E4DE)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              // Save Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4593A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Save Subscription',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      validator: validator ?? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFACA8A1), fontWeight: FontWeight.w400, fontSize: 13.5),
        labelStyle: const TextStyle(color: Color(0xFF6B6B80), fontWeight: FontWeight.w500, fontSize: 13.5),
        prefixIcon: Icon(icon, color: const Color(0xFFD4593A), size: 19),
        filled: true,
        fillColor: const Color(0xFFFAF9F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8E4DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8E4DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4593A), width: 1.5),
        ),
      ),
    );
  }
}
