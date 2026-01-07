import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/monthly_plan.dart';
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

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;

    if (userId == null) {
      return const Center(child: Text('로그인이 필요합니다'));
    }

    final monthString = app_date.DateHelper.toMonthString(_selectedMonth);

    return Scaffold(
      body: Column(
        children: [
          // 캘린더
          Card(
            margin: const EdgeInsets.all(16),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextFormatter: (date, locale) {
                  return '${date.year}년 ${date.month}월';
                },
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                  _selectedMonth = focusedDay;
                });
              },
              // 주간 계획을 캘린더에 표시
              eventLoader: (day) {
                // 나중에 주간 계획 데이터를 여기에 추가할 수 있습니다
                return [];
              },
            ),
          ),

          // 월간 목표 리스트
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '이번 달 목표',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<MonthlyPlan>>(
              stream: _firestoreService.getMonthlyPlans(userId, monthString),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '월간 목표가 없습니다',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '아래 버튼을 눌러 새 목표를 추가하세요',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                final plans = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return plan.subjectId != null
                        ? StreamBuilder<Subject?>(
                            stream: _firestoreService.getSubjectById(plan.subjectId!).asStream(),
                            builder: (context, snapshot) {
                              Color? subjectColor;
                              IconData? subjectIcon;
                              String? subjectName;

                              if (snapshot.hasData && snapshot.data != null) {
                                final subject = snapshot.data!;
                                subjectColor = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
                                subjectIcon = SubjectIconHelper.getIcon(subject.icon);
                                subjectName = subject.name;
                              }

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: subjectColor != null
                                      ? BorderSide(color: subjectColor, width: 2)
                                      : BorderSide.none,
                                ),
                                child: ListTile(
                                  onTap: () => _showPlanDetails(plan),
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: plan.isCompleted,
                                        onChanged: (value) async {
                                          await _firestoreService.updateMonthlyPlan(
                                            plan.id,
                                            {'isCompleted': value ?? false},
                                          );
                                        },
                                      ),
                                      if (subjectColor != null && subjectIcon != null)
                                        Icon(
                                          subjectIcon,
                                          color: subjectColor,
                                          size: 24,
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    plan.title,
                                    style: TextStyle(
                                      decoration: plan.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (plan.notes.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          plan.notes,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      if (subjectName != null && subjectColor != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          subjectName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subjectColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
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
                                            Text('삭제', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              onTap: () => _showPlanDetails(plan),
                              leading: Checkbox(
                                value: plan.isCompleted,
                                onChanged: (value) async {
                                  await _firestoreService.updateMonthlyPlan(
                                    plan.id,
                                    {'isCompleted': value ?? false},
                                  );
                                },
                              ),
                              title: Text(
                                plan.title,
                                style: TextStyle(
                                  decoration: plan.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (plan.notes.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      plan.notes,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
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
                                        Text('삭제', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPlan(monthString),
        icon: const Icon(Icons.add),
        label: const Text('목표 추가'),
      ),
    );
  }

  void _addPlan(String month) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MonthlyFormScreen(month: month),
      ),
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
              // 월
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    plan.month,
                    style: const TextStyle(fontSize: 15),
                  ),
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
        builder: (context) => MonthlyFormScreen(
          month: plan.month,
          plan: plan,
        ),
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
                  SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
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
