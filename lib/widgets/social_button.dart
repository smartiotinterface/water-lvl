// lib/widgets/social_button.dart
// Social media link buttons for YouTube and Facebook

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A reusable social media button with icon, label, and URL.
class SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String url;
  final Color color;

  const SocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.url,
    required this.color,
  });

  Future<void> _launch() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;
    return InkWell(
      onTap: _launch,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pre-built YouTube button
class YouTubeButton extends StatelessWidget {
  const YouTubeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SocialButton(
      label: 'YouTube',
      icon: Icons.play_circle_fill,
      url: 'https://youtube.com/@smartiotinterface',
      color: Color(0xFFFF0000),
    );
  }
}

/// Pre-built Facebook button
class FacebookButton extends StatelessWidget {
  const FacebookButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SocialButton(
      label: 'Facebook',
      icon: Icons.facebook,
      url: 'https://www.facebook.com/profile.php?id=100087725496322',
      color: Color(0xFF1877F2),
    );
  }
}

/// Row of both social buttons, centered
class SocialButtonRow extends StatelessWidget {
  const SocialButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        YouTubeButton(),
        SizedBox(width: 12),
        FacebookButton(),
      ],
    );
  }
}
