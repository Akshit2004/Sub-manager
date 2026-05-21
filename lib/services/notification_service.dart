import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notifications plugin and setup local timezone databases
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Initialize Timezones
      tz.initializeTimeZones();
      
      // Setup current timezone securely via flutter_timezone
      String timeZoneName = 'UTC';
      try {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        timeZoneName = timezoneInfo.identifier;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        debugPrint('Warning: Timezone initialization failed for "$timeZoneName", falling back to UTC: $e');
        try {
          tz.setLocalLocation(tz.getLocation('UTC'));
        } catch (_) {}
      }

      // Android settings - use customized Terracotta brand launcher icon
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // iOS settings
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      _initialized = true;
      debugPrint('NotificationService initialized successfully.');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Request runtime permissions on Android 13+ and iOS
  Future<bool> requestPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final bool? granted = await androidImplementation?.requestNotificationsPermission();
        return granted ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final bool? granted = await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Helper to convert a custom Month-Day string (e.g., "Jun 15") into a DateTime
  DateTime? _parseRenewalDate(String renewalDateStr) {
    final monthsMap = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };

    try {
      final dateStr = renewalDateStr.toLowerCase().trim();
      final parts = dateStr.split(' ');
      if (parts.length >= 2) {
        final monthStr = parts[0];
        final dayStr = parts[1];
        
        final monthKey = monthStr.substring(0, monthStr.length > 3 ? 3 : monthStr.length);
        final month = monthsMap[monthKey];
        final day = int.tryParse(dayStr);

        if (month != null && day != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          var year = now.year;
          var renewalDate = DateTime(year, month, day);
          
          // If the date has already passed this year, assume the next cycle is next year
          if (renewalDate.isBefore(today)) {
            year += 1;
            renewalDate = DateTime(year, month, day);
          }
          return renewalDate;
        }
      }
    } catch (e) {
      debugPrint('Error parsing subscription renewal date "$renewalDateStr": $e');
    }
    return null;
  }

  /// Unique hash code helper to represent string subscription IDs as distinct base integers
  int _getSubBaseId(String subId) {
    return subId.hashCode.abs() % 100000000; // Limit length to fit safely in a 32-bit Android ID
  }

  /// Schedule reminders 5 days and 2 days before the renewal date for the next 5 cycles (years)
  Future<void> scheduleSubscriptionReminders(Map<String, dynamic> sub) async {
    await init(); // Ensure initialization has completed

    final String subName = sub['name'] ?? 'Subscription';
    final String? renewalDateStr = sub['renewalDate'];
    final String rawSubId = (sub['id'] ?? sub['createdAt'] ?? '').toString();

    if (renewalDateStr == null || renewalDateStr.isEmpty || rawSubId.isEmpty) {
      debugPrint('Skipping reminders: subscription details are incomplete.');
      return;
    }

    final DateTime? initialRenewal = _parseRenewalDate(renewalDateStr);
    if (initialRenewal == null) {
      debugPrint('Skipping reminders: failed to parse renewal date "$renewalDateStr".');
      return;
    }

    final double price = (sub['price'] as num?)?.toDouble() ?? 0.0;
    final String currency = sub['currency'] ?? 'USD';

    // First cancel any existing notifications for this subscription to avoid duplicates/stales
    await cancelSubscriptionReminders(rawSubId);

    final int baseId = _getSubBaseId(rawSubId);
    final now = DateTime.now();

    // Pre-schedule notifications for the next 5 cycles (years)
    for (int cycle = 0; cycle < 5; cycle++) {
      // Calculate renewal date for this specific future cycle
      final DateTime cycleRenewalDate = DateTime(
        initialRenewal.year + cycle,
        initialRenewal.month,
        initialRenewal.day,
      );

      // ── Schedule 5-Day Alert ──────────────────────────────────────
      final DateTime alert5Day = cycleRenewalDate.subtract(const Duration(days: 5));
      // Schedule for 9:00 AM on the target day
      final DateTime alert5DayScheduled = DateTime(
        alert5Day.year,
        alert5Day.month,
        alert5Day.day,
        9, // Hour
        0, // Minute
      );

      // Only schedule if the alert time is in the future
      if (alert5DayScheduled.isAfter(now)) {
        final int notificationId = baseId + (cycle * 10) + 5;
        await _scheduleNotification(
          id: notificationId,
          title: '$subName Renewal Warning',
          body: 'Your $subName subscription ($currency $price) will renew in 5 days on $renewalDateStr.',
          scheduledDate: alert5DayScheduled,
          payload: 'sub_details:$rawSubId',
        );
      }

      // ── Schedule 2-Day Alert ──────────────────────────────────────
      final DateTime alert2Day = cycleRenewalDate.subtract(const Duration(days: 2));
      // Schedule for 9:00 AM on the target day
      final DateTime alert2DayScheduled = DateTime(
        alert2Day.year,
        alert2Day.month,
        alert2Day.day,
        9, // Hour
        0, // Minute
      );

      // Only schedule if the alert time is in the future
      if (alert2DayScheduled.isAfter(now)) {
        final int notificationId = baseId + (cycle * 10) + 2;
        await _scheduleNotification(
          id: notificationId,
          title: '$subName Renewal Alert',
          body: 'Your $subName subscription ($currency $price) is renewing in 2 days on $renewalDateStr!',
          scheduledDate: alert2DayScheduled,
          payload: 'sub_details:$rawSubId',
        );
      }
    }

    debugPrint('Scheduled 5-cycle reminders (5-day & 2-day) successfully for "$subName".');
  }

  /// Internal scheduled zoned helper
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String payload,
  }) async {
    try {
      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'subscription_renewals',
            'Subscription Renewals',
            channelDescription: 'Alerts prior to subscription billing renewals',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFFD4593A), // Match Terracotta Brand Color
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error scheduling notification ID $id: $e');
    }
  }

  /// Cancel all scheduled reminders (5-day and 2-day alerts across 5 cycles) for a specific subscription
  Future<void> cancelSubscriptionReminders(String subId) async {
    if (subId.isEmpty) return;
    
    final int baseId = _getSubBaseId(subId);
    
    try {
      // Loop over the scheduled cycle intervals and cancel them
      for (int cycle = 0; cycle < 5; cycle++) {
        final int id5Day = baseId + (cycle * 10) + 5;
        final int id2Day = baseId + (cycle * 10) + 2;
        
        await _notificationsPlugin.cancel(id5Day);
        await _notificationsPlugin.cancel(id2Day);
      }
      debugPrint('Cancelled all pending reminders for subscription ID: $subId');
    } catch (e) {
      debugPrint('Error cancelling reminders for subscription $subId: $e');
    }
  }

  /// Bulk sync: schedules reminders for all subscriptions of a user
  Future<void> syncAllSubscriptionsReminders(List<Map<String, dynamic>> subs) async {
    debugPrint('Syncing local reminders for ${subs.length} subscriptions...');
    for (final sub in subs) {
      await scheduleSubscriptionReminders(sub);
    }
    debugPrint('All local reminders synced successfully.');
  }
}
