import 'package:flutter/material.dart';
import '../../services/mongodb_service.dart';

class SubDetailsController extends ChangeNotifier {
  final String userEmail;
  Map<String, dynamic> subscription;
  
  bool savingNotes = false;
  bool deleting = false;
  late final TextEditingController notesController;

  SubDetailsController({
    required this.userEmail,
    required this.subscription,
  }) {
    notesController = TextEditingController(text: subscription['notes'] ?? '');
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
