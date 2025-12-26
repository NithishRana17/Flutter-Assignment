import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/utils/time_utils.dart';
import '../../../data/models/logbook_entry.dart';
import '../../../providers/providers.dart';

class LogbookListScreen extends ConsumerStatefulWidget {
  final String userId;

  const LogbookListScreen({super.key, required this.userId});

  @override
  ConsumerState<LogbookListScreen> createState() => _LogbookListScreenState();
}

class _LogbookListScreenState extends ConsumerState<LogbookListScreen> {
  final _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncEntries() async {
    final result = await ref
        .read(logbookNotifierProvider(widget.userId).notifier)
        .syncEntries();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _FilterBottomSheet(
        userId: widget.userId,
        onApply: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logbookState = ref.watch(logbookNotifierProvider(widget.userId));
    final entries = logbookState.filteredEntries;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Logbook'),
            const SizedBox(width: 8),
            _LiveBadge(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncEntries,
            tooltip: 'Sync',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by aircraft or route...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(logbookNotifierProvider(widget.userId).notifier)
                                    .setSearchQuery(null);
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      ref
                          .read(logbookNotifierProvider(widget.userId).notifier)
                          .setSearchQuery(value.isEmpty ? null : value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: _hasActiveFilters(logbookState)
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasActiveFilters(logbookState)
                          ? AppColors.primary
                          : AppColors.surfaceLight,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: _hasActiveFilters(logbookState)
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    onPressed: _showFilterBottomSheet,
                  ),
                ),
              ],
            ),
          ),

          // Active Filters Chips
          if (_hasActiveFilters(logbookState))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (logbookState.filterFlightType != null)
                        _FilterChip(
                          label: logbookState.filterFlightType!,
                          onRemove: () {
                            ref
                                .read(logbookNotifierProvider(widget.userId).notifier)
                                .setFlightTypeFilter(null);
                          },
                        ),
                      if (logbookState.filterStartDate != null)
                        _FilterChip(
                          label: '${DateTimeUtils.formatDate(logbookState.filterStartDate!)} - ${DateTimeUtils.formatDate(logbookState.filterEndDate!)}',
                          onRemove: () {
                            ref
                                .read(logbookNotifierProvider(widget.userId).notifier)
                                .setDateRangeFilter(null, null);
                          },
                        ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ref
                            .read(logbookNotifierProvider(widget.userId).notifier)
                            .clearFilters();
                      },
                      child: const Text('Clear All'),
                    ),
                  ),
                ],
              ),
            ),

          // Entries List
          Expanded(
            child: logbookState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () async {
                          await ref
                              .read(logbookNotifierProvider(widget.userId).notifier)
                              .loadEntries();
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: _EmptyState(
                                hasFilters: _hasActiveFilters(logbookState),
                                onRefresh: () async {
                                  await ref
                                      .read(logbookNotifierProvider(widget.userId).notifier)
                                      .loadEntries();
                                },
                              ),
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await ref
                              .read(logbookNotifierProvider(widget.userId).notifier)
                              .loadEntries();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 100,
                          ),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            return _FlightCard(
                              entry: entries[index],
                              index: index,
                              onTap: () => context.push('/flight/${entries[index].id}'),
                              onRetrySync: () async {
                                await ref
                                    .read(logbookNotifierProvider(widget.userId).notifier)
                                    .retrySyncEntry(entries[index]);
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters(LogbookState state) {
    return state.filterFlightType != null ||
        state.filterStartDate != null ||
        state.filterEndDate != null;
  }
}

class _FlightCard extends StatelessWidget {
  final LogbookEntry entry;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRetrySync;

  const _FlightCard({
    required this.entry,
    required this.index,
    required this.onTap,
    required this.onRetrySync,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Date
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateTimeUtils.formatDate(entry.date),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Sync Status
                  _SyncStatusBadge(
                    status: entry.status,
                    onRetry: entry.isDraft ? onRetrySync : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Route
              Row(
                children: [
                  _IcaoBox(code: entry.depIcao),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  _IcaoBox(code: entry.arrIcao),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        entry.aircraftReg,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        TimeUtils.decimalToDuration(entry.totalHours),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Flight Types
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: entry.flightType.map((type) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getFlightTypeColor(type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: _getFlightTypeColor(type),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.1, end: 0);
  }

  Color _getFlightTypeColor(String type) {
    switch (type) {
      case 'Solo':
        return AppColors.accent;
      case 'Dual':
        return AppColors.primary;
      case 'Cross-country':
        return AppColors.warning;
      case 'Instrument':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _IcaoBox extends StatelessWidget {
  final String code;

  const _IcaoBox({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SyncStatusBadge extends StatelessWidget {
  final String status;
  final VoidCallback? onRetry;

  const _SyncStatusBadge({required this.status, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final icon = _getStatusIcon();
    final label = _getStatusLabel();

    return GestureDetector(
      onTap: onRetry,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case 'synced':
        return AppColors.statusSynced;
      case 'queued':
        return AppColors.statusQueued;
      default:
        return AppColors.statusDraft;
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case 'synced':
        return Icons.cloud_done;
      case 'queued':
        return Icons.cloud_upload;
      default:
        return Icons.cloud_off;
    }
  }

  String _getStatusLabel() {
    switch (status) {
      case 'synced':
        return 'Synced';
      case 'queued':
        return 'Syncing...';
      default:
        return 'Draft';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback? onRefresh;

  const _EmptyState({required this.hasFilters, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.filter_alt_off : Icons.flight_takeoff,
            size: 80,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No matching flights' : 'No flights yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try adjusting your filters'
                : 'Tap the + button to log your first flight',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
            textAlign: TextAlign.center,
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterBottomSheet extends ConsumerStatefulWidget {
  final String userId;
  final VoidCallback onApply;

  const _FilterBottomSheet({required this.userId, required this.onApply});

  @override
  ConsumerState<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  String? _selectedFlightType;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    final state = ref.read(logbookNotifierProvider(widget.userId));
    _selectedFlightType = state.filterFlightType;
    if (state.filterStartDate != null && state.filterEndDate != null) {
      _dateRange = DateTimeRange(
        start: state.filterStartDate!,
        end: state.filterEndDate!,
      );
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _applyFilters() {
    final notifier = ref.read(logbookNotifierProvider(widget.userId).notifier);
    notifier.setFlightTypeFilter(_selectedFlightType);
    notifier.setDateRangeFilter(_dateRange?.start, _dateRange?.end);
    widget.onApply();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedFlightType = null;
                    _dateRange = null;
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Flight Type
          Text(
            'Flight Type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.flightTypes.map((type) {
              final isSelected = _selectedFlightType == type;
              return FilterChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFlightType = selected ? type : null;
                  });
                },
                selectedColor: AppColors.primary.withOpacity(0.2),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Date Range
          Text(
            'Date Range',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.calendar_today),
            label: Text(
              _dateRange != null
                  ? '${DateTimeUtils.formatDate(_dateRange!.start)} - ${DateTimeUtils.formatDate(_dateRange!.end)}'
                  : 'Select Date Range',
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _applyFilters,
              child: const Text('Apply Filters'),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Live badge widget for AppBar
class _LiveBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtimeStatus = ref.watch(realtimeStatusProvider);
    
    if (realtimeStatus != RealtimeStatus.connected) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Live',
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
