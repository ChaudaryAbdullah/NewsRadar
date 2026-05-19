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

  // Role badge color (hex int)
  int get colorValue {
    switch (this) {
      case UserRole.consumer:   return 0xFF64748B; // slate
      case UserRole.journalist: return 0xFF0284C7; // blue
      case UserRole.editor:     return 0xFF7C3AED; // purple
      case UserRole.admin:      return 0xFFDC2626; // red
      case UserRole.auditor:    return 0xFF059669; // green
    }
  }

  bool get canViewAnalytics => index >= UserRole.journalist.index;
  bool get canViewAdmin =>     this == UserRole.admin;
  bool get canViewAudit =>     this == UserRole.admin || this == UserRole.auditor;
  bool get canOverrideVerdicts => index >= UserRole.editor.index;
}

// ─── App User ─────────────────────────────────────────────────────────────────

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String avatarInitials;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarInitials,
  });
}

// ─── Auth Service ─────────────────────────────────────────────────────────────

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // ── Hardcoded credentials (replace with DB later) ──────────────────────────
  static const _users = [
    _UserCredential(
      id: 'usr-001',
      name: 'Admin User',
      email: 'admin@newsradar.com',
      password: 'admin123',
      role: UserRole.admin,
      initials: 'AU',
    ),
    _UserCredential(
      id: 'usr-002',
      name: 'Editor Jane',
      email: 'editor@newsradar.com',
      password: 'editor123',
      role: UserRole.editor,
      initials: 'EJ',
    ),
    _UserCredential(
      id: 'usr-003',
      name: 'John Reporter',
      email: 'journalist@newsradar.com',
      password: 'press123',
      role: UserRole.journalist,
      initials: 'JR',
    ),
    _UserCredential(
      id: 'usr-004',
      name: 'Regular User',
      email: 'user@newsradar.com',
      password: 'user123',
      role: UserRole.consumer,
      initials: 'RU',
    ),
    _UserCredential(
      id: 'usr-005',
      name: 'Audit Smith',
      email: 'auditor@newsradar.com',
      password: 'audit123',
      role: UserRole.auditor,
      initials: 'AS',
    ),
  ];

  /// Returns null on success, or an error message string on failure.
  String? login(String email, String password) {
    if (email.trim().isEmpty) return 'Email is required';
    if (password.isEmpty) return 'Password is required';

    final match = _users.where(
      (u) => u.email.toLowerCase() == email.trim().toLowerCase()
           && u.password == password,
    ).firstOrNull;

    if (match == null) return 'Invalid email or password';

    _currentUser = AppUser(
      id: match.id,
      name: match.name,
      email: match.email,
      role: match.role,
      avatarInitials: match.initials,
    );
    return null; // success
  }

  void logout() => _currentUser = null;
}

// ─── Internal credential record ───────────────────────────────────────────────

class _UserCredential {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String initials;

  const _UserCredential({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.initials,
  });
}
