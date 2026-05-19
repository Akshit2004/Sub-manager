import 'package:flutter/material.dart';

class CreateGroupView extends StatelessWidget {
  final bool isAddPage;
  final bool submitting;
  final GlobalKey<FormState> formKey;
  final TextEditingController groupNameCtrl;
  final VoidCallback onCreate;

  const CreateGroupView({
    super.key,
    this.isAddPage = false,
    required this.submitting,
    required this.formKey,
    required this.groupNameCtrl,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isAddPage) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E4DE)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.people_outline_rounded, size: 40, color: Color(0xFFD4593A)),
                  const SizedBox(height: 12),
                  const Text(
                    'How Family Sharing Works',
                    style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow(Icons.sync_rounded, 'Auto-Sync Reminders', 'Sync alerts for all family members.'),
                  const SizedBox(height: 8),
                  _buildFeatureRow(Icons.analytics_outlined, 'Combined Visuals', 'Combined timeline visuals on dashboard.'),
                  const SizedBox(height: 8),
                  _buildFeatureRow(Icons.lock_outline_rounded, 'Secure & Private', 'Secure individual password notes.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          const Text(
            'Create a Family Group',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8E4DE)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: groupNameCtrl,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a group name' : null,
                    style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600, fontSize: 14.0),
                    decoration: const InputDecoration(
                      labelText: 'Family Group Name',
                      hintText: 'e.g. The Sharma Family',
                      prefixIcon: Icon(Icons.group_work_rounded, color: Color(0xFFD4593A)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: submitting ? null : onCreate,
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                            )
                          : const Text('Create Family Group'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFFD4593A)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
