import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../family_controller.dart';
import 'family_invite_card.dart';
import '../../../utils/currency_utils.dart';

class ActiveGroupView extends StatefulWidget {
  final Map<String, dynamic> group;
  final FamilyController controller;
  final bool isFirstPage;

  const ActiveGroupView({
    super.key,
    required this.group,
    required this.controller,
    required this.isFirstPage,
  });

  @override
  State<ActiveGroupView> createState() => _ActiveGroupViewState();
}

class _ActiveGroupViewState extends State<ActiveGroupView> with WidgetsBindingObserver {
  final _inviteFormKey = GlobalKey<FormState>();
  late final TextEditingController _inviteEmailCtrl;

  bool _waitingForUpiReturn = false;
  double _pendingAmount = 0.0;
  String _pendingUpiId = '';
  String _pendingRecipientEmail = '';

  @override
  void initState() {
    super.initState();
    _inviteEmailCtrl = TextEditingController();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadPayments(widget.group['id'], _getCurrentBillingPeriod());
    });
  }

  @override
  void didUpdateWidget(covariant ActiveGroupView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group['id'] != widget.group['id']) {
      widget.controller.loadPayments(widget.group['id'], _getCurrentBillingPeriod());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inviteEmailCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForUpiReturn) {
      _waitingForUpiReturn = false;
      _promptPaymentVerification();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.group['name'] ?? 'Family Group';
    final owner = widget.group['ownerEmail'] ?? '';
    final members = List<String>.from(widget.group['members'] ?? []);
    final pending = List<String>.from(widget.group['pendingInvites'] ?? []);
    final isOwner = owner.toLowerCase().trim() == widget.controller.userEmail.toLowerCase().trim();
    final linkedSubs = widget.controller.subscriptions.where((s) => s['groupId'] == widget.group['id']).toList();
    final payments = widget.controller.activeGroupPayments;
    final pendingApprovals = payments.where((p) {
      return p['status'] == 'pending' &&
          p['senderEmail'].toString().toLowerCase().trim() != owner.toLowerCase().trim();
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Invites logic specific to the first active page if exists
          if (widget.isFirstPage && widget.controller.invites.isNotEmpty) ...[
            _buildSectionHeader('Incoming Invitations'),
            const SizedBox(height: 12),
            ...widget.controller.invites.map((invite) => FamilyInviteCard(
                  invite: invite,
                  onAccept: () async {
                    final res = await widget.controller.acceptInvite(invite['id']);
                    if (context.mounted) _showSnackBar(context, res['message'] ?? '', res['success'] == true);
                  },
                  onDecline: () async {
                    final res = await widget.controller.declineInvite(invite['id']);
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
                            'Created on ${widget.group['createdAt']?.toString().substring(0, 10) ?? 'Recently'}',
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
                onPressed: () => _handleLinkSubscriptions(context),
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
                      onPressed: () => _handleLinkSubscriptions(context),
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

          if (!isOwner) _buildPaySection(context, widget.group, linkedSubs, members, name, owner),
          if (isOwner) _buildOwnerPendingApprovalsSection(pendingApprovals, owner),

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
                  final isMe = m.toLowerCase().trim() == widget.controller.userEmail.toLowerCase().trim();
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
                                isMe ? '${widget.controller.userName} (You)' : m.split('@')[0],
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
                key: _inviteFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _inviteEmailCtrl,
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
                        onPressed: widget.controller.submitting ? null : () async {
                          if (!_inviteFormKey.currentState!.validate()) return;
                          final email = _inviteEmailCtrl.text.trim();
                          final res = await widget.controller.sendInvite(widget.group['id'], widget.group['name'] ?? 'Group', email);
                          if (context.mounted) _showSnackBar(context, res['message'] ?? '', res['success'] == true);
                          if (res['success'] == true) {
                            _inviteEmailCtrl.clear();
                          }
                        },
                      child: widget.controller.submitting
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

            // ── Payment Settings
            _buildSectionHeader('Payment Settings'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E4DE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments_rounded, size: 20, color: const Color(0xFFD4593A)),
                      const SizedBox(width: 10),
                      Text(
                        'Receive payments via UPI',
                        style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F7F4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8E4DE)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Current UPI: ',
                          style: TextStyle(color: const Color(0xFF6B6B80), fontSize: 13.5),
                        ),
                        Expanded(
                          child: Text(
                            (widget.group['upiId']?.toString() ?? '').isNotEmpty
                                ? widget.group['upiId'].toString()
                                : 'Not set',
                            style: TextStyle(
                              color: (widget.group['upiId']?.toString() ?? '').isNotEmpty
                                  ? const Color(0xFF1A1A2E)
                                  : const Color(0xFFACA8A1),
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final upiId = await _showUpiIdDialog(context, widget.group);
                        if (upiId != null && context.mounted) {
                          // Let the dialog exit animation finish before
                          // triggering a controller rebuild.
                          await Future.delayed(const Duration(milliseconds: 350));
                          if (!context.mounted) return;
                          final res = await widget.controller.updateUpiId(widget.group['id'], upiId);
                          if (context.mounted) {
                            _showSnackBar(context, res['message'] ?? '', res['success'] == true);
                          }
                        }
                      },
                      icon: Icon(
                        (widget.group['upiId']?.toString() ?? '').isNotEmpty
                            ? Icons.edit_rounded
                            : Icons.add_rounded,
                        size: 16,
                      ),
                      label: Text(
                        (widget.group['upiId']?.toString() ?? '').isNotEmpty
                            ? 'Update UPI ID'
                            : 'Set UPI ID',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD4593A),
                        side: const BorderSide(color: Color(0xFFD4593A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
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
                    onPressed: () => _handleLeaveGroup(context, widget.group, isOwner),
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
      // Let the dialog exit animation finish before triggering a controller rebuild.
      await Future.delayed(const Duration(milliseconds: 350));
      if (!context.mounted) return;
      final res = await widget.controller.leaveGroup(group['id']);
      if (context.mounted) _showSnackBar(context, res['message'] ?? '', res['success'] == true);
    }
  }

  Future<void> _handleLinkSubscriptions(BuildContext context) async {
    final selectedSubIds = await _showLinkSubscriptionsSheet(context, widget.group);
    if (selectedSubIds != null && selectedSubIds.isNotEmpty && context.mounted) {
      // Let the sheet exit animation finish before triggering a controller rebuild.
      await Future.delayed(const Duration(milliseconds: 350));
      if (!context.mounted) return;
      final success = await widget.controller.linkSubscriptions(widget.group['id'], selectedSubIds);
      if (context.mounted) {
        if (success) {
          _showSnackBar(context, 'Subscriptions linked successfully!', true);
        } else {
          _showSnackBar(context, 'Some subscriptions failed to link.', false);
        }
      }
    }
  }

  Future<List<String>?> _showLinkSubscriptionsSheet(BuildContext context, Map<String, dynamic> group) async {
    final privateSubs = widget.controller.subscriptions.where((s) => s['groupId'] == null).toList();
    
    if (privateSubs.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
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
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Understood', style: TextStyle(color: Color(0xFFD4593A), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return null;
    }

    return showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        List<String> selectedSubIds = [];
        return StatefulBuilder(
          builder: (builderCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(builderCtx).viewInsets.bottom + 24,
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
                        onPressed: () => Navigator.of(builderCtx).pop(null),
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
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(builderCtx).size.height * 0.4),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: privateSubs.length,
                      itemBuilder: (listCtx, index) {
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
                          : () {
                              Navigator.of(builderCtx).pop(selectedSubIds);
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
      // Let the dialog exit animation finish before triggering a controller rebuild.
      await Future.delayed(const Duration(milliseconds: 350));
      if (!context.mounted) return;
      final success = await widget.controller.unlinkSubscription(subId);
      if (context.mounted) {
        if (success) {
          _showSnackBar(context, 'Subscription unlinked successfully.', true);
        } else {
          _showSnackBar(context, 'Failed to unlink subscription.', false);
        }
      }
    }
  }

  Future<String?> _showUpiIdDialog(BuildContext context, Map<String, dynamic> group) {
    final ctrl = TextEditingController(text: group['upiId']?.toString() ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('UPI Payment ID', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your UPI ID so family members can pay you directly via GPay, Paytm, or PhonePe.',
              style: TextStyle(color: Color(0xFF6B6B80), fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'e.g. familyhead@paytm',
                prefixIcon: Icon(Icons.payments_rounded, color: Color(0xFFD4593A)),
              ),
              style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600, fontSize: 14.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B6B80), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              final upiId = ctrl.text.trim();
              Navigator.of(ctx).pop(upiId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4593A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _getCurrentBillingPeriod() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String _getBillingPeriodName(String period) {
    try {
      final parts = period.split('-');
      final year = parts[0];
      final monthInt = int.parse(parts[1]);
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[monthInt - 1]} $year';
    } catch (_) {
      return period;
    }
  }

  String _formatTimestamp(dynamic timestampStr) {
    if (timestampStr == null) return '';
    try {
      final dt = DateTime.parse(timestampStr.toString());
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:$min';
    } catch (_) {
      return timestampStr.toString();
    }
  }

  void _promptPaymentVerification() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFDE68A), width: 2),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: Color(0xFFD97706),
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Verify UPI Payment',
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Did your transfer of ₹${_pendingAmount.toStringAsFixed(0)} to the family head complete successfully?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B6B80),
                  fontSize: 14.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSnackBar(context, 'Payment declared as failed/canceled.', false);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B6B80),
                        side: const BorderSide(color: Color(0xFFE8E4DE), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'No, Canceled',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _handleDeclarePaymentSuccess();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4593A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Yes, Successful',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleDeclarePaymentSuccess() async {
    final billingPeriod = _getCurrentBillingPeriod();
    final res = await widget.controller.recordPayment(
      groupId: widget.group['id'],
      recipientEmail: _pendingRecipientEmail,
      amount: _pendingAmount,
      upiId: _pendingUpiId,
      status: 'pending',
      billingPeriod: billingPeriod,
    );
    if (mounted) {
      _showSnackBar(
        context,
        res['success'] == true
            ? 'Payment declared! Awaiting confirmation from family owner.'
            : res['message'] ?? 'Failed to record payment.',
        res['success'] == true,
      );
    }
  }

  Future<void> _payViaUpi(BuildContext context, String upiId, double amount, String groupName, String recipientEmail) async {
    final cleanUpi = upiId.trim();
    final txnRef = 'SUB${DateTime.now().millisecondsSinceEpoch}';

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAF8F5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: const Color(0xFFD0CCC6), borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Choose Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 6),
            Text(
              'Pay ₹${amount.toStringAsFixed(0)} to $groupName',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B6B80)),
            ),
            const SizedBox(height: 24),

            // Option 1: Open UPI App (GPay / PhonePe recommended)
            _buildPayOptionTile(
              icon: Icons.open_in_new_rounded,
              color: const Color(0xFF4CAF50),
              title: 'Open UPI App',
              subtitle: 'GPay or PhonePe recommended',
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(
                  'upi://pay?pa=$cleanUpi'
                  '&pn=${Uri.encodeComponent(groupName)}'
                  '&am=${amount.toStringAsFixed(2)}'
                  '&cu=INR'
                  '&tn=${Uri.encodeComponent("Family Share")}'
                  '&tr=$txnRef',
                );
                try {
                  _pendingAmount = amount;
                  _pendingUpiId = cleanUpi;
                  _pendingRecipientEmail = recipientEmail;
                  _waitingForUpiReturn = true;
                  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!launched && context.mounted) {
                    _waitingForUpiReturn = false;
                    _showSnackBar(context, 'No UPI app found. Try copying UPI details instead.', false);
                  }
                } catch (e) {
                  _waitingForUpiReturn = false;
                  if (context.mounted) {
                    _showSnackBar(context, 'Could not open UPI app. Try copying UPI details instead.', false);
                  }
                }
              },
            ),
            const SizedBox(height: 12),

            // Option 2: Copy UPI Details (fallback for Paytm risk blocks)
            _buildPayOptionTile(
              icon: Icons.copy_rounded,
              color: const Color(0xFF2196F3),
              title: 'Copy UPI Details',
              subtitle: 'Pay manually in any UPI app',
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: cleanUpi));
                _pendingAmount = amount;
                _pendingUpiId = cleanUpi;
                _pendingRecipientEmail = recipientEmail;
                _waitingForUpiReturn = true;
                if (context.mounted) {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (innerCtx) => Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAF8F5),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40, height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(color: const Color(0xFFD0CCC6), borderRadius: BorderRadius.circular(2)),
                          ),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 48),
                          const SizedBox(height: 12),
                          const Text('UPI ID Copied!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EDE8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE0DCD6)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('UPI ID', style: TextStyle(color: Color(0xFF6B6B80), fontSize: 12)),
                                    Text(cleanUpi, style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Amount', style: TextStyle(color: Color(0xFF6B6B80), fontSize: 12)),
                                    Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Open any UPI app (GPay, PhonePe, etc.)\nPaste the UPI ID and pay the amount above.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF6B6B80), fontSize: 13, height: 1.5),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(innerCtx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A1A2E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EDE8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0DCD6)),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B80))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0ACA6), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaySection(BuildContext context, Map<String, dynamic> group, List<Map<String, dynamic>> linkedSubs, List<String> members, String groupName, String ownerEmail) {
    final upiId = group['upiId']?.toString() ?? '';
    if (upiId.isEmpty || linkedSubs.isEmpty) return const SizedBox.shrink();

    double totalLinkedCost = 0.0;
    for (final sub in linkedSubs) {
      final price = (sub['price'] as num?)?.toDouble() ?? 0.0;
      final currency = (sub['currency'] ?? 'USD').toString().toUpperCase();
      totalLinkedCost += CurrencyUtils.convert(price, currency, 'INR');
    }
    final share = totalLinkedCost / members.length;

    // Check payment status for the current sender
    final userEmail = widget.controller.userEmail;
    final currentPeriod = _getCurrentBillingPeriod();
    final userPayment = widget.controller.activeGroupPayments.firstWhere(
      (p) => p['senderEmail'].toString().toLowerCase().trim() == userEmail.toLowerCase().trim() && p['billingPeriod'] == currentPeriod,
      orElse: () => <String, dynamic>{},
    );

    if (userPayment.isNotEmpty && userPayment['status'] == 'pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Pay Family Head'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB), // Elegant warm amber/gold
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFD97706), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Approval Pending',
                      style: TextStyle(color: Color(0xFF78350F), fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'You declared a payment of ₹${userPayment['amount']?.toStringAsFixed(0)} on ${_formatTimestamp(userPayment['timestamp'])}.',
                  style: const TextStyle(color: Color(0xFF92400E), fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Waiting for the Family Head to verify and confirm receipt of the funds.',
                  style: TextStyle(color: Color(0xFFB45309), fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    if (userPayment.isNotEmpty && userPayment['status'] == 'success') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Pay Family Head'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5), // Sleek lush green/emerald
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD1FAE5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Paid & Confirmed',
                      style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Your monthly share of ₹${userPayment['amount']?.toStringAsFixed(0)} has been paid and verified for ${_getBillingPeriodName(currentPeriod)}.',
                  style: const TextStyle(color: Color(0xFF065F46), fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: 6),
                Text(
                  'Confirmed on ${_formatTimestamp(userPayment['timestamp'])}.',
                  style: const TextStyle(color: Color(0xFF047857), fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Pay Family Head'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E4DE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 20, color: const Color(0xFFD4593A)),
                  const SizedBox(width: 10),
                  Text(
                    'Your Monthly Share',
                    style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...linkedSubs.map((sub) {
                final subPrice = (sub['price'] as num?)?.toDouble() ?? 0.0;
                final subCurrency = (sub['currency'] ?? 'USD').toString().toUpperCase();
                final subInr = CurrencyUtils.convert(subPrice, subCurrency, 'INR');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(sub['name'] ?? 'Plan', style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 13.5)),
                      Text('₹${subInr.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13)),
                    ],
                  ),
                );
              }),
              const Divider(color: Color(0xFFE8E4DE), height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('₹${totalLinkedCost.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Your share: ₹${share.toStringAsFixed(0)}/mo (${members.length} members)',
                style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _payViaUpi(context, upiId, share, groupName, ownerEmail),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: Text('Pay ₹${share.toStringAsFixed(0)} via UPI'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildOwnerPendingApprovalsSection(List<Map<String, dynamic>> pendingApprovals, String owner) {
    if (pendingApprovals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Pending Payment Approvals'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E4DE)),
          ),
          child: Column(
            children: List.generate(pendingApprovals.length, (i) {
              final pay = pendingApprovals[i];
              final sender = pay['senderEmail'].toString();
              final amount = pay['amount'] ?? 0.0;
              final dateStr = _formatTimestamp(pay['timestamp']);
              final shortName = sender.split('@')[0];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: i == pendingApprovals.length - 1
                      ? null
                      : const Border(bottom: BorderSide(color: Color(0xFFE8E4DE), width: 0.5)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFFFFBEB),
                      child: Text(
                        shortName[0].toUpperCase(),
                        style: const TextStyle(color: Color(0xFFD97706), fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$shortName declared payment',
                            style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Amount: ₹${amount.toStringAsFixed(0)} • $dateStr',
                            style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 22),
                          onPressed: () async {
                            final res = await widget.controller.verifyPayment(
                              pay['id'],
                              'failed',
                              widget.group['id'],
                              _getCurrentBillingPeriod(),
                            );
                            if (mounted) _showSnackBar(context, res['message'] ?? 'Payment declined.', false);
                          },
                          tooltip: 'Decline Payment',
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 22),
                          onPressed: () async {
                            final res = await widget.controller.verifyPayment(
                              pay['id'],
                              'success',
                              widget.group['id'],
                              _getCurrentBillingPeriod(),
                            );
                            if (mounted) _showSnackBar(context, res['message'] ?? 'Payment approved!', true);
                          },
                          tooltip: 'Confirm Receipt',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
