import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_page.dart';
import 'dashboard/dashboard_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _float;
  late final List<Widget> _cards;

  // ── warm cream + coral palette ────────────────────────────
  static const _bg = Color(0xFFF8F6F1);
  static const _surfLow = Color(0xFFFFFFFF);
  static const _onSurface = Color(0xFF1A1A2E);
  static const _onSurfVar = Color(0xFF6B6B80);
  static const _outline = Color(0xFFACA8A1);
  static const _outlineVar = Color(0xFFE8E4DE);
  static const _primary = Color(0xFFD4593A);
  static const _primaryContainer = Color(0xFFD4593A);

  // ── subscription card data ───────────────────────────────
  static const _subs = [
    ('Netflix', '\$15.49', 'Jun 3', Icons.play_circle_filled_rounded, Color(0xFFE50914)),
    ('Spotify', '\$9.99', 'Jun 7', Icons.music_note_rounded, Color(0xFF1DB954)),
    ('Figma', '\$12.00', 'Jun 15', Icons.design_services_rounded, Color(0xFFA259FF)),
    ('iCloud', '\$2.99', 'Jun 22', Icons.cloud_rounded, Color(0xFF3395FF)),
  ];

  // card fan: (rotation°, dx, dy)
  static final _fans = [
    (-7.0 * math.pi / 180, -10.0, 14.0),
    (-2.5 * math.pi / 180, -3.0, 5.0),
    (3.0 * math.pi / 180, 4.0, -3.0),
    (6.5 * math.pi / 180, 10.0, -10.0),
  ];

  @override
  void initState() {
    super.initState();
    _cards = List.generate(_subs.length, (i) => RepaintBoundary(child: _subCard(i)));
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _float.dispose();
    super.dispose();
  }

  void _openAuth(bool isLogin) =>
      Navigator.of(context).push(_AuthRoute(isLogin: isLogin));

  Animation<double> _stagger(double s, double e) => CurvedAnimation(
        parent: _entrance,
        curve: Interval(s, e, curve: Curves.easeOutCubic),
      );

  Widget _fade(double s, double e, {required Widget child, Offset? from}) {
    final a = _stagger(s, e);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: from ?? const Offset(0, 0.06), end: Offset.zero)
            .animate(a),
        child: child,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isWide = w >= 840;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: _fade(0, 0.28, child: _nav()),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Column(
                  children: [
                    SizedBox(height: isWide ? 56 : 12),
                    isWide ? _wideHero() : _narrowHero(),
                    const SizedBox(height: 16),
                    _fade(0.70, 1.0, child: _footer()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── nav ──────────────────────────────────────────────────
  Widget _nav() {
    return Row(
      children: [
        const Text(
          'SubManager',
          style: TextStyle(
            color: _onSurface,
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => _openAuth(true),
          style: TextButton.styleFrom(
            foregroundColor: _onSurfVar,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          child: const Text('Sign in'),
        ),
      ],
    );
  }

  // ── wide hero (desktop) ──────────────────────────────────
  Widget _wideHero() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1080),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 11, child: _textBlock(TextAlign.left, CrossAxisAlignment.start)),
          const SizedBox(width: 48),
          Expanded(
            flex: 9,
            child: _fade(0.22, 0.72, from: const Offset(0.06, 0), child: _cardStack()),
          ),
        ],
      ),
    );
  }

  // ── narrow hero (mobile) ─────────────────────────────────
  Widget _narrowHero() {
    return Column(
      children: [
        _fade(0.14, 0.58, child: _cardStack()),
        const SizedBox(height: 14),
        _textBlock(TextAlign.center, CrossAxisAlignment.center),
      ],
    );
  }

  // ── text block ───────────────────────────────────────────
  Widget _textBlock(TextAlign align, CrossAxisAlignment cross) {
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    return Column(
      crossAxisAlignment: cross,
      children: [

        _fade(
          0.12,
          0.48,
          child: RichText(
            textAlign: align,
            text: TextSpan(
              style: TextStyle(
                color: _onSurface,
                fontSize: isWide ? 52 : 36,
                height: 1.1,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.5,
              ),
              children: [
                const TextSpan(text: 'Stop guessing\nwhere your '),
                TextSpan(
                  text: 'money',
                  style: TextStyle(
                    color: _primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const TextSpan(text: ' goes.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _fade(
          0.22,
          0.56,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              'Track every recurring charge, catch renewals before they hit, '
              'and see your full spending picture in seconds.',
              textAlign: align,
              style: const TextStyle(color: _onSurfVar, fontSize: 16, height: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _fade(0.34, 0.68, child: _buttons(cross)),
      ],
    );
  }

  // ── buttons ──────────────────────────────────────────────
  Widget _buttons(CrossAxisAlignment cross) {
    final compact = MediaQuery.sizeOf(context).width < 480;
    final primary = SizedBox(
      height: 52,
      width: compact ? double.infinity : null,
      child: ElevatedButton(
        onPressed: () => _openAuth(false),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryContainer,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: const Text('Get started — free'),
      ),
    );
    final secondary = SizedBox(
      height: 52,
      width: compact ? double.infinity : null,
      child: OutlinedButton(
        onPressed: () => _openAuth(true),
        style: OutlinedButton.styleFrom(
          foregroundColor: _onSurface,
          side: const BorderSide(color: _outlineVar),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: const Text('Log in'),
      ),
    );

    final guestBtn = TextButton(
      onPressed: () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', 'guest');
          await prefs.setString('user_name', 'Guest');
        } catch (e) {
          debugPrint('Error starting guest session: $e');
        }
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const DashboardPage(userName: 'Guest', userEmail: 'guest'),
          ),
          (_) => false,
        );
      },
      style: TextButton.styleFrom(
        foregroundColor: _onSurfVar,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
      ),
      child: const Text('Continue as Guest'),
    );

    if (compact) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        primary,
        const SizedBox(height: 10),
        secondary,
        const SizedBox(height: 12),
        guestBtn,
      ]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: [
        Row(
          mainAxisSize: cross == CrossAxisAlignment.center
              ? MainAxisSize.min
              : MainAxisSize.max,
          children: [primary, const SizedBox(width: 12), secondary],
        ),
        const SizedBox(height: 12),
        guestBtn,
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  CARD STACK — the hero visual
  // ════════════════════════════════════════════════════════════
  Widget _cardStack() {
    return SizedBox(
      height: 240,
      child: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _float]),
        builder: (context, _) {
          final ft = _float.value;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: List.generate(_subs.length, (i) {
              // entrance: deal in from right with spring
              final deal = CurvedAnimation(
                parent: _entrance,
                curve: Interval(
                  0.18 + i * 0.09,
                  0.55 + i * 0.09,
                  curve: Curves.easeOutBack,
                ),
              ).value;

              final fan = _fans[i];
              final floatDy = 3.0 * math.sin(ft * 2 * math.pi + i * math.pi / 2);

              // interpolate from entrance position to final
              final rot = fan.$1 * deal;
              final dx = lerpDouble(120, fan.$2, deal)!;
              final dy = lerpDouble(40, fan.$3 + floatDy, deal)!;
              final opacity = deal.clamp(0.0, 1.0);

              return Positioned(
                child: Opacity(
                  opacity: opacity,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.translationValues(dx, dy, 0)
                      ..rotateZ(rot),
                    child: _cards[i],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _subCard(int i) {
    final s = _subs[i];
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVar),
        boxShadow: [
          BoxShadow(
            color: _onSurface.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _onSurface.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // brand stripe + icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: s.$5.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.$4, color: s.$5, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.$1,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Renews ${s.$3}',
                  style: TextStyle(color: _outline, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Text(
            '${s.$2}/mo',
            style: const TextStyle(
              color: _onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }


  // ── footer ───────────────────────────────────────────────
  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_rounded, color: _outline, size: 13),
        const SizedBox(width: 6),
        Text(
          'Your data stays on-device  ·  No credit card needed',
          style: TextStyle(color: _outline, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── lerp helper ──────────────────────────────────────────────
double? lerpDouble(double a, double b, double t) => a + (b - a) * t;

// ── page route ───────────────────────────────────────────────
class _AuthRoute extends PageRouteBuilder<void> {
  _AuthRoute({required bool isLogin})
      : super(
          transitionDuration: const Duration(milliseconds: 650),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, anim1, anim2) => AuthPage(isLogin: isLogin),
          transitionsBuilder: (context, animation, secondaryAnim, child) {
            final slideIn = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            ));

            final scale = Tween<double>(
              begin: 0.92,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            return SlideTransition(
              position: slideIn,
              child: ScaleTransition(
                scale: scale,
                child: child,
              ),
            );
          },
        );
}
