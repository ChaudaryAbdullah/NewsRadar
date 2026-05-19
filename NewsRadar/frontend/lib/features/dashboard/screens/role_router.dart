import 'package:flutter/material.dart';
import '../../../shared/models/user.dart';
import '../../feed/screens/feed_screen.dart';
import 'journalist_dashboard.dart';
import 'editor_dashboard.dart';
import 'admin_dashboard.dart';
import 'auditor_dashboard.dart';

/// Reads the current user role and routes to the correct dashboard.
class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    if (user == null) {
      // Safety — should never happen
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    switch (user.role) {
      case UserRole.admin:
        return const AdminDashboard();
      case UserRole.editor:
        return const EditorDashboard();
      case UserRole.journalist:
        return const JournalistDashboard();
      case UserRole.auditor:
        return const AuditorDashboard();
      case UserRole.consumer:
      default:
        return const FeedScreen();
    }
  }
}
