import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scan settings
          const _SectionHeader('Scan Settings'),
          const _SettingsTile(
            icon: Icons.timer_outlined,
            title: 'Max Scan Duration',
            subtitle: '3 seconds',
            trailing: Icon(Icons.chevron_right, color: Colors.white38),
          ),
          const _SettingsTile(
            icon: Icons.high_quality_outlined,
            title: 'Capture Quality',
            subtitle: 'High (1080p)',
            trailing: Icon(Icons.chevron_right, color: Colors.white38),
          ),

          const SizedBox(height: 24),

          // Account
          const _SectionHeader('Account'),
          const _SettingsTile(
            icon: Icons.person_outline,
            title: 'Free Plan',
            subtitle: '5 scans remaining today',
          ),
          const _SettingsTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Upgrade to Pro',
            subtitle: 'Unlimited scans + detailed breakdown',
            trailing: Icon(Icons.chevron_right, color: Colors.white38),
          ),

          const SizedBox(height: 24),

          // About
          const _SectionHeader('About'),
          const _SettingsTile(
            icon: Icons.info_outline,
            title: 'How It Works',
            subtitle: 'Learn about our detection methodology',
            trailing: Icon(Icons.chevron_right, color: Colors.white38),
          ),
          const _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Your scans stay private',
            trailing: Icon(Icons.chevron_right, color: Colors.white38),
          ),
          const _SettingsTile(
            icon: Icons.code,
            title: 'Version',
            subtitle: '1.0.0 (Build 1)',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
