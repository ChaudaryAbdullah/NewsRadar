import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';

/// Opens a URL in the device's default browser.
/// Shows a snackbar if the URL can't be launched.
Future<void> openArticleUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    _showError(context, 'Invalid URL');
    return;
  }

  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication, // opens in browser/Chrome
    );
    if (!launched && context.mounted) {
      // Fallback: try in-app browser
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  } catch (_) {
    if (context.mounted) _showError(context, 'Could not open article. Copy link instead?');
  }
}

void _showError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.badgeRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

/// A reusable "Open Article" button widget
class OpenArticleButton extends StatelessWidget {
  final String url;
  final String sourceName;
  final bool compact;

  const OpenArticleButton({
    super.key,
    required this.url,
    required this.sourceName,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return GestureDetector(
        onTap: () => openArticleUrl(context, url),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accentDeep.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accentDeep.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.open_in_new_rounded, size: 13, color: AppColors.accentDeep),
            const SizedBox(width: 4),
            Text('Open', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentDeep)),
          ]),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => openArticleUrl(context, url),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: Text(
          'Read full article on $sourceName ↗',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentDeep,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }
}
