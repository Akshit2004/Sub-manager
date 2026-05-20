import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/mongodb_service.dart';
import '../../services/email_service.dart';

class FamilyController extends ChangeNotifier {
  final String userName;
  final String userEmail;
  final VoidCallback onGroupChanged;

  bool loading = true;
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> invites = [];
  List<Map<String, dynamic>> subscriptions = [];
  bool submitting = false;

  StreamSubscription<String>? _syncSubscription;

  FamilyController({
    required this.userName,
    required String userEmail,
    required this.onGroupChanged,
  }) : userEmail = userEmail.toLowerCase().trim() {
    loadFamilyData();

    // Listen to background synchronizations to update family data silently
    _syncSubscription = MongoDbService.syncStream.listen((email) {
      if (email == userEmail) {
        loadFamilyData(silent: true);
      }
    });
  }

  Future<void> loadFamilyData({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    final mongo = MongoDbService();
    groups = await mongo.getUserGroups(userEmail);
    invites = await mongo.getInvitesForUser(userEmail);
    subscriptions = await mongo.getSubscriptions(userEmail);

    loading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> createGroup(String groupName) async {
    submitting = true;
    notifyListeners();

    final res = await MongoDbService().createGroup(groupName, userEmail);

    submitting = false;
    notifyListeners();

    if (res['success'] == true) {
      await loadFamilyData();
      onGroupChanged();
    }
    return res;
  }

  Future<Map<String, dynamic>> sendInvite(String groupId, String groupName, String invitedEmail) async {
    submitting = true;
    notifyListeners();

    final res = await MongoDbService().inviteMember(groupId, invitedEmail);

    submitting = false;
    notifyListeners();

    if (res['success'] == true) {
      await loadFamilyData();
      EmailService().sendGroupInviteEmail(
        recipientEmail: invitedEmail,
        groupName: groupName,
        ownerEmail: userEmail,
      );
    }
    return res;
  }

  Future<Map<String, dynamic>> acceptInvite(String groupId) async {
    loading = true;
    notifyListeners();

    final res = await MongoDbService().acceptInvite(groupId, userEmail);
    await loadFamilyData();
    onGroupChanged();
    return res;
  }

  Future<Map<String, dynamic>> declineInvite(String groupId) async {
    loading = true;
    notifyListeners();

    final res = await MongoDbService().declineInvite(groupId, userEmail);
    await loadFamilyData();
    return res;
  }

  Future<Map<String, dynamic>> leaveGroup(String groupId) async {
    loading = true;
    notifyListeners();

    final res = await MongoDbService().leaveGroup(groupId, userEmail);
    await loadFamilyData();
    onGroupChanged();
    return res;
  }

  Future<bool> linkSubscriptions(String groupId, List<String> subIds) async {
    loading = true;
    notifyListeners();

    final mongo = MongoDbService();
    bool allSuccess = true;
    for (final id in subIds) {
      final success = await mongo.updateSubscriptionGroup(userEmail, id, groupId);
      if (!success) allSuccess = false;
    }

    await loadFamilyData();
    onGroupChanged();
    return allSuccess;
  }

  Future<bool> unlinkSubscription(String subId) async {
    loading = true;
    notifyListeners();

    final mongo = MongoDbService();
    final success = await mongo.updateSubscriptionGroup(userEmail, subId, null);
    
    await loadFamilyData();
    onGroupChanged();
    return success;
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }
}
