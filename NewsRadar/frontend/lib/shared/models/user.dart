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

  // ── Pre-seeded demo credentials ────────────────────────────────────────────
  final List<_UserCredential> _users = [
    const _UserCredential(id: 'usr-001', name: 'Admin User',     email: 'admin@newsradar.com',      password: 'admin123',  role: UserRole.admin,      initials: 'AU'),
    const _UserCredential(id: 'usr-002', name: 'Editor Jane',    email: 'editor@newsradar.com',     password: 'editor123', role: UserRole.editor,     initials: 'EJ'),
    const _UserCredential(id: 'usr-003', name: 'John Reporter',  email: 'journalist@newsradar.com', password: 'press123',  role: UserRole.journalist, initials: 'JR'),
    const _UserCredential(id: 'usr-004', name: 'Regular User',   email: 'user@newsradar.com',       password: 'user123',   role: UserRole.consumer,   initials: 'RU'),
    const _UserCredential(id: 'usr-005', name: 'Audit Smith',    email: 'auditor@newsradar.com',    password: 'audit123',  role: UserRole.auditor,    initials: 'AS'),
  ];

  int _nextId = 6;

  /// Login — returns null on success, error string on failure.
  String? login(String email, String password) {
    if (email.trim().isEmpty) return 'Email is required';
    if (password.isEmpty)     return 'Password is required';

    final match = _users.where(
      (u) => u.email.toLowerCase() == email.trim().toLowerCase()
          && u.password == password,
    ).firstOrNull;

    if (match == null) return 'Invalid email or password';

    _currentUser = AppUser(
      id: match.id, name: match.name,
      email: match.email, role: match.role,
      avatarInitials: match.initials,
    );
    return null;
  }

  /// Register — returns null on success, error string on failure.
  /// New users always get CONSUMER role (upgrade requires admin approval).
  String? register({
    required String fullName,
    required String email,
    required String password,
    required UserRole selectedRole,
  }) {
    if (fullName.trim().isEmpty) return 'Full name is required';
    if (email.trim().isEmpty)    return 'Email is required';
    if (!email.contains('@'))    return 'Enter a valid email';
    if (password.length < 6)     return 'Password must be at least 6 characters';

    final exists = _users.any(
      (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
    );
    if (exists) return 'An account with this email already exists';

    final initials = fullName.trim().split(' ')
        .take(2).map((w) => w[0].toUpperCase()).join();

    final id = 'usr-${_nextId.toString().padLeft(3, '0')}';
    _nextId++;

    // Elevated roles need approval — registered as CONSUMER for now
    final actualRole = selectedRole.requiresApproval
        ? UserRole.consumer
        : selectedRole;

    _users.add(_UserCredential(
      id: id,
      name: fullName.trim(),
      email: email.trim().toLowerCase(),
      password: password,
      role: actualRole,
      initials: initials.isEmpty ? '?' : initials,
    ));

    // Auto-login after register
    _currentUser = AppUser(
      id: id, name: fullName.trim(),
      email: email.trim().toLowerCase(),
      role: actualRole,
      avatarInitials: initials.isEmpty ? '?' : initials,
    );

    return null;
  }

  String? get registerNote {
    final role = _currentUser?.role;
    if (role == null) return null;
    return role.requiresApproval
        ? 'Note: Elevated role requires admin approval. You have been registered as CONSUMER.'
        : null;
  }

  void logout() => _currentUser = null;
}

// ─── Internal record ──────────────────────────────────────────────────────────

class _UserCredential {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String initials;

  const _UserCredential({
    required this.id, required this.name,
    required this.email, required this.password,
    required this.role, required this.initials,
  });
}
