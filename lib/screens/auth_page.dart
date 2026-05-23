import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mongodb_service.dart';
import '../services/api_service.dart';
import 'dashboard/dashboard_page.dart';

class AuthPage extends StatefulWidget {
  final bool isLogin;
  const AuthPage({super.key, this.isLogin = true});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  late bool _isLogin;
  late final AnimationController _entrance;
  late final AnimationController _float;
  bool _loading = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── warm cream + coral palette ────────────────────────────
  static const _bg = Color(0xFFF8F6F1);
  static const _surfLow = Color(0xFFFFFFFF);
  static const _surfContainer = Color(0xFFFAF9F6);
  static const _surfHigh = Color(0xFFF0EDE8);
  static const _primary = Color(0xFFD4593A);
  static const _primaryContainer = Color(0xFFD4593A);
  static const _onSurface = Color(0xFF1A1A2E);
  static const _onSurfVar = Color(0xFF6B6B80);
  static const _outline = Color(0xFFACA8A1);
  static const _outlineVar = Color(0xFFE8E4DE);
  static const _error = Color(0xFFDC2626);
  static const _tertiary = Color(0xFFD4593A);

  // ── feature deck data ────────────────────────────────────
  static const _features = [
    ('Secure Access', 'Encrypted login keeps credentials safe.', Icons.lock_outline_rounded, _primary),
    ('Smart Reminders', 'Subtle alerts before renewal charges hit.', Icons.calendar_month_outlined, _tertiary),
    ('Spend Overview', 'See your monthly recurring overhead instantly.', Icons.insights_outlined, _primaryContainer),
  ];

  static final _fans = [
    (-6.0 * math.pi / 180, -12.0, 16.0),
    (0.0, 0.0, 0.0),
    (6.0 * math.pi / 180, 12.0, -16.0),
  ];

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _connectMongo();
  }

  Future<void> _connectMongo() async {
    final uri = dotenv.env['MONGO_URI'];
    final host = dotenv.env['MONGO_HOST'] ?? '127.0.0.1';
    final port = int.tryParse(dotenv.env['MONGO_PORT'] ?? '27017') ?? 27017;
    final dbName = dotenv.env['MONGO_DB_NAME'] ?? 'sub_manager';
    await MongoDbService().connect(
      host: host,
      port: port,
      dbName: dbName,
      connectionString: uri,
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _float.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _setMode(bool isLogin) {
    if (_isLogin == isLogin) return;
    setState(() => _isLogin = isLogin);
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final mongo = MongoDbService();
    Map<String, dynamic> result;

    if (_isLogin) {
      result = await mongo.login(
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );
    } else {
      result = await mongo.register(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      final user = result['user'] as Map<String, dynamic>?;
      final name = (user?['name'] ?? _nameCtrl.text).toString().trim();
      final email = (user?['email'] ?? _emailCtrl.text).toString().toLowerCase().trim();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email);
        await prefs.setString('user_name', name);

        // ── SYNC LOGIC ───────────────────────────────────────────
        final guestJson = prefs.getString('local_subs_guest');
        if (guestJson != null && guestJson.trim().isNotEmpty) {
          setState(() => _loading = true); // Set loading while resolving and syncing
          
          List<Map<String, dynamic>> guestSubs = [];
          try {
            final decoded = List<dynamic>.from(jsonDecode(guestJson));
            guestSubs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          } catch (e) {
            debugPrint('Failed to parse guest data during sync: $e');
          }

          if (guestSubs.isNotEmpty) {
            // Fetch cloud data using raw ApiService to bypass cache
            final cloudSubs = await ApiService().getSubscriptions(email);
            final normalizedCloud = <String, Map<String, dynamic>>{};
            for (final sub in cloudSubs) {
              final normName = sub['name'].toString().trim().toLowerCase();
              normalizedCloud[normName] = sub;
            }

            final conflicts = <Map<String, dynamic>>[];
            final nonConflicts = <Map<String, dynamic>>[];

            for (final guestSub in guestSubs) {
              final normName = guestSub['name'].toString().trim().toLowerCase();
              if (normalizedCloud.containsKey(normName)) {
                final cloudSub = normalizedCloud[normName]!;
                // Check if key properties differ (Price, Currency, RenewalDate, Category)
                final localPrice = (guestSub['price'] ?? 0).toString();
                final cloudPrice = (cloudSub['price'] ?? 0).toString();
                final localCurr = (guestSub['currency'] ?? 'USD').toString().toUpperCase();
                final cloudCurr = (cloudSub['currency'] ?? 'USD').toString().toUpperCase();
                final localRen = (guestSub['renewalDate'] ?? '').toString();
                final cloudRen = (cloudSub['renewalDate'] ?? '').toString();
                final localCat = (guestSub['category'] ?? 'Other').toString();
                final cloudCat = (cloudSub['category'] ?? 'Other').toString();

                if (localPrice != cloudPrice ||
                    localCurr != cloudCurr ||
                    localRen != cloudRen ||
                    localCat != cloudCat) {
                  conflicts.add({
                    'local': guestSub,
                    'cloud': cloudSub,
                  });
                }
                // If they are exactly identical, we ignore the local duplicate
              } else {
                nonConflicts.add(guestSub);
              }
            }

            List<int>? decisions;
            if (conflicts.isNotEmpty && mounted) {
              // Hide loading indicator to show bottom sheet
              setState(() => _loading = false);
              
              decisions = await showModalBottomSheet<List<int>>(
                context: context,
                isScrollControlled: true,
                isDismissible: false,
                enableDrag: false,
                backgroundColor: const Color(0xFFF8F6F1),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => PopScope(
                  canPop: false, // Prevent physical back button pop
                  child: ConflictResolverSheet(
                    conflicts: conflicts,
                    onCancel: () => Navigator.of(context).pop(),
                  ),
                ),
              );

              // Set loading back
              if (mounted) setState(() => _loading = true);
            }

            // Sync: nonConflicts & resolved ones
            try {
              // 1. Upload non-conflicting guest subscriptions
              for (final sub in nonConflicts) {
                await ApiService().addSubscription(email, {
                  ...sub,
                  'email': email, // Ensure it is linked to the user's email
                });
              }

              // 2. Upload/update resolved ones
              if (decisions != null) {
                for (int i = 0; i < conflicts.length; i++) {
                  final local = conflicts[i]['local'] as Map<String, dynamic>;
                  final cloud = conflicts[i]['cloud'] as Map<String, dynamic>;
                  final choice = decisions[i]; // 0 = Keep Cloud, 1 = Keep Local

                  if (choice == 1) {
                    // Update cloud copy in MongoDB with guest details
                    await ApiService().updateSubscription(email, cloud['id'].toString(), {
                      'name': local['name'],
                      'plan': local['plan'],
                      'price': local['price'],
                      'currency': local['currency'],
                      'renewalDate': local['renewalDate'],
                      'category': local['category'],
                      'color': local['color'],
                      'notes': local['notes'],
                    });
                  }
                }
              }

              // Success! Clear guest database from SharedPreferences
              await prefs.remove('local_subs_guest');
            } catch (e) {
              debugPrint('Error during subscription sync: $e');
              _showSnackBar('Network error: Some guest subscriptions failed to sync. Keeping guest copy local.', isError: true);
            }
          }
        }

        // Ensure fetch timestamp cache is cleared so Dashboard pulls updated remote list
        await prefs.remove('last_fetch_$email');
      } catch (e) {
        debugPrint('Failed to save session token locally: $e');
      }

      if (mounted) {
        setState(() => _loading = false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => DashboardPage(userName: name, userEmail: email),
          ),
          (_) => false,
        );
      }
    } else {
      _showSnackBar(result['message'] ?? 'Something went wrong', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isError ? Colors.white : _onSurface,
        )),
        backgroundColor: isError ? const Color(0xFF93000A) : _surfHigh,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Animation<double> _stagger(double s, double e) => CurvedAnimation(
        parent: _entrance,
        curve: Interval(s, e, curve: Curves.easeOutCubic),
      );

  Widget _fade(double s, double e, {required Widget child, Offset? from}) {
    final a = _stagger(s, e);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: from ?? const Offset(0, 0.06), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 24, 0),
              child: _fade(0.0, 0.25, from: const Offset(0, -0.04), child: _buildTopBar()),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: _onSurface,
        ),
        const SizedBox(width: 4),
        const Text(
          'SubManager',
          style: TextStyle(color: _onSurface, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        ),
      ],
    );
  }

  // ── layouts ──────────────────────────────────────────────
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 11,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fade(0.08, 0.40, child: _buildTitle(48)),
              const SizedBox(height: 48),
              _fade(0.16, 0.58, from: const Offset(-0.04, 0), child: _buildFeatureStack()),
            ],
          ),
        ),
        const SizedBox(width: 64),
        Expanded(
          flex: 9,
          child: _fade(0.24, 0.72, from: const Offset(0.04, 0), child: _buildAuthCard()),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _fade(0.08, 0.44, child: _buildTitle(32)),
        const SizedBox(height: 32),
        _fade(0.18, 0.68, child: _buildAuthCard()),
      ],
    );
  }

  Widget _buildTitle(double fontSize) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: _switchTransition,
      child: Column(
        key: ValueKey<String>('title-$_isLogin'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isLogin ? 'Welcome back.' : 'Join the space.',
            style: TextStyle(color: _onSurface, fontSize: fontSize, fontWeight: FontWeight.w600, letterSpacing: -1.5, height: 1.1),
          ),
          const SizedBox(height: 14),
          Text(
            _isLogin
                ? 'Sign in to access your dashboard and manage subscriptions.'
                : 'Create a workspace and start tracking payments in seconds.',
            style: const TextStyle(color: _onSurfVar, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── feature deck ─────────────────────────────────────────
  Widget _buildFeatureStack() {
    return SizedBox(
      height: 290,
      width: 440,
      child: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _float]),
        builder: (context, _) {
          final ft = _float.value;
          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: List.generate(_features.length, (i) {
              final deal = CurvedAnimation(
                parent: _entrance,
                curve: Interval(0.20 + i * 0.1, 0.65 + i * 0.1, curve: Curves.easeOutBack),
              ).value;
              final fan = _fans[i];
              final floatDy = 4.0 * math.sin(ft * 2 * math.pi + i * math.pi / 2.5);
              final rot = fan.$1 * deal;
              final dx = _lerp(-80, fan.$2, deal);
              final dy = _lerp(30, fan.$3 + floatDy, deal);
              return Positioned(
                left: 20,
                child: Opacity(
                  opacity: deal.clamp(0.0, 1.0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.translationValues(dx, dy, 0)..rotateZ(rot),
                    child: _featureCard(i),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _featureCard(int i) {
    final item = _features[i];
    return Container(
      width: 320,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVar),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.$4.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.$3, color: item.$4, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.$1, style: const TextStyle(color: _onSurface, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(item.$2, style: const TextStyle(color: _onSurfVar, fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── auth form card ───────────────────────────────────────
  Widget _buildAuthCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surfLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outlineVar),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: _switchTransition,
              child: Text(
                _isLogin ? 'Sign in' : 'Create account',
                key: ValueKey<String>('card-title-$_isLogin'),
                style: const TextStyle(color: _onSurface, fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: _switchTransition,
              child: Text(
                _isLogin ? 'Fill in your login credentials.' : 'Set up your workspace in seconds.',
                key: ValueKey<String>('card-sub-$_isLogin'),
                style: const TextStyle(color: _onSurfVar, fontSize: 13.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: _formTransition,
                child: _isLogin ? _loginFields() : _signupFields(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryContainer,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _surfHigh,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          _isLogin ? 'Sign in' : 'Get started',
                          key: ValueKey<String>('submit-$_isLogin'),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => _setMode(!_isLogin),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    _isLogin ? 'Don\'t have an account? Sign up' : 'Already have an account? Log in',
                    key: ValueKey<String>('toggle-$_isLogin'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loginFields() {
    return Column(
      key: const ValueKey('login-form'),
      children: [
        _field(_emailCtrl, 'Email address', Icons.email_outlined, validator: _validateEmail),
        const SizedBox(height: 16),
        _field(_passCtrl, 'Password', Icons.lock_outline_rounded, obscure: true, validator: _validatePass),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: _bg,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                builder: (_) => _ForgotPasswordSheet(initialEmail: _emailCtrl.text),
              );
            },
            style: TextButton.styleFrom(foregroundColor: _onSurfVar, visualDensity: VisualDensity.compact),
            child: const Text('Forgot password?', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _signupFields() {
    return Column(
      key: const ValueKey('signup-form'),
      children: [
        _field(_nameCtrl, 'Full name', Icons.person_outline_rounded, validator: _validateName),
        const SizedBox(height: 16),
        _field(_emailCtrl, 'Email address', Icons.email_outlined, validator: _validateEmail),
        const SizedBox(height: 16),
        _field(_passCtrl, 'Password', Icons.lock_outline_rounded, obscure: true, validator: _validatePass),
        const SizedBox(height: 16),
        _field(_confirmCtrl, 'Confirm password', Icons.lock_outline_rounded, obscure: true, validator: _validateConfirm),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: _onSurface, fontWeight: FontWeight.w600, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _outline, fontWeight: FontWeight.w500, fontSize: 14),
        prefixIcon: Icon(icon, color: _primary, size: 19),
        filled: true,
        fillColor: _surfContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        errorStyle: const TextStyle(color: _error, fontSize: 12, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _outlineVar),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _outlineVar),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
      ),
    );
  }

  // ── validators ───────────────────────────────────────────
  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w\-.]+@[\w\-]+\.\w+').hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePass(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passCtrl.text) return 'Passwords do not match';
    return null;
  }

  // ── animation transitions ────────────────────────────────
  Widget _switchTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }

  Widget _formTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  const _ForgotPasswordSheet({required this.initialEmail});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  int _step = 1; // 1 = Request OTP, 2 = Verify & Reset
  bool _loading = false;
  String? _errorMessage;
  String? _successMessage;
  
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // Color tokens from parent
  static const _surfContainer = Color(0xFFFAF9F6);
  static const _surfHigh = Color(0xFFF0EDE8);
  static const _primary = Color(0xFFD4593A);
  static const _onSurface = Color(0xFF1A1A2E);
  static const _onSurfVar = Color(0xFF6B6B80);
  static const _outline = Color(0xFFACA8A1);
  static const _outlineVar = Color(0xFFE8E4DE);
  static const _error = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    final result = await MongoDbService().sendPasswordResetOtp(_emailCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      setState(() {
        _step = 2;
        _successMessage = result['message'] ?? 'OTP sent to your email.';
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to send OTP.';
        _successMessage = null;
      });
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    final result = await MongoDbService().verifyOtpAndResetPassword(
      email: _emailCtrl.text,
      otp: _otpCtrl.text,
      newPassword: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      _showSnackBar(result['message'] ?? 'Password reset successfully.');
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to reset password.';
        _successMessage = null;
      });
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: isError ? _error : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 120,
          left: 24,
          right: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildNotificationBanner() {
    final isError = _errorMessage != null;
    final message = isError ? _errorMessage! : _successMessage!;
    final bgColor = isError ? _error.withValues(alpha: 0.1) : const Color(0xFFD4593A).withValues(alpha: 0.1);
    final borderColor = isError ? _error.withValues(alpha: 0.2) : const Color(0xFFD4593A).withValues(alpha: 0.2);
    final iconColor = isError ? _error : const Color(0xFFD4593A);
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: iconColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.close_rounded, color: iconColor.withValues(alpha: 0.6), size: 16),
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _successMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.lock_reset_rounded, color: _primary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset Password',
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _step == 1
                    ? 'Enter email to receive an OTP verification code.'
                    : 'Enter the 6-digit OTP code and set your new password.',
                style: const TextStyle(color: _onSurfVar, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: _onSurfVar),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null || _successMessage != null) ...[
                _buildNotificationBanner(),
                const SizedBox(height: 16),
              ],
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTitleRow(),
                      const SizedBox(height: 24),
                      if (_step == 1) ...[
                        _field(
                          _emailCtrl,
                          'Email address',
                          Icons.email_outlined,
                          textInputAction: TextInputAction.send,
                          onFieldSubmitted: (_) => _loading ? null : _handleSendOtp(),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Email is required';
                            if (!RegExp(r'^[\w\-.]+@[\w\-]+\.\w+').hasMatch(v.trim())) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleSendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _surfHigh,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Text('Send Verification OTP'),
                          ),
                        ),
                      ] else ...[
                        _field(
                          _otpCtrl,
                          '6-digit OTP Code',
                          Icons.vpn_key_outlined,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Verification code is required';
                            if (v.trim().length != 6) return 'Verification code must be 6 digits';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _field(
                          _passCtrl,
                          'New Password',
                          Icons.lock_outline_rounded,
                          obscure: true,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password is required';
                            if (v.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _field(
                          _confirmCtrl,
                          'Confirm New Password',
                          Icons.lock_outline_rounded,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _loading ? null : _handleResetPassword(),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please confirm your password';
                            if (v != _passCtrl.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleResetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _surfHigh,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Text('Reset Password'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() {
                              _step = 1;
                              _errorMessage = null;
                              _successMessage = null;
                            }),
                            style: TextButton.styleFrom(foregroundColor: _primary),
                            child: const Text('Back to email entry', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(color: _onSurface, fontWeight: FontWeight.w600, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _outline, fontWeight: FontWeight.w500, fontSize: 14),
        prefixIcon: Icon(icon, color: _primary, size: 19),
        filled: true,
        fillColor: _surfContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        errorStyle: const TextStyle(color: _error, fontSize: 12, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _outlineVar),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _outlineVar),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
      ),
    );
  }
}

class ConflictResolverSheet extends StatefulWidget {
  final List<Map<String, dynamic>> conflicts;
  final VoidCallback onCancel;

  const ConflictResolverSheet({
    super.key,
    required this.conflicts,
    required this.onCancel,
  });

  @override
  State<ConflictResolverSheet> createState() => _ConflictResolverSheetState();
}

class _ConflictResolverSheetState extends State<ConflictResolverSheet> {
  // Store decision index for each conflict: 0 = Cloud (first), 1 = Local (second)
  late List<int> _decisions;

  @override
  void initState() {
    super.initState();
    // Default to keep local guest version (1)
    _decisions = List.filled(widget.conflicts.length, 1);
  }

  void _bulkSet(int choice) {
    setState(() {
      _decisions = List.filled(widget.conflicts.length, choice);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle/indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFACA8A1).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resolve Sync Conflicts',
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'We found duplicate subscriptions with mismatching values. Choose which one to keep.',
                      style: TextStyle(
                        color: Color(0xFF6B6B80),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Bulk actions
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _bulkSet(1),
                icon: const Icon(Icons.download_done_rounded, size: 16),
                label: const Text('Keep All Local Guest'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD4593A),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _bulkSet(0),
                icon: const Icon(Icons.cloud_download_rounded, size: 16),
                label: const Text('Keep All Cloud'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B6B80),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Conflicting items list
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: widget.conflicts.length,
              itemBuilder: (context, i) {
                final local = widget.conflicts[i]['local'] as Map<String, dynamic>;
                final cloud = widget.conflicts[i]['cloud'] as Map<String, dynamic>;
                return _buildConflictCard(i, local, cloud);
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Confirm Button
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Return selected decisions: list of choices
                Navigator.of(context).pop(_decisions);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4593A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Sync & Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictCard(int index, Map<String, dynamic> local, Map<String, dynamic> cloud) {
    final name = local['name'] ?? cloud['name'] ?? 'Subscription';
    final localPrice = '${local['price'] ?? 0} ${(local['currency'] ?? 'USD').toString().toUpperCase()}';
    final cloudPrice = '${cloud['price'] ?? 0} ${(cloud['currency'] ?? 'USD').toString().toUpperCase()}';
    final localRenews = local['renewalDate'] ?? '';
    final cloudRenews = cloud['renewalDate'] ?? '';
    final localCategory = local['category'] ?? 'Other';
    final cloudCategory = cloud['category'] ?? 'Other';

    final choice = _decisions[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E4DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4593A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.sync_problem_rounded, color: Color(0xFFD4593A), size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8E4DE)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Cloud option
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _decisions[index] = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: choice == 0 ? const Color(0xFFD4593A).withValues(alpha: 0.05) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: choice == 0 ? const Color(0xFFD4593A) : const Color(0xFFE8E4DE),
                          width: choice == 0 ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                choice == 0 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                color: choice == 0 ? const Color(0xFFD4593A) : const Color(0xFFACA8A1),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Keep Cloud',
                                style: TextStyle(
                                  color: Color(0xFF1A1A2E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cloudPrice,
                            style: const TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Renews $cloudRenews',
                            style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 10),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cat: $cloudCategory',
                            style: const TextStyle(color: Color(0xFFACA8A1), fontSize: 9),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Local Guest option
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _decisions[index] = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: choice == 1 ? const Color(0xFFD4593A).withValues(alpha: 0.05) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: choice == 1 ? const Color(0xFFD4593A) : const Color(0xFFE8E4DE),
                          width: choice == 1 ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                choice == 1 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                color: choice == 1 ? const Color(0xFFD4593A) : const Color(0xFFACA8A1),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Keep Local',
                                style: TextStyle(
                                  color: Color(0xFF1A1A2E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            localPrice,
                            style: const TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Renews $localRenews',
                            style: const TextStyle(color: Color(0xFF6B6B80), fontSize: 10),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cat: $localCategory',
                            style: const TextStyle(color: Color(0xFFACA8A1), fontSize: 9),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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
}
