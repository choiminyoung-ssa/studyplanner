import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/daily_plan.dart';
import '../../models/subject.dart';
import '../../models/subtask.dart';
import '../../models/weekly_plan.dart';
import '../../utils/date_utils.dart';

class DailyFormScreen extends StatefulWidget {
  final DateTime date;
  final DailyPlan? plan;
  final String? initialStartTime;
  final String? initialEndTime;

  const DailyFormScreen({
    super.key,
    required this.date,
    this.plan,
    this.initialStartTime,
    this.initialEndTime,
  });

  @override
  State<DailyFormScreen> createState() => _DailyFormScreenState();
}

class _DailyFormScreenState extends State<DailyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _subjectController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  int _priority = 2;
  bool _isCompleted = false;
  String? _selectedSubjectId;
  String? _selectedWeeklyId;
  List<Subtask> _subtasks = [];
  final Map<String, TextEditingController> _subtaskTitleControllers = {};
  final Map<String, TextEditingController> _subtaskPageStartControllers = {};
  final Map<String, TextEditingController> _subtaskPageEndControllers = {};
  final Map<String, TextEditingController> _subtaskMinutesControllers = {};

  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.plan?.title ?? '');
    _notesController = TextEditingController(text: widget.plan?.notes ?? '');
    _subjectController = TextEditingController(text: widget.plan?.subject ?? '');
    _selectedSubjectId = widget.plan?.subjectId;
    _selectedWeeklyId = widget.plan?.parentWeeklyId;
    _subtasks = widget.plan?.subtasks ?? [];
    for (final subtask in _subtasks) {
      _ensureSubtaskControllers(subtask);
    }

    if (widget.plan != null) {
      final startParts = widget.plan!.startTime.split(':');
      final endParts = widget.plan!.endTime.split(':');
      _startTime = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
      _endTime = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
    } else if (widget.initialStartTime != null && widget.initialEndTime != null) {
      // 초기 시간이 제공된 경우
      final startParts = widget.initialStartTime!.split(':');
      final endParts = widget.initialEndTime!.split(':');
      _startTime = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
      _endTime = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
    } else {
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
    }

    _priority = widget.plan?.priority ?? 2;
    _isCompleted = widget.plan?.isCompleted ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _subjectController.dispose();
    for (final controller in _subtaskTitleControllers.values) {
      controller.dispose();
    }
    for (final controller in _subtaskPageStartControllers.values) {
      controller.dispose();
    }
    for (final controller in _subtaskPageEndControllers.values) {
      controller.dispose();
    }
    for (final controller in _subtaskMinutesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  TextEditingController _getSubtaskController(
    Map<String, TextEditingController> map,
    String id,
    String initialText,
  ) {
    return map.putIfAbsent(id, () => TextEditingController(text: initialText));
  }

  void _ensureSubtaskControllers(Subtask subtask) {
    _getSubtaskController(_subtaskTitleControllers, subtask.id, subtask.title);
    final parts = _splitPageRange(subtask.pageRange);
    _getSubtaskController(_subtaskPageStartControllers, subtask.id, parts['start'] ?? '');
    _getSubtaskController(_subtaskPageEndControllers, subtask.id, parts['end'] ?? '');
    final minutesText = subtask.estimatedMinutes > 0 ? subtask.estimatedMinutes.toString() : '';
    _getSubtaskController(_subtaskMinutesControllers, subtask.id, minutesText);
  }

  void _disposeSubtaskControllers(String id) {
    _subtaskTitleControllers.remove(id)?.dispose();
    _subtaskPageStartControllers.remove(id)?.dispose();
    _subtaskPageEndControllers.remove(id)?.dispose();
    _subtaskMinutesControllers.remove(id)?.dispose();
  }

  Map<String, String> _splitPageRange(String? range) {
    if (range == null || range.trim().isEmpty) {
      return {'start': '', 'end': ''};
    }
    final parts = range.split('-');
    if (parts.length == 1) {
      return {'start': parts[0].trim(), 'end': ''};
    }
    final start = parts.first.trim();
    final end = parts.sublist(1).join('-').trim();
    return {'start': start, 'end': end};
  }

  String? _buildPageRange(String start, String end) {
    final cleanStart = start.trim();
    final cleanEnd = end.trim();
    if (cleanStart.isEmpty && cleanEnd.isEmpty) return null;
    if (cleanEnd.isEmpty) return cleanStart;
    if (cleanStart.isEmpty) return '-$cleanEnd';
    return '$cleanStart-$cleanEnd';
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _addSubtask() {
    setState(() {
      final subtask = Subtask(
        id: _uuid.v4(),
        title: '',
        order: _subtasks.length,
      );
      _subtasks.add(subtask);
      _ensureSubtaskControllers(subtask);
    });
  }

  void _removeSubtask(int index) {
    setState(() {
      _disposeSubtaskControllers(_subtasks[index].id);
      _subtasks.removeAt(index);
      // 순서 재정렬
      for (int i = 0; i < _subtasks.length; i++) {
        _subtasks[i] = _subtasks[i].copyWith(order: i);
      }
    });
  }

  void _updateSubtask(int index, Subtask subtask) {
    setState(() {
      _subtasks[index] = subtask;
    });
  }

  void _toggleSubtaskComplete(int index) {
    setState(() {
      _subtasks[index] = _subtasks[index].copyWith(
        isCompleted: !_subtasks[index].isCompleted,
      );
    });
  }

  void _reorderSubtasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _subtasks.removeAt(oldIndex);
      _subtasks.insert(newIndex, item);
      // 순서 재정렬
      for (int i = 0; i < _subtasks.length; i++) {
        _subtasks[i] = _subtasks[i].copyWith(order: i);
      }
    });
  }

  Future<void> _savePlan() async {
    if (_formKey.currentState!.validate()) {
      final startTimeStr = _formatTime(_startTime);
      final endTimeStr = _formatTime(_endTime);

      // 시간 유효성 검사
      if (!DateHelper.isValidTimeRange(startTimeStr, endTimeStr)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('종료 시간은 시작 시간보다 늦어야 합니다'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final userId = context.read<AuthProvider>().userId;
      if (userId == null) return;

      try {
        final previousWeeklyId = widget.plan?.parentWeeklyId;
        if (widget.plan == null) {
          final newPlan = DailyPlan(
            id: '',
            userId: userId,
            date: widget.date,
            startTime: startTimeStr,
            endTime: endTimeStr,
            title: _titleController.text.trim(),
            notes: _notesController.text.trim(),
            subject: '',
            subjectId: _selectedSubjectId,
            pageRanges: [],
            subtasks: _subtasks,
            priority: _priority,
            isCompleted: _isCompleted,
            parentWeeklyId: _selectedWeeklyId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          final docId = await _firestoreService.createDailyPlan(newPlan);
          final savedPlan = newPlan.copyWith(id: docId);
          if (mounted) {
            await context.read<NotificationProvider>().onPlanCreated(savedPlan);
          }
        } else {
          await _firestoreService.updateDailyPlan(
            widget.plan!.id,
            {
              'startTime': startTimeStr,
              'endTime': endTimeStr,
              'title': _titleController.text.trim(),
              'notes': _notesController.text.trim(),
              'subject': '',
              'subjectId': _selectedSubjectId,
              'pageRanges': [],
              'subtasks': _subtasks.map((s) => s.toMap()).toList(),
              'priority': _priority,
              'isCompleted': _isCompleted,
              'parentWeeklyId': _selectedWeeklyId,
            },
          );

          final updatedPlan = widget.plan!.copyWith(
            startTime: startTimeStr,
            endTime: endTimeStr,
            title: _titleController.text.trim(),
            notes: _notesController.text.trim(),
            subject: '',
            subjectId: _selectedSubjectId,
            pageRanges: [],
            subtasks: _subtasks,
            priority: _priority,
            isCompleted: _isCompleted,
            parentWeeklyId: _selectedWeeklyId,
          );
          if (mounted) {
            await context.read<NotificationProvider>().onPlanUpdated(updatedPlan);
          }

          if (previousWeeklyId != _selectedWeeklyId) {
            if (previousWeeklyId != null && previousWeeklyId.isNotEmpty) {
              await _firestoreService.removeDailyIdFromWeekly(previousWeeklyId, widget.plan!.id);
            }
            if (_selectedWeeklyId != null && _selectedWeeklyId!.isNotEmpty) {
              await _firestoreService.addDailyIdToWeekly(_selectedWeeklyId!, widget.plan!.id);
            }
          }
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.plan == null ? '일정이 추가되었습니다' : '일정이 수정되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan == null ? '일정 추가' : '일정 수정'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 날짜 표시
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('날짜'),
                subtitle: Text(DateHelper.toKoreanDateString(widget.date)),
              ),
            ),
            const SizedBox(height: 16),

            // 시간 선택
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('시작 시간'),
                      subtitle: Text(_formatTime(_startTime)),
                      onTap: () => _selectTime(context, true),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('종료 시간'),
                      subtitle: Text(_formatTime(_endTime)),
                      onTap: () => _selectTime(context, false),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 연결된 주간 목표
            if (userId != null)
              StreamBuilder<List<WeeklyPlan>>(
                stream: _firestoreService.getWeeklyPlansByDateRange(
                  userId,
                  DateHelper.getWeekStartDate(widget.date),
                  DateHelper.getWeekEndDate(widget.date),
                ),
                builder: (context, snapshot) {
                  final weeklyPlans = snapshot.data ?? [];
                  final availableIds = weeklyPlans.map((plan) => plan.id).toSet();
                  final selectedId = availableIds.contains(_selectedWeeklyId) ? _selectedWeeklyId : null;

                  if (weeklyPlans.isEmpty) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.link_off),
                        title: const Text('연결된 주간 목표 없음'),
                        subtitle: const Text('주간 탭에서 목표를 추가할 수 있어요'),
                      ),
                    );
                  }

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: DropdownButtonFormField<String>(
                        value: selectedId,
                        decoration: InputDecoration(
                          labelText: '상위 주간 목표',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.link),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('연결 안 함'),
                          ),
                          ...weeklyPlans.map((plan) {
                            return DropdownMenuItem<String>(
                              value: plan.id,
                              child: Text(
                                '${plan.title} · ${DateHelper.toKoreanDateString(plan.date)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedWeeklyId = value;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '일정 제목 *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '제목을 입력해주세요';
                }
                return null;
              },
              maxLength: 100,
            ),
            const SizedBox(height: 16),

            StreamBuilder<List<Subject>>(
              stream: _firestoreService.getSubjects(context.read<AuthProvider>().userId!),
              builder: (context, snapshot) {
                final subjects = snapshot.data ?? [];

                return DropdownButtonFormField<String>(
                  initialValue: _selectedSubjectId,
                  decoration: InputDecoration(
                    labelText: '과목/분야',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.book),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('미지정'),
                    ),
                    ...subjects.map((subject) {
                      final color = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
                      return DropdownMenuItem<String>(
                        value: subject.id,
                        child: Row(
                          children: [
                            Icon(
                              SubjectIconHelper.getIcon(subject.icon),
                              color: color,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(subject.name),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSubjectId = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: '메모',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.notes),
              ),
              maxLines: 3,
              maxLength: 300,
            ),
            const SizedBox(height: 16),

            // 일간 세부 목표
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.checklist, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              '일간 세부 목표',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            if (_subtasks.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  Subtask.getCompletionText(_subtasks),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: _addSubtask,
                          tooltip: '일간 세부 목표 추가',
                        ),
                      ],
                    ),
                    if (_subtasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '일정에 필요한 세부 목표를 추가하세요 (선택사항)',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: _reorderSubtasks,
                        itemCount: _subtasks.length,
                        itemBuilder: (context, index) {
                          final subtask = _subtasks[index];
                          _ensureSubtaskControllers(subtask);
                          final titleController = _subtaskTitleControllers[subtask.id]!;
                          final startController = _subtaskPageStartControllers[subtask.id]!;
                          final endController = _subtaskPageEndControllers[subtask.id]!;
                          final minutesController = _subtaskMinutesControllers[subtask.id]!;
                          return Card(
                            key: ValueKey(subtask.id),
                            margin: const EdgeInsets.only(top: 8),
                            child: ExpansionTile(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_handle),
                                  ),
                                  Checkbox(
                                    value: subtask.isCompleted,
                                    onChanged: (_) => _toggleSubtaskComplete(index),
                                  ),
                                ],
                              ),
                              title: Text(
                                subtask.title.isEmpty ? '제목 없음' : subtask.title,
                                style: TextStyle(
                                  decoration: subtask.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (subtask.pageRange != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.auto_stories, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          subtask.getPageProgressText(),
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    if (subtask.completedPage != null && subtask.getPageProgress() > 0) ...[
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: subtask.getPageProgress() / 100,
                                        minHeight: 3,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ],
                                  ],
                                  if (subtask.estimatedMinutes > 0) ...[
                                    const SizedBox(height: 4),
                                    Text('예상: ${subtask.estimatedMinutes}분', style: const TextStyle(fontSize: 12)),
                                  ],
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeSubtask(index),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      TextField(
                                        decoration: const InputDecoration(
                                          labelText: '제목',
                                          border: OutlineInputBorder(),
                                        ),
                                        controller: titleController,
                                        onChanged: (value) {
                                          _updateSubtask(
                                            index,
                                            subtask.copyWith(title: value),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              decoration: const InputDecoration(
                                                labelText: '시작 페이지',
                                                border: OutlineInputBorder(),
                                                hintText: '예: 12',
                                                prefixIcon: Icon(Icons.auto_stories, size: 20),
                                              ),
                                              keyboardType: TextInputType.number,
                                              controller: startController,
                                              onChanged: (value) {
                                                _updateSubtask(
                                                  index,
                                                  subtask.copyWith(
                                                    pageRange: _buildPageRange(value, endController.text),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextField(
                                              decoration: const InputDecoration(
                                                labelText: '끝 페이지',
                                                border: OutlineInputBorder(),
                                                hintText: '예: 34',
                                                prefixIcon: Icon(Icons.flag, size: 20),
                                              ),
                                              keyboardType: TextInputType.number,
                                              controller: endController,
                                              onChanged: (value) {
                                                _updateSubtask(
                                                  index,
                                                  subtask.copyWith(
                                                    pageRange: _buildPageRange(startController.text, value),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        decoration: const InputDecoration(
                                          labelText: '예상 시간 (분)',
                                          border: OutlineInputBorder(),
                                          suffixText: '분',
                                        ),
                                        keyboardType: TextInputType.number,
                                        controller: minutesController,
                                        onChanged: (value) {
                                          final minutes = int.tryParse(value) ?? 0;
                                          _updateSubtask(
                                            index,
                                            subtask.copyWith(estimatedMinutes: minutes),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    if (_subtasks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '총 예상 시간: ${Subtask.getTotalEstimatedMinutes(_subtasks)}분',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '완료율: ${Subtask.getCompletionPercentage(_subtasks).toStringAsFixed(0)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _subtasks.isEmpty
                            ? 0
                            : Subtask.getCompletionPercentage(_subtasks) / 100,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('우선순위', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('높음')),
                        ButtonSegment(value: 2, label: Text('중간')),
                        ButtonSegment(value: 3, label: Text('낮음')),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _priority = selection.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('완료됨'),
              value: _isCompleted,
              onChanged: (value) {
                setState(() {
                  _isCompleted = value;
                });
              },
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _savePlan,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.plan == null ? '일정 추가' : '일정 수정',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
