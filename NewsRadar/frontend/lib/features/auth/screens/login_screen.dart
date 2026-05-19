import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/user.dart';
import '../../../core/theme.dart';
import '../../feed/screens/feed_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService();

  bool _obscurePass = true;
  bool _loading = false;
  String? _errorMsg;

  // Quick-fill buttons for demo
  static const _demoUsers = [
    ('Admin',      'admin@newsradar.com',      'admin123'),
    ('Editor',     'editor@newsradar.com',     'editor123'),
    ('Journalist', 'journalist@newsradar.com', 'press123'),
    ('User',       'user@newsradar.com',       'user123'),
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMsg = null; });

    // Simulate a short network delay for realism
    await Future.delayed(const Duration(milliseconds: 600));

    final err = _auth.login(_emailCtrl.text, _passCtrl.text);

    if (!mounted) return;

    if (err != null) {
      setState(() { _loading = false; _errorMsg = err; });
    } else {
      setState(() => _loading = false);
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const FeedScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _fillDemo(String email, String pass) {
    _emailCtrl.text = email;
    _passCtrl.text = pass;
    setState(() => _errorMsg = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 32),
                _buildCard(),
                const SizedBox(height: 20),
                _buildDemoQuickFill(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo ───────────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accent, AppColors.accentDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.radar_rounded, color: Colors.white, size: 38),
      ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
      const SizedBox(height: 16),
      Text(
        'NewsRadar',
        style: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.w800,
          color: AppColors.textPrimary, letterSpacing: -0.5,
        ),
      ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
      const SizedBox(height: 4),
      Text(
        'AI-Powered News Intelligence',
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
      ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
    ]);
  }

  // ── Login Card ─────────────────────────────────────────────────────────────

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Sign in',
            style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Access your NewsRadar workspace',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          // Error banner
          if (_errorMsg != null) ...[
            _ErrorBanner(message: _errorMsg!),
            const SizedBox(height: 16),
          ],

          // Email
          _FieldLabel(label: 'Email address'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
            decoration: _inputDecor(
              hint: 'you@example.com',
              icon: Icons.email_outlined,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          _FieldLabel(label: 'Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscurePass,
            autofillHints: const [AutofillHints.password],
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
            decoration: _inputDecor(
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                icon: Icon(
                  _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textMuted, size: 18,
                ),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 4) return 'Password too short';
              return null;
            },
            onFieldSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 28),

          // Sign in button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Sign in',
                      style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ]),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.08);
  }

  // ── Demo Quick-fill ────────────────────────────────────────────────────────

  Widget _buildDemoQuickFill() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bolt_rounded, size: 14, color: AppColors.accentDeep),
          const SizedBox(width: 4),
          Text(
            'Demo accounts — click to auto-fill',
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: AppColors.accentDeep, letterSpacing: 0.3,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _demoUsers.map((u) {
            final (label, email, pass) = u;
            final isActive = _emailCtrl.text.toLowerCase() == email.toLowerCase();
            return GestureDetector(
              onTap: () => _fillDemo(email, pass),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.accent.withOpacity(0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? AppColors.accent : AppColors.divider,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.accentDeep : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      email,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10, color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    ).animate().fadeIn(delay: 450.ms, duration: 400.ms);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  InputDecoration _inputDecor({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.badgeRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.badgeRed, width: 1.8),
      ),
      errorStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.badgeRed),
    );
  }
}

// ── Small sub-widgets ─────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: GoogleFonts.inter(
      fontSize: 13, fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.badgeRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.badgeRed.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.badgeRed, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.badgeRed),
          ),
        ),
      ]),
    ).animate().shake(duration: 400.ms, hz: 3);
  }
}
