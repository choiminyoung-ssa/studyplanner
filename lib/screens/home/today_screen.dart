import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/daily_plan.dart';
import '../../models/weekly_plan.dart';
import '../../models/monthly_plan.dart';
import '../../utils/date_utils.dart';
import '../daily/completion_tracker_dialog.dart';

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(context, today),
          const SizedBox(height: 24),

          _buildSectionHeader(
            context,
            icon: Icons.today,
            title: '오늘의 일정',
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<DailyPlan>>(
            stream: firestoreService.getDailyPlans(userId, today),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyStateCard(
                  context,
                  icon: Icons.event_available,
                  message: '오늘 예정된 일정이 없습니다',
                );
              }

              final dailyPlans = snapshot.data!;
              dailyPlans.sort((a, b) => a.startTime.compareTo(b.startTime));
              final completedCount = dailyPlans.where((p) => p.isCompleted).length;
              final totalCount = dailyPlans.length;
              final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withAlpha(120),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withAlpha(40),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up, size: 18, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              '완료 $completedCount/$totalCount',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: Colors.white,
                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...dailyPlans.map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDailyPlanCard(context, plan, firestoreService),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          _buildSectionHeader(
            context,
            icon: Icons.calendar_view_week,
            title: '이번 주 계획',
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<WeeklyPlan>>(
            stream: firestoreService.getWeeklyPlansByDateRange(
              userId,
              DateHelper.getWeekStartDate(today),
              DateHelper.getWeekEndDate(today),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyStateCard(
                  context,
                  icon: Icons.calendar_today,
                  message: '이번 주 계획이 없습니다',
                );
              }

              final weeklyPlans = snapshot.data!;
              return Column(
                children: weeklyPlans.take(5).map((plan) {
                  final accentColor = plan.isCompleted ? Colors.green : colorScheme.primary;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: plan.isCompleted ? Colors.green[50] : colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accentColor.withAlpha(60)),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withAlpha(25),
                          blurRadius: 6.0,
                          offset: const Offset(0, 2.0),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accentColor.withAlpha(30),
                        child: Icon(
                          plan.isCompleted ? Icons.check : Icons.radio_button_unchecked,
                          color: accentColor,
                        ),
                      ),
                      title: Text(
                        plan.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text(
                        DateHelper.toKoreanDateString(plan.date),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          _buildSectionHeader(
            context,
            icon: Icons.calendar_month,
            title: '이번 달 목표',
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<MonthlyPlan>>(
            stream: firestoreService.getMonthlyPlans(
              userId,
              DateHelper.toMonthString(today),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyStateCard(
                  context,
                  icon: Icons.flag_outlined,
                  message: '이번 달 목표가 없습니다',
                );
              }

              final monthlyPlans = snapshot.data!;
              final completedCount =
                  monthlyPlans.where((p) => p.isCompleted).length;
              final totalCount = monthlyPlans.length;
              final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.primaryContainer.withAlpha(180),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '진행률',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$completedCount / $totalCount 완료',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...monthlyPlans.take(3).map((plan) {
                    final accentColor = plan.isCompleted ? Colors.green : colorScheme.primary;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: plan.isCompleted ? Colors.green[50] : colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor.withAlpha(60)),
                      ),
                      child: ListTile(
                        leading: Icon(
                          plan.isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: accentColor,
                        ),
                        title: Text(
                          plan.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: plan.subject.isNotEmpty
                            ? Text(plan.subject)
                            : null,
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, DateTime today) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primary.withAlpha(200),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(40),
            blurRadius: 12.0,
            offset: const Offset(0, 4.0),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(220),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today,
              color: colorScheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateHelper.toKoreanDateString(today),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateHelper.getWeekdayName(today)}요일',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(220),
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

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildDailyPlanCard(
    BuildContext context,
    DailyPlan plan,
    FirestoreService firestoreService,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = plan.isCompleted ? Colors.green : colorScheme.primary;
    final backgroundColor = plan.isCompleted ? Colors.green[50]! : colorScheme.surface;
    final completedSubtasks = plan.subtasks.where((s) => s.isCompleted).length;
    final totalSubtasks = plan.subtasks.length;
    final subtaskProgress = totalSubtasks == 0 ? 0.0 : completedSubtasks / totalSubtasks;

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      color: backgroundColor,
      shadowColor: accentColor.withAlpha(40),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                width: 4,
                height: 78,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${plan.startTime} ~ ${plan.endTime}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (plan.isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '완료',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      plan.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (plan.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        plan.notes,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (totalSubtasks > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.checklist, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '$completedSubtasks/$totalSubtasks 완료',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(subtaskProgress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: subtaskProgress,
                          minHeight: 4,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
