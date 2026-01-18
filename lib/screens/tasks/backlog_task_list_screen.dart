import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/backlog_task.dart';
import '../../models/subject.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import 'backlog_task_form_screen.dart';

class BacklogTaskListScreen extends StatelessWidget {
  BacklogTaskListScreen({super.key});

  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('할일 보관함'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BacklogTaskFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('할일 추가'),
      ),
      body: StreamBuilder<List<BacklogTask>>(
        stream: _firestoreService.getBacklogTasks(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      '저장된 할일이 없습니다',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '예시: 영어 단어장 3챕터 복습',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const BacklogTaskFormScreen()),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('할일 추가'),
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<List<Subject>>(
            stream: _firestoreService.getSubjects(userId),
            builder: (context, subjectSnapshot) {
              final subjects = subjectSnapshot.data ?? [];
              final subjectMap = {for (final s in subjects) s.id: s};

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  if (!task.isCompleted &&
                      task.subtasks.isNotEmpty &&
                      task.subtasks.every((s) => s.isCompleted)) {
                    Future.microtask(() {
                      _firestoreService.updateBacklogTask(
                        userId,
                        task.id,
                        {
                          'isCompleted': true,
                          'completedAt': DateTime.now(),
                        },
                      );
                    });
                  }
                  final subject = task.subjectId != null ? subjectMap[task.subjectId!] : null;
                  final subjectColor = subject != null
                      ? Color(int.parse(subject.color.replaceFirst('#', '0xFF')))
                      : Theme.of(context).colorScheme.primary;

                  return Card(
                    color: task.isCompleted ? const Color(0xFFEAF7EE) : null,
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => BacklogTaskFormScreen(task: task)),
                        );
                      },
                      title: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: subjectColor.withAlpha(30),
                        child: Icon(
                          SubjectIconHelper.getIcon(subject?.icon ?? 'book'),
                          color: subjectColor,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (task.notes.isNotEmpty)
                            Text(
                              task.notes,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (subject != null) Chip(label: Text(subject.name, style: const TextStyle(fontSize: 11))),
                              Chip(label: Text('우선순위 ${task.priority}', style: const TextStyle(fontSize: 11))),
                              if (task.subtasks.isNotEmpty)
                                Chip(
                                  label: Text(
                                    '세부 ${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                          if (task.subtasks.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: task.completionRatio,
                                minHeight: 5,
                                backgroundColor: Colors.grey[200],
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: task.isCompleted,
                            onChanged: (value) async {
                              final next = value ?? false;
                              final updatedSubtasks = next
                                  ? task.subtasks.map((s) => s.copyWith(isCompleted: true)).toList()
                                  : task.subtasks.map((s) => s.copyWith(isCompleted: false)).toList();
                              await _firestoreService.updateBacklogTask(
                                userId,
                                task.id,
                                {
                                  'isCompleted': next,
                                  'completedAt': next ? DateTime.now() : null,
                                  'subtasks': updatedSubtasks.map((s) => s.toMap()).toList(),
                                },
                              );
                            },
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => BacklogTaskFormScreen(task: task)),
                                );
                              } else if (value == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('할일 삭제'),
                                    content: const Text('정말 이 할일을 삭제하시겠습니까?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('취소'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                        child: const Text('삭제'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await _firestoreService.deleteBacklogTask(userId, task.id);
                                }
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('수정')),
                              PopupMenuItem(value: 'delete', child: Text('삭제')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
