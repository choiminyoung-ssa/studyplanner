import 'dart:math';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/daily_plan.dart';
import '../../models/statistics.dart';
import '../../models/study_goal.dart';
import '../../models/subject.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/statistics_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/date_utils.dart';
import '../daily/daily_form_screen.dart';
import '../goals/goal_settings_screen.dart';

enum ProgressBasis { subtask, time, page }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _initialized = false;
  ProgressBasis _basis = ProgressBasis.subtask;
  int? _selectedDayIndex;
  String? _selectedSubjectId;
  bool _showAdvanced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final userId = context.read<AuthProvider>().userId;
    if (userId != null) {
      context.read<StatisticsProvider>().loadStatistics(userId);
      _refreshGoals(userId);
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
      backgroundColor: _StatsColors.canvas,
      body: SafeArea(
        child: Consumer<StatisticsProvider>(
          builder: (context, provider, _) {
            final slivers = <Widget>[
              SliverToBoxAdapter(child: _buildHeroHeader(provider)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  height: 128,
                  child: _buildFilterBar(provider, userId),
                ),
              ),
            ];

            if (provider.isLoading) {
              slivers.add(
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
              return CustomScrollView(slivers: slivers);
            }

            if (provider.errorMessage != null) {
              slivers.add(
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildStatsError(provider, userId),
                ),
              );
              return CustomScrollView(slivers: slivers);
            }

            final stats = provider.currentStats;
            if (stats == null) {
              slivers.add(
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('데이터가 없습니다')),
                ),
              );
              return CustomScrollView(slivers: slivers);
            }

            slivers.add(
              SliverToBoxAdapter(
                child: _buildStatsContent(stats, provider, userId),
              ),
            );

            return CustomScrollView(slivers: slivers);
          },
        ),
      ),
    );
  }

  Widget _buildHeroHeader(StatisticsProvider provider) {
    final rangeLabel = _rangeLabel(provider);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_StatsColors.headerStart, _StatsColors.headerEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _StatsColors.shadow.withAlpha(30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '통계',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white.withAlpha(240),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '공부 흐름을 이해하고 다음 행동을 결정하세요.',
            style: TextStyle(
              color: Colors.white.withAlpha(220),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(50)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  rangeLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(StatisticsProvider provider, String userId) {
    return Container(
      color: _StatsColors.canvas,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 720;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildPeriodPill(
                label: '오늘',
                isSelected: provider.period == StatsPeriod.day,
                onTap: () => _changePeriod(provider, userId, StatsPeriod.day),
              ),
              _buildPeriodPill(
                label: '이번 주',
                isSelected: provider.period == StatsPeriod.week,
                onTap: () => _changePeriod(provider, userId, StatsPeriod.week),
              ),
              _buildPeriodPill(
                label: '이번 달',
                isSelected: provider.period == StatsPeriod.month,
                onTap: () => _changePeriod(provider, userId, StatsPeriod.month),
              ),
              _buildPeriodPill(
                label: '사용자 지정',
                isSelected: provider.period == StatsPeriod.custom,
                onTap: () => _selectCustomRange(provider, userId),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _StatsColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18),
                      onPressed: provider.period == StatsPeriod.custom
                          ? null
                          : () => _shiftRange(provider, userId, -1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                    ),
                    Text(
                      _rangeLabel(provider),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      onPressed: provider.period == StatsPeriod.custom
                          ? null
                          : () => _shiftRange(provider, userId, 1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                    ),
                  ],
                ),
              ),
              if (isWide) const SizedBox(width: 6),
              StreamBuilder<List<Subject>>(
                stream: FirestoreService().getSubjects(userId),
                builder: (context, snapshot) {
                  final subjects = snapshot.data ?? [];
                  return _buildSubjectFilter(provider, subjects, userId);
                },
              ),
              _buildTogglePill(
                label: '완료만',
                isActive: provider.completedOnly,
                onTap: () {
                  provider.setCompletedOnly(!provider.completedOnly);
                  provider.loadStatistics(userId);
                },
              ),
              IconButton(
                tooltip: '필터 초기화',
                onPressed: () {
                  provider.resetFilters();
                  provider.loadStatistics(userId);
                  _refreshGoals(userId);
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriodPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return _PillButton(
      label: label,
      isSelected: isSelected,
      onTap: onTap,
      icon: Icons.calendar_today,
    );
  }

  Widget _buildTogglePill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return _PillButton(
      label: label,
      isSelected: isActive,
      onTap: onTap,
      icon: isActive ? Icons.check_circle : Icons.circle_outlined,
    );
  }

  Widget _buildSubjectFilter(StatisticsProvider provider, List<Subject> subjects, String userId) {
    final selected = subjects.any((subject) => subject.id == provider.subjectId) ? provider.subjectId : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _StatsColors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selected,
          hint: const Text('과목 전체'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('과목 전체'),
            ),
            ...subjects.map((subject) {
              return DropdownMenuItem<String?>(
                value: subject.id,
                child: Row(
                  children: [
                    Icon(
                      SubjectIconHelper.getIcon(subject.icon),
                      size: 16,
                      color: _parseColor(subject.color),
                    ),
                    const SizedBox(width: 6),
                    Text(subject.name),
                  ],
                ),
              );
            }),
          ],
          onChanged: (value) {
            provider.setSubjectFilter(value);
            provider.loadStatistics(userId);
          },
        ),
      ),
    );
  }

  Widget _buildStatsContent(
    StudyStatistics stats,
    StatisticsProvider provider,
    String userId,
  ) {
    return StreamBuilder<List<Subject>>(
      stream: FirestoreService().getSubjects(userId),
      builder: (context, snapshot) {
        final subjects = snapshot.data ?? [];
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1000;
            final maxWidth = isWide ? 1200.0 : 760.0;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProgressBasisSelector(),
                      const SizedBox(height: 16),
                      _buildKpiGrid(stats, provider),
                      const SizedBox(height: 16),
                      _buildGoalProgressCard(provider),
                      const SizedBox(height: 20),
                      isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildMainChart(stats, provider, subjects),
                                      const SizedBox(height: 16),
                                      _buildDayBreakdownCard(stats, subjects),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSubjectChart(stats, subjects),
                                      const SizedBox(height: 16),
                                      _buildSubjectDetailCard(stats, subjects),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMainChart(stats, provider, subjects),
                                const SizedBox(height: 16),
                                _buildDayBreakdownCard(stats, subjects),
                                const SizedBox(height: 16),
                                _buildSubjectChart(stats, subjects),
                                const SizedBox(height: 16),
                                _buildSubjectDetailCard(stats, subjects),
                              ],
                            ),
                      const SizedBox(height: 20),
                      _buildInsightSection(stats, provider, subjects, userId),
                      const SizedBox(height: 16),
                      _buildAdvancedSection(stats, provider, subjects),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProgressBasisSelector() {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 520;
          final segmentedButton = SegmentedButton<ProgressBasis>(
            segments: const [
              ButtonSegment(value: ProgressBasis.subtask, label: Text('세부 목표')),
              ButtonSegment(value: ProgressBasis.time, label: Text('시간')),
              ButtonSegment(value: ProgressBasis.page, label: Text('페이지')),
            ],
            selected: {_basis},
            onSelectionChanged: (set) {
              setState(() => _basis = set.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _StatsColors.primary
                    : Colors.white,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : _StatsColors.primary,
              ),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              side: WidgetStateProperty.all(
                const BorderSide(color: _StatsColors.line),
              ),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.tune, size: 18, color: _StatsColors.primary),
                  SizedBox(width: 8),
                  Text(
                    '진행률 기준',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: isCompact
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: segmentedButton,
                      )
                    : segmentedButton,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiGrid(StudyStatistics stats, StatisticsProvider provider) {
    final basisLabel = _basisLabel(_basis);
    final basisTotal = _basisTotal(stats, _basis);
    final basisCompleted = _basisCompleted(stats, _basis);
    final completionRate = _rate(basisCompleted, basisTotal);
    final average = _averagePerDay(stats, basisTotal);
    final streak = _calculateStreak(stats, _basis);
    final peak = _peakStudyBlock(stats.plans);

    final goalProvider = context.watch<GoalProvider>();
    final achievement = goalProvider.currentAchievement;
    final goalRate = achievement?.achievementRate ?? 0;
    final goalTargetMinutes = achievement?.goal.targetMinutes ?? 0;

    final goalDescription = goalTargetMinutes > 0
        ? '${_formatMinutes(achievement?.actualMinutes ?? 0)} / ${_formatMinutes(goalTargetMinutes)}'
        : '목표가 설정되지 않았습니다';

    final kpis = [
      _KpiData(
        title: '총 학습량',
        value: _formatBasisValue(basisTotal, _basis),
        numericValue: basisTotal.toDouble(),
        formatter: (value) => _formatBasisValue(value.round(), _basis),
        subtitle: '기준: $basisLabel',
        icon: Icons.auto_graph,
        tooltip: '선택한 기준으로 집계한 총 학습량입니다.',
      ),
      _KpiData(
        title: '완료율',
        value: '${completionRate.toStringAsFixed(0)}%',
        numericValue: completionRate,
        formatter: (value) => '${value.toStringAsFixed(0)}%',
        subtitle: '기준: $basisLabel',
        icon: Icons.check_circle,
        tooltip: '선택한 기준으로 완료된 비율입니다.',
      ),
      _KpiData(
        title: '일 평균',
        value: _formatBasisValue(average.round(), _basis),
        numericValue: average.toDouble(),
        formatter: (value) => _formatBasisValue(value.round(), _basis),
        subtitle: '기간 평균',
        icon: Icons.equalizer,
        tooltip: '선택한 기간의 하루 평균 학습량입니다.',
      ),
      _KpiData(
        title: '목표 대비',
        value: goalTargetMinutes > 0 ? '${goalRate.toStringAsFixed(0)}%' : '-',
        numericValue: goalTargetMinutes > 0 ? goalRate : null,
        formatter: (value) => '${value.toStringAsFixed(0)}%',
        subtitle: goalDescription,
        icon: Icons.flag,
        tooltip: '설정한 목표 대비 달성률입니다. 시간 기준에 맞춰 계산됩니다.',
      ),
      _KpiData(
        title: '연속 학습',
        value: '$streak일',
        numericValue: streak.toDouble(),
        formatter: (value) => '${value.toStringAsFixed(0)}일',
        subtitle: '연속 기록',
        icon: Icons.local_fire_department,
        tooltip: '학습이 기록된 연속 일수입니다.',
      ),
      _KpiData(
        title: '최고 집중 시간대',
        value: peak.label,
        subtitle: peak.detail,
        icon: Icons.schedule,
        tooltip: '학습 시간이 가장 많이 기록된 시간대입니다.',
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: kpis.map((kpi) => _buildKpiCard(kpi)).toList(),
    );
  }

  Widget _buildGoalProgressCard(StatisticsProvider provider) {
    final goalProvider = context.watch<GoalProvider>();
    final achievement = goalProvider.currentAchievement;
    if (achievement == null || achievement.goal.targetMinutes <= 0) {
      return const SizedBox.shrink();
    }

    final target = achievement.goal.targetMinutes;
    final actual = achievement.actualMinutes;
    final remaining = (target - actual).clamp(0, target);
    final progress = target == 0 ? 0.0 : (actual / target).clamp(0.0, 1.0);

    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: _StatsColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('목표 대비 진행', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${(achievement.achievementRate).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: _StatsColors.line,
              valueColor: const AlwaysStoppedAnimation<Color>(_StatsColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '남은 시간: ${_formatMinutes(remaining)}',
            style: const TextStyle(fontSize: 12, color: _StatsColors.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(_KpiData data) {
    return Tooltip(
      message: data.tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: SizedBox(
        width: 180,
        child: _GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _StatsColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(data.icon, size: 16, color: _StatsColors.primary),
                  ),
                  const Spacer(),
                  Icon(Icons.info_outline, size: 14, color: _StatsColors.mutedText),
                ],
              ),
              const SizedBox(height: 10),
              _AnimatedValueText(
                value: data.value,
                numericValue: data.numericValue,
                formatter: data.formatter,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                data.title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                data.subtitle,
                style: const TextStyle(fontSize: 11, color: _StatsColors.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainChart(
    StudyStatistics stats,
    StatisticsProvider provider,
    List<Subject> subjects,
  ) {
    final basisLabel = _basisLabel(_basis);
    final values = stats.dailyStats.map((e) => _dailyTotalValue(e, _basis)).toList();
    final maxValue = values.isEmpty ? 0 : values.reduce(max);
    final goalLine = _goalLineValue(provider, stats);
    final maxY = max(maxValue.toDouble(), goalLine ?? 0) + (maxValue * 0.2);

    if (values.isEmpty) {
      return _sectionCard(
        title: '학습 흐름',
        subtitle: '데이터가 없습니다',
        child: const SizedBox(
          height: 200,
          child: Center(child: Text('표시할 데이터가 없습니다.')),
        ),
      );
    }

    final labelInterval = _labelInterval(values.length, provider.period);

    return _sectionCard(
      title: '학습 흐름',
      subtitle: '기준: $basisLabel',
      trailing: goalLine != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _StatsColors.warning.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _StatsColors.warning.withAlpha(80)),
              ),
              child: Text(
                '목표선 ${_formatBasisValue(goalLine.round(), ProgressBasis.time)}',
                style: const TextStyle(fontSize: 11, color: _StatsColors.warning),
              ),
            )
          : null,
      child: SizedBox(
        height: 240,
        child: BarChart(
          BarChartData(
            maxY: maxY == 0 ? 10 : maxY,
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY == 0 ? 10 : maxY / 4,
              getDrawingHorizontalLine: (value) => FlLine(
                color: _StatsColors.line,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      _axisLeftLabel(value),
                      style: const TextStyle(fontSize: 10, color: _StatsColors.mutedText),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= stats.dailyStats.length) {
                      return const SizedBox.shrink();
                    }
                    final date = stats.dailyStats[index].date;
                    if (_shouldSkipLabel(index, date, provider.period, labelInterval)) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _formatAxisLabel(date, provider.period, stats),
                        style: const TextStyle(fontSize: 11, color: _StatsColors.mutedText),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 12,
                tooltipPadding: const EdgeInsets.all(10),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final day = stats.dailyStats[groupIndex].date;
                  final subjectLines = _buildDaySubjectSummary(
                    day,
                    stats.plans,
                    subjects,
                    _basis,
                  );
                  final title = '${DateHelper.toDateString(day)}\n';
                  final body = subjectLines.isEmpty ? '기록 없음' : subjectLines.join('\n');
                  return BarTooltipItem(
                    '$title$body',
                    const TextStyle(fontSize: 11, color: Colors.white),
                  );
                },
              ),
              touchCallback: (event, response) {
                if (response == null || response.spot == null) return;
                if (event is FlTapUpEvent) {
                  setState(() => _selectedDayIndex = response.spot!.touchedBarGroupIndex);
                }
              },
            ),
            barGroups: stats.dailyStats.asMap().entries.map((entry) {
              final index = entry.key;
              final value = _dailyTotalValue(entry.value, _basis).toDouble();
              final isSelected = _selectedDayIndex == index;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: value,
                    width: 14,
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [_StatsColors.primary, _StatsColors.accent]
                          : [_StatsColors.primary.withAlpha(180), _StatsColors.primary],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ],
              );
            }).toList(),
            extraLinesData: goalLine != null
                ? ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: goalLine,
                        color: _StatsColors.warning,
                        strokeWidth: 1,
                        dashArray: [6, 4],
                      ),
                    ],
                  )
                : ExtraLinesData(horizontalLines: []),
          ),
        ),
      ),
    );
  }

  Widget _buildDayBreakdownCard(StudyStatistics stats, List<Subject> subjects) {
    final dayIndex = _selectedDayIndex ?? (stats.dailyStats.isNotEmpty ? stats.dailyStats.length - 1 : null);
    if (dayIndex == null || dayIndex < 0 || dayIndex >= stats.dailyStats.length) {
      return _sectionCard(
        title: '일별 상세',
        subtitle: '차트를 눌러 상세를 확인하세요',
        child: const SizedBox(height: 120, child: Center(child: Text('선택된 날짜가 없습니다.'))),
      );
    }

    final day = stats.dailyStats[dayIndex];
    final dayPlans = _plansForDate(stats.plans, day.date);
    final basisTotal = _dailyTotalValue(day, _basis);
    final basisCompleted = _dailyCompletedValue(day, _basis, dayPlans);
    final rate = _rate(basisCompleted, basisTotal);
    final subjectLines = _buildDaySubjectSummary(day.date, stats.plans, subjects, _basis);

    return _sectionCard(
      title: '일별 상세',
      subtitle: DateHelper.toKoreanDateString(day.date),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatChip('총 ${_formatBasisValue(basisTotal, _basis)}', _StatsColors.primary),
              const SizedBox(width: 6),
              _buildStatChip('완료율 ${rate.toStringAsFixed(0)}%', _StatsColors.accent),
              const SizedBox(width: 6),
              _buildStatChip('일정 ${dayPlans.length}개', _StatsColors.mutedText),
            ],
          ),
          const SizedBox(height: 12),
          if (subjectLines.isEmpty)
            const Text('등록된 일정이 없습니다.', style: TextStyle(color: _StatsColors.mutedText))
          else
            ...subjectLines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: const TextStyle(fontSize: 12)),
                )),
          if (dayPlans.isNotEmpty) ...[
            const SizedBox(height: 12),
            Column(
              children: dayPlans.take(3).map((plan) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _buildSubjectDot(plan.subjectId, subjects),
                  title: Text(plan.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${plan.startTime} - ${plan.endTime}', style: const TextStyle(fontSize: 11)),
                  trailing: Icon(
                    plan.isCompleted ? Icons.check_circle : Icons.pending,
                    color: plan.isCompleted ? _StatsColors.success : _StatsColors.mutedText,
                    size: 18,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectChart(StudyStatistics stats, List<Subject> subjects) {
    final subjectValues = _subjectValues(stats, _basis);
    if (subjectValues.isEmpty) {
      return _sectionCard(
        title: '과목 분해',
        subtitle: '과목 데이터가 없습니다',
        child: const SizedBox(height: 200, child: Center(child: Text('과목 데이터를 추가하세요.'))),
      );
    }

    final total = subjectValues.values.fold<int>(0, (sum, value) => sum + value);
    final subjectMap = {for (final subject in subjects) subject.id: subject};
    final sortedEntries = subjectValues.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _sectionCard(
      title: '과목 분해',
      subtitle: '비율과 절대값을 함께 확인하세요',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (response == null || response.touchedSection == null) return;
                    setState(() => _selectedSubjectId = response.touchedSection!.touchedSection?.title);
                  },
                ),
                sections: sortedEntries.map((entry) {
                  final value = entry.value;
                  final percent = total > 0 ? (value / total * 100) : 0;
                  final subject = subjectMap[entry.key];
                  final color = subject != null ? _parseColor(subject.color) : _StatsColors.accent;

                  return PieChartSectionData(
                    value: value.toDouble(),
                    title: entry.key,
                    color: color,
                    radius: _selectedSubjectId == entry.key ? 78 : 72,
                    titleStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
                    badgeWidget: _PieBadge(
                      label: '${percent.toStringAsFixed(0)}%\n${_formatBasisValue(value, _basis)}',
                      color: color,
                      isSelected: _selectedSubjectId == entry.key,
                    ),
                    badgePositionPercentageOffset: 1.2,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedEntries.map((entry) {
              final subject = subjectMap[entry.key];
              final name = subject?.name ?? '알 수 없음';
              final color = subject != null ? _parseColor(subject.color) : _StatsColors.accent;
              final percent = total > 0 ? (entry.value / total * 100) : 0;
              return InkWell(
                onTap: () => setState(() => _selectedSubjectId = entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withAlpha(90)),
                  ),
                  child: Text(
                    '$name ${percent.toStringAsFixed(0)}% · ${_formatBasisValue(entry.value, _basis)}',
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectDetailCard(StudyStatistics stats, List<Subject> subjects) {
    final subjectValues = _subjectValues(stats, _basis);
    if (subjectValues.isEmpty) {
      return _sectionCard(
        title: '과목 상세',
        subtitle: '선택된 과목이 없습니다',
        child: const SizedBox(height: 120, child: Center(child: Text('과목을 추가해 주세요.'))),
      );
    }

    final subjectMap = {for (final subject in subjects) subject.id: subject};
    final total = subjectValues.values.fold<int>(0, (sum, value) => sum + value);
    final topEntry = subjectValues.entries.reduce((a, b) => a.value > b.value ? a : b);
    final selectedId = _selectedSubjectId ?? topEntry.key;
    final value = subjectValues[selectedId] ?? 0;
    final percent = total > 0 ? value / total * 100 : 0;
    final subject = subjectMap[selectedId];
    final color = subject != null ? _parseColor(subject.color) : _StatsColors.accent;
    final plans = stats.plans.where((plan) => plan.subjectId == selectedId).toList();
    final averageMinutes = plans.isEmpty
        ? 0
        : plans.map(_effectiveMinutes).reduce((a, b) => a + b) ~/ plans.length;
    final basisCompleted = _subjectCompletedValue(stats, selectedId, _basis);
    final basisTotal = value;
    final basisRate = _rate(basisCompleted, basisTotal);
    final topPlans = List<DailyPlan>.from(plans)..sort((a, b) => _effectiveMinutes(b) - _effectiveMinutes(a));

    return _sectionCard(
      title: '과목 상세',
      subtitle: subject?.name ?? '알 수 없음',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text('${percent.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatChip(_formatBasisValue(value, _basis), color),
              const SizedBox(width: 8),
              _buildStatChip('완료율 ${basisRate.toStringAsFixed(0)}%', _StatsColors.accent),
              const SizedBox(width: 8),
              _buildStatChip('평균 ${_formatMinutes(averageMinutes)}', _StatsColors.mutedText),
            ],
          ),
          const SizedBox(height: 12),
          if (topPlans.isEmpty)
            const Text('과목 일정이 없습니다.', style: TextStyle(color: _StatsColors.mutedText))
          else
            Column(
              children: topPlans.take(3).map((plan) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _buildSubjectDot(plan.subjectId, subjects),
                  title: Text(plan.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${plan.startTime} - ${plan.endTime}', style: const TextStyle(fontSize: 11)),
                  trailing: Text(
                    _formatMinutes(_effectiveMinutes(plan)),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightSection(
    StudyStatistics stats,
    StatisticsProvider provider,
    List<Subject> subjects,
    String userId,
  ) {
    final insights = _buildInsights(stats, provider, subjects, userId);
    return _sectionCard(
      title: '인사이트',
      subtitle: '다음 행동을 결정하는 요약',
      child: Column(
        children: insights
            .map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InsightCard(data: insight),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildAdvancedSection(
    StudyStatistics stats,
    StatisticsProvider provider,
    List<Subject> subjects,
  ) {
    return _sectionCard(
      title: '심화 데이터',
      subtitle: '더 많은 데이터와 패턴을 확인하세요',
      trailing: TextButton(
        onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
        child: Text(_showAdvanced ? '접기' : '자세히 보기'),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _showAdvanced
            ? Column(
                key: const ValueKey('advanced'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeekdayAverage(stats),
                  const SizedBox(height: 12),
                  _buildPriorityCompletion(stats),
                  const SizedBox(height: 12),
                  _buildDelaySummary(stats, subjects),
                ],
              )
            : const SizedBox(
                key: ValueKey('collapsed'),
                height: 80,
                child: Center(child: Text('자세히 보기 버튼을 눌러 확장하세요.')),
              ),
      ),
    );
  }

  Widget _buildWeekdayAverage(StudyStatistics stats) {
    final values = <int, double>{};
    final counts = <int, int>{};
    for (final entry in stats.dailyStats) {
      final weekday = entry.date.weekday;
      values[weekday] = (values[weekday] ?? 0) + _dailyTotalValue(entry, _basis).toDouble();
      counts[weekday] = (counts[weekday] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('요일별 평균 학습', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (index) {
            final dayIndex = index + 1;
            final avg = (values[dayIndex] ?? 0) / max(1, counts[dayIndex] ?? 1);
            return _buildStatChip(
              '${_weekdayLabel(dayIndex)} ${_formatBasisValue(avg.round(), _basis)}',
              _StatsColors.primary,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPriorityCompletion(StudyStatistics stats) {
    final priorityTotals = <int, int>{};
    final priorityCompleted = <int, int>{};
    for (final plan in stats.plans) {
      priorityTotals[plan.priority] = (priorityTotals[plan.priority] ?? 0) + 1;
      if (plan.isCompleted) {
        priorityCompleted[plan.priority] = (priorityCompleted[plan.priority] ?? 0) + 1;
      }
    }

    final chips = priorityTotals.entries.map((entry) {
      final total = entry.value;
      final completed = priorityCompleted[entry.key] ?? 0;
      final rate = _rate(completed, total);
      return _buildStatChip('우선순위 ${entry.key} · ${rate.toStringAsFixed(0)}%', _StatsColors.accent);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('우선순위별 완료율', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips.isEmpty ? [_buildStatChip('데이터 없음', _StatsColors.mutedText)] : chips),
      ],
    );
  }

  Widget _buildDelaySummary(StudyStatistics stats, List<Subject> subjects) {
    final subjectTotals = <String, int>{};
    final subjectIncomplete = <String, int>{};
    for (final plan in stats.plans) {
      final subjectId = plan.subjectId ?? 'none';
      subjectTotals[subjectId] = (subjectTotals[subjectId] ?? 0) + 1;
      if (!plan.isCompleted) {
        subjectIncomplete[subjectId] = (subjectIncomplete[subjectId] ?? 0) + 1;
      }
    }
    String? worstSubjectId;
    int worstCount = 0;
    subjectIncomplete.forEach((key, value) {
      if (value > worstCount) {
        worstSubjectId = key;
        worstCount = value;
      }
    });
    final subjectMap = {for (final subject in subjects) subject.id: subject};
    final name = worstSubjectId == null || worstSubjectId == 'none'
        ? '미지정'
        : subjectMap[worstSubjectId]?.name ?? '알 수 없음';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('미완료 요약', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('미완료 일정 ${stats.totalPlans - stats.completedPlans}개 · 가장 자주 미뤄진 과목: $name'),
      ],
    );
  }

  Widget _buildStatsError(StatisticsProvider provider, String userId) {
    final message = provider.errorMessage ?? '통계 데이터를 불러오지 못했습니다.';
    final indexUrl = provider.indexUrl;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('데이터 조회 오류', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message),
              const SizedBox(height: 12),
              if (indexUrl != null) ...[
                SelectableText(indexUrl, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (indexUrl != null)
                    ElevatedButton.icon(
                      onPressed: () => launchUrlString(indexUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('인덱스 열기'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => context.read<StatisticsProvider>().loadStatistics(userId),
                    icon: const Icon(Icons.refresh),
                    label: const Text('새로고침'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshGoals(String userId) async {
    final statsProvider = context.read<StatisticsProvider>();
    final goalProvider = context.read<GoalProvider>();
    await goalProvider.loadGoals(userId, statsProvider.selectedDate);
    final goal = switch (statsProvider.period) {
      StatsPeriod.day => goalProvider.dailyGoal,
      StatsPeriod.week => goalProvider.weeklyGoal,
      StatsPeriod.month => goalProvider.monthlyGoal,
      StatsPeriod.custom => null,
    };
    if (goal != null) {
      await goalProvider.calculateAchievement(userId, goal);
    } else {
      goalProvider.clearAchievement();
    }
  }

  void _changePeriod(StatisticsProvider provider, String userId, StatsPeriod period) {
    provider.changePeriod(period);
    if (period == StatsPeriod.day) {
      provider.changeDate(DateTime.now());
    }
    provider.loadStatistics(userId);
    _refreshGoals(userId);
  }

  void _shiftRange(StatisticsProvider provider, String userId, int delta) {
    final date = _shiftDate(provider.selectedDate, provider.period, delta);
    provider.changeDate(date);
    provider.loadStatistics(userId);
    _refreshGoals(userId);
  }

  Future<void> _selectCustomRange(StatisticsProvider provider, String userId) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: provider.customStart != null && provider.customEnd != null
          ? DateTimeRange(start: provider.customStart!, end: provider.customEnd!)
          : DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (range == null) return;
    provider.setCustomRange(range.start, range.end);
    provider.loadStatistics(userId);
    _refreshGoals(userId);
  }

  DateTime _shiftDate(DateTime date, StatsPeriod period, int delta) {
    switch (period) {
      case StatsPeriod.day:
        return date.add(Duration(days: delta));
      case StatsPeriod.week:
        return date.add(Duration(days: 7 * delta));
      case StatsPeriod.month:
        return DateTime(date.year, date.month + delta, date.day);
      case StatsPeriod.custom:
        return date;
    }
  }

  String _rangeLabel(StatisticsProvider provider) {
    switch (provider.period) {
      case StatsPeriod.day:
        return DateHelper.toDateString(provider.selectedDate);
      case StatsPeriod.week:
        return '${DateHelper.toDateString(DateHelper.getWeekStartDate(provider.selectedDate))}'
            ' ~ ${DateHelper.toDateString(DateHelper.getWeekEndDate(provider.selectedDate))}';
      case StatsPeriod.month:
        return '${provider.selectedDate.year}년 ${provider.selectedDate.month}월';
      case StatsPeriod.custom:
        if (provider.customStart != null && provider.customEnd != null) {
          return '${DateHelper.toDateString(provider.customStart!)}'
              ' ~ ${DateHelper.toDateString(provider.customEnd!)}';
        }
        return '사용자 지정';
    }
  }

  String _basisLabel(ProgressBasis basis) {
    switch (basis) {
      case ProgressBasis.subtask:
        return '세부 목표 기준';
      case ProgressBasis.time:
        return '시간 기준';
      case ProgressBasis.page:
        return '페이지 기준';
    }
  }

  int _basisTotal(StudyStatistics stats, ProgressBasis basis) {
    return switch (basis) {
      ProgressBasis.time => stats.totalMinutes,
      ProgressBasis.subtask => stats.totalSubtasks,
      ProgressBasis.page => stats.totalUnits,
    };
  }

  int _basisCompleted(StudyStatistics stats, ProgressBasis basis) {
    return switch (basis) {
      ProgressBasis.time => _completedMinutes(stats.plans),
      ProgressBasis.subtask => stats.completedSubtasks,
      ProgressBasis.page => stats.completedUnits,
    };
  }

  int _dailyTotalValue(DailyStats stats, ProgressBasis basis) {
    return switch (basis) {
      ProgressBasis.time => stats.minutes,
      ProgressBasis.subtask => stats.totalSubtasks,
      ProgressBasis.page => stats.totalUnits,
    };
  }

  int _dailyCompletedValue(DailyStats stats, ProgressBasis basis, List<DailyPlan> plans) {
    return switch (basis) {
      ProgressBasis.time => _completedMinutes(plans),
      ProgressBasis.subtask => stats.completedSubtasks,
      ProgressBasis.page => stats.completedUnits,
    };
  }

  Map<String, int> _subjectValues(StudyStatistics stats, ProgressBasis basis) {
    final values = <String, int>{};
    stats.subjectStats.forEach((subjectId, stat) {
      values[subjectId] = switch (basis) {
        ProgressBasis.time => stat.minutes,
        ProgressBasis.subtask => stat.totalSubtasks,
        ProgressBasis.page => stat.totalUnits,
      };
    });
    values.removeWhere((key, value) => value == 0);
    return values;
  }

  int _subjectCompletedValue(StudyStatistics stats, String subjectId, ProgressBasis basis) {
    final subject = stats.subjectStats[subjectId];
    if (subject == null) return 0;
    return switch (basis) {
      ProgressBasis.time => _completedMinutes(stats.plans.where((p) => p.subjectId == subjectId).toList()),
      ProgressBasis.subtask => subject.completedSubtasks,
      ProgressBasis.page => subject.completedUnits,
    };
  }

  List<DailyPlan> _plansForDate(List<DailyPlan> plans, DateTime date) {
    return plans.where((plan) => DateHelper.isSameDay(plan.date, date)).toList();
  }

  int _completedMinutes(List<DailyPlan> plans) {
    return plans.where((plan) => plan.isCompleted).fold(0, (sum, plan) => sum + _effectiveMinutes(plan));
  }

  int _effectiveMinutes(DailyPlan plan) {
    final actual = plan.actualMinutes;
    if (actual > 0) return actual;
    final partsStart = plan.startTime.split(':');
    final partsEnd = plan.endTime.split(':');
    if (partsStart.length < 2 || partsEnd.length < 2) return 0;
    final startHour = int.tryParse(partsStart[0]) ?? 0;
    final startMin = int.tryParse(partsStart[1]) ?? 0;
    final endHour = int.tryParse(partsEnd[0]) ?? 0;
    final endMin = int.tryParse(partsEnd[1]) ?? 0;
    final start = startHour * 60 + startMin;
    final end = endHour * 60 + endMin;
    final diff = end - start;
    return diff > 0 ? diff : 0;
  }

  double _rate(int completed, int total) {
    if (total <= 0) return 0;
    return (completed / total * 100).clamp(0, 100).toDouble();
  }

  int _averagePerDay(StudyStatistics stats, int total) {
    final days = stats.endDate.difference(stats.startDate).inDays + 1;
    if (days <= 0) return 0;
    return (total / days).round();
  }

  int _calculateStreak(StudyStatistics stats, ProgressBasis basis) {
    int streak = 0;
    for (int i = stats.dailyStats.length - 1; i >= 0; i--) {
      final day = stats.dailyStats[i];
      final value = _dailyTotalValue(day, basis);
      if (value > 0) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  _PeakBlock _peakStudyBlock(List<DailyPlan> plans) {
    if (plans.isEmpty) {
      return const _PeakBlock(label: '-', detail: '데이터 없음');
    }
    final buckets = <int, int>{};
    for (final plan in plans) {
      final minutes = _effectiveMinutes(plan);
      final parts = plan.startTime.split(':');
      final hour = int.tryParse(parts.first) ?? 0;
      final bucket = (hour ~/ 2) * 2;
      buckets[bucket] = (buckets[bucket] ?? 0) + minutes;
    }
    int bestBucket = 0;
    int bestMinutes = 0;
    buckets.forEach((hour, minutes) {
      if (minutes > bestMinutes) {
        bestBucket = hour;
        bestMinutes = minutes;
      }
    });
    final label = '${bestBucket.toString().padLeft(2, '0')}-${(bestBucket + 2).toString().padLeft(2, '0')}시';
    return _PeakBlock(label: label, detail: '총 ${_formatMinutes(bestMinutes)}');
  }

  String _formatBasisValue(int value, ProgressBasis basis) {
    return switch (basis) {
      ProgressBasis.time => _formatMinutes(value),
      ProgressBasis.subtask => '$value개',
      ProgressBasis.page => '$value페이지',
    };
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0분';
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    if (hours <= 0) return '$remain분';
    if (remain == 0) return '$hours시간';
    return '$hours시간 $remain분';
  }

  String _weekdayLabel(int weekday) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return labels[weekday - 1];
  }

  double? _goalLineValue(StatisticsProvider provider, StudyStatistics stats) {
    if (_basis != ProgressBasis.time) return null;
    final goalProvider = context.read<GoalProvider>();
    final goal = switch (provider.period) {
      StatsPeriod.day => goalProvider.dailyGoal,
      StatsPeriod.week => goalProvider.weeklyGoal,
      StatsPeriod.month => goalProvider.monthlyGoal,
      StatsPeriod.custom => null,
    };
    if (goal == null || goal.targetMinutes <= 0) return null;

    if (provider.period == StatsPeriod.day) {
      return goal.targetMinutes.toDouble();
    }
    final days = stats.endDate.difference(stats.startDate).inDays + 1;
    if (days <= 0) return null;
    return goal.targetMinutes / days;
  }

  String _axisLeftLabel(double value) {
    if (_basis == ProgressBasis.time) {
      if (value >= 60) {
        return '${(value / 60).toStringAsFixed(0)}h';
      }
      return '${value.toStringAsFixed(0)}m';
    }
    return value.toStringAsFixed(0);
  }

  String _formatAxisLabel(DateTime date, StatsPeriod period, StudyStatistics stats) {
    switch (period) {
      case StatsPeriod.day:
        return '${date.month}/${date.day}';
      case StatsPeriod.week:
        return DateHelper.getWeekdayName(date);
      case StatsPeriod.month:
        return date.day.toString();
      case StatsPeriod.custom:
        final spanMonths = stats.startDate.month != stats.endDate.month;
        return spanMonths ? '${date.month}/${date.day}' : date.day.toString();
    }
  }

  int _labelInterval(int count, StatsPeriod period) {
    if (period == StatsPeriod.day) return 1;
    if (count > 30) return 5;
    if (count > 14) return 2;
    return 1;
  }

  bool _shouldSkipLabel(int index, DateTime date, StatsPeriod period, int interval) {
    if (period == StatsPeriod.month || period == StatsPeriod.custom) {
      return index % interval != 0;
    }
    return false;
  }

  List<String> _buildDaySubjectSummary(
    DateTime date,
    List<DailyPlan> plans,
    List<Subject> subjects,
    ProgressBasis basis,
  ) {
    final subjectMap = {for (final subject in subjects) subject.id: subject};
    final dayPlans = plans.where((plan) => DateHelper.isSameDay(plan.date, date));
    final totals = <String, int>{};
    for (final plan in dayPlans) {
      final subjectId = plan.subjectId ?? 'none';
      final value = switch (basis) {
        ProgressBasis.time => _effectiveMinutes(plan),
        ProgressBasis.subtask => plan.subtasks.length,
        ProgressBasis.page => _subtaskUnits(plan.subtasks),
      };
      totals[subjectId] = (totals[subjectId] ?? 0) + value;
    }
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((entry) {
      final name = entry.key == 'none' ? '미지정' : subjectMap[entry.key]?.name ?? '알 수 없음';
      return '$name · ${_formatBasisValue(entry.value, basis)}';
    }).toList();
  }

  int _subtaskUnits(List<dynamic> subtasks) {
    int units = 0;
    for (final subtask in subtasks) {
      final range = subtask.pageRange;
      if (range == null || range.toString().isEmpty) continue;
      final parts = range.toString().split('-');
      if (parts.length != 2) continue;
      final start = int.tryParse(parts[0].trim()) ?? 0;
      final end = int.tryParse(parts[1].trim()) ?? 0;
      if (end >= start) {
        units += end - start + 1;
      }
    }
    return units;
  }

  Color _parseColor(String value) {
    return Color(int.parse(value.replaceFirst('#', '0xFF')));
  }

  Widget _buildSubjectDot(String? subjectId, List<Subject> subjects) {
    final subject = subjects.where((s) => s.id == subjectId).toList();
    final color = subject.isNotEmpty ? _parseColor(subject.first.color) : _StatsColors.mutedText;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: _StatsColors.mutedText)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  List<_InsightData> _buildInsights(
    StudyStatistics stats,
    StatisticsProvider provider,
    List<Subject> subjects,
    String userId,
  ) {
    final insights = <_InsightData>[];
    final subjectValues = _subjectValues(stats, _basis);
    final total = subjectValues.values.fold<int>(0, (sum, value) => sum + value);
    if (subjectValues.isNotEmpty && total > 0) {
      final top = subjectValues.entries.reduce((a, b) => a.value > b.value ? a : b);
      final ratio = top.value / total;
      final subjectMatch = subjects.where((subject) => subject.id == top.key).toList();
      final subjectName = subjectMatch.isNotEmpty ? subjectMatch.first.name : '알 수 없음';
      final subjectId = subjectMatch.isNotEmpty ? subjectMatch.first.id : top.key;
      if (ratio >= 0.6) {
        insights.add(
          _InsightData(
            title: '과목 비중이 편향되어 있습니다.',
            description: '$subjectName 비중이 ${(ratio * 100).toStringAsFixed(0)}%입니다. 다른 과목을 하루 30분씩 추가해보세요.',
            actionLabel: '추천 일정 생성',
            onAction: () => _openDailyForm(
              initialTitle: '$subjectName 보충 학습',
              initialNotes: '과목 비중을 균형 있게 맞추기',
              subjectId: subjectId,
            ),
          ),
        );
      }
    }

    final goalProvider = context.read<GoalProvider>();
    final achievement = goalProvider.currentAchievement;
    if (_basis == ProgressBasis.time && achievement != null) {
      final remaining = achievement.goal.targetMinutes - achievement.actualMinutes;
      if (remaining > 0) {
        final days = stats.endDate.difference(stats.startDate).inDays + 1;
        final dailyNeed = (remaining / max(1, days)).ceil();
        insights.add(
          _InsightData(
            title: '목표까지 남은 시간이 있습니다.',
            description: '목표까지 ${_formatMinutes(remaining)} 남았습니다. 하루 ${_formatMinutes(dailyNeed)}씩 확보해보세요.',
            actionLabel: '목표 수정하기',
            onAction: () => _openGoalSettings(provider.period, achievement.goal.targetMinutes),
          ),
        );
      } else {
        insights.add(
          _InsightData(
            title: '목표를 달성했습니다.',
            description: '현재 목표를 넘어섰습니다. 다음 목표를 조금 높여볼까요?',
            actionLabel: '목표 수정하기',
            onAction: () => _openGoalSettings(provider.period, achievement.goal.targetMinutes),
          ),
        );
      }
    }

    final peak = _peakStudyBlock(stats.plans);
    insights.add(
      _InsightData(
        title: '학습 효율이 높은 시간대',
        description: '${peak.label}에 가장 집중도가 높았습니다. 이 시간에 핵심 과제를 배치하세요.',
        actionLabel: '다음 주 계획에 반영',
        onAction: () => _openDailyForm(
          initialTitle: '집중 시간대 학습',
          initialNotes: '${peak.label}에 핵심 과제 배치',
        ),
      ),
    );

    if (insights.length < 3) {
      final basisRate = _rate(_basisCompleted(stats, _basis), _basisTotal(stats, _basis));
      insights.add(
        _InsightData(
          title: '완료율을 조금 더 끌어올려 보세요.',
          description: '현재 완료율은 ${basisRate.toStringAsFixed(0)}%입니다. 오늘 한 가지 일정부터 완료해보세요.',
          actionLabel: '추천 일정 생성',
          onAction: () => _openDailyForm(
            initialTitle: '완료율 개선',
            initialNotes: '작은 목표부터 완료',
          ),
        ),
      );
    }

    while (insights.length < 3) {
      insights.add(
        _InsightData(
          title: '학습 기록을 꾸준히 쌓아보세요.',
          description: '짧은 기록이라도 남기면 통계가 더 정확해집니다.',
          actionLabel: '일정 추가',
          onAction: () => _openDailyForm(initialTitle: '학습 기록 추가'),
        ),
      );
    }

    return insights.take(3).toList();
  }

  void _openDailyForm({String? initialTitle, String? initialNotes, String? subjectId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DailyFormScreen(
          date: DateTime.now(),
          initialTitle: initialTitle,
          initialNotes: initialNotes,
          initialSubjectId: subjectId,
        ),
      ),
    );
  }

  void _openGoalSettings(StatsPeriod period, int targetMinutes) {
    GoalPeriod initialPeriod = GoalPeriod.daily;
    if (period == StatsPeriod.week) {
      initialPeriod = GoalPeriod.weekly;
    } else if (period == StatsPeriod.month) {
      initialPeriod = GoalPeriod.monthly;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GoalSettingsScreen(
          initialPeriod: initialPeriod,
          initialTargetMinutes: targetMinutes,
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _StickyHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _StatsColors.canvas,
        boxShadow: [
          if (overlapsContent)
            BoxShadow(
              color: _StatsColors.shadow.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(210),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _StatsColors.line),
            boxShadow: [
              BoxShadow(
                color: _StatsColors.shadow.withAlpha(18),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final IconData? icon;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: isSelected ? 1.02 : 1.0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isSelected ? 1 : 0.85,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? _StatsColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isSelected ? _StatsColors.primary : _StatsColors.line),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: _StatsColors.primary.withAlpha(35),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: isSelected ? Colors.white : _StatsColors.primary),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : _StatsColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedValueText extends StatelessWidget {
  final String value;
  final double? numericValue;
  final String Function(double)? formatter;
  final TextStyle style;

  const _AnimatedValueText({
    required this.value,
    required this.style,
    this.numericValue,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    if (numericValue != null && formatter != null) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: numericValue),
        duration: const Duration(milliseconds: 700),
        builder: (context, animatedValue, child) {
          return Text(formatter!(animatedValue), style: style);
        },
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: Text(
        value,
        key: ValueKey(value),
        style: style,
      ),
    );
  }
}

class _PieBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;

  const _PieBadge({required this.label, required this.color, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(isSelected ? 30 : 20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InsightData {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  const _InsightData({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });
}

class _InsightCard extends StatelessWidget {
  final _InsightData data;

  const _InsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _StatsColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 48,
            decoration: BoxDecoration(
              color: _StatsColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(data.description, style: const TextStyle(fontSize: 12, color: _StatsColors.mutedText)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: data.onAction,
                    child: Text(data.actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final double? numericValue;
  final String Function(double)? formatter;
  final String subtitle;
  final IconData icon;
  final String tooltip;

  const _KpiData({
    required this.title,
    required this.value,
    this.numericValue,
    this.formatter,
    required this.subtitle,
    required this.icon,
    required this.tooltip,
  });
}

class _PeakBlock {
  final String label;
  final String detail;

  const _PeakBlock({required this.label, required this.detail});
}

class _StatsColors {
  static const canvas = Color(0xFFF3F5F9);
  static const headerStart = Color(0xFF2B3A67);
  static const headerEnd = Color(0xFF3E5C90);
  static const primary = Color(0xFF3E5C90);
  static const accent = Color(0xFF6A8DFF);
  static const warning = Color(0xFFF0A04B);
  static const success = Color(0xFF55B685);
  static const line = Color(0xFFE1E7F0);
  static const mutedText = Color(0xFF6B7684);
  static const shadow = Color(0xFF0F172A);
}
