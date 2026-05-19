import 'package:flutter/material.dart';

import 'dashboard_controller.dart';
import 'widgets/dashboard_app_bar.dart';
import 'widgets/spend_summary_card.dart';
import 'widgets/subscription_list_header.dart';
import 'widgets/subscription_list_item.dart';
import 'widgets/empty_state.dart';
import 'widgets/add_subscription_sheet.dart';
import '../timeline/timeline_page.dart';
import '../analytics/analytics_page.dart';
import '../family/family_page.dart';

class DashboardPage extends StatefulWidget {
  final String userName;
  final String userEmail;
  const DashboardPage({super.key, required this.userName, required this.userEmail});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final DashboardController _controller;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController(userName: widget.userName, userEmail: widget.userEmail);
    _controller.addListener(_onStateChange);
    
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _entrance.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() {});
      }
    });
    
    _entrance.forward();
  }

  void _onStateChange() {
    if (mounted) {
      // Re-trigger entrance animation when data loads successfully
      if (!_controller.loading && _entrance.isCompleted) {
        // _entrance.reset();
        // _entrance.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _stagger(double s, double e) => CurvedAnimation(
        parent: _entrance,
        curve: Interval(s, e, curve: Curves.easeOutCubic),
      );

  Widget _fade(double s, double e, {required Widget child}) {
    if (_entrance.isCompleted) {
      return child;
    }
    final a = _stagger(s, e);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  void _showAddSubscriptionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddSubSheet(
        userEmail: widget.userEmail,
        onSaved: () {
          Navigator.of(context).pop();
          _controller.loadSubscriptions();
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_navIndex) {
      case 0:
        return Column(
          children: [
            SafeArea(
              bottom: false,
              child: _fade(0.0, 0.3, child: DashboardAppBar(controller: _controller)),
            ),
            Expanded(
              child: _controller.loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFD4593A)),
                    )
                  : RefreshIndicator(
                      onRefresh: _controller.loadSubscriptions,
                      color: const Color(0xFFD4593A),
                      backgroundColor: const Color(0xFFFFFFFF),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            _fade(0.08, 0.38, child: SpendSummaryCard(controller: _controller, entrance: _entrance)),
                            const SizedBox(height: 32),
                            _fade(0.20, 0.50, child: SubscriptionListHeader(controller: _controller)),
                            if (_controller.subscriptions.isEmpty)
                              _fade(0.25, 0.60, child: EmptyState(onAddPressed: _showAddSubscriptionSheet))
                            else
                              ...List.generate(_controller.subscriptions.length, (i) {
                                return _fade(
                                  0.24 + i * 0.06,
                                  0.54 + i * 0.06,
                                  child: SubscriptionListItem(
                                    subscription: _controller.subscriptions[i],
                                    isNext: i == 0,
                                    controller: _controller,
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            SafeArea(
              bottom: false,
              child: _fade(0.0, 0.3, child: DashboardAppBar(controller: _controller)),
            ),
            Expanded(
              child: TimelinePage(
                userName: widget.userName,
                userEmail: widget.userEmail,
              ),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            SafeArea(
              bottom: false,
              child: _fade(0.0, 0.3, child: DashboardAppBar(controller: _controller)),
            ),
            Expanded(
              child: AnalyticsPage(
                userName: widget.userName,
                userEmail: widget.userEmail,
              ),
            ),
          ],
        );
      case 3:
      default:
        return Column(
          children: [
            SafeArea(
              bottom: false,
              child: _fade(0.0, 0.3, child: DashboardAppBar(controller: _controller)),
            ),
            Expanded(
              child: FamilyPage(
                userName: widget.userName,
                userEmail: widget.userEmail,
                onGroupChanged: () {
                  _controller.loadSubscriptions();
                },
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F6F1),
          body: _buildBody(context),
          bottomNavigationBar: _fade(0.40, 0.80, child: _buildBottomNav()),
          floatingActionButton: _fade(
            0.35,
            0.75,
            child: FloatingActionButton(
              onPressed: _showAddSubscriptionSheet,
              backgroundColor: const Color(0xFFD4593A),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add_rounded, size: 24),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.calendar_today_rounded, Icons.calendar_today_outlined, 'Timeline'),
      (Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Analytics'),
      (Icons.people_alt_rounded, Icons.people_outline, 'Family'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F6F1),
        border: Border(top: BorderSide(color: Color(0xFFE8E4DE), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = _navIndex == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _navIndex = i);
                  _controller.loadSubscriptions();
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? items[i].$1 : items[i].$2,
                        color: active ? const Color(0xFFD4593A) : const Color(0xFF6B6B80),
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$3,
                        style: TextStyle(
                          color: active ? const Color(0xFFD4593A) : const Color(0xFF6B6B80),
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
