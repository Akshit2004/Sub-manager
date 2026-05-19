import 'package:flutter/material.dart';
import '../family_controller.dart';
import 'family_invite_card.dart';

class ActiveGroupView extends StatelessWidget {
  final Map<String, dynamic> group;
  final FamilyController controller;
  final bool isFirstPage;
  
  final GlobalKey<FormState> inviteFormKey;
  final TextEditingController inviteEmailCtrl;

  const ActiveGroupView({
    super.key,
    required this.group,
    required this.controller,
    required this.isFirstPage,
    required this.inviteFormKey,
    required this.inviteEmailCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final name = group['name'] ?? 'Family Group';
    final owner = group['ownerEmail'] ?? '';
    final members = List<String>.from(group['members'] ?? []);
    final pending = List<String>.from(group['pendingInvites'] ?? []);
    final isOwner = owner.toLowerCase().trim() == controller.userEmail.toLowerCase().trim();
    final linkedSubs = controller.subscriptions.where((s) => s['groupId'] == group['id']).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Invites logic specific to the first active page if exists
          if (isFirstPage && controller.invites.isNotEmpty) ...[
            _buildSectionHeader('Incoming Invitations'),
            const SizedBox(height: 12),
            ...controller.invites.map((invite) => FamilyInviteCard(
                  invite: invite,
                  onAccept: () async {
                    final res = await controller.acceptInvite(invite['id']);
                    if (context.mounted) _showSnackBar(context, res['message'] ?? '', res['success'] == true);
                  },
                  onDecline: () async {
                    final res = await controller.declineInvite(invite['id']);
                    if (context.mounted) _showSnackBar(context, res['message'] ?? '', res['success'] == true);
                  },
                )),
            const SizedBox(height: 32),
          ],

          // ── Group Info Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFD4593A), const Color(0xFFD4593A).withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4593A).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Created on ${group['createdAt']?.toString().substring(0, 10) ?? 'Recently'}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        isOwner ? 'OWNER' : 'MEMBER',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MEMBERS ACTIVE',
                          style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${members.length} member(s)',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (pending.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'PENDING INVITES',
                            style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pending.length} pending',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Shared Subscriptions Segment
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Shared Subscriptions'),
              TextButton.icon(
                onPressed: () => _showLinkSubscriptionsSheet(context, group),
                icon: const Icon(Icons.link_rounded, size: 16, color: Color(0xFFD4593A)),
                label: const Text(
                  'Link Plans',
                  style: TextStyle(color: Color(0xFFD4593A), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (linkedSubs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E4DE)),
              ),
              child: Column(
                children: [
                  Icon(Icons.link_off_rounded, size: 36, color: const Color(0xFFACA8A1).withValues(alpha: 0.8)),
                  const SizedBox(height: 8),
                  const Text(
                    'No shared subscriptions in this pool',
                    style: TextStyle(color: Color(0xFF6B6B80), fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => _showLinkSubscriptionsSheet(context, group),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD4593A),
                        side: const BorderSide(color: Color(0xFFD4593A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Link Existing Subscriptions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E4DE)),
              ),
              child: Column(
                children: List.generate(linkedSubs.length, (i) {
                  final sub = linkedSubs[i];
                  final subName = sub['name'] ?? 'Plan';
                  final price = sub['price'] ?? 0.0;
                  final currency = sub['currency'] ?? 'USD';
                  final colorHex = sub['color'] ?? 'FF6B6B80';
                  final color = Color(int.tryParse(colorHex, radix: 16) ?? 0xFF6B6B80);
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: i == linkedSubs.length - 1
                          ? null
                          : const Border(bottom: BorderSide(color: Color(0xFFE8E4DE), width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 24,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subName,
                                style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 14.5),
                              ),
                              Text(
                                sub['plan'] ?? 'No plan details',
                                style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$price $currency',
                          style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.link_off_rounded, color: Color(0xFFDC2626), size: 18),
                          onPressed: () => _handleUnlinkSubscription(context, sub),
                          tooltip: 'Unlink from family',
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          const SizedBox(height: 32),

          // ── Members List
          _buildSectionHeader('Family Members'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8E4DE)),
            ),
            child: Column(
              children: [
                ...List.generate(members.length, (i) {
                  final m = members[i];
                  final isMe = m.toLowerCase().trim() == controller.userEmail.toLowerCase().trim();
                  final isGroupOwner = m.toLowerCase().trim() == owner.toLowerCase().trim();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: i == members.length - 1
                          ? null
                          : const Border(bottom: BorderSide(color: Color(0xFFE8E4DE), width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isGroupOwner ? const Color(0xFFD4593A) : const Color(0xFF6B6B80),
                          child: Text(
                            m[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMe ? '${controller.userName} (You)' : m.split('@')[0],
                                style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 14.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m,
                                style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        if (isGroupOwner)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4593A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Owner',
                              style: TextStyle(color: Color(0xFFD4593A), fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Invites List (if owner)
          if (isOwner && pending.isNotEmpty) ...[
            _buildSectionHeader('Pending Invitations'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E4DE)),
              ),
              child: Column(
                children: List.generate(pending.length, (i) {
                  final p = pending[i];
                  return ListTile(
                    title: Text(p, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_empty_rounded, size: 16, color: Color(0xFF6B6B80)),
                        SizedBox(width: 6),
                        Text('Invited', style: TextStyle(color: Color(0xFF6B6B80), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // ── Invite Panel
          if (isOwner) ...[
            _buildSectionHeader('Invite Family Member'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E4DE)),
              ),
              child: Form(
                key: inviteFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: inviteEmailCtrl,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter an email';
                        if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                        return null;
                      },
                      style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600, fontSize: 14.5),
                      decoration: const InputDecoration(
                        labelText: 'Member Email Address',
                        hintText: 'e.g. sister@gmail.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded, color: Color(0xFFD4593A)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: controller.submitting ? null : () async {
                          if (!inviteFormKey.currentState!.validate()) return;
                          final email = inviteEmailCtrl.text.trim();
                          final res = await controller.sendInvite(group['id'], group['name'] ?? 'Group', email);
                          if (context.mounted) _showSnackBar(context, res['message'] ?? '', res['success'] == true);
                          if (res['success'] == true) {
                            inviteEmailCtrl.clear();
                          }
                        },
                        child: controller.submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Send Group Invite'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // ── Danger Zone
          _buildSectionHeader(isOwner ? 'Disband Group' : 'Leave Group'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isOwner
                      ? 'Disbanding this Family Group will immediately kick all members out and stop sharing subscription data.'
                      : 'Leaving this Family Group will stop sharing your subscriptions, and you will no longer see other members\' bills.',
                  style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _handleLeaveGroup(context, group, isOwner),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isOwner ? 'Disband Family Group' : 'Leave Family Group',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1A1A2E),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
          ],
        ),
        backgroundColor: success ? const Color(0xFF1A1A2E) : const Color(0xFFD4593A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleLeaveGroup(BuildContext context, Map<String, dynamic> group, bool isOwner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isOwner ? 'Disband Family Group?' : 'Leave Family Group?',
          style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        content: Text(
          isOwner
              ? 'Are you sure you want to permanently disband this group? All shared subscriptions will return to individual status for their respective owners.'
              : 'Are you sure you want to leave this family group? You will no longer see shared family subscriptions on your timeline or dashboard.',
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
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(isOwner ? 'Disband' : 'Leave', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final res = await controller.leaveGroup(group['id']);
      if (context.mounted) _showSnackBar(context, res['message'] ?? '', res['success'] == true);
    }
  }

  void _showLinkSubscriptionsSheet(BuildContext context, Map<String, dynamic> group) {
    final privateSubs = controller.subscriptions.where((s) => s['groupId'] == null).toList();
    
    if (privateSubs.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('No Private Subscriptions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          content: const Text(
            'All of your subscriptions are already shared with family groups, or you do not have any subscriptions configured yet. Add private subscriptions on your Home tab to link them here!',
            style: TextStyle(color: Color(0xFF6B6B80), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Understood', style: TextStyle(color: Color(0xFFD4593A), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        List<String> selectedSubIds = [];
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Link Existing Subscriptions',
                        style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF6B6B80)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select which private subscriptions to link to ${group['name'] ?? 'Family'}. These will be shared instantly with all group members.',
                    style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: privateSubs.length,
                      itemBuilder: (context, index) {
                        final sub = privateSubs[index];
                        final subId = sub['_id']?.toString() ?? sub['id'] ?? sub['createdAt'] ?? '';
                        final cleanId = subId.toString().replaceAll('ObjectId("', '').replaceAll('")', '');
                        final name = sub['name'] ?? 'Plan';
                        final plan = sub['plan'] ?? 'No plan details';
                        final colorHex = sub['color'] ?? 'FF6B6B80';
                        final color = Color(int.tryParse(colorHex, radix: 16) ?? 0xFF6B6B80);
                        final isChecked = selectedSubIds.contains(cleanId);

                        return CheckboxListTile(
                          activeColor: const Color(0xFFD4593A),
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Text(plan, style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12)),
                          ),
                          value: isChecked,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedSubIds.add(cleanId);
                              } else {
                                selectedSubIds.remove(cleanId);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: selectedSubIds.isEmpty
                          ? null
                          : () async {
                              Navigator.of(context).pop();
                              final success = await controller.linkSubscriptions(group['id'], selectedSubIds);
                              if (context.mounted) {
                                if (success) {
                                  _showSnackBar(context, 'Subscriptions linked successfully!', true);
                                } else {
                                  _showSnackBar(context, 'Some subscriptions failed to link.', false);
                                }
                              }
                            },
                      child: Text('Link Selected (${selectedSubIds.length})'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleUnlinkSubscription(BuildContext context, Map<String, dynamic> sub) async {
    final subId = (sub['_id'] != null)
        ? sub['_id'].toString().replaceAll('ObjectId("', '').replaceAll('")', '')
        : (sub['id'] ?? sub['createdAt'] ?? '').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unlink Subscription?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        content: Text(
          'Are you sure you want to stop sharing "${sub['name']}"? This plan will become private again to your dashboard.',
          style: const TextStyle(color: Color(0xFF6B6B80), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unlink', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success = await controller.unlinkSubscription(subId);
      if (context.mounted) {
        if (success) {
          _showSnackBar(context, 'Subscription unlinked successfully.', true);
        } else {
          _showSnackBar(context, 'Failed to unlink subscription.', false);
        }
      }
    }
  }
}
