import 'package:flutter/material.dart';
import 'timeline_controller.dart';
import 'widgets/timeline_item.dart';

class TimelinePage extends StatefulWidget {
  final String userName;
  final String userEmail;

  const TimelinePage({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> with TickerProviderStateMixin {
  late final TimelineController _controller;
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _controller = TimelineController(userName: widget.userName, userEmail: widget.userEmail);
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _stagger(double s, double e) => CurvedAnimation(
        parent: _entrance,
        curve: Interval(s, e, curve: Curves.easeOutCubic),
      );

  Widget _fade(double s, double e, {required Widget child}) {
    final a = _stagger(s, e);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.loading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD4593A)),
          );
        }

        final noItems = _controller.thisWeek.isEmpty && _controller.thisMonth.isEmpty && _controller.later.isEmpty;

        return RefreshIndicator(
          onRefresh: _controller.loadSubscriptions,
          color: const Color(0xFFD4593A),
          backgroundColor: const Color(0xFFFFFFFF),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                _fade(0.0, 0.3, child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timeline',
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.5,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Upcoming renewals and scheduled payments.',
                      style: TextStyle(
                        color: Color(0xFF6B6B80),
                        fontSize: 15,
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 32),

                if (noItems)
                  _fade(0.1, 0.4, child: Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8E4DE)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 40, color: Color(0xFFD4593A)),
                          SizedBox(height: 16),
                          Text(
                            'No upcoming renewals',
                            style: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'All subscription timelines will render here.',
                            style: TextStyle(color: Color(0xFF6B6B80), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ))
                else ...[
                  // ── This Week Section ─────────────────────────────
                  if (_controller.thisWeek.isNotEmpty) ...[
                    _fade(0.1, 0.4, child: _buildSectionHeader('This Week')),
                    const SizedBox(height: 8),
                    ...List.generate(_controller.thisWeek.length, (i) {
                      return _fade(
                        0.15 + i * 0.05,
                        0.45 + i * 0.05,
                        child: TimelineItem(
                          subscription: _controller.thisWeek[i],
                          baseCurrency: _controller.baseCurrency,
                        ),
                      );
                    }),
                    const SizedBox(height: 28),
                  ],

                  // ── This Month Section ────────────────────────────
                  if (_controller.thisMonth.isNotEmpty) ...[
                    _fade(0.2, 0.5, child: _buildSectionHeader('This Month')),
                    const SizedBox(height: 8),
                    ...List.generate(_controller.thisMonth.length, (i) {
                      return _fade(
                        0.25 + i * 0.05,
                        0.55 + i * 0.05,
                        child: TimelineItem(
                          subscription: _controller.thisMonth[i],
                          baseCurrency: _controller.baseCurrency,
                        ),
                      );
                    }),
                    const SizedBox(height: 28),
                  ],

                  // ── Later Section ──────────────────────────────────
                  if (_controller.later.isNotEmpty) ...[
                    _fade(0.3, 0.6, child: _buildSectionHeader('Later')),
                    const SizedBox(height: 8),
                    ...List.generate(_controller.later.length, (i) {
                      return _fade(
                        0.35 + i * 0.05,
                        0.65 + i * 0.05,
                        child: TimelineItem(
                          subscription: _controller.later[i],
                          baseCurrency: _controller.baseCurrency,
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E4DE), width: 1.0)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}
