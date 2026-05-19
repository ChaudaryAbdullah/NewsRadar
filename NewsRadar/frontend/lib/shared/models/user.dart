import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_api_service.dart';

// ─── User Roles ───────────────────────────────────────────────────────────────

enum UserRole { consumer, journalist, editor, admin, auditor }

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.consumer:   return 'CONSUMER';
      case UserRole.journalist: return 'JOURNALIST';
      case UserRole.editor:     return 'EDITOR';
      case UserRole.admin:      return 'ADMIN';
      case UserRole.auditor:    return 'AUDITOR';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.consumer:   return 'Consumer';
      case UserRole.journalist: return 'Journalist';
      case UserRole.editor:     return 'Editor';
      case UserRole.admin:      return 'Admin';
      case UserRole.auditor:    return 'Auditor';
    }
  }

  int get colorValue {
    switch (this) {
      case UserRole.consumer:   return 0xFF64748B;
      case UserRole.journalist: return 0xFF0284C7;
      case UserRole.editor:     return 0xFF7C3AED;
      case UserRole.admin:      return 0xFFDC2626;
      case UserRole.auditor:    return 0xFF059669;
    }
  }

  String get description {
    switch (this) {
      case UserRole.consumer:   return 'Read articles, use chatbot';
      case UserRole.journalist: return 'Analytics, reports, evidence';
      case UserRole.editor:     return 'Override verdicts, configure alerts';
      case UserRole.admin:      return 'Full platform management';
      case UserRole.auditor:    return 'Compliance and audit logs';
    }
  }

  bool get canViewAnalytics    => index >= UserRole.journalist.index;
  bool get canViewAdmin        => this == UserRole.admin;
  bool get canViewAudit        => this == UserRole.admin || this == UserRole.auditor;
  bool get canOverrideVerdicts => index >= UserRole.editor.index;
  bool get requiresApproval    => index >= UserRole.journalist.index;

  static UserRole fromString(String s) {
    switch (s.toLowerCase()) {
      case 'admin':      return UserRole.admin;
      case 'editor':     return UserRole.editor;
      case 'journalist': return UserRole.journalist;
      case 'auditor':    return UserRole.auditor;
      default:           return UserRole.consumer;
    }
  }
}

// ─── App User ─────────────────────────────────────────────────────────────────

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String avatarInitials;
  final String status;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarInitials,
    this.status = 'active',
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id:             j['id'] as String,
    name:           j['name'] as String,
    email:          j['email'] as String,
    role:           UserRoleExt.fromString(j['role'] as String),
    avatarInitials: j['initials'] as String? ??
        (j['name'] as String).split(' ').take(2).map((w) => w[0].toUpperCase()).join(),
    status:         j['status'] as String? ?? 'active',
  );
}

// ─── AuthService — real API-backed ────────────────────────────────────────────
// The actual HTTP implementation lives in AuthApiService (auth_api_service.dart).
// This class remains the singleton interface used by the rest of the app.

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AppUser? _currentUser;
  String?  _token;

  AppUser? get currentUser => _currentUser;
  String?  get token       => _token;
  bool     get isLoggedIn  => _currentUser != null && _token != null;

  // ── Restore session from shared_preferences ──────────────────────────────
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    if (savedToken == null) return false;
    try {
      final user = await AuthApiService().fetchMe(savedToken);
      _token = savedToken;
      _currentUser = user;
      return true;
    } catch (_) {
      await prefs.remove('auth_token');
      return false;
    }
  }

  // ── Login ────────────────────────────────────────────────────────────────
  /// Returns null on success, error string on failure.
  Future<String?> loginAsync(String email, String password) async {
    try {
      final result = await AuthApiService().login(email.trim(), password);
      _token = result['access_token'] as String;
      _currentUser = AppUser.fromJson(result['user'] as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // ── Register ─────────────────────────────────────────────────────────────
  Future<String?> registerAsync({
    required String fullName,
    required String email,
    required String password,
    required UserRole selectedRole,
  }) async {
    try {
      final result = await AuthApiService().register(
        fullName: fullName.trim(),
        email: email.trim(),
        password: password,
        role: selectedRole.displayName.toLowerCase(),
      );
      _token = result['access_token'] as String;
      _currentUser = AppUser.fromJson(result['user'] as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────
  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ── Note shown after register if role was downgraded ────────────────────
  String? get registerNote {
    final role = _currentUser?.role;
    if (role == null) return null;
    return role.requiresApproval
        ? 'Note: Elevated role requires admin approval. You have been registered as Consumer.'
        : null;
  }
}
