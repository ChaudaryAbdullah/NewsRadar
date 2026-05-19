import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user.dart';
import '../../core/theme.dart';
import '../../features/auth/screens/auth_screen.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final PreferredSizeWidget? bottom;
  final List<Widget>? extraActions;

  const CommonAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.bottom,
    this.extraActions,
  });

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final roleColor = user != null ? Color(user.role.colorValue) : AppColors.accent;

    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      bottom: bottom,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [iconColor ?? AppColors.accent, (iconColor ?? AppColors.accent).withOpacity(0.6)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon ?? Icons.radar_rounded, color: Colors.white, size: 20),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: GoogleFonts.inter(
            fontSize: 17, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          )),
          if (subtitle != null)
            Text(subtitle!, style: GoogleFonts.inter(
              fontSize: 10, color: AppColors.textMuted,
            )),
        ],
      ),
      actions: [
        if (extraActions != null) ...extraActions!,
        if (user != null)
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: AppColors.surface,
            onSelected: (v) {
              if (v == 'logout') {
                AuthService().logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (_) => false,
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(user.email, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: roleColor.withOpacity(0.4)),
                    ),
                    child: Text(user.role.label, style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: roleColor, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(children: [
                  const Icon(Icons.logout_rounded, size: 16, color: AppColors.badgeRed),
                  const SizedBox(width: 10),
                  Text('Sign out', style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.badgeRed, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: roleColor.withOpacity(0.15),
                child: Text(user.avatarInitials, style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: roleColor)),
              ),
            ),
          ),
      ],
    );
  }
}
