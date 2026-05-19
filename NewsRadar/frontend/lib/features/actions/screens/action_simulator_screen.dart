import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/models/models.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/badges.dart';
import '../../../core/theme.dart';

class ActionSimulatorScreen extends StatefulWidget {
  final AnalysisResponse analysis;
  const ActionSimulatorScreen({super.key, required this.analysis});

  @override
  State<ActionSimulatorScreen> createState() => _ActionSimulatorScreenState();
}

class _ActionSimulatorScreenState extends State<ActionSimulatorScreen> {
  final _api = ApiService();
  SimulationResult? _simulation;
  bool _simulating = false;
  String? _error;
  String? _selectedActionId;

  Map<String, Color> get _actionColors => {
    'FACT_CHECK': AppColors.actionFactCheck,
    'SET_ALERT': AppColors.actionAlert,
    'FLAG_MISINFORMATION': AppColors.actionFlag,
    'SHARE_WITH_EDITOR': AppColors.actionShare,
    'ARCHIVE': AppColors.actionArchive,
  };

  Map<String, IconData> get _actionIcons => {
    'FACT_CHECK': Icons.fact_check_rounded,
    'SET_ALERT': Icons.notifications_active_rounded,
    'FLAG_MISINFORMATION': Icons.flag_rounded,
    'SHARE_WITH_EDITOR': Icons.share_rounded,
    'ARCHIVE': Icons.archive_rounded,
  };

  Future<void> _simulate(RecommendedAction action) async {
    setState(() { _simulating = true; _error = null; _selectedActionId = action.id; _simulation = null; });
    try {
      final result = await _api.simulateAction(
        article: widget.analysis.article,
        evaluation: widget.analysis.evaluation,
        actionType: action.type,
      );
      setState(() { _simulation = result; _simulating = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _simulating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Recommended Actions', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Article context
          _ContextCard(analysis: widget.analysis),
          const SizedBox(height: 16),
          Text('AI-Generated Actions', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Tap an action to simulate its execution', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          // Action cards
          ...widget.analysis.recommendedActions.asMap().entries.map((e) =>
            _ActionCard(
              action: e.value,
              index: e.key,
              color: _actionColors[e.value.type] ?? AppColors.accent,
              icon: _actionIcons[e.value.type] ?? Icons.bolt_rounded,
              isSelected: _selectedActionId == e.value.id,
              isSimulating: _simulating && _selectedActionId == e.value.id,
              onTap: () => _simulate(e.value),
            ),
          ),
          const SizedBox(height: 20),
          // Simulation result
          if (_simulating && _simulation == null)
            _SimulatingLoader(),
          if (_simulation != null)
            _SimulationResultCard(result: _simulation!),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.badgeRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.badgeRed.withOpacity(0.3))),
              child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.badgeRed)),
            ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  final AnalysisResponse analysis;
  const _ContextCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CONTEXT', style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Text(analysis.article.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Row(children: [
          RiskLevelWidget(riskLevel: analysis.evaluation.riskLevel),
          const SizedBox(width: 12),
          ReliabilityBadgeWidget(badge: analysis.evaluation.reliabilityBadge),
          const Spacer(),
          Text('${(analysis.evaluation.misinformationProbability * 100).toInt()}% misinfo risk',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final RecommendedAction action;
  final int index;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final bool isSimulating;
  final VoidCallback onTap;

  const _ActionCard({
    required this.action, required this.index, required this.color,
    required this.icon, required this.isSelected, required this.isSimulating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : AppColors.divider, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : [],
        ),
        child: Row(children: [
          // Priority badge
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Center(child: Icon(icon, color: color, size: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text('P${action.priority}', style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(action.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            ]),
            const SizedBox(height: 4),
            Text(action.description, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          isSimulating
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color))
            : Icon(isSelected ? Icons.check_circle_rounded : Icons.play_circle_rounded,
                color: isSelected ? color : AppColors.textMuted, size: 24),
        ]),
      ),
    ).animate(delay: Duration(milliseconds: index * 100)).fadeIn(duration: 400.ms).slideX(begin: 0.1);
  }
}

class _SimulatingLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(children: [
        const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
        const SizedBox(height: 16),
        Text('Simulating action...', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Executing pipeline and computing state changes', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted), textAlign: TextAlign.center),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _SimulationResultCard extends StatelessWidget {
  final SimulationResult result;
  const _SimulationResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Text('SIMULATION COMPLETE', style: GoogleFonts.inter(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const Spacer(),
            Text('${result.durationMs}ms', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Before / After
            Row(children: [
              Expanded(child: _StateBox(label: 'BEFORE', state: result.beforeState, isAfter: false)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, color: AppColors.accent, size: 20)
                  .animate(onPlay: (c) => c.repeat()).fade(duration: 600.ms),
              ),
              Expanded(child: _StateBox(label: 'AFTER', state: result.afterState, isAfter: true)),
            ]),
            const SizedBox(height: 16),
            // Impact summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.badgeGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.badgeGreen.withOpacity(0.2))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.bolt_rounded, color: AppColors.badgeGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(result.impactSummary, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5))),
              ]),
            ),
            const SizedBox(height: 16),
            // Execution log
            Text('EXECUTION LOG', style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: result.executionLog.asMap().entries.map((e) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(e.value, style: GoogleFonts.robotoMono(fontSize: 10, color: e.key == result.executionLog.length - 1 ? AppColors.badgeGreen : AppColors.textMuted, height: 1.4)),
                )
              ).toList()),
            ),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
  }
}

class _StateBox extends StatelessWidget {
  final String label;
  final ArticleState state;
  final bool isAfter;
  const _StateBox({required this.label, required this.state, required this.isAfter});

  @override
  Widget build(BuildContext context) {
    final accentColor = isAfter ? AppColors.badgeGreen : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: accentColor, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 8),
        VerdictBadgeWidget(status: state.status),
        const SizedBox(height: 6),
        ReliabilityBadgeWidget(badge: state.reliabilityBadge),
        if (state.lastAction != null) ...[
          const SizedBox(height: 6),
          Text(state.lastAction!.replaceAll('_', ' '), style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent)),
        ],
      ]),
    );
  }
}
