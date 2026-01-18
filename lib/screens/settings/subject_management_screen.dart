import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/subject.dart';
import 'subject_form_screen.dart';

class SubjectManagementScreen extends StatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  State<SubjectManagementScreen> createState() => _SubjectManagementScreenState();
}

class _SubjectManagementScreenState extends State<SubjectManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _showArchived = false;

  void _addSubject() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubjectFormScreen(),
      ),
    );
  }

  void _editSubject(Subject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubjectFormScreen(subject: subject),
      ),
    );
  }

  void _archiveSubject(Subject subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('과목 보관'),
        content: Text('${subject.name} 과목을 보관하시겠습니까?\n이 과목을 사용하는 계획에는 "미지정"으로 표시됩니다.'),
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
                await _firestoreService.deleteSubject(subject.id);
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('과목이 보관되었습니다'),
                    backgroundColor: Colors.green,
                  ),
                );
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
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('보관'),
          ),
        ],
      ),
    );
  }

  void _restoreSubject(Subject subject) async {
    try {
      await _firestoreService.restoreSubject(subject.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('과목이 복구되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteSubjectForever(Subject subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('과목 영구 삭제'),
        content: Text('${subject.name} 과목을 영구 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
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
                await _firestoreService.deleteSubjectForever(subject.id);
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('과목이 삭제되었습니다'),
                    backgroundColor: Colors.green,
                  ),
                );
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

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('과목 관리'),
      ),
      body: StreamBuilder<List<Subject>>(
        stream: _firestoreService.getAllSubjects(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }

          final subjects = snapshot.data ?? [];
          final activeSubjects = subjects.where((subject) => subject.isActive).toList();
          final archivedSubjects = subjects.where((subject) => !subject.isActive).toList();
          final visibleSubjects = _showArchived ? archivedSubjects : activeSubjects;

          if (visibleSubjects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _showArchived ? '보관된 과목이 없습니다' : '등록된 과목이 없습니다',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  if (!_showArchived)
                    FilledButton.icon(
                      onPressed: _addSubject,
                      icon: const Icon(Icons.add),
                      label: const Text('과목 추가'),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visibleSubjects.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('활성')),
                      ButtonSegment(value: true, label: Text('보관')),
                    ],
                    selected: {_showArchived},
                    onSelectionChanged: (value) {
                      setState(() => _showArchived = value.first);
                    },
                  ),
                );
              }
              final subject = visibleSubjects[index - 1];
              final color = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      SubjectIconHelper.getIcon(subject.icon),
                      color: color,
                    ),
                  ),
                  title: Text(
                    subject.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(subject.isActive ? '활성화' : '보관됨'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (subject.isActive) ...[
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editSubject(subject),
                        ),
                        IconButton(
                          icon: const Icon(Icons.archive, color: Colors.orange),
                          onPressed: () => _archiveSubject(subject),
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.restore, color: Colors.green),
                          onPressed: () => _restoreSubject(subject),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          onPressed: () => _deleteSubjectForever(subject),
                        ),
                      ],
                    ],
                  ),
                  onTap: subject.isActive ? () => _editSubject(subject) : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: _addSubject,
              icon: const Icon(Icons.add),
              label: const Text('과목 추가'),
            ),
    );
  }
}
