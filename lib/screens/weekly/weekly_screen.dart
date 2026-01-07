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

class WeeklyScreen extends StatefulWidget {
  const WeeklyScreen({super.key});

  @override
  State<WeeklyScreen> createState() => _WeeklyScreenState();
}

class _WeeklyScreenState extends State<WeeklyScreen> {
  DateTime _selectedWeek = DateTime.now();
  final FirestoreService _firestoreService = FirestoreService();

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

    return Scaffold(
      body: Column(
        children: [
          // 주 선택기
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeWeek(-1),
                    ),
                    Text(
                      '${DateHelper.toMonthString(weekStart)} 주간',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeWeek(1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${DateHelper.toDateString(weekStart)} ~ ${DateHelper.toDateString(weekEnd)}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),

          // 1주 캘린더 (월~일)
          Expanded(
            child: StreamBuilder<List<WeeklyPlan>>(
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
                  final err = snapshot.error;
                  if (err is FirestoreIndexException) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('데이터 조회 오류', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('이 쿼리를 실행하려면 Firestore에 복합 인덱스가 필요합니다.'),
                              const SizedBox(height: 8),
                              if (err.indexUrl != null) ...[
                                SelectableText(err.indexUrl!),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => launchUrlString(err.indexUrl!),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('인덱스 생성 페이지 열기'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Center(child: Text('오류: ${snapshot.error}'));
                }

                final allPlans = snapshot.data ?? [];

                final screenSize = MediaQuery.of(context).size;
                final isNarrowPortrait = screenSize.width < 420 && screenSize.width < screenSize.height;

                if (isNarrowPortrait) {
                  // Vertical day list for narrow/phone portrait screens
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 7,
                    itemBuilder: (context, dayIndex) {
                      final date = weekDates[dayIndex];
                      final isToday = DateHelper.isToday(date);
                      final dayPlans = allPlans.where((plan) => DateHelper.isSameDay(plan.date, date)).toList();

                      return GestureDetector(
                        onTap: () => _addPlanForDate(date, weekStart, weekEnd),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                child: Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateHelper.getWeekdayName(date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isToday ? Colors.white : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${date.day}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isToday ? Colors.white : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: Colors.white),
                                      onPressed: () => _addPlanForDate(date, weekStart, weekEnd),
                                    ),
                                  ],
                                ),
                              ),

                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: dayPlans.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                          child: Text('일정이 없습니다', style: TextStyle(color: Colors.grey)),
                                        ),
                                      )
                                    : Column(
                                        children: dayPlans.map((plan) {
                                          return GestureDetector(
                                            onTap: () => _showPlanDetails(plan, weekStart, weekEnd),
                                            child: Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: plan.subjectId != null
                                                  ? StreamBuilder<Subject?>(
                                                      stream: _firestoreService.getSubjectById(plan.subjectId!).asStream(),
                                                      builder: (context, snapshot) {
                                                        Color? subjectColor;
                                                        Widget? subjectIcon;

                                                        if (snapshot.hasData && snapshot.data != null) {
                                                          final subject = snapshot.data!;
                                                          subjectColor = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
                                                          subjectIcon = Icon(
                                                            SubjectIconHelper.getIcon(subject.icon),
                                                            size: 14,
                                                            color: subjectColor,
                                                          );
                                                        }

                                                        return Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                          decoration: BoxDecoration(
                                                            gradient: plan.isCompleted
                                                                ? LinearGradient(
                                                                    colors: [Colors.green[50]!, Colors.green[100]!],
                                                                    begin: Alignment.topLeft,
                                                                    end: Alignment.bottomRight,
                                                                  )
                                                                : LinearGradient(
                                                                    colors: [
                                                                      Theme.of(context).colorScheme.primaryContainer,
                                                                      Theme.of(context).colorScheme.primaryContainer.withAlpha(179),
                                                                    ],
                                                                    begin: Alignment.topLeft,
                                                                    end: Alignment.bottomRight,
                                                                  ),
                                                            borderRadius: BorderRadius.circular(6),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: (subjectColor ?? Colors.grey).withAlpha(51),
                                                                blurRadius: 4.0,
                                                                offset: const Offset(0, 1.0),
                                                              ),
                                                            ],
                                                            border: subjectColor != null
                                                                ? Border(left: BorderSide(color: subjectColor, width: 3))
                                                                : Border.all(
                                                                    color: plan.isCompleted
                                                                        ? Colors.green.withAlpha(128)
                                                                        : Theme.of(context).colorScheme.primary.withAlpha(77),
                                                                    width: 1,
                                                                  ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              if (plan.isCompleted)
                                                                Icon(Icons.check_circle, size: 14, color: Colors.green[700])
                                                              else if (subjectIcon != null) ...[
                                                                subjectIcon,
                                                                const SizedBox(width: 8),
                                                              ],
                                                              Expanded(
                                                                child: Text(
                                                                  plan.title,
                                                                  style: TextStyle(
                                                                    fontSize: 14,
                                                                    fontWeight: FontWeight.w500,
                                                                    decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                                                                  ),
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    )
                                                  : Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: plan.isCompleted
                                                            ? Colors.green[100]
                                                            : Theme.of(context).colorScheme.primaryContainer,
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        plan.title,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 14, // 7일 x 2줄 (날짜 + 내용)
                  itemBuilder: (context, index) {
                    if (index < 7) {
                      // 첫 번째 줄: 날짜 헤더
                      final date = weekDates[index];
                      final isToday = DateHelper.isToday(date);

                      return GestureDetector(
                        onTap: () => _addPlanForDate(date, weekStart, weekEnd),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isToday
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateHelper.getWeekdayName(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? Colors.white : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? Colors.white : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      // 두 번째 줄: 해당 날짜의 계획 목록
                      final dayIndex = index - 7;
                      final date = weekDates[dayIndex];
                      final dayPlans = allPlans
                          .where((plan) => DateHelper.isSameDay(plan.date, date))
                          .toList();

                      return GestureDetector(
                        onTap: () => _addPlanForDate(date, weekStart, weekEnd),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: dayPlans.isEmpty
                              ? const Center(
                                  child: Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(4),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: dayPlans.length,
                                  itemBuilder: (context, i) {
                                    final plan = dayPlans[i];
                                    return GestureDetector(
                                      onTap: () => _showPlanDetails(plan, weekStart, weekEnd),
                                      child: plan.subjectId != null
                                          ? StreamBuilder<Subject?>(
                                              stream: _firestoreService.getSubjectById(plan.subjectId!).asStream(),
                                              builder: (context, snapshot) {
                                                Color? subjectColor;
                                                Widget? subjectIcon;

                                                if (snapshot.hasData && snapshot.data != null) {
                                                  final subject = snapshot.data!;
                                                  subjectColor = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
                                                  subjectIcon = Icon(
                                                    SubjectIconHelper.getIcon(subject.icon),
                                                    size: 10,
                                                    color: subjectColor,
                                                  );
                                                }

                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 3),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    gradient: plan.isCompleted
                                                        ? LinearGradient(
                                                            colors: [Colors.green[50]!, Colors.green[100]!],
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                          )
                                                        : LinearGradient(
                                                            colors: [
                                                              Theme.of(context).colorScheme.primaryContainer,
                                                              Theme.of(context).colorScheme.primaryContainer.withAlpha(179),
                                                            ],
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                          ),
                                                    borderRadius: BorderRadius.circular(6),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: (subjectColor ?? Colors.grey).withAlpha(51),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 1.0),
                                                      ),
                                                    ],
                                                    border: subjectColor != null
                                                        ? Border(left: BorderSide(color: subjectColor, width: 3))
                                                        : Border.all(
                                                            color: plan.isCompleted
                                                                ? Colors.green.withAlpha(128)
                                                                : Theme.of(context).colorScheme.primary.withAlpha(77),
                                                            width: 1,
                                                          ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      if (plan.isCompleted)
                                                        Icon(Icons.check_circle, size: 10, color: Colors.green[700])
                                                      else if (subjectIcon != null) ...[
                                                        subjectIcon,
                                                        const SizedBox(width: 4),
                                                      ],
                                                      Expanded(
                                                        child: Text(
                                                          plan.title,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w500,
                                                            decoration: plan.isCompleted
                                                                ? TextDecoration.lineThrough
                                                                : null,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              margin: const EdgeInsets.only(bottom: 2),
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: plan.isCompleted
                                                    ? Colors.green[100]
                                                    : Theme.of(context).colorScheme.primaryContainer,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                plan.title,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  decoration: plan.isCompleted
                                                      ? TextDecoration.lineThrough
                                                      : null,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                    );
                                  },
                                ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPlanForDate(DateTime.now(), weekStart, weekEnd),
        icon: const Icon(Icons.add),
        label: const Text('계획 추가'),
      ),
    );
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

              // 세부 목표
              if (plan.subtasks.isNotEmpty) ...[
                const Divider(),
                Row(
                  children: [
                    const Icon(Icons.checklist, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '세부 목표 (${plan.subtasks.where((s) => s.isCompleted).length}/${plan.subtasks.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...plan.subtasks.map((subtask) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              subtask.isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                              color: subtask.isCompleted ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                subtask.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (subtask.pageRange != null || subtask.estimatedMinutes > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (subtask.pageRange != null) ...[
                                Icon(Icons.auto_stories, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  subtask.getPageProgressText(),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                if (subtask.estimatedMinutes > 0)
                                  const SizedBox(width: 12),
                              ],
                              if (subtask.estimatedMinutes > 0) ...[
                                Icon(Icons.timer_outlined, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${subtask.estimatedMinutes}분',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (subtask.pageRange != null && subtask.completedPage != null) ...[
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: subtask.getPageProgress() / 100,
                            minHeight: 3,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ],
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 8),
                // 총 예상 시간
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '총 예상 시간: ${plan.subtasks.fold<int>(0, (sum, s) => sum + s.estimatedMinutes)}분',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
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
}
