import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/user.dart';
import '../../../core/theme.dart';
import '../../dashboard/screens/role_router.dart';

// ─── Auth Screen (Login + Signup unified) ─────────────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthState { login, signup }

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  _AuthState _view = _AuthState.login;

  void _goTo(_AuthState s) => setState(() => _view = s);

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
                _Logo(),
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _view == _AuthState.login
                      ? _LoginForm(key: const ValueKey('login'), onGoSignup: () => _goTo(_AuthState.signup))
                      : _SignupForm(key: const ValueKey('signup'), onGoLogin: () => _goTo(_AuthState.login)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Logo ─────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accent, AppColors.accentDeep],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: const Icon(Icons.radar_rounded, color: Colors.white, size: 38),
      ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
      const SizedBox(height: 14),
      Text('NewsRadar', style: GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w800,
        color: AppColors.textPrimary, letterSpacing: -0.5,
      )).animate().fadeIn(delay: 100.ms),
      const SizedBox(height: 4),
      Text('AI-Powered News Intelligence', style: GoogleFonts.inter(
        fontSize: 13, color: AppColors.textMuted,
      )).animate().fadeIn(delay: 200.ms),
    ]);
  }
}

// ─── Login Form ───────────────────────────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  final VoidCallback onGoSignup;
  const _LoginForm({super.key, required this.onGoSignup});
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  static const _demos = [
    ('Admin',      'admin@newsradar.com',      'admin123'),
    ('Editor',     'editor@newsradar.com',     'editor123'),
    ('Journalist', 'journalist@newsradar.com', 'press123'),
    ('User',       'user@newsradar.com',       'user123'),
  ];

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final err = await AuthService().loginAsync(_emailCtrl.text, _passCtrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _loading = false; });
    } else {
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const RoleRouter()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Card(child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardTitle(title: 'Welcome back', sub: 'Sign in to your workspace'),
          const SizedBox(height: 20),
          if (_error != null) ...[_ErrorBanner(msg: _error!), const SizedBox(height: 14)],
          _Label('Email'), const SizedBox(height: 6),
          _Field(ctrl: _emailCtrl, hint: 'you@example.com', icon: Icons.email_outlined,
            type: TextInputType.emailAddress,
            validator: (v) => v!.trim().isEmpty ? 'Required' : !v.contains('@') ? 'Invalid email' : null),
          const SizedBox(height: 14),
          _Label('Password'), const SizedBox(height: 6),
          _Field(ctrl: _passCtrl, hint: '••••••••', icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            suffix: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AppColors.textMuted, size: 18), onPressed: () => setState(() => _obscure = !_obscure)),
            validator: (v) => v!.isEmpty ? 'Required' : null,
            onSubmit: (_) => _submit()),
          const SizedBox(height: 24),
          _SubmitBtn(label: 'Sign in', loading: _loading, onTap: _submit),
          const SizedBox(height: 16),
          Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text("Don't have an account? ", style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
            GestureDetector(
              onTap: widget.onGoSignup,
              child: Text('Create one', style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.accentDeep, fontWeight: FontWeight.w600)),
            ),
          ])),
        ]),
      )),
      const SizedBox(height: 16),
      _DemoChips(onFill: (e, p) { _emailCtrl.text = e; _passCtrl.text = p; setState(() => _error = null); },
        selectedEmail: _emailCtrl.text, demos: _demos),
    ]);
  }
}

// ─── Signup Form ──────────────────────────────────────────────────────────────

class _SignupForm extends StatefulWidget {
  final VoidCallback onGoLogin;
  const _SignupForm({super.key, required this.onGoLogin});
  @override
  State<_SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<_SignupForm> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _confCtrl  = TextEditingController();
  bool _obscure1 = true, _obscure2 = true;
  bool _loading = false;
  bool _gdprConsent = false;
  String? _error;
  UserRole _selectedRole = UserRole.consumer;

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); _confCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_gdprConsent) { setState(() => _error = 'You must accept the privacy policy'); return; }
    setState(() { _loading = true; _error = null; });
    final err = await AuthService().registerAsync(
      fullName: _nameCtrl.text, email: _emailCtrl.text,
      password: _passCtrl.text, selectedRole: _selectedRole,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _loading = false; });
    } else {
      final note = AuthService().registerNote;
      if (note != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(note), duration: const Duration(seconds: 5)));
      }
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const RoleRouter()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Back button
        GestureDetector(
          onTap: widget.onGoLogin,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppColors.accentDeep),
            const SizedBox(width: 4),
            Text('Back to sign in', style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.accentDeep, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 16),
        _CardTitle(title: 'Create account', sub: 'Join the NewsRadar intelligence network'),
        const SizedBox(height: 20),
        if (_error != null) ...[_ErrorBanner(msg: _error!), const SizedBox(height: 14)],

        _Label('Full name'), const SizedBox(height: 6),
        _Field(ctrl: _nameCtrl, hint: 'Jane Reporter', icon: Icons.person_outline_rounded,
          validator: (v) => v!.trim().isEmpty ? 'Required' : null),
        const SizedBox(height: 14),

        _Label('Email address'), const SizedBox(height: 6),
        _Field(ctrl: _emailCtrl, hint: 'you@example.com', icon: Icons.email_outlined,
          type: TextInputType.emailAddress,
          validator: (v) => v!.trim().isEmpty ? 'Required' : !v.contains('@') ? 'Invalid email' : null),
        const SizedBox(height: 14),

        _Label('Password'), const SizedBox(height: 6),
        _Field(ctrl: _passCtrl, hint: 'Min 6 characters', icon: Icons.lock_outline_rounded,
          obscure: _obscure1,
          suffix: IconButton(icon: Icon(_obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.textMuted, size: 18), onPressed: () => setState(() => _obscure1 = !_obscure1)),
          validator: (v) => v!.length < 6 ? 'Min 6 characters' : null),
        const SizedBox(height: 14),

        _Label('Confirm password'), const SizedBox(height: 6),
        _Field(ctrl: _confCtrl, hint: 'Repeat password', icon: Icons.lock_outline_rounded,
          obscure: _obscure2,
          suffix: IconButton(icon: Icon(_obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.textMuted, size: 18), onPressed: () => setState(() => _obscure2 = !_obscure2)),
          validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null),
        const SizedBox(height: 16),

        // Role selector
        _Label('Account type'), const SizedBox(height: 8),
        _RoleSelector(selected: _selectedRole, onChanged: (r) => setState(() => _selectedRole = r)),
        const SizedBox(height: 16),

        // GDPR consent
        GestureDetector(
          onTap: () => setState(() => _gdprConsent = !_gdprConsent),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: _gdprConsent ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _gdprConsent ? AppColors.accent : AppColors.divider, width: 2),
              ),
              child: _gdprConsent
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'I agree to the Privacy Policy and consent to my data being processed for the NewsRadar service.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            )),
          ]),
        ),
        const SizedBox(height: 24),
        _SubmitBtn(label: 'Create account', loading: _loading, onTap: _submit),
        const SizedBox(height: 14),
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Already have an account? ', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          GestureDetector(onTap: widget.onGoLogin,
            child: Text('Sign in', style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.accentDeep, fontWeight: FontWeight.w600))),
        ])),
      ]),
    ));
  }
}

// ─── Role Selector ────────────────────────────────────────────────────────────

class _RoleSelector extends StatelessWidget {
  final UserRole selected;
  final ValueChanged<UserRole> onChanged;
  const _RoleSelector({required this.selected, required this.onChanged});

  static const _roles = [UserRole.consumer, UserRole.journalist, UserRole.editor];

  @override
  Widget build(BuildContext context) {
    return Column(children: _roles.map((r) {
      final isSel = selected == r;
      return GestureDetector(
        onTap: () => onChanged(r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? Color(r.colorValue).withOpacity(0.1) : AppColors.primary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? Color(r.colorValue) : AppColors.divider,
              width: isSel ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(
              color: isSel ? Color(r.colorValue) : AppColors.divider,
              shape: BoxShape.circle,
            )),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.displayName, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: isSel ? Color(r.colorValue) : AppColors.textPrimary)),
              Text(r.description, style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textMuted)),
            ])),
            if (r.requiresApproval)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.badgeAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Needs approval', style: GoogleFonts.inter(
                  fontSize: 9, color: AppColors.badgeAmber, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      );
    }).toList());
  }
}

// ─── Demo chips ───────────────────────────────────────────────────────────────

class _DemoChips extends StatelessWidget {
  final List<(String, String, String)> demos;
  final String selectedEmail;
  final void Function(String email, String pass) onFill;
  const _DemoChips({required this.demos, required this.selectedEmail, required this.onFill});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bolt_rounded, size: 13, color: AppColors.accentDeep),
          const SizedBox(width: 4),
          Text('Demo accounts', style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: AppColors.accentDeep)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6,
          children: demos.map((d) {
            final (label, email, pass) = d;
            final active = selectedEmail.toLowerCase() == email.toLowerCase();
            return GestureDetector(
              onTap: () => onFill(email, pass),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent.withOpacity(0.15) : AppColors.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: active ? AppColors.accent : AppColors.divider,
                    width: active ? 1.5 : 1),
                ),
                child: Text(label, style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: active ? AppColors.accentDeep : AppColors.textPrimary)),
              ),
            );
          }).toList()),
      ]),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(maxWidth: 440),
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.divider),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
    ),
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  final String title, sub;
  const _CardTitle({required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    const SizedBox(height: 3),
    Text(sub, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
  ]);
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmit;
  final TextInputType type;
  const _Field({
    required this.ctrl, required this.hint, required this.icon,
    this.obscure = false, this.suffix, this.validator,
    this.onSubmit, this.type = TextInputType.text,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, obscureText: obscure, keyboardType: type,
    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
    onFieldSubmitted: onSubmit, validator: validator,
    decoration: InputDecoration(
      hintText: hint, hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
      suffixIcon: suffix, filled: true, fillColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.8)),
      errorBorder:   OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.badgeRed)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.badgeRed, width: 1.8)),
      errorStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.badgeRed),
    ),
  );
}

class _SubmitBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _SubmitBtn({required this.label, required this.loading, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 48,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent, foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: loading
        ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(label, style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String msg;
  const _ErrorBanner({required this.msg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.badgeRed.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.badgeRed.withOpacity(0.4)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.badgeRed, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: GoogleFonts.inter(fontSize: 13, color: AppColors.badgeRed))),
    ]),
  ).animate().shake(duration: 400.ms, hz: 3);
}
