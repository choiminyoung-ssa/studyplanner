import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/monthly_plan.dart';
import '../../models/weekly_plan.dart';
import '../../models/subject.dart';
import '../../utils/date_utils.dart' as app_date;
import 'monthly_form_screen.dart';

class MonthlyScreen extends StatefulWidget {
  const MonthlyScreen({super.key});

  @override
  State<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends State<MonthlyScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final FirestoreService _firestoreService = FirestoreService();
  static const List<Color> _planPalette = [
    Color(0xFF3F7CFB),
    Color(0xFF2CBFAE),
    Color(0xFF53C26B),
    Color(0xFFF4B740),
    Color(0xFFF28B57),
    Color(0xFFE75D7D),
    Color(0xFF6D7FEA),
  ];

  void _changeMonth(int delta) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + delta, 1);
      _selectedMonth = _focusedDay;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;

    if (userId == null) {
      return const Center(child: Text('로그인이 필요합니다'));
    }

    final monthString = app_date.DateHelper.toMonthString(_selectedMonth);
    final colorScheme = Theme.of(context).colorScheme;
    final firstDayOfMonth = app_date.DateHelper.getFirstDayOfMonth(_focusedDay);
    final lastDayOfMonth = app_date.DateHelper.getLastDayOfMonth(_focusedDay);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colorScheme),
            Expanded(
              child: StreamBuilder<List<MonthlyPlan>>(
                stream: _firestoreService.getMonthlyPlans(userId, monthString),
                builder: (context, monthlySnapshot) {
                  if (monthlySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (monthlySnapshot.hasError) {
                    return _buildErrorState(monthlySnapshot.error);
                  }

                  final monthlyPlans = monthlySnapshot.data ?? [];
                  final planColors = _buildPlanColorAssignments(monthlyPlans);
                  final planRangeMap = _buildPlanRangeMap(
                    monthlyPlans,
                    planColors,
                  );

                  return StreamBuilder<List<WeeklyPlan>>(
                    stream: _firestoreService.getWeeklyPlansByDateRange(
                      userId,
                      firstDayOfMonth,
                      lastDayOfMonth,
                    ),
                    builder: (context, weeklySnapshot) {
                      final weeklyPlans = weeklySnapshot.data ?? [];
                      final weeklyCountMap = _buildWeeklyCountMap(weeklyPlans);

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 1100;
                          final calendarCard = _buildCalendarCard(
                            context,
                            monthKey: monthString,
                            planRangeMap: planRangeMap,
                            weeklyCountMap: weeklyCountMap,
                            totalMonthlyPlans: monthlyPlans.length,
                            totalWeeklyPlans: weeklyPlans.length,
                          );
                          final listCard = _buildMonthlyPlanListPane(
                            context,
                            monthlyPlans: monthlyPlans,
                            planColors: planColors,
                            scrollable: isWide,
                          );

                          if (isWide) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                20,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: calendarCard),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 2, child: listCard),
                                ],
                              ),
                            );
                          }

                          return ListView(
                            key: ValueKey('monthly-$monthString'),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            children: [
                              calendarCard,
                              const SizedBox(height: 16),
                              listCard,
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPlan(monthString),
        icon: const Icon(Icons.add),
        label: const Text('목표 추가'),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    final textColor = colorScheme.onPrimaryContainer;
    final titleGroup = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '월간 목표',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '이번 달 계획을 한눈에 확인하세요',
          style: TextStyle(fontSize: 12, color: textColor.withAlpha(160)),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 420;
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleGroup,
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildMonthNavigator(colorScheme),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleGroup),
              const SizedBox(width: 12),
              _buildMonthNavigator(colorScheme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthNavigator(ColorScheme colorScheme) {
    final textColor = colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
      ),
      child: Row(
        children: [
          _buildNavIcon(
            icon: Icons.chevron_left,
            onPressed: () => _changeMonth(-1),
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            '${_selectedMonth.year}년 ${_selectedMonth.month}월',
            style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(width: 6),
          _buildNavIcon(
            icon: Icons.chevron_right,
            onPressed: () => _changeMonth(1),
            color: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 18,
      color: color,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      splashRadius: 18,
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text('오류가 발생했습니다', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(
    BuildContext context, {
    required String monthKey,
    required Map<DateTime, List<Color>> planRangeMap,
    required Map<DateTime, int> weeklyCountMap,
    required int totalMonthlyPlans,
    required int totalWeeklyPlans,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 520;
    final rowHeight = isCompact ? 60.0 : 72.0;
    final cellMargin = isCompact
        ? const EdgeInsets.all(3)
        : const EdgeInsets.all(4);
    final markerTopPadding = isCompact ? 4.0 : 6.0;
    final markerBarWidth = isCompact ? 16.0 : 20.0;
    final markerBarHeight = isCompact ? 2.5 : 3.0;
    final markerBarSpacing = isCompact ? 1.5 : 2.0;

    final calendar = TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerVisible: false,
      rowHeight: rowHeight,
      sixWeekMonthsEnforced: false,
      availableGestures: AvailableGestures.horizontalSwipe,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle:
            textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ) ??
            const TextStyle(fontWeight: FontWeight.w600),
        weekendStyle:
            textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ) ??
            const TextStyle(fontWeight: FontWeight.w600),
      ),
      calendarStyle: CalendarStyle(
        isTodayHighlighted: true,
        outsideDaysVisible: true,
        cellMargin: cellMargin,
        defaultDecoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(70)),
        ),
        outsideDecoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withAlpha(80),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(40)),
        ),
        todayDecoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withAlpha(140)),
        ),
        selectedDecoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        defaultTextStyle:
            textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ) ??
            const TextStyle(fontWeight: FontWeight.w600),
        weekendTextStyle:
            textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ) ??
            const TextStyle(fontWeight: FontWeight.w600),
        outsideTextStyle:
            textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withAlpha(140),
            ) ??
            const TextStyle(),
        todayTextStyle:
            textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onPrimaryContainer,
            ) ??
            const TextStyle(fontWeight: FontWeight.w700),
        selectedTextStyle:
            textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onPrimary,
            ) ??
            const TextStyle(fontWeight: FontWeight.w700),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
          _selectedMonth = DateTime(focusedDay.year, focusedDay.month, 1);
        });
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
          _selectedMonth = DateTime(focusedDay.year, focusedDay.month, 1);
        });
      },
      eventLoader: (day) =>
          _buildCalendarMarkers(day, planRangeMap, weeklyCountMap),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isEmpty) {
            return const SizedBox.shrink();
          }

          final planMarkers = events.whereType<_PlanMarker>().toList();
          final weeklyCount = events.whereType<_WeeklyCountMarker>().fold<int>(
            0,
            (sum, marker) => sum + marker.count,
          );

          if (planMarkers.isEmpty && weeklyCount == 0) {
            return const SizedBox.shrink();
          }

          const maxBars = 3;
          final extraBars = planMarkers.length - maxBars;

          return Padding(
            padding: EdgeInsets.only(top: markerTopPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (planMarkers.isNotEmpty)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...planMarkers
                          .take(maxBars)
                          .map(
                            (marker) => Container(
                              margin: EdgeInsets.only(bottom: markerBarSpacing),
                              width: markerBarWidth,
                              height: markerBarHeight,
                              decoration: BoxDecoration(
                                color: marker.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      if (extraBars > 0)
                        Text(
                          '+$extraBars',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            fontSize: isCompact ? 9 : null,
                          ),
                        ),
                    ],
                  ),
                if (weeklyCount > 0) ...[
                  if (planMarkers.isNotEmpty) const SizedBox(height: 2),
                  _buildWeeklyCountBadge(
                    context,
                    weeklyCount,
                    dense: isCompact,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
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
          Row(
            children: [
              Text(
                '캘린더',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _buildCountChip(context, label: '목표', count: totalMonthlyPlans),
              const SizedBox(width: 6),
              _buildCountChip(
                context,
                label: '주간',
                count: totalWeeklyPlans,
                accent: colorScheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey('calendar-view-$monthKey'),
              child: calendar,
            ),
          ),
          const SizedBox(height: 12),
          _buildCalendarLegend(context),
        ],
      ),
    );

    return _buildFadeSlide(card, delay: 0, key: ValueKey('calendar-$monthKey'));
  }

  Widget _buildMonthlyPlanListPane(
    BuildContext context, {
    required List<MonthlyPlan> monthlyPlans,
    required Map<String, Color> planColors,
    required bool scrollable,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sortedPlans = [...monthlyPlans]
      ..sort((a, b) {
        final aDate = a.startDate ?? a.endDate ?? a.createdAt;
        final bDate = b.startDate ?? b.endDate ?? b.createdAt;
        return aDate.compareTo(bDate);
      });

    final completedCount = sortedPlans.where((plan) => plan.isCompleted).length;

    final header = Row(
      children: [
        Text(
          '이번 달 목표',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        _buildCountChip(
          context,
          label: '완료',
          count: completedCount,
          accent: colorScheme.tertiary,
        ),
        const Spacer(),
        Text(
          '${sortedPlans.length}개',
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    Widget content;
    if (sortedPlans.isEmpty) {
      content = _buildEmptyPlansState(
        context,
        month: app_date.DateHelper.toMonthString(_selectedMonth),
      );
    } else if (scrollable) {
      content = ListView.separated(
        itemCount: sortedPlans.length,
        padding: const EdgeInsets.only(top: 4),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final plan = sortedPlans[index];
          final accentColor = planColors[plan.id] ?? colorScheme.primary;
          return _buildMonthlyPlanItem(
            context,
            plan: plan,
            accentColor: accentColor,
            index: index,
          );
        },
      );
    } else {
      content = Column(
        children: [
          const SizedBox(height: 4),
          ...sortedPlans.asMap().entries.map((entry) {
            final index = entry.key;
            final plan = entry.value;
            final accentColor = planColors[plan.id] ?? colorScheme.primary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMonthlyPlanItem(
                context,
                plan: plan,
                accentColor: accentColor,
                index: index,
              ),
            );
          }),
        ],
      );
    }

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
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
          header,
          const SizedBox(height: 12),
          if (scrollable) Expanded(child: content) else content,
        ],
      ),
    );

    return _buildFadeSlide(card, delay: 80);
  }

  Widget _buildMonthlyPlanItem(
    BuildContext context, {
    required MonthlyPlan plan,
    required Color accentColor,
    required int index,
  }) {
    final child = plan.subjectId != null
        ? StreamBuilder<Subject?>(
            stream: _firestoreService
                .getSubjectById(plan.subjectId!)
                .asStream(),
            builder: (context, snapshot) {
              return _buildMonthlyPlanTile(
                context,
                plan: plan,
                accentColor: accentColor,
                subject: snapshot.data,
              );
            },
          )
        : _buildMonthlyPlanTile(context, plan: plan, accentColor: accentColor);

    return _buildFadeSlide(child, delay: 120 + (index * 40));
  }

  Widget _buildMonthlyPlanTile(
    BuildContext context, {
    required MonthlyPlan plan,
    required Color accentColor,
    Subject? subject,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rangeText = _formatPlanRange(plan);
    final now = _normalizeDate(DateTime.now());
    final progress = _getPlanProgress(plan, now);
    final statusLabel = _getPlanStatusLabel(progress);
    final statusColor = _getPlanStatusColor(progress, accentColor, colorScheme);
    final ddayText = _getPlanDdayText(plan, now, progress);
    final subjectName = subject?.name ?? plan.subject;
    final subjectIcon = subject != null
        ? SubjectIconHelper.getIcon(subject.icon)
        : null;
    final subjectColor = subject != null
        ? Color(int.parse(subject.color.replaceFirst('#', '0xFF')))
        : accentColor;
    final subtaskTotal = plan.subtasks.length;
    final subtaskCompleted = plan.subtasks.where((s) => s.isCompleted).length;
    final subtaskProgress = subtaskTotal == 0
        ? 0.0
        : subtaskCompleted / subtaskTotal;

    return Material(
      color: plan.isCompleted
          ? colorScheme.surfaceVariant.withAlpha(120)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showPlanDetails(plan),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
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
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: plan.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          Checkbox(
                            value: plan.isCompleted,
                            onChanged: (value) async {
                              final next = value ?? false;
                              await _firestoreService
                                  .updateMonthlyPlan(plan.id, {
                                    'isCompleted': next,
                                    'completedAt': next ? DateTime.now() : null,
                                  });
                            },
                            activeColor: accentColor,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editPlan(plan);
                              } else if (value == 'delete') {
                                _deletePlan(plan);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('수정'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text(
                                      '삭제',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (subtaskTotal > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.checklist, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '세부 목표 $subtaskCompleted/$subtaskTotal',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: subtaskProgress,
                            minHeight: 6,
                            backgroundColor: colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              accentColor,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.date_range,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rangeText,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (statusLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _buildStatusChip(
                              context,
                              label: statusLabel,
                              color: statusColor,
                            ),
                          ],
                          if (ddayText != null) ...[
                            const SizedBox(width: 6),
                            _buildStatusChip(
                              context,
                              label: ddayText,
                              color: statusColor,
                            ),
                          ],
                        ],
                      ),
                      if (subjectName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (subjectIcon != null) ...[
                              Icon(subjectIcon, size: 14, color: subjectColor),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              subjectName,
                              style: textTheme.labelSmall?.copyWith(
                                color: subjectColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (plan.notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          plan.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlansState(BuildContext context, {required String month}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Column(
        children: [
          Icon(Icons.event_note, size: 40, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            '이번 달 목표가 없습니다',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '예시: 영어 2권 완독',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _addPlan(month),
            icon: const Icon(Icons.add),
            label: const Text('월간 목표 추가'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarLegend(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Wrap(
          spacing: 4,
          children: _planPalette
              .take(3)
              .map(
                (color) => Container(
                  width: 12,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(width: 6),
        Text(
          '목표 기간',
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        _buildWeeklyCountBadge(context, 3),
        const SizedBox(width: 6),
        Text(
          '주간 일정 수',
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyCountBadge(
    BuildContext context,
    int count, {
    bool dense = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 4 : 6,
        vertical: dense ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(dense ? 6 : 8),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSecondaryContainer,
          fontSize: dense ? 9 : null,
        ),
      ),
    );
  }

  Widget _buildCountChip(
    BuildContext context, {
    required String label,
    required int count,
    Color? accent,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipColor = accent ?? colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withAlpha(80)),
      ),
      child: Text(
        '$label $count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: chipColor,
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFadeSlide(Widget child, {int delay = 0, Key? key}) {
    final baseDuration = 360;
    final totalDuration = baseDuration + delay;
    final start = delay / totalDuration;

    return TweenAnimationBuilder<double>(
      key: key,
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

  Map<String, Color> _buildPlanColorAssignments(List<MonthlyPlan> plans) {
    final map = <String, Color>{};
    for (final plan in plans) {
      map[plan.id] = _colorForPlanId(plan.id);
    }
    return map;
  }

  Map<DateTime, List<Color>> _buildPlanRangeMap(
    List<MonthlyPlan> plans,
    Map<String, Color> planColors,
  ) {
    final map = <DateTime, List<Color>>{};

    for (final plan in plans) {
      final range = _getPlanRange(plan);
      if (range == null) continue;

      var current = _normalizeDate(range.start);
      final end = _normalizeDate(range.end);
      final color = planColors[plan.id] ?? _colorForPlanId(plan.id);

      while (!current.isAfter(end)) {
        map.putIfAbsent(current, () => []).add(color);
        current = current.add(const Duration(days: 1));
      }
    }

    return map;
  }

  Map<DateTime, int> _buildWeeklyCountMap(List<WeeklyPlan> weeklyPlans) {
    final map = <DateTime, int>{};
    for (final plan in weeklyPlans) {
      final key = _normalizeDate(plan.date);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  List<_CalendarMarker> _buildCalendarMarkers(
    DateTime day,
    Map<DateTime, List<Color>> planRangeMap,
    Map<DateTime, int> weeklyCountMap,
  ) {
    final key = _normalizeDate(day);
    final markers = <_CalendarMarker>[];
    final colors = planRangeMap[key] ?? [];

    for (final color in colors) {
      markers.add(_PlanMarker(color));
    }

    final weeklyCount = weeklyCountMap[key] ?? 0;
    if (weeklyCount > 0) {
      markers.add(_WeeklyCountMarker(weeklyCount));
    }

    return markers;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  _PlanRange? _getPlanRange(MonthlyPlan plan) {
    if (plan.startDate == null && plan.endDate == null) {
      return null;
    }

    final start = plan.startDate ?? plan.endDate!;
    final end = plan.endDate ?? plan.startDate!;

    if (start.isAfter(end)) {
      return _PlanRange(end, start);
    }
    return _PlanRange(start, end);
  }

  Color _colorForPlanId(String id) {
    var hash = 0;
    for (final code in id.codeUnits) {
      hash = (hash * 37 + code) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    final saturation = 0.55 + ((hash >> 3) % 25) / 100;
    final lightness = 0.45 + ((hash >> 5) % 20) / 100;
    return HSLColor.fromAHSL(
      1,
      hue,
      saturation.clamp(0.45, 0.85),
      lightness.clamp(0.4, 0.65),
    ).toColor();
  }

  String _formatPlanRange(MonthlyPlan plan) {
    if (plan.startDate == null && plan.endDate == null) {
      return '기간 미지정';
    }

    final start = plan.startDate ?? plan.endDate!;
    final end = plan.endDate ?? plan.startDate!;
    final startDate = _normalizeDate(start);
    final endDate = _normalizeDate(end);

    if (startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day) {
      return '${startDate.month}.${startDate.day}';
    }

    return '${startDate.month}.${startDate.day} ~ ${endDate.month}.${endDate.day}';
  }

  _PlanRange? _resolvePlanRange(MonthlyPlan plan) {
    final range = _getPlanRange(plan);
    if (range != null) return range;
    final parts = plan.month.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return null;
    return _PlanRange(DateTime(year, month, 1), DateTime(year, month + 1, 0));
  }

  _PlanProgress _getPlanProgress(MonthlyPlan plan, DateTime today) {
    if (plan.isCompleted) return _PlanProgress.completed;
    final range = _resolvePlanRange(plan);
    if (range == null) return _PlanProgress.upcoming;
    final start = _normalizeDate(range.start);
    final end = _normalizeDate(range.end);
    if (today.isBefore(start)) return _PlanProgress.upcoming;
    if (today.isAfter(end)) return _PlanProgress.ended;
    return _PlanProgress.ongoing;
  }

  String _getPlanStatusLabel(_PlanProgress progress) {
    switch (progress) {
      case _PlanProgress.completed:
        return '완료';
      case _PlanProgress.ongoing:
        return '진행중';
      case _PlanProgress.ended:
        return '기간 종료';
      case _PlanProgress.upcoming:
      default:
        return '진행전';
    }
  }

  Color _getPlanStatusColor(
    _PlanProgress progress,
    Color accent,
    ColorScheme colorScheme,
  ) {
    switch (progress) {
      case _PlanProgress.completed:
        return accent;
      case _PlanProgress.ongoing:
        return accent;
      case _PlanProgress.ended:
        return colorScheme.outline;
      case _PlanProgress.upcoming:
      default:
        return colorScheme.secondary;
    }
  }

  String? _getPlanDdayText(
    MonthlyPlan plan,
    DateTime today,
    _PlanProgress progress,
  ) {
    if (progress == _PlanProgress.completed ||
        progress == _PlanProgress.ended) {
      return null;
    }
    final range = _resolvePlanRange(plan);
    if (range == null) return null;
    final target = progress == _PlanProgress.ongoing ? range.end : range.start;
    final targetDate = _normalizeDate(target);
    final diff = targetDate.difference(today).inDays;
    if (diff == 0) return 'D-day';
    if (diff > 0) return 'D-$diff';
    return 'D+${diff.abs()}';
  }

  void _addPlan(String month) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MonthlyFormScreen(month: month)),
    );
  }

  // 상세 정보 다이얼로그 표시
  void _showPlanDetails(MonthlyPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                plan.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (plan.isCompleted)
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  final now = _normalizeDate(DateTime.now());
                  final progress = _getPlanProgress(plan, now);
                  final statusLabel = _getPlanStatusLabel(progress);
                  final accent = _colorForPlanId(plan.id);
                  final statusColor = _getPlanStatusColor(
                    progress,
                    accent,
                    Theme.of(context).colorScheme,
                  );
                  final ddayText = _getPlanDdayText(plan, now, progress);

                  return Row(
                    children: [
                      const Icon(Icons.timelapse, size: 18),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                        context,
                        label: statusLabel,
                        color: statusColor,
                      ),
                      if (ddayText != null) ...[
                        const SizedBox(width: 6),
                        _buildStatusChip(
                          context,
                          label: ddayText,
                          color: statusColor,
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              // 월
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Text(plan.month, style: const TextStyle(fontSize: 15)),
                ],
              ),
              if (plan.relatedWeeklyIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.link, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '연결된 주간 목표 ${plan.relatedWeeklyIds.length}개',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // 과목
              if (plan.subjectId != null)
                StreamBuilder<Subject?>(
                  stream: _firestoreService
                      .getSubjectById(plan.subjectId!)
                      .asStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final subject = snapshot.data!;
                      final color = Color(
                        int.parse(subject.color.replaceFirst('#', '0xFF')),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              SubjectIconHelper.getIcon(subject.icon),
                              size: 18,
                              color: color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              subject.name,
                              style: TextStyle(
                                fontSize: 15,
                                color: color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

              // 페이지 범위
              if (plan.pageRanges.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_stories, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: plan.pageRanges
                            .map(
                              (range) => Chip(
                                label: Text(
                                  'p.$range',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 0,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // 메모
              if (plan.notes.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan.notes,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _editPlan(plan);
            },
            icon: const Icon(Icons.edit),
            label: const Text('수정'),
          ),
        ],
      ),
    );
  }

  void _editPlan(MonthlyPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthlyFormScreen(month: plan.month, plan: plan),
      ),
    );
  }

  void _deletePlan(MonthlyPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('목표 삭제'),
        content: const Text('정말 이 목표를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _firestoreService.deleteMonthlyPlan(plan.id);
                if (!mounted) return;
                navigator.pop();
              } catch (e) {
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('오류: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _PlanRange {
  final DateTime start;
  final DateTime end;

  const _PlanRange(this.start, this.end);
}

enum _PlanProgress { upcoming, ongoing, ended, completed }

abstract class _CalendarMarker {
  const _CalendarMarker();
}

class _PlanMarker extends _CalendarMarker {
  final Color color;

  const _PlanMarker(this.color);
}

class _WeeklyCountMarker extends _CalendarMarker {
  final int count;

  const _WeeklyCountMarker(this.count);
}
