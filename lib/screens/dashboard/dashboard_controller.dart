import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../services/mongodb_service.dart';
import '../../../utils/currency_utils.dart';

class DashboardController extends ChangeNotifier {
  final String userName;
  final String userEmail;

  bool loading = true;
  List<Map<String, dynamic>> subscriptions = [];
  double totalSpend = 0.0;
  String baseCurrency = 'INR';

  double entSpend = 0.0;
  double softSpend = 0.0;
  double utilSpend = 0.0;
  double otherSpend = 0.0;

  bool isSelectionMode = false;
  final Set<String> selectedIds = {};
  
  StreamSubscription<String>? _syncSubscription;

  DashboardController({required this.userName, required String userEmail})
      : userEmail = userEmail.toLowerCase().trim() {
    _init();
    
    // Listen to background synchronizations to update dashboard silently
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
    // loadSubscriptions is called inside loadBaseCurrency after fetchExchangeRates
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

  Future<void> saveBaseCurrency(String cur) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('base_currency', cur);
      baseCurrency = cur;
      notifyListeners();
      await loadSubscriptions();
    } catch (e) {
      debugPrint('Error saving base currency: $e');
    }
  }

  Future<void> loadSubscriptions({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    final list = await MongoDbService().getSubscriptions(userEmail);

    double total = 0.0;
    double ent = 0.0;
    double soft = 0.0;
    double util = 0.0;
    double other = 0.0;

    for (final s in list) {
      final price = (s['price'] as num?)?.toDouble() ?? 0.0;
      final subCurrency = (s['currency'] ?? 'USD').toString().toUpperCase();

      final convertedPrice = CurrencyUtils.convert(price, subCurrency, baseCurrency);
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

    subscriptions = list;
    totalSpend = total;
    entSpend = ent;
    softSpend = soft;
    utilSpend = util;
    otherSpend = other;
    loading = false;
    notifyListeners();
  }

  void toggleSelectionMode() {
    isSelectionMode = !isSelectionMode;
    selectedIds.clear();
    notifyListeners();
  }

  void cancelSelection() {
    isSelectionMode = false;
    selectedIds.clear();
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    final allSelected = selectedIds.length == subscriptions.length && subscriptions.isNotEmpty;
    selectedIds.clear();
    if (!allSelected) {
      for (final s in subscriptions) {
        final id = (s['_id'] != null)
            ? s['_id'].toString().replaceAll('ObjectId("', '').replaceAll('")', '')
            : (s['id'] ?? s['createdAt'] ?? '').toString();
        if (id.isNotEmpty) selectedIds.add(id);
      }
    }
    notifyListeners();
  }

  Future<void> confirmBulkDelete(BuildContext context) async {
    final count = selectedIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Subscriptions?',
          style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        content: Text(
          'Are you sure you want to permanently delete these $count selected subscription(s) from your workspace? This action is irreversible.',
          style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4593A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      loading = true;
      notifyListeners();
      
      final success = await MongoDbService().deleteSubscriptions(
        userEmail,
        selectedIds.toList(),
      );

      if (success) {
        selectedIds.clear();
        isSelectionMode = false;
      }
      loading = false;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Successfully deleted $count subscription(s)' : 'Failed to delete subscriptions. Check network.',
            ),
            backgroundColor: success ? const Color(0xFF1A1A2E) : const Color(0xFFD4593A),
          ),
        );
      }
      await loadSubscriptions();
    }
  }
}
