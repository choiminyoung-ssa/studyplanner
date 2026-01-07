import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/subject.dart';

class SubjectFormScreen extends StatefulWidget {
  final Subject? subject;

  const SubjectFormScreen({super.key, this.subject});

  @override
  State<SubjectFormScreen> createState() => _SubjectFormScreenState();
}

class _SubjectFormScreenState extends State<SubjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  String _selectedColor = '#2196F3';
  String _selectedIcon = 'book';

  final FirestoreService _firestoreService = FirestoreService();

  // 미리 정의된 색상 팔레트
  final List<String> _colorPalette = [
    '#F44336', '#E91E63', '#9C27B0', '#673AB7',
    '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
    '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
    '#FFEB3B', '#FFC107', '#FF9800', '#FF5722',
    '#795548', '#9E9E9E', '#607D8B', '#000000',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subject?.name ?? '');
    _selectedColor = widget.subject?.color ?? '#2196F3';
    _selectedIcon = widget.subject?.icon ?? 'book';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveSubject() async {
    if (_formKey.currentState!.validate()) {
      final userId = context.read<AuthProvider>().userId;
      if (userId == null) return;

      try {
        if (widget.subject == null) {
          // 새 과목 생성
          final newSubject = Subject(
            id: '',
            userId: userId,
            name: _nameController.text.trim(),
            color: _selectedColor,
            icon: _selectedIcon,
            displayOrder: 0,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _firestoreService.createSubject(newSubject);
        } else {
          // 기존 과목 수정
          await _firestoreService.updateSubject(
            widget.subject!.id,
            {
              'name': _nameController.text.trim(),
              'color': _selectedColor,
              'icon': _selectedIcon,
            },
          );
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.subject == null ? '과목이 추가되었습니다' : '과목이 수정되었습니다'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject == null ? '과목 추가' : '과목 수정'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 과목명 입력
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '과목명 *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.book),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '과목명을 입력해주세요';
                }
                return null;
              },
              maxLength: 30,
            ),
            const SizedBox(height: 24),

            // 색상 선택
            const Text(
              '색상 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _colorPalette.length,
                itemBuilder: (context, index) {
                  final colorHex = _colorPalette[index];
                  final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                  final isSelected = colorHex == _selectedColor;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = colorHex;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 아이콘 선택
            const Text(
              '아이콘 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: SubjectIconHelper.getAllIcons().length,
                itemBuilder: (context, index) {
                  final entry = SubjectIconHelper.getAllIcons()[index];
                  final iconName = entry.key;
                  final icon = entry.value;
                  final isSelected = iconName == _selectedIcon;
                  final selectedColor = Color(int.parse(_selectedColor.replaceFirst('#', '0xFF')));

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIcon = iconName;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? selectedColor.withAlpha(51) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? selectedColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? selectedColor : Colors.grey[600],
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 저장 버튼
            FilledButton(
              onPressed: _saveSubject,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.subject == null ? '과목 추가' : '과목 수정',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
