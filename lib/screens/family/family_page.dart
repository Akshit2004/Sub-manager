import 'package:flutter/material.dart';
import '../../services/mongodb_service.dart';
import '../../services/email_service.dart';

class FamilyPage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onGroupChanged;

  const FamilyPage({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onGroupChanged,
  });

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  bool _loading = true;
  Map<String, dynamic>? _group;
  List<Map<String, dynamic>> _invites = [];

  final _createFormKey = GlobalKey<FormState>();
  final _inviteFormKey = GlobalKey<FormState>();
  final _groupNameCtrl = TextEditingController();
  final _inviteEmailCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  @override
  void dispose() {
    _groupNameCtrl.dispose();
    _inviteEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyData() async {
    setState(() => _loading = true);
    final mongo = MongoDbService();

    final group = await mongo.getUserGroup(widget.userEmail);
    final invites = await mongo.getInvitesForUser(widget.userEmail);

    if (mounted) {
      setState(() {
        _group = group;
        _invites = invites;
        _loading = false;
      });
    }
  }

  Future<void> _handleCreateGroup() async {
    if (!_createFormKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final res = await MongoDbService().createGroup(
      _groupNameCtrl.text.trim(),
      widget.userEmail,
    );

    setState(() => _submitting = false);
    _showSnackBar(res['message'] ?? '', success: res['success'] ?? false);

    if (res['success'] == true) {
      _groupNameCtrl.clear();
      _loadFamilyData();
      widget.onGroupChanged();
    }
  }

  Future<void> _handleSendInvite() async {
    if (!_inviteFormKey.currentState!.validate()) return;
    if (_group == null) return;
    setState(() => _submitting = true);

    final invitedEmail = _inviteEmailCtrl.text.trim();

    final res = await MongoDbService().inviteMember(
      _group!['id'],
      invitedEmail,
    );

    setState(() => _submitting = false);
    _showSnackBar(res['message'] ?? '', success: res['success'] ?? false);

    if (res['success'] == true) {
      _inviteEmailCtrl.clear();
      _loadFamilyData();
      
      // Asynchronously trigger invitation email via SMTP
      EmailService().sendGroupInviteEmail(
        recipientEmail: invitedEmail,
        groupName: _group!['name'] ?? 'Family Group',
        ownerEmail: widget.userEmail,
      );
    }
  }

  Future<void> _handleAcceptInvite(String groupId) async {
    setState(() => _loading = true);
    final res = await MongoDbService().acceptInvite(groupId, widget.userEmail);
    _showSnackBar(res['message'] ?? '', success: res['success'] ?? false);
    _loadFamilyData();
    widget.onGroupChanged();
  }

  Future<void> _handleDeclineInvite(String groupId) async {
    setState(() => _loading = true);
    final res = await MongoDbService().declineInvite(groupId, widget.userEmail);
    _showSnackBar(res['message'] ?? '', success: res['success'] ?? false);
    _loadFamilyData();
  }

  Future<void> _handleLeaveGroup() async {
    if (_group == null) return;

    final isOwner = _group!['ownerEmail'] == widget.userEmail.toLowerCase().trim();

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

    if (confirmed == true) {
      setState(() => _loading = true);
      final res = await MongoDbService().leaveGroup(_group!['id'], widget.userEmail);
      _showSnackBar(res['message'] ?? '', success: res['success'] ?? false);
      _loadFamilyData();
      widget.onGroupChanged();
    }
  }

  void _showSnackBar(String message, {required bool success}) {
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4593A)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFamilyData,
      color: const Color(0xFFD4593A),
      backgroundColor: const Color(0xFFFFFFFF),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title Header ──────────────────────────────────────
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Family Sharing',
                  style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Pool your subscriptions and auto-sync payment reminders.',
                  style: TextStyle(
                    color: Color(0xFF6B6B80),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Incoming Invites (Always priority) ────────────────
            if (_invites.isNotEmpty) ...[
              _buildSectionHeader('Incoming Invitations'),
              const SizedBox(height: 12),
              ..._invites.map((invite) => _buildInviteCard(invite)),
              const SizedBox(height: 32),
            ],

            // ── Main UI based on group state ──────────────────────
            if (_group == null)
              _buildNoGroupUI()
            else
              _buildGroupUI(),
          ],
        ),
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

  Widget _buildNoGroupUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Features preview card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E4DE)),
          ),
          child: Column(
            children: [
              const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFFD4593A)),
              const SizedBox(height: 16),
              const Text(
                'How Family Sharing Works',
                style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _buildFeatureRow(Icons.sync_rounded, 'Auto-Sync Reminders', 'Share subscriptions so billing alerts go to everyone in the family.'),
              const SizedBox(height: 10),
              _buildFeatureRow(Icons.analytics_outlined, 'Combined Visuals', 'Members see pool expenses on their dashboard alongside personal ones.'),
              const SizedBox(height: 10),
              _buildFeatureRow(Icons.lock_outline_rounded, 'Secure & Private', 'Keep personal logins in your notes. Only subscription plans are pooled.'),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Create Group Form
        _buildSectionHeader('Create a Family Group'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E4DE)),
          ),
          child: Form(
            key: _createFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _groupNameCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a group name' : null,
                  style: const TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600, fontSize: 14.5),
                  decoration: const InputDecoration(
                    labelText: 'Family Group Name',
                    hintText: 'e.g. The Sharma Family',
                    prefixIcon: Icon(Icons.group_work_rounded, color: Color(0xFFD4593A)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _handleCreateGroup,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Create Family Group'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

  Widget _buildGroupUI() {
    final name = _group!['name'] ?? 'Family Group';
    final owner = _group!['ownerEmail'] ?? '';
    final members = List<String>.from(_group!['members'] ?? []);
    final pending = List<String>.from(_group!['pendingInvites'] ?? []);
    final isOwner = owner.toLowerCase().trim() == widget.userEmail.toLowerCase().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Group Info Card
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
                          'Created on ${_group!['createdAt']?.toString().substring(0, 10) ?? 'Recently'}',
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

        // Members List Section
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
                final isMe = m.toLowerCase().trim() == widget.userEmail.toLowerCase().trim();
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
                              isMe ? '${widget.userName} (You)' : m.split('@')[0],
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

        // Invites List Section (if owner & pending invites exist)
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

        // Invite Panel (Only if owner)
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
                      onPressed: _submitting ? null : _handleSendInvite,
                      child: _submitting
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

        // Danger Zone: Disband or Leave group
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
                  onPressed: _handleLeaveGroup,
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
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> invite) {
    final id = invite['id'] ?? '';
    final name = invite['name'] ?? 'Family Group';
    final owner = invite['ownerEmail'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4593A).withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: Color(0xFFD4593A)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FAMILY INVITATION',
                      style: TextStyle(
                        color: Color(0xFFD4593A),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Join "$name"',
                      style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Invited by $owner to pool and sync all family subscription due dates.',
            style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 13.5, height: 1.3),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => _handleDeclineInvite(id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B6B80),
                      side: const BorderSide(color: Color(0xFFE8E4DE)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => _handleAcceptInvite(id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4593A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Accept & Join', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
