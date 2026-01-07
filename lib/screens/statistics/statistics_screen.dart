import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/statistics_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/subject.dart';
import '../../models/statistics.dart';
import '../../utils/date_utils.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final userId = context.read<AuthProvider>().userId;
    if (userId != null) {
      context.read<StatisticsProvider>().loadStatistics(userId);
    }
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('통계'),
        actions: [
          Consumer<StatisticsProvider>(
            builder: (context, provider, _) {
              return SegmentedButton<StatsPeriod>(
                segments: const [
                  ButtonSegment(value: StatsPeriod.week, label: Text('주간')),
                  ButtonSegment(value: StatsPeriod.month, label: Text('월간')),
                  ButtonSegment(value: StatsPeriod.year, label: Text('연간')),
                ],
                selected: {provider.period},
                onSelectionChanged: (set) {
                  provider.changePeriod(set.first);
                  provider.loadStatistics(userId);
                },
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Consumer<StatisticsProvider>(
        builder: (context, provider, _) {
          final stats = provider.currentStats;
          if (stats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodHeader(provider, userId),
                const SizedBox(height: 16),
                _buildSummaryCard(stats),
                const SizedBox(height: 24),
                Text('일별 학습 시간', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildDailyBarChart(stats),
                const SizedBox(height: 24),
                Text('과목별 학습 분포', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildSubjectPieChart(stats, userId),
                const SizedBox(height: 24),
                Text('완료율 추이', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildCompletionLineChart(stats),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodHeader(StatisticsProvider provider, String userId) {
    final label = provider.period == StatsPeriod.week
        ? '이번 주'
        : provider.period == StatsPeriod.month
            ? '이번 달'
            : '올해';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final date = _shiftDate(provider.selectedDate, provider.period, -1);
                provider.changeDate(date);
                provider.loadStatistics(userId);
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final date = _shiftDate(provider.selectedDate, provider.period, 1);
                provider.changeDate(date);
                provider.loadStatistics(userId);
              },
            ),
          ],
        ),
      ),
    );
  }

  DateTime _shiftDate(DateTime date, StatsPeriod period, int delta) {
    switch (period) {
      case StatsPeriod.week:
        return date.add(Duration(days: 7 * delta));
      case StatsPeriod.month:
        return DateTime(date.year, date.month + delta, date.day);
      case StatsPeriod.year:
        return DateTime(date.year + delta, date.month, date.day);
    }
  }

  Widget _buildSummaryCard(StudyStatistics stats) {
    final completionRate = stats.completionRate.toStringAsFixed(0);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('요약', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryItem('총 학습', '${stats.totalMinutes}분'),
                _summaryItem('완료율', '$completionRate%'),
                _summaryItem('평균', '${stats.averageDailyMinutes.toStringAsFixed(1)}분'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: stats.completionRate / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String title, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildDailyBarChart(stats) {
    final maxMinutes = stats.dailyStats.fold<int>(0, (max, item) => item.minutes > max ? item.minutes : max);
    if (stats.dailyStats.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text('데이터가 없습니다')));
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxMinutes > 0 ? maxMinutes.toDouble() : 10,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= stats.dailyStats.length) {
                    return const SizedBox.shrink();
                  }
                  final day = stats.dailyStats[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(DateHelper.getWeekdayName(day)),
                  );
                },
              ),
            ),
          ),
          barGroups: stats.dailyStats.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.minutes.toDouble(),
                  color: Colors.blue,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSubjectPieChart(stats, String userId) {
    if (stats.subjectMinutes.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: Text('과목 데이터가 없습니다')));
    }

    return StreamBuilder<List<Subject>>(
      stream: FirestoreService().getAllSubjects(userId),
      builder: (context, snapshot) {
        final subjects = snapshot.data ?? [];
        final total = stats.subjectMinutes.values.fold<int>(0, (sum, v) => sum + v);
        final colors = <String, Color>{
          for (final subject in subjects)
            subject.id: Color(int.parse(subject.color.replaceFirst('#', '0xFF'))),
        };

        return SizedBox(
          height: 240,
          child: PieChart(
            PieChartData(
              sections: stats.subjectMinutes.entries.map((entry) {
                final value = entry.value;
                final percentage = total > 0 ? (value / total * 100).toStringAsFixed(0) : '0';
                final color = colors[entry.key] ?? Colors.blueGrey;

                return PieChartSectionData(
                  value: value.toDouble(),
                  title: '$percentage%',
                  color: color,
                  radius: 90,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 32,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletionLineChart(stats) {
    if (stats.dailyStats.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text('데이터가 없습니다')));
    }

    final spots = stats.dailyStats.asMap().entries.map((entry) {
      final completed = entry.value.completedPlans;
      final total = entry.value.totalPlans;
      final rate = total > 0 ? completed / total * 100 : 0.0;
      return FlSpot(entry.key.toDouble(), rate);
    }).toList();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= stats.dailyStats.length) {
                    return const SizedBox.shrink();
                  }
                  final day = stats.dailyStats[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(DateHelper.getWeekdayName(day)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.green.withAlpha(40)),
            ),
          ],
        ),
      ),
    );
  }
}
