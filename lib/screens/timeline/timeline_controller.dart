import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/mongodb_service.dart';
import '../../utils/currency_utils.dart';

class TimelineController extends ChangeNotifier {
  final String userName;
  final String userEmail;

  bool loading = true;
  List<Map<String, dynamic>> subscriptions = [];
  String baseCurrency = 'INR';

  List<Map<String, dynamic>> thisWeek = [];
  List<Map<String, dynamic>> thisMonth = [];
  List<Map<String, dynamic>> later = [];
  
  StreamSubscription<String>? _syncSubscription;

  TimelineController({required this.userName, required String userEmail})
      : userEmail = userEmail.toLowerCase().trim() {
    _init();
    
    // Listen to background sync notifications to redraw timeline silently
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
    
    _groupSubscriptions();
    loading = false;
    notifyListeners();
  }

  // Parse custom strings like "Jun 15" into DateTimes and group them
  void _groupSubscriptions() {
    thisWeek.clear();
    thisMonth.clear();
    later.clear();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final oneWeekLater = today.add(const Duration(days: 7));
    final oneMonthLater = today.add(const Duration(days: 30));

    final monthsMap = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };

    for (final s in subscriptions) {
      final dateStr = (s['renewalDate'] ?? '').toString().toLowerCase().trim();
      DateTime? renewalDate;

      // Try to parse format: "Jun 15"
      final parts = dateStr.split(' ');
      if (parts.length >= 2) {
        final monthStr = parts[0];
        final dayStr = parts[1];
        final month = monthsMap[monthStr.substring(0, double.parse(monthStr.length.toString()) > 3 ? 3 : monthStr.length)];
        final day = int.tryParse(dayStr);

        if (month != null && day != null) {
          // Construct DateTime for current year
          var year = now.year;
          var testDate = DateTime(year, month, day);
          
          // If the renewal date has already passed this year, assume it's next year
          if (testDate.isBefore(today)) {
            year += 1;
            testDate = DateTime(year, month, day);
          }
          renewalDate = testDate;
        }
      }

      // If parsing failed or date format was generic, use a default fallback
      renewalDate ??= today.add(const Duration(days: 14));

      // Add a helper field to the subscription map for rendering in the UI
      final updatedSub = Map<String, dynamic>.from(s);
      updatedSub['parsedRenewalDate'] = renewalDate;

      if (renewalDate.isBefore(oneWeekLater)) {
        thisWeek.add(updatedSub);
      } else if (renewalDate.isBefore(oneMonthLater)) {
        thisMonth.add(updatedSub);
      } else {
        later.add(updatedSub);
      }
    }

    // Sort groups by parsed date
    int sortFn(Map<String, dynamic> a, Map<String, dynamic> b) {
      final da = a['parsedRenewalDate'] as DateTime;
      final db = b['parsedRenewalDate'] as DateTime;
      return da.compareTo(db);
    }

    thisWeek.sort(sortFn);
    thisMonth.sort(sortFn);
    later.sort(sortFn);
  }
}
