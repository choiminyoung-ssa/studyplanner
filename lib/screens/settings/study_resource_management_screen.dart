import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/study_resource.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class StudyResourceManagementScreen extends StatefulWidget {
  const StudyResourceManagementScreen({super.key});

  @override
  State<StudyResourceManagementScreen> createState() => _StudyResourceManagementScreenState();
}

class _StudyResourceManagementScreenState extends State<StudyResourceManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();

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
        title: const Text('학습 자료'),
      ),
      body: StreamBuilder<List<StudyResource>>(
        stream: _firestoreService.getStudyResources(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }

          final resources = snapshot.data ?? [];
          if (resources.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: resources.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final resource = resources[index];
              return _buildResourceCard(context, userId, resource);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showResourceEditor(context, userId),
        icon: const Icon(Icons.add),
        label: const Text('자료 추가'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(120),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 40, color: colorScheme.primary),
            const SizedBox(height: 10),
            const Text(
              '등록된 학습 자료가 없습니다',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '강의/문제집을 먼저 추가해두면\n세부 목표에서 바로 선택할 수 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCard(
    BuildContext context,
    String userId,
    StudyResource resource,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = _resourceAccent(resource.type, colorScheme);
    final unitLabel = resource.type.unitLabel;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withAlpha(16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(90)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _resourceIcon(resource.type),
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildChip(resource.type.label, accent),
                    if (resource.totalUnits != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '총 ${resource.totalUnits}$unitLabel',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
                if (resource.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    resource.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showResourceEditor(context, userId, resource: resource);
              } else if (value == 'delete') {
                _confirmDeleteResource(context, userId, resource);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('수정'),
                  ],
                ),
              ),
              PopupMenuItem(
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
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
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

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
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

  void _showResourceEditor(
    BuildContext context,
    String userId, {
    StudyResource? resource,
  }) {
    final titleController = TextEditingController(text: resource?.title ?? '');
    final notesController = TextEditingController(text: resource?.notes ?? '');
    final totalController = TextEditingController(
      text: resource?.totalUnits != null ? resource!.totalUnits.toString() : '',
    );
    var selectedType = resource?.type ?? StudyResourceType.book;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final inset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        resource == null ? '학습 자료 추가' : '학습 자료 수정',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: _inputDecoration(
                      context,
                      label: '자료 이름',
                      hint: '예: 수학 문제집, 영어 문법 강의',
                      icon: Icons.bookmark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<StudyResourceType>(
                    segments: const [
                      ButtonSegment(value: StudyResourceType.book, label: Text('문제집')),
                      ButtonSegment(value: StudyResourceType.lecture, label: Text('강의')),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (selection) {
                      setSheetState(() {
                        selectedType = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: totalController,
                    decoration: _inputDecoration(
                      context,
                      label: '총 ${selectedType.unitLabel} (선택)',
                      hint: selectedType == StudyResourceType.book ? '예: 300' : '예: 24',
                      icon: Icons.format_list_numbered,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: _inputDecoration(
                      context,
                      label: '메모 (선택)',
                      hint: '특이사항이나 목표를 적어두세요',
                      icon: Icons.notes,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('자료 이름을 입력해주세요'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final totalUnits = int.tryParse(totalController.text.trim());

                            try {
                              if (resource == null) {
                                final newResource = StudyResource(
                                  id: '',
                                  userId: userId,
                                  title: title,
                                  type: selectedType,
                                  notes: notesController.text.trim(),
                                  totalUnits: totalUnits,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );
                                await _firestoreService.createStudyResource(newResource);
                              } else {
                                await _firestoreService.updateStudyResource(
                                  userId,
                                  resource.id,
                                  {
                                    'title': title,
                                    'type': selectedType.name,
                                    'notes': notesController.text.trim(),
                                    'totalUnits': totalUnits,
                                  },
                                );
                              }
                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('오류: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: const Text('저장'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteResource(
    BuildContext context,
    String userId,
    StudyResource resource,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('학습 자료 삭제'),
        content: Text('${resource.title} 을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                await _firestoreService.deleteStudyResource(userId, resource.id);
                navigator.pop();
              } catch (e) {
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
