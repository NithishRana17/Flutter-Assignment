import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final profile = authState.profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    if (profile.fullName != null && profile.fullName!.isNotEmpty)
                      Text(
                        profile.fullName!,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    
                    // Email
                    const SizedBox(height: 4),
                    Text(
                      profile.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (profile.pilotType != null)
                          _Badge(
                            label: profile.pilotType!,
                            color: AppColors.primary,
                          ),
                        if (profile.pilotType != null &&
                            profile.licenseType != null)
                          const SizedBox(width: 8),
                        if (profile.licenseType != null)
                          _Badge(
                            label: profile.licenseType!,
                            color: AppColors.accent,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 24),

            // Settings Section
            _SettingsSection(
              title: 'Account',
              items: [
                _SettingsItem(
                  icon: Icons.person_outline,
                  title: 'Edit Profile',
                  onTap: () => _showEditProfileDialog(context, ref, profile),
                ),
                _SettingsItem(
                  icon: Icons.sync,
                  title: 'Sync Status',
                  subtitle: 'Auto-sync enabled',
                  onTap: () {
                    _showSyncStatusDialog(context, ref);
                  },
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 16),

            _SettingsSection(
              title: 'App',
              items: [
                _SettingsItem(
                  icon: Icons.info_outline,
                  title: 'About',
                  subtitle: 'Version 1.0.0',
                  onTap: () {
                    _showAboutDialog(context);
                  },
                ),
              ],
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 24),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) async {
    // First check if device is online
    final syncService = ref.read(syncServiceProvider);
    final isOnline = await syncService.isOnline;
    
    if (!isOnline && context.mounted) {
      // Show offline warning
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(Icons.cloud_off, color: AppColors.warning),
              const SizedBox(width: 8),
              const Text('You\'re Offline'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You cannot sign out while offline.'),
              SizedBox(height: 12),
              Text(
                'Please connect to the internet to sign out safely and sync your data.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Check if user can sign out (no unsynced data)
    final check = await ref.read(authNotifierProvider.notifier).canSignOut();
    
    if (!check.canSignOut && context.mounted) {
      // Show warning dialog for unsynced data
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              const Text('Cannot Sign Out'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(check.reason ?? 'You have unsynced data.'),
              const SizedBox(height: 16),
              const Text(
                'Please sync your data before signing out to avoid data loss.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final userId = ref.read(authNotifierProvider).profile?.id ?? '';
                final result = await ref
                    .read(logbookNotifierProvider(userId).notifier)
                    .syncEntries();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      backgroundColor: result.success ? AppColors.success : AppColors.warning,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Normal sign out confirmation
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
    }
  }

  void _showSyncStatusDialog(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.profile?.id ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.sync, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Sync Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Auto-sync is enabled. Flights are synced automatically when you have an internet connection.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final logbookState = ref.watch(logbookNotifierProvider(userId));
                final draftCount = logbookState.entries
                    .where((e) => e.status == 'draft')
                    .length;
                final queuedCount = logbookState.entries
                    .where((e) => e.status == 'queued')
                    .length;
                final syncedCount = logbookState.entries
                    .where((e) => e.status == 'synced')
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SyncStatusRow(
                      icon: Icons.cloud_off,
                      label: 'Pending',
                      count: draftCount,
                      color: AppColors.statusDraft,
                    ),
                    const SizedBox(height: 12),
                    _SyncStatusRow(
                      icon: Icons.cloud_upload,
                      label: 'Syncing',
                      count: queuedCount,
                      color: AppColors.statusQueued,
                    ),
                    const SizedBox(height: 12),
                    _SyncStatusRow(
                      icon: Icons.cloud_done,
                      label: 'Synced',
                      count: syncedCount,
                      color: AppColors.statusSynced,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ref
                  .read(logbookNotifierProvider(userId).notifier)
                  .syncEntries();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor:
                        result.success ? AppColors.success : AppColors.warning,
                  ),
                );
              }
            },
            child: const Text('Sync Now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.flight_takeoff, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Logbook Lite'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text(
              'A pilot logbook app with offline-first architecture and cloud sync.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 16),
            Text(
              'Built with Flutter & Supabase',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, dynamic profile) {
    final nameController = TextEditingController(text: profile.fullName ?? '');
    String? selectedPilotType = profile.pilotType;
    String? selectedLicenseType = profile.licenseType;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(Icons.edit, color: AppColors.primary),
              const SizedBox(width: 12),
              const Text('Edit Profile'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full Name
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Pilot Type
                Text(
                  'Pilot Type',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['Student', 'Instructor'].map((type) {
                    final isSelected = selectedPilotType == type;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: type == 'Student' ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => selectedPilotType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                
                // License Type
                Text(
                  'License Type',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['FAA', 'EASA'].map((type) {
                    final isSelected = selectedLicenseType == type;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: type == 'FAA' ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => selectedLicenseType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accent.withOpacity(0.1)
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.accent : AppColors.surfaceLight,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: isSelected ? AppColors.accent : AppColors.textSecondary,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                
                // Update profile
                final success = await ref.read(authNotifierProvider.notifier).updateProfile(
                  fullName: nameController.text.trim(),
                  pilotType: selectedPilotType,
                  licenseType: selectedLicenseType,
                );
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Profile updated!' : 'Failed to update profile'),
                      backgroundColor: success ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: items
                .map((item) => Column(
                      children: [
                        item,
                        if (item != items.last)
                          const Divider(height: 1, indent: 56),
                      ],
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class _SyncStatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SyncStatusRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
