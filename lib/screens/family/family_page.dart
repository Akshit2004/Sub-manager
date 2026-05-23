import 'dart:ui';
import 'package:flutter/material.dart';
import '../auth_page.dart';
import 'family_controller.dart';
import 'widgets/family_page_indicator.dart';
import 'widgets/create_group_view.dart';
import 'widgets/active_group_view.dart';
import 'widgets/family_invite_card.dart';

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
  late FamilyController _controller;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _createFormKey = GlobalKey<FormState>();
  final _groupNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = FamilyController(
      userName: widget.userName,
      userEmail: widget.userEmail,
      onGroupChanged: widget.onGroupChanged,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _groupNameCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, bool success) {
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

  Future<void> _handleCreateGroup() async {
    if (!_createFormKey.currentState!.validate()) return;
    
    final res = await _controller.createGroup(_groupNameCtrl.text.trim());
    _showSnackBar(res['message'] ?? '', res['success'] == true);

    if (res['success'] == true) {
      _groupNameCtrl.clear();
      // Swipe to the newly created group at the end of the list
      if (_controller.groups.isNotEmpty && _pageController.hasClients) {
        _pageController.animateToPage(
          _controller.groups.length - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
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

  Widget _buildInvitesOnly() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      children: [
        _buildSectionHeader('Incoming Invitations'),
        const SizedBox(height: 12),
        ..._controller.invites.map((invite) => FamilyInviteCard(
              invite: invite,
              onAccept: () async {
                final res = await _controller.acceptInvite(invite['id']);
                _showSnackBar(res['message'] ?? '', res['success'] == true);
              },
              onDecline: () async {
                final res = await _controller.declineInvite(invite['id']);
                _showSnackBar(res['message'] ?? '', res['success'] == true);
              },
            )),
        const SizedBox(height: 32),
        CreateGroupView(
          submitting: _controller.submitting,
          formKey: _createFormKey,
          groupNameCtrl: _groupNameCtrl,
          onCreate: _handleCreateGroup,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = widget.userEmail.toLowerCase().trim() == 'guest';

    Widget pageBody = ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        if (_controller.loading && _controller.groups.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD4593A)),
          );
        }

        // Keep page within bounds if groups are removed
        if (_currentPage >= _controller.groups.length && _controller.groups.isNotEmpty) {
          _currentPage = _controller.groups.length - 1;
        }

        return RefreshIndicator(
          onRefresh: _controller.loadFamilyData,
          color: const Color(0xFFD4593A),
          backgroundColor: const Color(0xFFFFFFFF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Fixed Top Header ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Family Sharing',
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pool your subscriptions and auto-sync payment reminders.',
                      style: TextStyle(
                        color: Color(0xFF6B6B80),
                        fontSize: 15,
                      ),
                    ),
                    if (_controller.groups.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      FamilyPageIndicator(
                        groupsLength: _controller.groups.length,
                        currentPage: _currentPage,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Scrollable Body ────────────────────────────────────────
              Expanded(
                child: _controller.invites.isNotEmpty && _controller.groups.isEmpty
                    ? _buildInvitesOnly()
                    : _controller.groups.isEmpty
                        ? CreateGroupView(
                            submitting: _controller.submitting,
                            formKey: _createFormKey,
                            groupNameCtrl: _groupNameCtrl,
                            onCreate: _handleCreateGroup,
                          )
                        : PageView.builder(
                            controller: _pageController,
                            onPageChanged: (i) {
                              if (mounted) setState(() => _currentPage = i);
                            },
                            itemCount: _controller.groups.length + 1, // +1 for "Create New" page
                            itemBuilder: (context, index) {
                              if (index == _controller.groups.length) {
                                return CreateGroupView(
                                  isAddPage: true,
                                  submitting: _controller.submitting,
                                  formKey: _createFormKey,
                                  groupNameCtrl: _groupNameCtrl,
                                  onCreate: _handleCreateGroup,
                                );
                              }
                              return ActiveGroupView(
                                group: _controller.groups[index],
                                controller: _controller,
                                isFirstPage: index == 0,
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );

    if (isGuest) {
      return Stack(
        children: [
          // Blurred background containing dummy family views
          Opacity(
            opacity: 0.3,
            child: AbsorbPointer(
              child: pageBody,
            ),
          ),
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: Container(
                  color: const Color(0xFFF8F6F1).withValues(alpha: 0.35),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE8E4DE)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A1A2E).withValues(alpha: 0.08),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4593A).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.people_outline_rounded,
                                color: Color(0xFFD4593A),
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Family Sharing',
                              style: TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Connect with your family members to pool subscriptions, split bills, and sync payment reminders in real-time.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF6B6B80),
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const AuthPage(isLogin: true)),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4593A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Sign in to unlock',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return pageBody;
  }
}
