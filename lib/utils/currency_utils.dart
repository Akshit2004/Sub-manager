import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CurrencyUtils {
  static const Map<String, String> currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'JPY': '¥',
  };

  static final Map<String, double> liveRates = {
    'USD': 1.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'INR': 83.5,
    'JPY': 156.0,
  };

  static Future<void> fetchExchangeRates() async {
    try {
      final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD')).timeout(
        const Duration(seconds: 4),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;
        if (rates != null) {
          for (final key in liveRates.keys) {
            if (rates.containsKey(key)) {
              liveRates[key] = (rates[key] as num).toDouble();
            }
          }
          debugPrint('Live currency conversion rates loaded successfully: $liveRates');
        }
      }
    } catch (e) {
      debugPrint('Warning: Could not fetch live exchange rates, using high-quality local fallbacks. $e');
    }
  }

  static double convert(double amount, String from, String to) {
    final cleanFrom = from.toUpperCase().trim();
    final cleanTo = to.toUpperCase().trim();

    final rateFrom = liveRates[cleanFrom] ?? 1.0;
    final rateTo = liveRates[cleanTo] ?? 1.0;

    // Convert amount to USD first, then convert from USD to Target currency
    final usd = amount / rateFrom;
    return usd * rateTo;
  }
}
