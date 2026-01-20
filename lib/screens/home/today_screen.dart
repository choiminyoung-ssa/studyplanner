import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/daily_plan.dart';
import '../../models/weekly_plan.dart';
import '../../models/monthly_plan.dart';
import '../../utils/date_utils.dart';
import '../daily/completion_tracker_dialog.dart';
import '../daily/daily_form_screen.dart';
import '../weekly/weekly_form_screen.dart';
import '../monthly/monthly_form_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;
    final today = DateTime.now();
    final firestoreService = FirestoreService();
    final colorScheme = Theme.of(context).colorScheme;

    if (userId == null) {
      return const Center(child: Text('로그인이 필요합니다'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;
        final maxWidth = isWide ? 1200.0 : 720.0;
        final headerCard = _buildAnimatedEntry(_buildHeaderCard(context, today), delay: 0);
        final flowCard = _buildAnimatedEntry(_buildFlowDiagramCard(context), delay: 40);
        final todaySection = _buildAnimatedEntry(
          _buildTodayPlansSection(
            context,
            userId: userId,
            today: today,
            firestoreService: firestoreService,
          ),
          delay: 80,
        );
        final weeklySection = _buildAnimatedEntry(
          _buildWeeklySection(
            context,
            userId: userId,
            today: today,
            firestoreService: firestoreService,
          ),
          delay: 160,
        );
        final monthlySection = _buildAnimatedEntry(
          _buildMonthlySection(
            context,
            userId: userId,
            today: today,
            firestoreService: firestoreService,
          ),
          delay: 240,
        );

        return DecoratedBox(
          decoration: BoxDecoration(color: colorScheme.surface),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                headerCard,
                                const SizedBox(height: 16),
                                flowCard,
                                const SizedBox(height: 20),
                                todaySection,
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                weeklySection,
                                const SizedBox(height: 20),
                                monthlySection,
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          headerCard,
                          const SizedBox(height: 16),
                          flowCard,
                          const SizedBox(height: 20),
                          todaySection,
                          const SizedBox(height: 20),
                          weeklySection,
                          const SizedBox(height: 20),
                          monthlySection,
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedEntry(Widget child, {int delay = 0}) {
    final baseDuration = 360;
    final totalDuration = baseDuration + delay;
    final start = delay / totalDuration;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: totalDuration),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            icon: icon,
            title: title,
            subtitle: subtitle,
            trailing: trailing,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SizedBox(
      height: 120,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildProgressSummary(
    BuildContext context, {
    required String label,
    required int completed,
    required int total,
    Color? accentColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? colorScheme.primary;
    final progress = total == 0 ? 0.0 : completed / total;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withAlpha(18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withAlpha(60)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: value,
                          strokeWidth: 6,
                          backgroundColor: colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                        Text(
                          '${(value * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '완료 $completed / $total',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayPlansSection(
    BuildContext context, {
    required String userId,
    required DateTime today,
    required FirestoreService firestoreService,
  }) {
    return _buildSectionCard(
      context,
      icon: Icons.today_rounded,
      title: '오늘의 일정',
      subtitle: '오늘 해야 할 일정',
      child: StreamBuilder<List<DailyPlan>>(
        stream: firestoreService.getDailyPlans(userId, today),
        builder: (context, snapshot) {
          Widget content;

          if (snapshot.connectionState == ConnectionState.waiting) {
            content = _buildLoadingState();
          } else if (snapshot.hasError) {
            content = _buildEmptyStateCard(
              context,
              key: const ValueKey('daily-error'),
              icon: Icons.error_outline,
              message: '일정을 불러오는 중 오류가 발생했습니다',
            );
          } else {
            final dailyPlans = snapshot.data ?? [];
            dailyPlans.sort((a, b) => a.startTime.compareTo(b.startTime));

            if (dailyPlans.isEmpty) {
              content = _buildEmptyStateCard(
                context,
                key: const ValueKey('daily-empty'),
                icon: Icons.event_available,
                message: '오늘 예정된 일정이 없습니다',
                exampleTitle: '예시: 수학 문제집 1단원',
                exampleSubtitle: '18:00 ~ 19:30 · 핵심 문제 풀이',
                actionLabel: '일정 추가',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DailyFormScreen(date: today),
                    ),
                  );
                },
              );
            } else {
              final completedCount = dailyPlans.where((p) => p.isCompleted).length;
              final totalCount = dailyPlans.length;

              content = Column(
                key: const ValueKey('daily-list'),
                children: [
                  _buildProgressSummary(
                    context,
                    label: '오늘 진행률',
                    completed: completedCount,
                    total: totalCount,
                    accentColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  ...dailyPlans.map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDailyPlanCard(context, plan, firestoreService),
                    ),
                  ),
                ],
              );
            }
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: content,
          );
        },
      ),
    );
  }

  Widget _buildWeeklySection(
    BuildContext context, {
    required String userId,
    required DateTime today,
    required FirestoreService firestoreService,
  }) {
    return _buildSectionCard(
      context,
      icon: Icons.calendar_view_week_rounded,
      title: '이번 주 계획',
      subtitle: '이번 주 전체 일정',
      child: StreamBuilder<List<WeeklyPlan>>(
        stream: firestoreService.getWeeklyPlansByDateRange(
          userId,
          DateHelper.getWeekStartDate(today),
          DateHelper.getWeekEndDate(today),
        ),
        builder: (context, snapshot) {
          Widget content;

          if (snapshot.connectionState == ConnectionState.waiting) {
            content = _buildLoadingState();
          } else if (snapshot.hasError) {
            content = _buildEmptyStateCard(
              context,
              key: const ValueKey('weekly-error'),
              icon: Icons.error_outline,
              message: '주간 계획을 불러오는 중 오류가 발생했습니다',
            );
          } else {
            final weeklyPlans = snapshot.data ?? [];
            weeklyPlans.sort((a, b) => a.date.compareTo(b.date));

            if (weeklyPlans.isEmpty) {
              content = _buildEmptyStateCard(
                context,
                key: const ValueKey('weekly-empty'),
                icon: Icons.calendar_today,
                message: '이번 주 계획이 없습니다',
                exampleTitle: '예시: 주간 수학 목표',
                exampleSubtitle: '이번 주 총 5시간 확보',
                actionLabel: '주간 계획 추가',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WeeklyFormScreen(
                        date: today,
                        weekStart: DateHelper.getWeekStartDate(today),
                        weekEnd: DateHelper.getWeekEndDate(today),
                      ),
                    ),
                  );
                },
              );
            } else {
              content = Column(
                key: const ValueKey('weekly-list'),
                children:
                    weeklyPlans.map((plan) => _buildWeeklyPlanTile(context, plan)).toList(),
              );
            }
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: content,
          );
        },
      ),
    );
  }

  Widget _buildMonthlySection(
    BuildContext context, {
    required String userId,
    required DateTime today,
    required FirestoreService firestoreService,
  }) {
    return _buildSectionCard(
      context,
      icon: Icons.calendar_month_rounded,
      title: '이번 달 목표',
      subtitle: '이번 달 핵심 목표',
      child: StreamBuilder<List<MonthlyPlan>>(
        stream: firestoreService.getMonthlyPlans(
          userId,
          DateHelper.toMonthString(today),
        ),
        builder: (context, snapshot) {
          Widget content;

          if (snapshot.connectionState == ConnectionState.waiting) {
            content = _buildLoadingState();
          } else if (snapshot.hasError) {
            content = _buildEmptyStateCard(
              context,
              key: const ValueKey('monthly-error'),
              icon: Icons.error_outline,
              message: '월간 목표를 불러오는 중 오류가 발생했습니다',
            );
          } else {
            final monthlyPlans = snapshot.data ?? [];

            if (monthlyPlans.isEmpty) {
              content = _buildEmptyStateCard(
                context,
                key: const ValueKey('monthly-empty'),
                icon: Icons.flag_outlined,
                message: '이번 달 목표가 없습니다',
                exampleTitle: '예시: 영어 2권 완독',
                exampleSubtitle: '1월 10일 ~ 1월 31일',
                actionLabel: '월간 목표 추가',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MonthlyFormScreen(
                        month: DateHelper.toMonthString(today),
                      ),
                    ),
                  );
                },
              );
            } else {
              final completedCount = monthlyPlans.where((p) => p.isCompleted).length;
              final totalCount = monthlyPlans.length;

              content = Column(
                key: const ValueKey('monthly-list'),
                children: [
                  _buildProgressSummary(
                    context,
                    label: '이번 달 진행률',
                    completed: completedCount,
                    total: totalCount,
                    accentColor: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(height: 12),
                  ...monthlyPlans.take(3).map((plan) => _buildMonthlyPlanTile(context, plan)),
                ],
              );
            }
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: content,
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, DateTime today) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateHelper.toKoreanDateString(today),
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${DateHelper.getWeekdayName(today)}요일',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withAlpha(160),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '오늘의 루틴을 시작해요',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '오늘',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowDiagramCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(16),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '학습 흐름',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildFlowStep(context, '월간 목표', Icons.flag),
              _buildFlowArrow(colorScheme),
              _buildFlowStep(context, '주간 계획', Icons.view_week),
              _buildFlowArrow(colorScheme),
              _buildFlowStep(context, '일간 일정', Icons.today),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '월 → 주 → 일 순서로 계획을 쌓으면 실행이 쉬워져요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStep(BuildContext context, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowArrow(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colorScheme.outline),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPlanTile(BuildContext context, WeeklyPlan plan) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = plan.isCompleted ? colorScheme.tertiary : colorScheme.primary;
    final backgroundColor = plan.isCompleted
        ? colorScheme.tertiaryContainer.withAlpha(120)
        : colorScheme.surfaceVariant.withAlpha(80);
    final subtitleParts = <String>[
      if (plan.subject.isNotEmpty) plan.subject,
      DateHelper.toKoreanDateString(plan.date),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitleParts.join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (plan.isCompleted)
            _buildMetaChip(
              context,
              label: '완료',
              icon: Icons.check_rounded,
              color: accentColor,
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyPlanTile(BuildContext context, MonthlyPlan plan) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = plan.isCompleted ? colorScheme.tertiary : colorScheme.primary;
    final backgroundColor = plan.isCompleted
        ? colorScheme.tertiaryContainer.withAlpha(110)
        : colorScheme.surfaceVariant.withAlpha(70);

    String? dDayText;
    Color? dDayColor;
    if (plan.endDate != null && !plan.isCompleted) {
      final now = DateTime.now();
      final endDate = DateTime(plan.endDate!.year, plan.endDate!.month, plan.endDate!.day);
      final todayDate = DateTime(now.year, now.month, now.day);
      final daysLeft = endDate.difference(todayDate).inDays;

      if (daysLeft < 0) {
        dDayText = 'D+${-daysLeft}';
        dDayColor = Colors.red;
      } else if (daysLeft == 0) {
        dDayText = 'D-Day';
        dDayColor = Colors.orange;
      } else {
        dDayText = 'D-$daysLeft';
        dDayColor = daysLeft <= 3 ? Colors.orange : colorScheme.primary;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            plan.isCompleted ? Icons.check_circle_rounded : Icons.flag_circle_rounded,
            color: accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                ),
                if (plan.subject.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    plan.subject,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (dDayText != null && dDayColor != null) _buildDdayChip(dDayText, dDayColor),
              if (plan.isCompleted) ...[
                if (dDayText != null) const SizedBox(height: 6),
                _buildMetaChip(
                  context,
                  label: '완료',
                  icon: Icons.check_rounded,
                  color: accentColor,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDdayChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDailyPlanCard(
    BuildContext context,
    DailyPlan plan,
    FirestoreService firestoreService,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = plan.isCompleted ? colorScheme.tertiary : colorScheme.primary;
    final backgroundColor =
        plan.isCompleted ? colorScheme.tertiaryContainer.withAlpha(120) : colorScheme.surface;
    final completedSubtasks = plan.subtasks.where((s) => s.isCompleted).length;
    final totalSubtasks = plan.subtasks.length;
    final subtaskProgress = totalSubtasks == 0 ? 0.0 : completedSubtasks / totalSubtasks;
    final metaChips = <Widget>[];

    if (plan.subject.isNotEmpty) {
      metaChips.add(
        _buildMetaChip(
          context,
          label: plan.subject,
          icon: Icons.book_rounded,
          color: colorScheme.secondary,
        ),
      );
    }
    if (plan.tag.isNotEmpty) {
      metaChips.add(
        _buildMetaChip(
          context,
          label: plan.tag,
          icon: Icons.local_offer_rounded,
          color: colorScheme.tertiary,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withAlpha(60)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => CompletionTrackerDialog(
                plan: plan,
                firestoreService: firestoreService,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        plan.startTime,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                      Text(
                        '~',
                        style: TextStyle(
                          fontSize: 11,
                          color: accentColor.withAlpha(160),
                        ),
                      ),
                      Text(
                        plan.endTime,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                            ),
                          ),
                          if (plan.isCompleted)
                            _buildMetaChip(
                              context,
                              label: '완료',
                              icon: Icons.check_rounded,
                              color: accentColor,
                            ),
                        ],
                      ),
                      if (metaChips.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: metaChips,
                        ),
                      ],
                      if (plan.notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          plan.notes,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (totalSubtasks > 0) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.checklist, size: 14, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '$completedSubtasks/$totalSubtasks 완료',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              '${(subtaskProgress * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: subtaskProgress),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 5,
                                backgroundColor: colorScheme.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    String? exampleTitle,
    String? exampleSubtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: key,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          if (exampleTitle != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exampleTitle,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (exampleSubtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      exampleSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}
