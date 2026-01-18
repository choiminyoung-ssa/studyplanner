import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/daily_plan.dart';
import '../../models/subject.dart';
import '../../models/subtask.dart';
import '../../models/study_resource.dart';
import '../../models/weekly_plan.dart';
import '../../utils/date_utils.dart';
import '../../models/backlog_task.dart';
import '../tasks/backlog_task_list_screen.dart';
import '../settings/study_resource_management_screen.dart';

class DailyFormScreen extends StatefulWidget {
  final DateTime date;
  final DailyPlan? plan;
  final String? initialStartTime;
  final String? initialEndTime;
  final String? initialTitle;
  final String? initialNotes;
  final String? initialSubjectId;

  const DailyFormScreen({
    super.key,
    required this.date,
    this.plan,
    this.initialStartTime,
    this.initialEndTime,
    this.initialTitle,
    this.initialNotes,
    this.initialSubjectId,
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
  final Map<String, TextEditingController> _subtaskResourceTitleControllers = {};

  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.plan?.title ?? widget.initialTitle ?? '',
    );
    _notesController = TextEditingController(
      text: widget.plan?.notes ?? widget.initialNotes ?? '',
    );
    _subjectController = TextEditingController(text: widget.plan?.subject ?? '');
    _selectedSubjectId = widget.plan?.subjectId ?? widget.initialSubjectId;
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
    for (final controller in _subtaskResourceTitleControllers.values) {
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
    _getSubtaskController(_subtaskResourceTitleControllers, subtask.id, subtask.resourceTitle ?? '');
  }

  void _disposeSubtaskControllers(String id) {
    _subtaskTitleControllers.remove(id)?.dispose();
    _subtaskPageStartControllers.remove(id)?.dispose();
    _subtaskPageEndControllers.remove(id)?.dispose();
    _subtaskMinutesControllers.remove(id)?.dispose();
    _subtaskResourceTitleControllers.remove(id)?.dispose();
  }

  void _resetSubtaskControllers(List<Subtask> nextSubtasks) {
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
    for (final controller in _subtaskResourceTitleControllers.values) {
      controller.dispose();
    }
    _subtaskTitleControllers.clear();
    _subtaskPageStartControllers.clear();
    _subtaskPageEndControllers.clear();
    _subtaskMinutesControllers.clear();
    _subtaskResourceTitleControllers.clear();
    _subtasks = nextSubtasks;
    for (final subtask in _subtasks) {
      _ensureSubtaskControllers(subtask);
    }
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

  void _applyBacklogTask(BacklogTask task) {
    final copiedSubtasks = task.subtasks
        .map(
          (subtask) => subtask.copyWith(
            id: _uuid.v4(),
            isCompleted: false,
            completedPage: null,
          ),
        )
        .toList();
    setState(() {
      _titleController.text = task.title;
      _notesController.text = task.notes;
      _selectedSubjectId = task.subjectId;
      _priority = task.priority;
      _resetSubtaskControllers(copiedSubtasks);
    });
  }

  void _openBacklogManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BacklogTaskListScreen()),
    );
  }

  void _openStudyResourceManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StudyResourceManagementScreen()),
    );
  }

  void _showBacklogPicker(List<BacklogTask> tasks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      '할일 보관함',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openBacklogManager();
                      },
                      child: const Text('관리'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return ListTile(
                        title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: task.notes.isNotEmpty
                            ? Text(task.notes, maxLines: 1, overflow: TextOverflow.ellipsis)
                            : null,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          Navigator.pop(context);
                          _applyBacklogTask(task);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
        final completedAt = _isCompleted ? (widget.plan?.completedAt ?? DateTime.now()) : null;
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
            completedAt: completedAt,
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
              'completedAt': completedAt,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeroHeader(context),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      if (userId != null) _buildAnimatedSection(_buildWeeklyLinkSection(userId), 0),
                      if (userId != null) const SizedBox(height: 14),
                      if (userId != null) _buildAnimatedSection(_buildBacklogSection(userId), 1),
                      if (userId != null) const SizedBox(height: 14),
                      _buildAnimatedSection(_buildBasicInfoSection(), 2),
                      const SizedBox(height: 14),
                      if (userId != null)
                        StreamBuilder<List<StudyResource>>(
                          stream: _firestoreService.getStudyResources(userId),
                          builder: (context, snapshot) {
                            final resources = snapshot.data ?? [];
                            final subtaskSection = _buildSubtaskSection(
                              context,
                              resources: resources,
                              userId: userId,
                            );

                            return _buildAnimatedSection(subtaskSection, 3);
                          },
                        )
                      else
                        _buildAnimatedSection(
                          _buildSubtaskSection(context, resources: const [], userId: null),
                          3,
                        ),
                      const SizedBox(height: 14),
                      _buildAnimatedSection(_buildPrioritySection(), 4),
                      const SizedBox(height: 14),
                      _buildAnimatedSection(_buildCompletionSection(), 5),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildSaveBar(context),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isEditing = widget.plan != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer.withAlpha(220),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: colorScheme.surface.withAlpha(230),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEditing ? '일정 수정' : '일정 추가',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (_isCompleted)
                _buildHeaderBadge(
                  label: '완료',
                  color: colorScheme.primary,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            DateHelper.toKoreanDateString(widget.date),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          Text(
            '${DateHelper.getWeekdayName(widget.date)}요일',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onPrimaryContainer.withAlpha(160),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTimeChip(
                  context,
                  label: '시작 시간',
                  time: _startTime,
                  onTap: () => _selectTime(context, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeChip(
                  context,
                  label: '종료 시간',
                  time: _endTime,
                  onTap: () => _selectTime(context, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTimeChip(
    BuildContext context, {
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface.withAlpha(230),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  _formatTime(time),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSection(Widget child, int index) {
    final delay = index * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delay),
      curve: Curves.easeOutCubic,
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
    required Widget child,
    String? title,
    String? subtitle,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (title != null || subtitle != null) const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? icon,
    String? suffixText,
    bool isDense = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      suffixText: suffixText,
      filled: true,
      isDense: isDense,
      fillColor: colorScheme.surfaceContainerHighest.withAlpha(140),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant.withAlpha(120)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    );
  }

  Widget _buildWeeklyLinkSection(String userId) {
    return StreamBuilder<List<WeeklyPlan>>(
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
          return _buildSectionCard(
            context,
            title: '주간 목표 연결',
            subtitle: '이번 주 목표와 연결하면 전체 흐름을 한눈에 볼 수 있어요',
            child: Row(
              children: [
                const Icon(Icons.link_off, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('이번 주 주간 목표가 없습니다. 주간 탭에서 먼저 추가해 주세요.'),
                ),
              ],
            ),
          );
        }

        return _buildSectionCard(
          context,
          title: '주간 목표 연결',
          subtitle: '현재 일정이 포함될 주간 목표를 선택하세요',
          child: DropdownButtonFormField<String?>(
            value: selectedId,
            decoration: _inputDecoration(
              context,
              label: '상위 주간 목표',
              icon: Icons.link,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('연결 안 함'),
              ),
              ...weeklyPlans.map((plan) {
                return DropdownMenuItem<String?>(
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
        );
      },
    );
  }

  Widget _buildBacklogSection(String userId) {
    return StreamBuilder<List<BacklogTask>>(
      stream: _firestoreService.getBacklogTasks(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildSectionCard(
            context,
            title: '할일 보관함',
            subtitle: '오류가 발생했습니다',
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text('${snapshot.error}')),
              ],
            ),
          );
        }

        final tasks = snapshot.data ?? [];
        final hasTasks = tasks.isNotEmpty;

        return _buildSectionCard(
          context,
          title: '할일 보관함',
          subtitle: '날짜 없는 할일을 불러와 일정에 빠르게 넣을 수 있어요',
          trailing: TextButton(
            onPressed: _openBacklogManager,
            child: const Text('관리'),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: hasTasks
                ? Column(
                    key: const ValueKey('backlog-has'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tasks.length}개의 할일이 저장되어 있습니다',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        onPressed: () => _showBacklogPicker(tasks),
                        icon: const Icon(Icons.file_open),
                        label: const Text('할일 선택해서 가져오기'),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('backlog-empty'),
                    children: [
                      const Icon(Icons.inbox),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('보관된 할일이 없습니다.')),
                      FilledButton.tonalIcon(
                        onPressed: _openBacklogManager,
                        icon: const Icon(Icons.add),
                        label: const Text('추가'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildBasicInfoSection() {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      return _buildSectionCard(
        context,
        title: '기본 정보',
        child: const Text('로그인이 필요합니다.'),
      );
    }

    return _buildSectionCard(
      context,
      title: '기본 정보',
      subtitle: '일정의 제목과 과목, 간단한 메모를 입력하세요',
      child: Column(
        children: [
          TextFormField(
            controller: _titleController,
            decoration: _inputDecoration(
              context,
              label: '일정 제목 *',
              hint: '예: 수학 문제집 1단원',
              icon: Icons.title,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '제목을 입력해주세요';
              }
              return null;
            },
            maxLength: 100,
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Subject>>(
            stream: _firestoreService.getSubjects(userId),
            builder: (context, snapshot) {
              final subjects = snapshot.data ?? [];

              return DropdownButtonFormField<String?>(
                value: _selectedSubjectId,
                decoration: _inputDecoration(
                  context,
                  label: '과목/분야',
                  icon: Icons.book,
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
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: _inputDecoration(
              context,
              label: '메모',
              hint: '공부 범위나 주의할 점을 적어두세요',
              icon: Icons.notes,
            ),
            maxLines: 3,
            maxLength: 300,
          ),
        ],
      ),
    );
  }

  Widget _buildInlineChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSubtaskSection(
    BuildContext context, {
    required List<StudyResource> resources,
    required String? userId,
  }) {
    final resourceMap = {for (final resource in resources) resource.id: resource};
    final hasSubtasks = _subtasks.isNotEmpty;

    final actionRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: userId == null ? null : _openStudyResourceManager,
          icon: const Icon(Icons.menu_book_rounded, size: 18),
          label: const Text('학습 자료'),
        ),
      ],
    );

    return _buildSectionCard(
      context,
      title: '세부 목표',
      subtitle: '세부 목표를 추가하고 강의/문제집 범위를 연결해보세요',
      trailing: actionRow,
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: hasSubtasks
                ? ReorderableListView.builder(
                    key: const ValueKey('subtask-list'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: _reorderSubtasks,
                    buildDefaultDragHandles: false,
                    itemCount: _subtasks.length,
                    itemBuilder: (context, index) {
                      final subtask = _subtasks[index];
                      return _buildSubtaskCard(
                        context,
                        index: index,
                        subtask: subtask,
                        resources: resources,
                        resourceMap: resourceMap,
                      );
                    },
                  )
                : Container(
                    key: const ValueKey('subtask-empty'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(120),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.checklist),
                        SizedBox(width: 8),
                        Expanded(child: Text('세부 목표를 추가해 일정을 구체화해보세요.')),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: userId == null ? null : _addSubtask,
              icon: const Icon(Icons.add),
              label: const Text('세부 목표 추가'),
            ),
          ),
          if (hasSubtasks) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 예상 ${Subtask.getTotalEstimatedMinutes(_subtasks)}분',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '완료율 ${Subtask.getCompletionPercentage(_subtasks).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _subtasks.isEmpty ? 0 : Subtask.getCompletionPercentage(_subtasks) / 100,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubtaskCard(
    BuildContext context, {
    required int index,
    required Subtask subtask,
    required List<StudyResource> resources,
    required Map<String, StudyResource> resourceMap,
  }) {
    _ensureSubtaskControllers(subtask);
    final titleController = _subtaskTitleControllers[subtask.id]!;
    final resourceTitleController = _subtaskResourceTitleControllers[subtask.id]!;
    final startController = _subtaskPageStartControllers[subtask.id]!;
    final endController = _subtaskPageEndControllers[subtask.id]!;
    final minutesController = _subtaskMinutesControllers[subtask.id]!;
    final resource = resourceMap[subtask.resourceId];
    final effectiveType = resource?.type ?? studyResourceTypeFromString(subtask.resourceType);
    final rangeLabel = effectiveType.rangeLabel;
    final headerTitle = subtask.title.isNotEmpty
        ? subtask.title
        : (resource?.title ?? '세부 목표');

    return Card(
      key: ValueKey(subtask.id),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
            headerTitle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: _buildSubtaskSubtitle(
            context,
            subtask: subtask,
            resource: resource,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeSubtask(index),
          ),
          children: [
            TextField(
              decoration: _inputDecoration(
                context,
                label: '세부 목표 제목',
                hint: resource?.title ?? '예: 강의 요약 정리',
                icon: Icons.edit_note,
                isDense: true,
              ),
              controller: titleController,
              onChanged: (value) {
                _updateSubtask(index, subtask.copyWith(title: value));
              },
              onSubmitted: (_) {
                if (index == _subtasks.length - 1) {
                  _addSubtask();
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: resource != null ? resource.id : null,
              decoration: _inputDecoration(
                context,
                label: '강의/문제집 선택',
                icon: _resourceIcon(effectiveType),
                hint: subtask.resourceTitle != null ? '${subtask.resourceTitle} (삭제됨)' : null,
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('직접 입력'),
                ),
                ...resources.map((item) {
                  return DropdownMenuItem<String?>(
                    value: item.id,
                    child: Row(
                      children: [
                        Icon(_resourceIcon(item.type), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(item.type.label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                final selected = value == null ? null : resourceMap[value];
                final shouldReplaceTitle = subtask.title.trim().isEmpty ||
                    (subtask.resourceTitle != null && subtask.title.trim() == subtask.resourceTitle!.trim());
                final nextTitle = shouldReplaceTitle ? (selected?.title ?? subtask.title) : subtask.title;
                final manualResourceTitle = resourceTitleController.text.trim();
                final nextResourceTitle = selected?.title ?? (manualResourceTitle.isNotEmpty ? manualResourceTitle : subtask.resourceTitle);
                if (selected != null) {
                  resourceTitleController.text = selected.title;
                }
                _updateSubtask(
                  index,
                  subtask.copyWith(
                    resourceId: selected?.id,
                    resourceTitle: nextResourceTitle,
                    resourceType: selected?.type.name ?? subtask.resourceType,
                    title: nextTitle,
                  ),
                );
              },
            ),
            if (resource == null) ...[
              const SizedBox(height: 10),
              TextField(
                decoration: _inputDecoration(
                  context,
                  label: '자료 이름 (직접 입력)',
                  hint: '예: 수학 문제집, 개념 강의',
                  icon: Icons.bookmark_border,
                  isDense: true,
                ),
                controller: resourceTitleController,
                onChanged: (value) {
                  _updateSubtask(
                    index,
                    subtask.copyWith(resourceTitle: value, resourceId: null),
                  );
                },
              ),
              const SizedBox(height: 10),
              SegmentedButton<StudyResourceType>(
                segments: const [
                  ButtonSegment(value: StudyResourceType.book, label: Text('문제집')),
                  ButtonSegment(value: StudyResourceType.lecture, label: Text('강의')),
                ],
                selected: {effectiveType},
                onSelectionChanged: (selection) {
                  final nextType = selection.first;
                  _updateSubtask(index, subtask.copyWith(resourceType: nextType.name));
                },
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: _inputDecoration(
                      context,
                      label: '시작 $rangeLabel',
                      hint: '예: 1',
                      icon: Icons.first_page,
                      isDense: true,
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
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    decoration: _inputDecoration(
                      context,
                      label: '끝 $rangeLabel',
                      hint: '예: 5',
                      icon: Icons.flag,
                      isDense: true,
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
              decoration: _inputDecoration(
                context,
                label: '예상 시간 (분)',
                icon: Icons.timer,
                suffixText: '분',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              controller: minutesController,
              onChanged: (value) {
                final minutes = int.tryParse(value) ?? 0;
                _updateSubtask(index, subtask.copyWith(estimatedMinutes: minutes));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtaskSubtitle(
    BuildContext context, {
    required Subtask subtask,
    required StudyResource? resource,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final chips = <Widget>[];

    if (resource != null) {
      chips.add(_buildInlineChip(resource.title, _resourceAccent(resource.type, colorScheme)));
      chips.add(_buildInlineChip(resource.type.label, _resourceAccent(resource.type, colorScheme)));
    } else if (subtask.resourceTitle != null && subtask.resourceTitle!.trim().isNotEmpty) {
      final type = studyResourceTypeFromString(subtask.resourceType);
      chips.add(_buildInlineChip(subtask.resourceTitle!.trim(), _resourceAccent(type, colorScheme)));
      chips.add(_buildInlineChip(type.label, _resourceAccent(type, colorScheme)));
    }
    if (subtask.pageRange != null && subtask.pageRange!.isNotEmpty) {
      chips.add(_buildInlineChip(subtask.getPageProgressText(), colorScheme.primary));
    }
    if (subtask.estimatedMinutes > 0) {
      chips.add(_buildInlineChip('예상 ${subtask.estimatedMinutes}분', colorScheme.tertiary));
    }

    if (chips.isEmpty) {
      return Text(
        '범위나 시간을 입력하면 요약이 표시됩니다',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _buildPrioritySection() {
    return _buildSectionCard(
      context,
      title: '우선순위',
      subtitle: '중요도를 선택해 우선순위를 정하세요',
      child: SegmentedButton<int>(
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
    );
  }

  Widget _buildCompletionSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSectionCard(
      context,
      title: '완료 상태',
      subtitle: '일정을 완료 처리하면 통계에 반영됩니다',
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _isCompleted,
        activeColor: colorScheme.primary,
        onChanged: (value) {
          setState(() {
            _isCompleted = value;
          });
        },
        title: const Text('완료됨'),
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _savePlan,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.check_circle),
          label: Text(
            widget.plan == null ? '일정 추가' : '일정 수정',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  IconData _resourceIcon(StudyResourceType type) {
    switch (type) {
      case StudyResourceType.lecture:
        return Icons.play_lesson_rounded;
      case StudyResourceType.book:
      default:
        return Icons.menu_book_rounded;
    }
  }

  Color _resourceAccent(StudyResourceType type, ColorScheme colorScheme) {
    switch (type) {
      case StudyResourceType.lecture:
        return colorScheme.tertiary;
      case StudyResourceType.book:
      default:
        return colorScheme.primary;
    }
  }

}
