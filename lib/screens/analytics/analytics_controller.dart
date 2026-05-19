import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/mongodb_service.dart';
import '../../utils/currency_utils.dart';

class AnalyticsController extends ChangeNotifier {
  final String userName;
  final String userEmail;

  bool loading = true;
  List<Map<String, dynamic>> subscriptions = [];
  String baseCurrency = 'INR';

  double totalSpend = 0.0;
  double entSpend = 0.0;
  double softSpend = 0.0;
  double utilSpend = 0.0;
  double otherSpend = 0.0;

  double entPercentage = 0.0;
  double softPercentage = 0.0;
  double utilPercentage = 0.0;
  double otherPercentage = 0.0;

  double spendTrend = 0.0;
  bool trendPositive = true;

  List<String> insights = [];
  double lifetimeSavings = 0.0;
  
  StreamSubscription<String>? _syncSubscription;

  AnalyticsController({required this.userName, required this.userEmail}) {
    _init();
    
    // Listen to background sync notifications to redraw analytics charts silently
    _syncSubscription = MongoDbService.syncStream.listen((email) {
      if (email == userEmail) {
        loadSubscriptions(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await loadBaseCurrency();
  }

  Future<void> loadBaseCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      baseCurrency = prefs.getString('base_currency') ?? 'INR';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading base currency: $e');
    }

    await CurrencyUtils.fetchExchangeRates();
    await loadSubscriptions();
  }

  Future<void> loadSubscriptions({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    final list = await MongoDbService().getSubscriptions(userEmail);
    subscriptions = list;

    _calculateAnalytics();
    loading = false;
    notifyListeners();
  }

  void _calculateAnalytics() {
    totalSpend = 0.0;
    entSpend = 0.0;
    softSpend = 0.0;
    utilSpend = 0.0;
    otherSpend = 0.0;

    for (final s in subscriptions) {
      final price = (s['price'] as num?)?.toDouble() ?? 0.0;
      final currency = (s['currency'] ?? 'USD').toString().toUpperCase();
      final cat = (s['category'] ?? 'Other').toString().toLowerCase();

      final basePrice = CurrencyUtils.convert(price, currency, baseCurrency);
      totalSpend += basePrice;

      if (cat.contains('entertainment')) {
        entSpend += basePrice;
      } else if (cat.contains('software')) {
        softSpend += basePrice;
      } else if (cat.contains('utility')) {
        utilSpend += basePrice;
      } else {
        otherSpend += basePrice;
      }
    }

    if (totalSpend > 0) {
      entPercentage = entSpend / totalSpend;
      softPercentage = softSpend / totalSpend;
      utilPercentage = utilSpend / totalSpend;
      otherPercentage = otherSpend / totalSpend;
    } else {
      entPercentage = 0.0;
      softPercentage = 0.0;
      utilPercentage = 0.0;
      otherPercentage = 0.0;
    }

    // Dynamic month-over-month trend calculation
    double previousSpend = 0.0;
    final now = DateTime.now();
    final firstOfThisMonth = DateTime(now.year, now.month, 1);

    for (final s in subscriptions) {
      final price = (s['price'] as num?)?.toDouble() ?? 0.0;
      final currency = (s['currency'] ?? 'USD').toString().toUpperCase();
      final basePrice = CurrencyUtils.convert(price, currency, baseCurrency);

      final createdAtStr = s['createdAt']?.toString();
      DateTime? createdDate;
      if (createdAtStr != null) {
        try {
          createdDate = DateTime.parse(createdAtStr);
        } catch (_) {}
      }

      if (createdDate == null || createdDate.isBefore(firstOfThisMonth)) {
        previousSpend += basePrice;
      }
    }

    if (previousSpend > 0) {
      spendTrend = ((totalSpend - previousSpend) / previousSpend) * 100;
      trendPositive = spendTrend >= 0;
    } else {
      spendTrend = totalSpend > 0 ? 100.0 : 0.0;
      trendPositive = true;
    }

    // Dynamic Optimization Insights
    insights.clear();
    final Map<String, List<String>> categorySubs = {};
    for (final s in subscriptions) {
      final name = s['name'] ?? 'Subscription';
      final cat = s['category'] ?? 'Other';
      categorySubs.putIfAbsent(cat, () => []).add(name);
    }

    categorySubs.forEach((cat, names) {
      if (names.length > 2 && cat.toLowerCase().contains('entertainment')) {
        insights.add(
          'You have ${names.length} overlapping streaming services. Cancelling one could save you average of ${(entSpend / names.length).toStringAsFixed(2)} $baseCurrency/mo.'
        );
      }
    });

    if (insights.isEmpty) {
      if (subscriptions.length > 5) {
        insights.add('Great job! Your subscription profile is highly optimized. Keep track of scheduled timeline renewals.');
      } else {
        insights.add('Add more recurring payments to scan for overlap and optimization discoveries.');
      }
    }

    // Dynamic Lifetime Savings (Mock representation using duration + active optimization count)
    lifetimeSavings = (totalSpend * 0.15) * 6; // Representing standard average cancellation savings over 6 months
  }
}
