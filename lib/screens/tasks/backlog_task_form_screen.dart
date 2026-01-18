import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/backlog_task.dart';
import '../../models/subtask.dart';
import '../../models/subject.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class BacklogTaskFormScreen extends StatefulWidget {
  final BacklogTask? task;

  const BacklogTaskFormScreen({super.key, this.task});

  @override
  State<BacklogTaskFormScreen> createState() => _BacklogTaskFormScreenState();
}

class _BacklogTaskFormScreenState extends State<BacklogTaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  late TextEditingController _titleController;
  late TextEditingController _notesController;
  String? _selectedSubjectId;
  int _priority = 2;
  bool _isCompleted = false;
  List<Subtask> _subtasks = [];
  final Map<String, TextEditingController> _subtaskTitleControllers = {};
  final Map<String, TextEditingController> _subtaskPageStartControllers = {};
  final Map<String, TextEditingController> _subtaskPageEndControllers = {};
  final Map<String, TextEditingController> _subtaskMinutesControllers = {};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _notesController = TextEditingController(text: widget.task?.notes ?? '');
    _selectedSubjectId = widget.task?.subjectId;
    _priority = widget.task?.priority ?? 2;
    _isCompleted = widget.task?.isCompleted ?? false;
    _subtasks = widget.task?.subtasks ?? [];
    for (final subtask in _subtasks) {
      _ensureSubtaskControllers(subtask);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
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
      if (_subtasks.isNotEmpty && _subtasks.every((s) => s.isCompleted)) {
        _isCompleted = true;
      }
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

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    try {
      final allSubtasksDone = _subtasks.isNotEmpty && _subtasks.every((s) => s.isCompleted);
      final nextCompleted = _isCompleted || allSubtasksDone;
      final completedAt = nextCompleted ? (widget.task?.completedAt ?? DateTime.now()) : null;

      if (widget.task == null) {
        final now = DateTime.now();
        final task = BacklogTask(
          id: '',
          userId: userId,
          title: _titleController.text.trim(),
          notes: _notesController.text.trim(),
          subjectId: _selectedSubjectId,
          priority: _priority,
          subtasks: _subtasks,
          isCompleted: nextCompleted,
          completedAt: completedAt,
          createdAt: now,
          updatedAt: now,
        );
        await _firestoreService.createBacklogTask(task);
      } else {
        await _firestoreService.updateBacklogTask(
          userId,
          widget.task!.id,
          {
            'title': _titleController.text.trim(),
            'notes': _notesController.text.trim(),
            'subjectId': _selectedSubjectId,
            'priority': _priority,
            'subtasks': _subtasks.map((s) => s.toMap()).toList(),
            'isCompleted': nextCompleted,
            'completedAt': completedAt,
          },
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.task == null ? '할일이 저장되었습니다' : '할일이 수정되었습니다'),
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

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? '할일 추가' : '할일 수정'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '할일 제목 *',
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
              stream: _firestoreService.getSubjects(userId),
              builder: (context, snapshot) {
                final subjects = snapshot.data ?? [];
                return DropdownButtonFormField<String?>(
                  value: _selectedSubjectId,
                  decoration: InputDecoration(
                    labelText: '과목/분야',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.book),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('미지정'),
                    ),
                    ...subjects.map((subject) {
                      final color = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
                      return DropdownMenuItem<String?>(
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
            SwitchListTile(
              title: const Text('완료 처리'),
              value: _isCompleted,
              onChanged: (value) {
                setState(() {
                  _isCompleted = value;
                  if (_isCompleted) {
                    _subtasks = _subtasks.map((s) => s.copyWith(isCompleted: true)).toList();
                  } else {
                    _subtasks = _subtasks.map((s) => s.copyWith(isCompleted: false)).toList();
                  }
                });
              },
            ),
            const SizedBox(height: 8),
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
                              '세부 항목',
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
                          tooltip: '세부 항목 추가',
                        ),
                      ],
                    ),
                    if (_subtasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '필요한 세부 항목을 추가하세요 (선택사항)',
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
                                        onSubmitted: (_) {
                                          if (index == _subtasks.length - 1) {
                                            _addSubtask();
                                          }
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _addSubtask,
                        icon: const Icon(Icons.add),
                        label: const Text('세부 항목 추가'),
                      ),
                    ),
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saveTask,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.task == null ? '할일 저장' : '할일 수정',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
