import 'package:flutter/material.dart';
import '../../services/mongodb_service.dart';

class SubDetailsController extends ChangeNotifier {
  final String userEmail;
  Map<String, dynamic> subscription;
  
  bool savingNotes = false;
  bool deleting = false;
  bool loadingGroup = true;
  List<Map<String, dynamic>> userGroups = [];
  late final TextEditingController notesController;

  SubDetailsController({
    required this.userEmail,
    required this.subscription,
  }) {
    notesController = TextEditingController(text: subscription['notes'] ?? '');
    _initGroup();
  }

  Future<void> _initGroup() async {
    loadingGroup = true;
    notifyListeners();
    userGroups = await MongoDbService().getUserGroups(userEmail);
    loadingGroup = false;
    notifyListeners();
  }

  Future<bool> updateGroupSharing(String? groupId) async {
    final mongo = MongoDbService();
    final success = await mongo.updateSubscriptionGroup(userEmail, id, groupId);
    if (success) {
      if (groupId == null) {
        subscription.remove('groupId');
      } else {
        subscription['groupId'] = groupId;
      }
      notifyListeners();
    }
    return success;
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  String get id {
    final s = subscription;
    return (s['_id'] != null)
        ? s['_id'].toString().replaceAll('ObjectId("', '').replaceAll('")', '')
        : (s['id'] ?? s['createdAt'] ?? '').toString();
  }

  Future<void> saveNotes() async {
    final newNotes = notesController.text.trim();
    if (newNotes == (subscription['notes'] ?? '')) return;

    savingNotes = true;
    notifyListeners();

    final mongo = MongoDbService();
    final success = await mongo.updateSubscriptionNotes(userEmail, id, newNotes);
    if (success) {
      subscription['notes'] = newNotes;
    }

    savingNotes = false;
    notifyListeners();
  }

  Future<bool> cancelSubscription() async {
    deleting = true;
    notifyListeners();

    final mongo = MongoDbService();
    final success = await mongo.deleteSubscriptions(userEmail, [id]);

    deleting = false;
    notifyListeners();
    return success;
  }
}
