import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/common_app_bar.dart';

class AuditorDashboard extends StatelessWidget {
  const AuditorDashboard({super.key});

  static final _logs = [
    _AuditLog('2026-05-19 14:32:11', 'Admin User',   'ADMIN',      'UPDATE_VERDICT',    '/api/v1/verdicts/892',    'PUT',    '192.168.1.1'),
    _AuditLog('2026-05-19 14:28:03', 'Editor Jane',  'EDITOR',     'OVERRIDE_VERDICT',  '/api/v1/verdicts/891',    'PATCH',  '192.168.1.5'),
    _AuditLog('2026-05-19 14:19:47', 'Admin User',   'ADMIN',      'DELETE_USER',       '/api/v1/users/usr-010',   'DELETE', '192.168.1.1'),
    _AuditLog('2026-05-19 14:15:22', 'John Reporter','JOURNALIST', 'EXPORT_REPORT',     '/api/v1/analytics/export','GET',    '10.0.0.23'),
    _AuditLog('2026-05-19 13:55:09', 'Alice Chen',   'JOURNALIST', 'MANUAL_FACTCHECK',  '/api/v1/articles/712',    'POST',   '10.0.0.41'),
    _AuditLog('2026-05-19 13:40:33', 'Bob Nguyen',   'CONSUMER',   'LOGIN_FAILED',      '/api/v1/auth/login',      'POST',   '203.0.113.5'),
    _AuditLog('2026-05-19 13:38:17', 'Bob Nguyen',   'CONSUMER',   'LOGIN_FAILED',      '/api/v1/auth/login',      'POST',   '203.0.113.5'),
    _AuditLog('2026-05-19 13:36:54', 'Bob Nguyen',   'CONSUMER',   'LOGIN_FAILED',      '/api/v1/auth/login',      'POST',   '203.0.113.5'),
    _AuditLog('2026-05-19 13:01:44', 'Audit Smith',  'AUDITOR',    'VIEW_AUDIT_LOGS',   '/api/v1/audit/logs',      'GET',    '192.168.1.9'),
    _AuditLog('2026-05-19 12:55:30', 'Admin User',   'ADMIN',      'UPDATE_LLM_CONFIG', '/api/v1/admin/llm-config','PATCH',  '192.168.1.1'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: CommonAppBar(
        title: 'Audit Log Viewer',
        subtitle: 'Immutable compliance records',
        icon: Icons.security_rounded,
        iconColor: AppColors.badgeGreen,
      ),
      body: Column(children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.surface,
          child: Row(children: [
            _MiniStat('Total Events', '${_logs.length}', AppColors.accentDeep),
            _Divider(),
            _MiniStat('Today', '${_logs.length}', AppColors.badgeGreen),
            _Divider(),
            _MiniStat('Failed Logins', '3', AppColors.badgeRed),
            _Divider(),
            _MiniStat('Overrides', '1', const Color(0xFF7C3AED)),
          ]),
        ),
        const Divider(height: 1),
        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppColors.surfaceVariant,
          child: Row(children: [
            const Icon(Icons.filter_list_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text('All action types', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const Spacer(),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_rounded, size: 14),
              label: const Text('Export CSV'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentDeep,
                textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
        // Log list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _AuditLogCard(log: _logs[i], index: i),
          ),
        ),
      ]),
    );
  }
}

class _AuditLog {
  final String timestamp, user, role, action, endpoint, method, ip;
  const _AuditLog(this.timestamp, this.user, this.role, this.action, this.endpoint, this.method, this.ip);
}

class _AuditLogCard extends StatefulWidget {
  final _AuditLog log;
  final int index;
  const _AuditLogCard({required this.log, required this.index});
  @override
  State<_AuditLogCard> createState() => _AuditLogCardState();
}

class _AuditLogCardState extends State<_AuditLogCard> {
  bool _expanded = false;

  Color get _actionColor {
    if (widget.log.action.contains('FAILED') || widget.log.action.contains('DELETE')) return AppColors.badgeRed;
    if (widget.log.action.contains('OVERRIDE') || widget.log.action.contains('UPDATE')) return const Color(0xFF7C3AED);
    if (widget.log.action.contains('EXPORT') || widget.log.action.contains('VIEW'))    return AppColors.accentDeep;
    return AppColors.badgeGreen;
  }

  Color get _methodColor {
    switch (widget.log.method) {
      case 'DELETE': return AppColors.badgeRed;
      case 'POST':   return AppColors.badgeGreen;
      case 'PATCH':  return const Color(0xFF7C3AED);
      default:       return AppColors.accentDeep;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _expanded ? _actionColor.withOpacity(0.4) : AppColors.divider),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _actionColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(widget.log.action, style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, color: _actionColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.log.user,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
              Text(widget.log.timestamp.split(' ')[1],
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.textMuted)),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 16, color: AppColors.textMuted),
            ]),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _LogRow('timestamp',  widget.log.timestamp),
                  _LogRow('user',       widget.log.user),
                  _LogRow('role',       widget.log.role),
                  _LogRow('action',     widget.log.action),
                  _LogRow('endpoint',   widget.log.endpoint),
                  _LogRow('method',     widget.log.method),
                  _LogRow('ip_address', widget.log.ip),
                ]),
              ),
            ),
          ],
        ]),
      ),
    ).animate(delay: Duration(milliseconds: widget.index * 30)).fadeIn().slideX(begin: 0.03);
  }
}

class _LogRow extends StatelessWidget {
  final String key2, value;
  const _LogRow(this.key2, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90, child: Text('"$key2":', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.accentDeep))),
      Expanded(child: Text('"$value"', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textPrimary))),
    ]),
  );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted), textAlign: TextAlign.center),
  ]));
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
    const SizedBox(height: 32, child: VerticalDivider(width: 1));
}
