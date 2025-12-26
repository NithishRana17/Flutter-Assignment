import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_utils.dart';
import '../../../providers/providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  final String userId;

  const AnalyticsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(logbookNotifierProvider(userId));
    final analytics = ref.watch(analyticsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsProvider(userId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Hours Hero Card
              _TotalHoursCard(
                totalHours: analytics.totalHours,
                totalFlights: analytics.totalFlights,
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 24),

              // Recent Activity
              _SectionTitle(title: 'Recent Activity'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Last 7 Days',
                      value: analytics.hoursLast7Days.toStringAsFixed(1),
                      unit: 'hrs',
                      icon: Icons.calendar_today,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Last 30 Days',
                      value: analytics.hoursLast30Days.toStringAsFixed(1),
                      unit: 'hrs',
                      icon: Icons.calendar_month,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 24),

              // Dual vs Solo Pie Chart
              _SectionTitle(title: 'Dual vs Solo Distribution'),
              const SizedBox(height: 12),
              _DualSoloChart(
                dualHours: analytics.dualHours,
                soloHours: analytics.soloHours,
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 24),

              // Time Breakdown
              _SectionTitle(title: 'Time Breakdown'),
              const SizedBox(height: 12),
              _TimeBreakdownCard(
                totalHours: analytics.totalHours,
                picHours: analytics.picHours,
                soloHours: analytics.soloHours,
                sicHours: analytics.sicHours,
                dualHours: analytics.dualHours,
                nightHours: analytics.nightHours,
                xcHours: analytics.xcHours,
                instrumentHours: analytics.instrumentHours,
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 24),

              // Monthly Bar Chart
              _SectionTitle(title: 'Monthly Hours'),
              const SizedBox(height: 12),
              _MonthlyHoursChart(
                monthlyHours: analytics.monthlyHours,
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 24),

              // Flight Type Breakdown
              if (analytics.flightTypeBreakdown.isNotEmpty) ...[
                _SectionTitle(title: 'Flight Types'),
                const SizedBox(height: 12),
                _FlightTypeBreakdown(
                  breakdown: analytics.flightTypeBreakdown,
                ).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 24),
              ],

              // Quick Stats Grid
              _SectionTitle(title: 'Quick Stats'),
              const SizedBox(height: 12),
              _QuickStatsGrid(
                totalFlights: analytics.totalFlights,
                avgHoursPerFlight: analytics.totalFlights > 0
                    ? analytics.totalHours / analytics.totalFlights
                    : 0,
                nightHours: analytics.nightHours,
                picHours: analytics.picHours,
              ).animate().fadeIn(delay: 700.ms),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _TotalHoursCard extends StatelessWidget {
  final double totalHours;
  final int totalFlights;

  const _TotalHoursCard({required this.totalHours, required this.totalFlights});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flight_takeoff, color: Colors.white70, size: 28),
              const SizedBox(width: 8),
              Text('Total Flight Hours',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totalHours.toStringAsFixed(1),
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.white, height: 1),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 8),
                child: Text('hours', style: TextStyle(fontSize: 20, color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$totalFlights flights logged',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text(unit, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DualSoloChart extends StatelessWidget {
  final double dualHours;
  final double soloHours;

  const _DualSoloChart({required this.dualHours, required this.soloHours});

  @override
  Widget build(BuildContext context) {
    final total = dualHours + soloHours;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.pie_chart_outline, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text('No dual or solo flights yet', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    final dualPercent = double.parse((dualHours / total * 100).toStringAsFixed(1));
    final soloPercent = double.parse((100.0 - dualPercent).toStringAsFixed(1));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: [
                    if (dualHours > 0)
                      PieChartSectionData(
                        value: dualHours,
                        color: AppColors.primary,
                        title: '${dualPercent.toStringAsFixed(1)}%',
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        radius: 50,
                      ),
                    if (soloHours > 0)
                      PieChartSectionData(
                        value: soloHours,
                        color: AppColors.accent,
                        title: '${soloPercent.toStringAsFixed(1)}%',
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        radius: 50,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _LegendItem(color: AppColors.primary, label: 'Dual', value: '${dualHours.toStringAsFixed(1)}h', percent: '${dualPercent.toStringAsFixed(1)}%'),
                _LegendItem(color: AppColors.accent, label: 'Solo', value: '${soloHours.toStringAsFixed(1)}h', percent: '${soloPercent.toStringAsFixed(1)}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final String percent;

  const _LegendItem({required this.color, required this.label, required this.value, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            Text('$value ($percent)', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class _TimeBreakdownCard extends StatelessWidget {
  final double totalHours;
  final double picHours;
  final double soloHours;
  final double sicHours;
  final double dualHours;
  final double nightHours;
  final double xcHours;
  final double instrumentHours;

  const _TimeBreakdownCard({
    required this.totalHours,
    required this.picHours,
    required this.soloHours,
    required this.sicHours,
    required this.dualHours,
    required this.nightHours,
    required this.xcHours,
    required this.instrumentHours,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _TimeBreakdownRow(label: 'PIC', hours: picHours, total: totalHours, color: AppColors.accent),
            const SizedBox(height: 12),
            _TimeBreakdownRow(label: 'Solo', hours: soloHours, total: totalHours, color: Colors.purple),
            const SizedBox(height: 12),
            _TimeBreakdownRow(label: 'SIC', hours: sicHours, total: totalHours, color: Colors.orange),
            const SizedBox(height: 12),
            _TimeBreakdownRow(label: 'Dual', hours: dualHours, total: totalHours, color: AppColors.primary),
            const SizedBox(height: 12),
            _TimeBreakdownRow(label: 'Night', hours: nightHours, total: totalHours, color: Colors.indigo),
            const SizedBox(height: 12),
            _TimeBreakdownRow(label: 'Cross-Country', hours: xcHours, total: totalHours, color: AppColors.warning),
            const SizedBox(height: 12),
            _TimeBreakdownRow(label: 'Instrument', hours: instrumentHours, total: totalHours, color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }
}

class _TimeBreakdownRow extends StatelessWidget {
  final String label;
  final double hours;
  final double total;
  final Color color;

  const _TimeBreakdownRow({required this.label, required this.hours, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? hours / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(TimeUtils.decimalToDuration(hours), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _MonthlyHoursChart extends StatelessWidget {
  final Map<String, double> monthlyHours;

  const _MonthlyHoursChart({required this.monthlyHours});

  @override
  Widget build(BuildContext context) {
    if (monthlyHours.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.bar_chart, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text('No flight data yet', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    final entries = monthlyHours.entries.toList();
    final maxValue = monthlyHours.values.fold(0.0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxValue > 0 ? maxValue * 1.2 : 10,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final month = entries[group.x.toInt()].key;
                    return BarTooltipItem('$month\n${rod.toY.toStringAsFixed(1)}h',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= entries.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(entries[index].key.split(' ')[0],
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) =>
                        Text('${value.toInt()}h', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(color: AppColors.surfaceLight.withValues(alpha: 0.5), strokeWidth: 1),
              ),
              barGroups: List.generate(entries.length, (index) {
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: entries[index].value,
                      color: AppColors.primary,
                      width: 20,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlightTypeBreakdown extends StatelessWidget {
  final Map<String, int> breakdown;

  const _FlightTypeBreakdown({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final total = breakdown.values.fold(0, (a, b) => a + b);
    final colors = [AppColors.primary, AppColors.accent, Colors.blue, Colors.orange];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: breakdown.entries.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final type = entry.value.key;
            final count = entry.value.value;
            final percent = total > 0 ? count / total : 0.0;
            final color = colors[index % colors.length];
            
            return Padding(
              padding: EdgeInsets.only(bottom: index < breakdown.length - 1 ? 12 : 0),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type, style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: color.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(color),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(percent * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _QuickStatsGrid extends StatelessWidget {
  final int totalFlights;
  final double avgHoursPerFlight;
  final double nightHours;
  final double picHours;

  const _QuickStatsGrid({
    required this.totalFlights,
    required this.avgHoursPerFlight,
    required this.nightHours,
    required this.picHours,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _QuickStatTile(icon: Icons.flight, label: 'Total Flights', value: totalFlights.toString(), color: AppColors.primary),
        _QuickStatTile(icon: Icons.timer_outlined, label: 'Avg Duration', value: '${avgHoursPerFlight.toStringAsFixed(1)}h', color: AppColors.warning),
        _QuickStatTile(icon: Icons.nightlight_round, label: 'Night Hours', value: '${nightHours.toStringAsFixed(1)}h', color: Colors.indigo),
        _QuickStatTile(icon: Icons.person, label: 'PIC Hours', value: '${picHours.toStringAsFixed(1)}h', color: AppColors.accent),
      ],
    );
  }
}

class _QuickStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
