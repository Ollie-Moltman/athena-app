import 'package:flutter/material.dart';
import '../../main.dart';

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
          // Scan Settings section
          const _SectionHeader('Scan Settings'),
          _SettingsTile(
            icon: Icons.timer_outlined,
            title: 'Max Scan Duration',
            subtitle: settingsService.maxDurationLabel,
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => _showDurationPicker(context),
          ),
          _SettingsTile(
            icon: Icons.high_quality_outlined,
            title: 'Capture Quality',
            subtitle: settingsService.qualityLabel,
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => _showQualityPicker(context),
          ),

          const SizedBox(height: 24),

          // Account section
          const _SectionHeader('Account'),
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Free Plan',
            subtitle: '${settingsService.scansRemaining} scans remaining today',
            onTap: () => _showPlanInfo(context),
          ),
          _SettingsTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Upgrade to Pro',
            subtitle: 'Unlimited scans + detailed breakdown',
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => _showUpgradeDialog(context),
          ),

          const SizedBox(height: 24),

          // Data section
          const _SectionHeader('Data'),
          _SettingsTile(
            icon: Icons.delete_outline,
            title: 'Clear Scan History',
            subtitle: 'Remove all saved scan results',
            onTap: () => _showClearHistoryDialog(context),
          ),

          const SizedBox(height: 24),

          // About section
          const _SectionHeader('About'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'How It Works',
            subtitle: 'Learn about our detection methodology',
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => _showHowItWorks(context),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Your scans stay private',
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => _showPrivacyPolicy(context),
          ),
          const _SettingsTile(
            icon: Icons.code,
            title: 'Version',
            subtitle: '1.0.0 (Build 4)',
          ),
        ],
      ),
    );
  }

  void _showDurationPicker(BuildContext context) {
    final current = settingsService.maxDurationMs;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Max Scan Duration',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...[
              (5000,  '5 seconds'),
              (10000, '10 seconds'),
              (20000, '20 seconds'),
              (30000, '30 seconds'),
            ].map((opt) => _OptionTile(
              label: opt.$2,
              selected: opt.$1 == current,
              onTap: () async {
                await settingsService.setMaxDurationMs(opt.$1);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) (context as Element).markNeedsBuild();
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showQualityPicker(BuildContext context) {
    final current = settingsService.quality;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Capture Quality',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...[
              ('720p',  '720p (Faster)'),
              ('1080p', '1080p (Recommended)'),
              ('4k',    '4K (Slower)'),
            ].map((opt) => _OptionTile(
              label: opt.$2,
              selected: opt.$1 == current,
              onTap: () async {
                await settingsService.setQuality(opt.$1);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) (context as Element).markNeedsBuild();
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showPlanInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Free Plan', style: TextStyle(color: Colors.white)),
        content: Text(
          'You have ${settingsService.scansRemaining} scans remaining today.\n\nScans reset at midnight.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Upgrade to Pro', style: TextStyle(color: Colors.white)),
        content: const Text(
          '• Unlimited scans\n• Detailed layer breakdown\n• Priority processing\n• Export results\n\nComing soon!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: const Text('Notify Me'),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Clear History?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete all saved scan results.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              await historyService.clearAll();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showHowItWorks(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('How Athena Works', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: const [
                    _HowStep(emoji: '🔍', title: 'Screen Capture', desc: 'We capture video directly from your screen using Android\'s MediaProjection API. No data leaves your device.'),
                    SizedBox(height: 16),
                    _HowStep(emoji: '📊', title: 'Layer 1 - Provenance', desc: 'Checks metadata patterns and capture signals that reveal AI generation.'),
                    SizedBox(height: 16),
                    _HowStep(emoji: '👁️', title: 'Layer 2 - Visual Artifacts', desc: 'Analyzes pixel-level artifacts: facial landmark anomalies, temporal inconsistencies, compression fingerprints.'),
                    SizedBox(height: 16),
                    _HowStep(emoji: '🧠', title: 'Layer 3 - Deep Learning', desc: 'ML model trained on thousands of AI vs real video pairs identifies generation patterns.'),
                    SizedBox(height: 16),
                    _HowStep(emoji: '🔗', title: 'Layer 4 - Contextual', desc: 'Cross-references visual signals with contextual expectations to detect subtle deepfakes.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
        content: const SingleChildScrollView(
          child: Text(
            '• Screen captures are processed locally on your device\n'
            '• Only analysis results are sent to our servers\n'
            '• We do not store your video data\n'
            '• All analysis is anonymous\n'
            '• You can delete your scan history anytime',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1))),
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
        style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5),
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

  const _SettingsTile({required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap});

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
              width: 40, height: 40,
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
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
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

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFF6366F1) : Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.w600 : FontWeight.normal))),
            if (selected) const Icon(Icons.check, color: Color(0xFF6366F1), size: 18),
          ],
        ),
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  final String emoji, title, desc;
  const _HowStep({required this.emoji, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
