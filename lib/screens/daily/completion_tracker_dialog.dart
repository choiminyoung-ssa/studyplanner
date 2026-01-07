import 'package:flutter/material.dart';
import '../../models/daily_plan.dart';
import '../../models/subtask.dart';
import '../../services/firestore_service.dart';

class CompletionTrackerDialog extends StatefulWidget {
  final DailyPlan plan;
  final FirestoreService firestoreService;
  final VoidCallback? onEdit;

  const CompletionTrackerDialog({
    super.key,
    required this.plan,
    required this.firestoreService,
    this.onEdit,
  });

  @override
  State<CompletionTrackerDialog> createState() => _CompletionTrackerDialogState();
}

class _CompletionTrackerDialogState extends State<CompletionTrackerDialog> {
  late bool _isCompleted;
  late List<bool> _subtaskCompletions;
  late List<double> _pageCompletions; // 0-100 percentage

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.plan.isCompleted;
    _subtaskCompletions = widget.plan.subtasks.map((s) => s.isCompleted).toList();
    _pageCompletions = widget.plan.subtasks.map((s) {
      if (s.pageRange != null) {
        final parts = s.pageRange!.split('-');
        if (parts.length == 2) {
          final start = int.tryParse(parts[0].trim());
          final end = int.tryParse(parts[1].trim());
          if (start != null && end != null && end > start) {
            if (s.completedPage != null) {
              final completed = (s.completedPage! - start + 1).clamp(0, end - start + 1);
              return (completed / (end - start + 1) * 100).clamp(0.0, 100.0).toDouble();
            }
          }
        }
      }
      return 0.0;
    }).toList().cast<double>();
  }

  Future<void> _savePlanCompletion() async {
    await widget.firestoreService.updateDailyPlan(
      widget.plan.id,
      {'isCompleted': _isCompleted},
    );
  }

  Future<void> _saveSubtaskUpdates() async {
    final updatedSubtasks = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.plan.subtasks.length; i++) {
      final subtask = widget.plan.subtasks[i];
      int? newCompletedPage;

      if (subtask.pageRange != null) {
        final parts = subtask.pageRange!.split('-');
        if (parts.length == 2) {
          final start = int.tryParse(parts[0].trim());
          final end = int.tryParse(parts[1].trim());
          if (start != null && end != null && end > start) {
            final total = end - start + 1;
            final completedPages = (_pageCompletions[i] / 100 * total).round();
            if (completedPages > 0) {
              newCompletedPage = (start + completedPages - 1).clamp(start, end);
            } else {
              newCompletedPage = null;
            }
          }
        }
      }

      updatedSubtasks.add(
        subtask.copyWith(
          isCompleted: _subtaskCompletions[i],
          completedPage: newCompletedPage,
        ).toMap(),
      );
    }

    await widget.firestoreService.updateDailyPlan(
      widget.plan.id,
      {'subtasks': updatedSubtasks},
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _subtaskCompletions.where((c) => c).length;
    final totalCount = _subtaskCompletions.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.primaryContainer.withAlpha((0.7 * 255).round()),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.plan.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      if (widget.onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onEdit!();
                          },
                          tooltip: '수정',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.plan.startTime} - ${widget.plan.endTime}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overall completion (tappable button)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _isCompleted = !_isCompleted;
                        });
                        _savePlanCompletion();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isCompleted ? Colors.green[50] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isCompleted ? Colors.green : Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 28,
                              color: _isCompleted ? Colors.green : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isCompleted ? '일정 완료됨' : '일정 미완료',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isCompleted ? Colors.green[800] : Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (widget.plan.subtasks.isNotEmpty) ...[
                      const SizedBox(height: 24),

                      // Progress summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[50]!, Colors.blue[100]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.checklist, color: Colors.blue[700]),
                                    const SizedBox(width: 8),
                                    Text(
                                      '세부 목표 진행도',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$completedCount/$totalCount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: totalCount > 0 ? completedCount / totalCount : 0.0,
                                minHeight: 8,
                                backgroundColor: Colors.white,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Subtasks
                      ...List.generate(widget.plan.subtasks.length, (index) {
                        final subtask = widget.plan.subtasks[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _subtaskCompletions[index]
                                ? Colors.green[50]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _subtaskCompletions[index]
                                  ? Colors.green[300]!
                                  : Colors.grey[300]!,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha((0.05 * 255).round()),
                                blurRadius: 4.0,
                                offset: const Offset(0, 2.0),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Subtask title with checkbox
                              Row(
                                children: [
                                  Transform.scale(
                                    scale: 1.2,
                                    child: Checkbox(
                                      value: _subtaskCompletions[index],
                                      onChanged: (value) {
                                        setState(() {
                                          _subtaskCompletions[index] = value ?? false;
                                        });
                                        _saveSubtaskUpdates().then((_) {
                                          final allDone = _subtaskCompletions.every((c) => c);
                                          if (allDone != _isCompleted) {
                                            setState(() {
                                              _isCompleted = allDone;
                                            });
                                            _savePlanCompletion();
                                          }
                                        });
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      activeColor: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      subtask.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        decoration: _subtaskCompletions[index]
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Time estimate
                              if (subtask.estimatedMinutes > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.timer_outlined,
                                      size: 16,
                                      color: Colors.grey[600]
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '예상 시간: ${subtask.estimatedMinutes}분',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // Page range slider
                              if (subtask.pageRange != null) ...[
                                const SizedBox(height: 12),
                                _buildPageSlider(subtask, index),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageSlider(Subtask subtask, int index) {
    final parts = subtask.pageRange!.split('-');
    if (parts.length != 2) return const SizedBox.shrink();

    final start = int.tryParse(parts[0].trim());
    final end = int.tryParse(parts[1].trim());
    if (start == null || end == null || end <= start) return const SizedBox.shrink();

    final total = end - start + 1;
    final completedPages = (_pageCompletions[index] / 100 * total).round();
    final currentPage = completedPages <= 0 ? start : start + completedPages - 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 6),
                  Text(
                    '페이지 진행도',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'p.$currentPage / p.$end',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blue[400],
              inactiveTrackColor: Colors.blue[100],
              thumbColor: Colors.blue[600],
              overlayColor: Colors.blue[100],
              trackHeight: 6,
            ),
            child: Slider(
              value: _pageCompletions[index],
              min: 0,
              max: 100,
              divisions: total,
              onChanged: (value) {
                setState(() {
                  _pageCompletions[index] = value;
                });
              },
              onChangeEnd: (value) {
                _saveSubtaskUpdates();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'p.$start',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                '${_pageCompletions[index].round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              Text(
                'p.$end',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
