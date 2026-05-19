import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  String get _user => dotenv.env['EMAIL_USER'] ?? 'flowceptsupport@gmail.com';
  String get _pass => dotenv.env['EMAIL_PASS'] ?? 'smwnyorhhrkhiofu';

  SmtpServer get _smtpServer {
    // Gmail SMTP helper from mailer package
    return gmail(_user, _pass);
  }

  /// Send a family group invitation email
  Future<bool> sendGroupInviteEmail({
    required String recipientEmail,
    required String groupName,
    required String ownerEmail,
  }) async {
    final message = Message()
      ..from = Address(_user, 'Sub Manager Family')
      ..recipients.add(recipientEmail.trim().toLowerCase())
      ..subject = 'You have been invited to join "$groupName"!'
      ..html = '''
        <div style="font-family: sans-serif; padding: 24px; color: #1A1A2E; max-width: 600px; margin: 0 auto; border: 1px solid #E8E4DE; border-radius: 16px; background-color: #FFFFFF;">
          <div style="text-align: center; margin-bottom: 20px;">
            <h2 style="color: #D4593A; margin: 0; font-size: 24px; font-weight: 800; letter-spacing: -0.5px;">Sub Manager Pro</h2>
            <span style="font-size: 11px; color: #6B6B80; font-weight: 700; letter-spacing: 1px; text-transform: uppercase;">Family Sync</span>
          </div>
          
          <p style="font-size: 15px; line-height: 1.5; color: #33334d; margin-top: 0;">
            Hey there!
          </p>
          <p style="font-size: 15px; line-height: 1.5; color: #33334d;">
            Great news! <strong>$ownerEmail</strong> has invited you to pool your recurring subscriptions, split bills, and sync due date reminders under their new Family Group: <strong style="color: #D4593A;">"$groupName"</strong>.
          </p>
          
          <div style="background-color: #FAF9F6; border: 1px dashed #D4593A; border-radius: 12px; padding: 18px; margin: 24px 0; text-align: center;">
            <span style="font-size: 12px; color: #D4593A; font-weight: 800; letter-spacing: 0.8px; text-transform: uppercase;">Accept the Invitation</span>
            <p style="margin: 8px 0 0 0; font-size: 14.5px; font-weight: 600; color: #1A1A2E; line-height: 1.4;">
              Open <strong>Sub Manager Pro</strong> on your device, tap the <strong>Family Sharing</strong> tab, and click <strong>Accept & Join</strong>!
            </p>
          </div>
          
          <p style="font-size: 14px; line-height: 1.5; color: #6B6B80;">
            Once you join, any shared subscriptions added by group members will automatically sync to your dashboard and calendar timeline.
          </p>
          
          <p style="font-size: 11px; color: #ACA8A1; border-top: 1px solid #E8E4DE; padding-top: 16px; margin-top: 28px; text-align: center;">
            This email was sent automatically from Sub Manager Pro alerts.
          </p>
        </div>
      ''';

    try {
      await send(message, _smtpServer);
      debugPrint('Invite email sent successfully to $recipientEmail');
      return true;
    } catch (e) {
      debugPrint('Failed to send invite email: $e');
      return false;
    }
  }

  /// Send a billing due alert to all members of a family group
  Future<bool> sendBillingReminder({
    required List<String> memberEmails,
    required String subscriptionName,
    required String priceStr,
    required String renewalDate,
    required String ownerEmail,
  }) async {
    final cleanEmails = memberEmails.map((e) => e.trim().toLowerCase()).toList();
    if (cleanEmails.isEmpty) return false;

    final message = Message()
      ..from = Address(_user, 'Sub Manager Family')
      ..recipients.addAll(cleanEmails)
      ..subject = '⏳ Synced Family Renewal Alert: $subscriptionName due soon!'
      ..html = '''
        <div style="font-family: sans-serif; padding: 24px; color: #1A1A2E; max-width: 600px; margin: 0 auto; border: 1px solid #E8E4DE; border-radius: 16px; background-color: #FFFFFF;">
          <div style="text-align: center; margin-bottom: 20px;">
            <h2 style="color: #D4593A; margin: 0; font-size: 24px; font-weight: 800; letter-spacing: -0.5px;">Sub Manager Pro</h2>
            <span style="font-size: 11px; color: #6B6B80; font-weight: 700; letter-spacing: 1px; text-transform: uppercase;">Family Sync</span>
          </div>

          <p style="font-size: 15px; line-height: 1.5; color: #33334d; margin-top: 0; text-align: center;">
            <strong>⚠️ Synced Family Renewal Notice</strong>
          </p>
          <p style="font-size: 14.5px; line-height: 1.5; color: #6B6B80; text-align: center;">
            This is an automatic notification for a shared family subscription billing cycle:
          </p>
          
          <div style="background-color: #FAF9F6; border-radius: 12px; padding: 20px; margin: 24px 0; border: 1px solid #E8E4DE;">
            <table style="width: 100%; font-size: 14.5px; border-collapse: collapse;">
              <tr style="border-bottom: 1px solid #E8E4DE;">
                <td style="color: #6B6B80; padding: 10px 0; font-weight: 500;">Subscription:</td>
                <td style="color: #1A1A2E; font-weight: 700; text-align: right; padding: 10px 0;">$subscriptionName</td>
              </tr>
              <tr style="border-bottom: 1px solid #E8E4DE;">
                <td style="color: #6B6B80; padding: 10px 0; font-weight: 500;">Recurring Cost:</td>
                <td style="color: #D4593A; font-weight: 800; text-align: right; padding: 10px 0; font-size: 17px;">$priceStr</td>
              </tr>
              <tr style="border-bottom: 1px solid #E8E4DE;">
                <td style="color: #6B6B80; padding: 10px 0; font-weight: 500;">Renewal Date:</td>
                <td style="color: #1A1A2E; font-weight: 700; text-align: right; padding: 10px 0;">$renewalDate</td>
              </tr>
              <tr>
                <td style="color: #6B6B80; padding: 10px 0; font-weight: 500;">Group Manager:</td>
                <td style="color: #6B6B80; text-align: right; padding: 10px 0; font-style: italic;">$ownerEmail</td>
              </tr>
            </table>
          </div>
          
          <p style="font-size: 13.5px; line-height: 1.4; color: #6B6B80; text-align: center; margin-bottom: 0;">
            Please coordinate expense splits or payments before the renewal date to avoid service disruption.
          </p>
          
          <p style="font-size: 11px; color: #ACA8A1; border-top: 1px solid #E8E4DE; padding-top: 16px; margin-top: 28px; text-align: center;">
            Sent to all verified members of this Family Group on Sub Manager Pro.
          </p>
        </div>
      ''';

    try {
      await send(message, _smtpServer);
      debugPrint('Billing due alert sent successfully to members');
      return true;
    } catch (e) {
      debugPrint('Failed to send billing reminder email: $e');
      return false;
    }
  }
}
