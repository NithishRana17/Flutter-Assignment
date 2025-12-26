import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/time_utils.dart';
import '../../../data/models/logbook_entry.dart';
import '../../../providers/providers.dart';

class LogbookDetailScreen extends ConsumerWidget {
  final String entryId;

  const LogbookDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.profile?.id ?? '';
    final logbookState = ref.watch(logbookNotifierProvider(userId));

    final entry = logbookState.entries.firstWhere(
      (e) => e.id == entryId,
      orElse: () => LogbookEntry(
        userId: '',
        date: DateTime.now(),
        depIcao: '',
        arrIcao: '',
        aircraftReg: '',
        flightType: [],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        totalHours: 0,
      ),
    );

    if (entry.userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flight Details')),
        body: const Center(child: Text('Flight not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Details'),
        actions: [
          _SyncStatusIndicator(status: entry.status),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Flight',
            onPressed: () => context.push('/edit-flight/$entryId'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Delete Flight',
            onPressed: () => _confirmDelete(context, ref, entry, userId),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route Card
            _RouteCard(entry: entry).animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1, end: 0),

            const SizedBox(height: 16),

            // Flight Info Card
            _InfoCard(
              title: 'Flight Information',
              children: [
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Date',
                  value: DateTimeUtils.formatDate(entry.date),
                ),
                _InfoRow(
                  icon: Icons.flight,
                  label: 'Aircraft',
                  value: entry.aircraftReg.toUpperCase(),
                ),
                _InfoRow(
                  icon: Icons.schedule,
                  label: 'Block Time',
                  value: '${DateTimeUtils.formatTime(entry.startTime)} - ${DateTimeUtils.formatTime(entry.endTime)}',
                ),
                _InfoRow(
                  icon: Icons.timer,
                  label: 'Total Time',
                  value: TimeUtils.decimalToDuration(entry.totalHours),
                  valueColor: AppColors.primary,
                ),
              ],
            ).animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.1, end: 0),

            const SizedBox(height: 16),

            // Flight Types
            _InfoCard(
              title: 'Flight Type',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entry.flightType.map((type) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        type,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ).animate()
              .fadeIn(delay: 300.ms)
              .slideY(begin: 0.1, end: 0),

            const SizedBox(height: 16),

            // Time Breakdown
            _InfoCard(
              title: 'Time Breakdown',
              children: [
                _HoursRow(
                  label: 'PIC',
                  value: entry.picHours,
                  color: AppColors.accent,
                ),
                _HoursRow(
                  label: 'Solo',
                  value: entry.soloHours,
                  color: Colors.purple,
                ),
                // Hide SIC and Dual when Solo flight
                if (!entry.flightType.contains('Solo')) ...[
                  _HoursRow(
                    label: 'SIC',
                    value: entry.sicHours,
                    color: Colors.orange,
                  ),
                  _HoursRow(
                    label: 'Dual',
                    value: entry.dualHours,
                    color: AppColors.primary,
                  ),
                ],
                _HoursRow(
                  label: 'Night',
                  value: entry.nightHours,
                  color: Colors.indigo,
                ),
                _HoursRow(
                  label: 'Cross-Country',
                  value: entry.xcHours,
                  color: AppColors.warning,
                ),
                _HoursRow(
                  label: 'Instrument',
                  value: entry.instrumentHours,
                  color: Colors.deepPurple,
                ),
              ],
            ).animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.1, end: 0),

            if (entry.remarks != null && entry.remarks!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Remarks',
                children: [
                  Text(
                    entry.remarks!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ).animate()
                .fadeIn(delay: 500.ms)
                .slideY(begin: 0.1, end: 0),
            ],

            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Tags',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor: AppColors.surfaceLight,
                      );
                    }).toList(),
                  ),
                ],
              ).animate()
                .fadeIn(delay: 600.ms)
                .slideY(begin: 0.1, end: 0),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/captain-mave?entryId=$entryId'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.flight, color: Colors.white),
        label: const Text(
          'Ask Captain MAVE',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ).animate()
        .fadeIn(delay: 700.ms)
        .slideY(begin: 0.5, end: 0),
    );
  }
  
  void _confirmDelete(BuildContext context, WidgetRef ref, LogbookEntry entry, String userId) {
    final deleteType = entry.isSynced ? 'This will mark the flight as deleted and sync the change.' : 'This will permanently delete this draft.';
    final parentContext = context; // Store parent context for navigation
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('Delete Flight'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this flight?'),
            const SizedBox(height: 8),
            Text(
              '${entry.route} on ${DateTimeUtils.formatDate(entry.date)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              deleteType,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
              
              final success = await ref
                  .read(logbookNotifierProvider(userId).notifier)
                  .deleteEntry(entry.id);
              
              if (parentContext.mounted) {
                if (success) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Flight deleted successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  parentContext.pop(); // Navigate back using parent context
                } else {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete flight'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final LogbookEntry entry;

  const _RouteCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    entry.depIcao.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Departure',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Icon(
                    Icons.flight_takeoff,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${entry.totalHours.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    entry.arrIcao.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Arrival',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _HoursRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            TimeUtils.decimalToDuration(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusIndicator extends StatelessWidget {
  final String status;

  const _SyncStatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'synced':
        color = AppColors.statusSynced;
        icon = Icons.cloud_done;
        label = 'Synced';
        break;
      case 'queued':
        color = AppColors.statusQueued;
        icon = Icons.cloud_upload;
        label = 'Syncing';
        break;
      default:
        color = AppColors.statusDraft;
        icon = Icons.cloud_off;
        label = 'Draft';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
