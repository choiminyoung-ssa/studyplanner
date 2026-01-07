import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/monthly_plan.dart';
import '../../models/subject.dart';
import '../../models/subtask.dart';

class MonthlyFormScreen extends StatefulWidget {
  final String month;
  final MonthlyPlan? plan; // 수정 모드일 때 전달

  const MonthlyFormScreen({
    super.key,
    required this.month,
    this.plan,
  });

  @override
  State<MonthlyFormScreen> createState() => _MonthlyFormScreenState();
}

class _MonthlyFormScreenState extends State<MonthlyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _tagController;
  int _priority = 2;
  bool _isCompleted = false;
  String? _selectedSubjectId;
  List<Subtask> _subtasks = []; 
  DateTime? _startDate;
  DateTime? _endDate;
  final Map<String, TextEditingController> _subtaskTitleControllers = {};
  final Map<String, TextEditingController> _subtaskPageRangeControllers = {};
  final Map<String, TextEditingController> _subtaskCompletedPageControllers = {};
  final Map<String, TextEditingController> _subtaskMinutesControllers = {};

  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.plan?.title ?? '');
    _notesController = TextEditingController(text: widget.plan?.notes ?? '');
    _tagController = TextEditingController(text: widget.plan?.tag ?? '');
    _selectedSubjectId = widget.plan?.subjectId;
    _subtasks = widget.plan?.subtasks ?? [];
    for (final subtask in _subtasks) {
      _ensureSubtaskControllers(subtask);
    }
    _priority = widget.plan?.priority ?? 2;
    _isCompleted = widget.plan?.isCompleted ?? false;

    if (widget.plan != null) {
      _startDate = widget.plan!.startDate;
      _endDate = widget.plan!.endDate;
    } else {
      // Default to the month range
      try {
        final parts = widget.month.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        _startDate = DateTime(y, m, 1);
        _endDate = DateTime(y, m + 1, 0);
      } catch (_) {
        _startDate = null;
        _endDate = null;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    for (final controller in _subtaskTitleControllers.values) {
      controller.dispose();
    }
    for (final controller in _subtaskPageRangeControllers.values) {
      controller.dispose();
    }
    for (final controller in _subtaskCompletedPageControllers.values) {
      controller.dispose();
    }
    for (final controller in _subtaskMinutesControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
    _getSubtaskController(_subtaskPageRangeControllers, subtask.id, subtask.pageRange ?? '');
    _getSubtaskController(
      _subtaskCompletedPageControllers,
      subtask.id,
      subtask.completedPage?.toString() ?? '',
    );
    final minutesText = subtask.estimatedMinutes > 0 ? subtask.estimatedMinutes.toString() : '';
    _getSubtaskController(_subtaskMinutesControllers, subtask.id, minutesText);
  }

  void _disposeSubtaskControllers(String id) {
    _subtaskTitleControllers.remove(id)?.dispose();
    _subtaskPageRangeControllers.remove(id)?.dispose();
    _subtaskCompletedPageControllers.remove(id)?.dispose();
    _subtaskMinutesControllers.remove(id)?.dispose();
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
      for (int i = 0; i < _subtasks.length; i++) {
        _subtasks[i] = _subtasks[i].copyWith(order: i);
      }
    });
  }
  Future<void> _savePlan() async {
    if (_formKey.currentState!.validate()) {
      final userId = context.read<AuthProvider>().userId;
      if (userId == null) return;

      try {
        if (widget.plan == null) {
          // 새 계획 생성
          final newPlan = MonthlyPlan(
            id: '',
            userId: userId,
            month: widget.month,
            title: _titleController.text.trim(),
            notes: _notesController.text.trim(),
            subject: '',
            subjectId: _selectedSubjectId,
            pageRanges: [],
            startDate: _startDate,
            endDate: _endDate,
            subtasks: _subtasks,
            tag: _tagController.text.trim(),
            priority: _priority,
            isCompleted: _isCompleted,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _firestoreService.createMonthlyPlan(newPlan);
        } else {
          // 기존 계획 수정
          await _firestoreService.updateMonthlyPlan(
            widget.plan!.id,
            {
              'title': _titleController.text.trim(),
              'notes': _notesController.text.trim(),
              'subject': '',
              'subjectId': _selectedSubjectId,
              'pageRanges': [],
              'startDate': _startDate != null ? Timestamp.fromDate(_startDate!) : null,
              'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
              'subtasks': _subtasks.map((s) => s.toMap()).toList(),
              'tag': _tagController.text.trim(),
              'priority': _priority,
              'isCompleted': _isCompleted,
            },
          );
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.plan == null ? '목표가 추가되었습니다' : '목표가 수정되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan == null ? '월간 목표 추가' : '월간 목표 수정'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 제목
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '목표 제목 *',
                hintText: '이번 달 목표를 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '목표 제목을 입력해주세요';
                }
                return null;
              },
              maxLength: 100,
            ),
            const SizedBox(height: 16),

            // 과목/분야
            StreamBuilder<List<Subject>>(
              stream: _firestoreService.getSubjects(context.read<AuthProvider>().userId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final subjects = snapshot.data ?? [];

                return DropdownButtonFormField<String>(
                  initialValue: _selectedSubjectId,
                  decoration: InputDecoration(
                    labelText: '과목/분야',
                    hintText: '예: 수학, 영어, 프로그래밍',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
            // 기간 (선택)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.date_range, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '기간',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  _startDate = picked;
                                  if (_endDate != null && _endDate!.isBefore(_startDate!)) {
                                    _endDate = _startDate;
                                  }
                                });
                              }
                            },
                            child: Text(_startDate != null ? '시작: ${_startDate!.toLocal().toString().split(' ').first}' : '시작일 선택'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  _endDate = picked;
                                  if (_startDate != null && _startDate!.isAfter(_endDate!)) {
                                    _startDate = _endDate;
                                  }
                                });
                              }
                            },
                            child: Text(_endDate != null ? '종료: ${_endDate!.toLocal().toString().split(' ').first}' : '종료일 선택'),
                          ),
                        ),
                      ],
                    ),
                    if (_startDate == null || _endDate == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '기간을 설정하지 않으면 월 전체가 기본 범위로 사용됩니다.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 태그
            TextFormField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: '태그',
                hintText: '예: 시험, 프로젝트',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.label),
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 16),

            // 메모
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: '메모',
                hintText: '추가 설명이나 세부 내용',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.notes),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            // 월간 세부 목표
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
                              '월간 세부 목표',
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
                          tooltip: '월간 세부 목표 추가',
                        ),
                      ],
                    ),
                    if (_subtasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '이번 달 목표를 세부로 나눠보세요 (선택사항)',
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
                          final pageRangeController = _subtaskPageRangeControllers[subtask.id]!;
                          final completedPageController = _subtaskCompletedPageControllers[subtask.id]!;
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
                              subtitle: (subtask.pageRange != null || subtask.estimatedMinutes > 0)
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (subtask.pageRange != null) ...[
                                          Row(
                                            children: [
                                              Icon(Icons.auto_stories, size: 14, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                subtask.getPageProgressText(),
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                          if (subtask.completedPage != null) ...[
                                            const SizedBox(height: 4),
                                            LinearProgressIndicator(
                                              value: subtask.getPageProgress() / 100,
                                              minHeight: 3,
                                              backgroundColor: Colors.grey[300],
                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                        ],
                                        if (subtask.estimatedMinutes > 0)
                                          Row(
                                            children: [
                                              Icon(Icons.timer_outlined, size: 14, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                '예상: ${subtask.estimatedMinutes}분',
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                      ],
                                    )
                                  : null,
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
                                      TextField(
                                        decoration: const InputDecoration(
                                          labelText: '페이지 범위 (선택사항)',
                                          border: OutlineInputBorder(),
                                          hintText: '예: 45-67',
                                          prefixIcon: Icon(Icons.auto_stories),
                                        ),
                                        controller: pageRangeController,
                                        onChanged: (value) {
                                          _updateSubtask(
                                            index,
                                            subtask.copyWith(
                                              pageRange: value.trim().isEmpty ? null : value.trim(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        decoration: const InputDecoration(
                                          labelText: '완료 페이지 (선택사항)',
                                          border: OutlineInputBorder(),
                                          hintText: '예: 52',
                                          prefixIcon: Icon(Icons.bookmark),
                                        ),
                                        controller: completedPageController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          final page = int.tryParse(value);
                                          _updateSubtask(
                                            index,
                                            subtask.copyWith(completedPage: page),
                                          );
                                        },
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

            // 우선순위
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '우선순위',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 1,
                          label: Text('높음'),
                          icon: Icon(Icons.priority_high),
                        ),
                        ButtonSegment(
                          value: 2,
                          label: Text('중간'),
                          icon: Icon(Icons.remove),
                        ),
                        ButtonSegment(
                          value: 3,
                          label: Text('낮음'),
                          icon: Icon(Icons.low_priority),
                        ),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (Set<int> selection) {
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

            // 완료 여부
            SwitchListTile(
              title: const Text('완료됨'),
              subtitle: const Text('이 목표를 완료했다면 체크하세요'),
              value: _isCompleted,
              onChanged: (value) {
                setState(() {
                  _isCompleted = value;
                });
              },
              secondary: Icon(
                _isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: _isCompleted ? Colors.green : null,
              ),
            ),
            const SizedBox(height: 24),

            // 저장 버튼
            FilledButton(
              onPressed: _savePlan,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                widget.plan == null ? '목표 추가' : '목표 수정',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
