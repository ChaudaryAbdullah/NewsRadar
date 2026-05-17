import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';

class ReliabilityBadgeWidget extends StatelessWidget {
  final String badge; // GREEN, AMBER, RED
  final bool large;

  const ReliabilityBadgeWidget({
    super.key,
    required this.badge,
    this.large = false,
  });

  Color get _color {
    switch (badge.toUpperCase()) {
      case 'GREEN':
        return AppColors.badgeGreen;
      case 'RED':
        return AppColors.badgeRed;
      default:
        return AppColors.badgeAmber;
    }
  }

  String get _label {
    switch (badge.toUpperCase()) {
      case 'GREEN':
        return 'Reliable';
      case 'RED':
        return 'Low Trust';
      default:
        return 'Moderate';
    }
  }

  IconData get _icon {
    switch (badge.toUpperCase()) {
      case 'GREEN':
        return Icons.verified_rounded;
      case 'RED':
        return Icons.warning_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = large ? 13.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 7,
        vertical: large ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: size + 2),
          const SizedBox(width: 4),
          Text(
            _label,
            style: GoogleFonts.inter(
              fontSize: size,
              color: _color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class VerdictBadgeWidget extends StatelessWidget {
  final String status;

  const VerdictBadgeWidget({super.key, required this.status});

  Color get _color {
    switch (status.toUpperCase()) {
      case 'VERIFIED':
        return AppColors.badgeGreen;
      case 'DISPUTED':
        return AppColors.badgeRed;
      case 'FLAGGED':
        return AppColors.badgeAmber;
      case 'FACT_CHECKED':
        return AppColors.accent;
      case 'PENDING':
        return AppColors.neutral;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: GoogleFonts.inter(
          fontSize: 10,
          color: _color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class RiskLevelWidget extends StatelessWidget {
  final String riskLevel;

  const RiskLevelWidget({super.key, required this.riskLevel});

  Color get _color {
    switch (riskLevel.toUpperCase()) {
      case 'LOW':
        return AppColors.riskLow;
      case 'HIGH':
        return AppColors.riskHigh;
      default:
        return AppColors.riskMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _color.withOpacity(0.5), blurRadius: 6)],
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .fade(duration: 800.ms, curve: Curves.easeInOut)
            .then()
            .fade(duration: 800.ms, curve: Curves.easeInOut),
        const SizedBox(width: 6),
        Text(
          '${riskLevel[0]}${riskLevel.substring(1).toLowerCase()} Risk',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: _color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class SentimentWidget extends StatelessWidget {
  final String sentiment;
  final double score;

  const SentimentWidget({
    super.key,
    required this.sentiment,
    required this.score,
  });

  Color get _color {
    switch (sentiment.toUpperCase()) {
      case 'POSITIVE':
        return AppColors.positive;
      case 'NEGATIVE':
        return AppColors.negative;
      default:
        return AppColors.neutral;
    }
  }

  IconData get _icon {
    switch (sentiment.toUpperCase()) {
      case 'POSITIVE':
        return Icons.sentiment_satisfied_rounded;
      case 'NEGATIVE':
        return Icons.sentiment_dissatisfied_rounded;
      default:
        return Icons.sentiment_neutral_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon, color: _color, size: 16),
        const SizedBox(width: 4),
        Text(
          sentiment[0] + sentiment.substring(1).toLowerCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: _color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class LoadingShimmerCard extends StatelessWidget {
  const LoadingShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(height: 14, width: double.infinity),
          const SizedBox(height: 8),
          _shimmer(height: 14, width: 200),
          const SizedBox(height: 12),
          _shimmer(height: 100, width: double.infinity),
          const SizedBox(height: 12),
          Row(
            children: [
              _shimmer(height: 24, width: 80),
              const SizedBox(width: 8),
              _shimmer(height: 24, width: 60),
            ],
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: AppColors.divider.withOpacity(0.5));
  }

  Widget _shimmer({required double height, required double width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
