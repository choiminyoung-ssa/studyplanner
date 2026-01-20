import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/weekly_plan.dart';
import '../../models/monthly_plan.dart';
import '../../models/subject.dart';
import '../../utils/date_utils.dart';
import 'weekly_form_screen.dart';
import '../../widgets/fade_sliver_header.dart';

class WeeklyScreen extends StatefulWidget {
  const WeeklyScreen({super.key});

  @override
  State<WeeklyScreen> createState() => _WeeklyScreenState();
}

class _WeeklyScreenState extends State<WeeklyScreen> {
  DateTime _selectedWeek = DateTime.now();
  final FirestoreService _firestoreService = FirestoreService();
  static const double _minBoardWidth = 980;

  void _changeWeek(int weeks) {
    setState(() {
      _selectedWeek = _selectedWeek.add(Duration(days: weeks * 7));
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;

    if (userId == null) {
      return const Center(child: Text('로그인이 필요합니다'));
    }

    final weekStart = DateHelper.getWeekStartDate(_selectedWeek);
    final weekEnd = DateHelper.getWeekEndDate(_selectedWeek);
    final weekDates = DateHelper.getWeekDates(_selectedWeek);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        top: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            FadeSliverHeader(
              maxHeight: 120,
              child: _buildHeader(weekStart, weekEnd, colorScheme),
            ),
          ],
          body: StreamBuilder<List<WeeklyPlan>>(
            stream: _firestoreService.getWeeklyPlansByDateRange(
              userId,
              weekStart,
              weekEnd,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error);
              }

              final allPlans = snapshot.data ?? [];

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < _minBoardWidth;
                  if (isCompact) {
                    return _buildCompactWeekList(
                      weekStart: weekStart,
                      weekEnd: weekEnd,
                      weekDates: weekDates,
                      allPlans: allPlans,
                    );
                  }
                  return _buildWeekBoard(
                    weekStart: weekStart,
                    weekEnd: weekEnd,
                    weekDates: weekDates,
                    allPlans: allPlans,
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPlanForDate(DateTime.now(), weekStart, weekEnd),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('계획 추가'),
      ),
    );
  }

  void _goToCurrentWeek() {
    setState(() {
      _selectedWeek = DateTime.now();
    });
  }

  Widget _buildHeader(DateTime weekStart, DateTime weekEnd, ColorScheme colorScheme) {
    final textColor = colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '주간 목표',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _goToCurrentWeek,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  foregroundColor: textColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                icon: const Icon(Icons.today, size: 16),
                label: const Text('이번 주'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildNavButton(
                icon: Icons.chevron_left,
                onPressed: () => _changeWeek(-1),
                foreground: textColor,
                background: colorScheme.surface.withAlpha(200),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withAlpha(230),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${DateHelper.toMonthString(weekStart)} 주간',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatShortDate(weekStart)} ~ ${_formatShortDate(weekEnd)}',
                        style: TextStyle(fontSize: 10, color: textColor.withAlpha(180)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildNavButton(
                icon: Icons.chevron_right,
                onPressed: () => _changeWeek(1),
                foreground: textColor,
                background: colorScheme.surface.withAlpha(200),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color foreground,
    required Color background,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: foreground),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    if (error is FirestoreIndexException) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF8C98A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Text(
                    '데이터 조회 오류',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('이 화면을 보려면 Firestore 복합 인덱스가 필요합니다.'),
              if (error.indexUrl != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  error.indexUrl!,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => launchUrlString(error.indexUrl!),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('인덱스 생성 페이지 열기'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Center(child: Text('오류: $error'));
  }

  Widget _buildCompactWeekList({
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<DateTime> weekDates,
    required List<WeeklyPlan> allPlans,
  }) {
    return ListView.separated(
      primary: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: weekDates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final date = weekDates[index];
        final dayPlans = allPlans.where((plan) => DateHelper.isSameDay(plan.date, date)).toList();
        final isToday = DateHelper.isToday(date);

        return _buildDayCard(
          date: date,
          isToday: isToday,
          plans: dayPlans,
          weekStart: weekStart,
          weekEnd: weekEnd,
          compact: true,
        );
      },
    );
  }

  Widget _buildWeekBoard({
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<DateTime> weekDates,
    required List<WeeklyPlan> allPlans,
  }) {
    // 하루 칸의 넓이를 280픽셀로 확대 (기존보다 훨씬 넓음)
    const dayCardWidth = 280.0;
    const cardSpacing = 12.0;

    return SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      scrollDirection: Axis.horizontal, // 가로 스크롤 활성화
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(weekDates.length, (index) {
          final date = weekDates[index];
          final dayPlans = allPlans.where((plan) => DateHelper.isSameDay(plan.date, date)).toList();
          final isToday = DateHelper.isToday(date);

          return SizedBox(
            width: dayCardWidth,
            child: Padding(
              padding: EdgeInsets.only(right: index == weekDates.length - 1 ? 0 : cardSpacing),
              child: _buildDayCard(
                date: date,
                isToday: isToday,
                plans: dayPlans,
                weekStart: weekStart,
                weekEnd: weekEnd,
                compact: false,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayCard({
    required DateTime date,
    required bool isToday,
    required List<WeeklyPlan> plans,
    required DateTime weekStart,
    required DateTime weekEnd,
    required bool compact,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDayHeader(
            date: date,
            isToday: isToday,
            compact: compact,
          ),
          const SizedBox(height: 12),
          if (plans.isEmpty)
            _buildEmptyDayPlaceholder(
              compact: compact,
              onAdd: () => _addPlanForDate(date, weekStart, weekEnd),
            )
          else
            Column(
              children: plans
                  .map((plan) => _buildPlanCard(plan, weekStart, weekEnd))
                  .toList(),
            ),
          if (plans.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildAddPlanButton(
              compact: compact,
              onAdd: () => _addPlanForDate(date, weekStart, weekEnd),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayHeader({
    required DateTime date,
    required bool isToday,
    required bool compact,
  }) {
    final dayLabel = DateHelper.getWeekdayName(date);
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
    final headerColor = isToday ? accent.withAlpha(28) : colorScheme.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday ? accent.withAlpha(120) : colorScheme.outlineVariant.withAlpha(120),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dayLabel요일',
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatShortDate(date),
                  style: TextStyle(
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withAlpha(20),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '오늘',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayPlaceholder({
    required bool compact,
    required VoidCallback onAdd,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(130),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.grey[500], size: compact ? 22 : 26),
            const SizedBox(height: 6),
            Text(
              '일정을 추가해보세요',
              style: TextStyle(color: Colors.grey[600], fontSize: compact ? 12 : 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '예시: 수학 문제집 2챕터',
                style: TextStyle(fontSize: compact ? 10 : 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPlanButton({
    required bool compact,
    required VoidCallback onAdd,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton.tonalIcon(
      onPressed: onAdd,
      style: FilledButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
        backgroundColor: colorScheme.primary.withAlpha(20),
        foregroundColor: colorScheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      icon: const Icon(Icons.add),
      label: const Text('일정 추가'),
    );
  }

  Widget _buildPlanCard(WeeklyPlan plan, DateTime weekStart, DateTime weekEnd) {
    if (plan.subjectId != null) {
      return StreamBuilder<Subject?>(
        stream: _firestoreService.getSubjectById(plan.subjectId!).asStream(),
        builder: (context, snapshot) {
          return _buildPlanCardContent(plan, weekStart, weekEnd, snapshot.data);
        },
      );
    }
    return _buildPlanCardContent(plan, weekStart, weekEnd, null);
  }

  Widget _buildPlanCardContent(
    WeeklyPlan plan,
    DateTime weekStart,
    DateTime weekEnd,
    Subject? subject,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final subjectName = subject?.name ?? (plan.subject.isNotEmpty ? plan.subject : null);
    final subjectColor = subject != null
        ? Color(int.parse(subject.color.replaceFirst('#', '0xFF')))
        : colorScheme.primary;
    final iconData = plan.isCompleted
        ? Icons.check_rounded
        : SubjectIconHelper.getIcon(subject?.icon ?? 'book');
    final metaPieces = <String>[];
    if (subjectName != null) metaPieces.add(subjectName);
    if (plan.pageRanges.isNotEmpty) {
      metaPieces.add('p.${plan.pageRanges.join(', ')}');
    }
    final metaText = metaPieces.join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showPlanDetails(plan, weekStart, weekEnd),
        onLongPress: () => _showPlanOptions(plan, weekStart, weekEnd),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: plan.isCompleted ? const Color(0xFFEAF7EE) : colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: plan.isCompleted
                  ? const Color(0xFFB7E4C7)
                  : colorScheme.outlineVariant.withAlpha(140),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: subjectColor.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: subjectColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (metaText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        metaText,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (plan.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        plan.notes,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Checkbox(
                value: plan.isCompleted,
                onChanged: (_) => _togglePlanComplete(plan),
                activeColor: colorScheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatShortDate(DateTime date) {
    return '${date.month}월 ${date.day}일';
  }

  void _addPlanForDate(DateTime date, DateTime weekStart, DateTime weekEnd) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeeklyFormScreen(
          date: date,
          weekStart: weekStart,
          weekEnd: weekEnd,
        ),
      ),
    );
  }

  Future<void> _togglePlanComplete(WeeklyPlan plan) async {
    final next = !plan.isCompleted;
    await _firestoreService.updateWeeklyPlan(
      plan.id,
      {
        'isCompleted': next,
        'completedAt': next ? DateTime.now() : null,
      },
    );
  }

  // 상세 정보 다이얼로그 표시
  void _showPlanDetails(WeeklyPlan plan, DateTime weekStart, DateTime weekEnd) {
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
              // 날짜
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    DateHelper.toDateString(plan.date),
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
              if (plan.parentMonthlyId != null) ...[
                const SizedBox(height: 12),
                FutureBuilder<MonthlyPlan?>(
                  future: _firestoreService.getParentMonthlyPlan(plan.parentMonthlyId!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox.shrink();
                    }
                    final parent = snapshot.data!;
                    return Row(
                      children: [
                        const Icon(Icons.link, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '상위 월간 목표: ${parent.title}',
                            style: const TextStyle(fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),

              // 과목
              if (plan.subjectId != null)
                StreamBuilder<Subject?>(
                  stream: _firestoreService.getSubjectById(plan.subjectId!).asStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final subject = snapshot.data!;
                      final color = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
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
                        children: plan.pageRanges.map((range) => Chip(
                          label: Text('p.$range', style: const TextStyle(fontSize: 12)),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
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
              _editPlan(plan, weekStart, weekEnd);
            },
            icon: const Icon(Icons.edit),
            label: const Text('수정'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeletePlan(plan);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete),
            label: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _editPlan(WeeklyPlan plan, DateTime weekStart, DateTime weekEnd) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeeklyFormScreen(
          date: plan.date,
          weekStart: weekStart,
          weekEnd: weekEnd,
          plan: plan,
        ),
      ),
    );
  }

  void _confirmDeletePlan(WeeklyPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주간 일정 삭제'),
        content: const Text('정말 이 일정을 삭제하시겠습니까?'),
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
                if (plan.parentMonthlyId != null && plan.parentMonthlyId!.isNotEmpty) {
                  await _firestoreService.removeWeeklyIdFromMonthly(plan.parentMonthlyId!, plan.id);
                }
                await _firestoreService.deleteWeeklyPlan(plan.id);
                if (!mounted) return;
                navigator.pop();
              } catch (e) {
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
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

  // 일정 옵션 메뉴 표시 (롱프레스)
  void _showPlanOptions(WeeklyPlan plan, DateTime weekStart, DateTime weekEnd) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 제목
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                plan.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            // 상세보기
            ListTile(
              leading: Icon(Icons.info_outline, color: colorScheme.primary),
              title: const Text('상세보기'),
              onTap: () {
                Navigator.pop(context);
                _showPlanDetails(plan, weekStart, weekEnd);
              },
            ),
            // 내일로 이동 (미완료 일정만)
            if (!plan.isCompleted) ...[
              ListTile(
                leading: Icon(Icons.fast_forward, color: colorScheme.secondary),
                title: const Text('내일로 이동'),
                subtitle: Text(
                  '${DateHelper.toKoreanDateString(plan.date.add(const Duration(days: 1)))}로 이동',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _movePlanToTomorrow(plan);
                },
              ),
            ],
            // 수정
            ListTile(
              leading: Icon(Icons.edit_outlined, color: colorScheme.tertiary),
              title: const Text('수정하기'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WeeklyFormScreen(
                      date: plan.date,
                      weekStart: weekStart,
                      weekEnd: weekEnd,
                      plan: plan,
                    ),
                  ),
                );
              },
            ),
            // 삭제
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('삭제하기', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletePlan(plan);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // 내일로 이동
  Future<void> _movePlanToTomorrow(WeeklyPlan plan) async {
    final tomorrow = plan.date.add(const Duration(days: 1));

    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내일로 이동'),
        content: Text(
          '이 일정을 ${DateHelper.toKoreanDateString(tomorrow)}로 이동하시겠습니까?\n\n'
          '일정: ${plan.title}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('이동'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Firestore에서 날짜 업데이트
      await _firestoreService.updateWeeklyPlan(
        plan.id,
        {'date': tomorrow},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${plan.title}"을(를) 내일로 이동했습니다'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 이동 실패: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
