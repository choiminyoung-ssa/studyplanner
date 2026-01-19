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

  // 미리 정의된 색상 팔레트 (더 많고 예쁜 색상들)
  final List<String> _colorPalette = [
    // 빨강 계열
    '#F44336', '#E91E63', '#EF5350', '#EC407A', '#FF5252',
    // 보라/핑크 계열
    '#9C27B0', '#AB47BC', '#BA68C8', '#CE93D8', '#EA80FC',
    // 파랑 계열
    '#673AB7', '#5E35B1', '#3F51B5', '#5C6BC0', '#2196F3',
    '#42A5F5', '#03A9F4', '#29B6F6', '#00BCD4', '#26C6DA',
    // 청록 계열
    '#00897B', '#009688', '#26A69A', '#4DB6AC', '#80CBC4',
    // 초록 계열
    '#43A047', '#4CAF50', '#66BB6A', '#81C784', '#8BC34A',
    '#9CCC65', '#AED581', '#C5E1A5',
    // 노랑/주황 계열
    '#FDD835', '#FFEB3B', '#FFEE58', '#FFF59D', '#FFC107',
    '#FFB300', '#FF9800', '#FFA726', '#FF6F00', '#FF5722',
    // 갈색 계열
    '#8D6E63', '#A1887F', '#BCAAA4',
    // 회색 계열
    '#78909C', '#90A4AE', '#B0BEC5', '#CFD8DC',
    // 다크 계열
    '#37474F', '#455A64', '#546E7A', '#607D8B',
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '과목명',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: '예: 수학, 영어, 과학 등',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
                          width: 2,
                        ),
                      ),
                      counterStyle: TextStyle(color: Colors.grey[600]),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '과목명을 입력해주세요';
                      }
                      return null;
                    },
                    maxLength: 30,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 색상 선택
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[400]!, width: 2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '색상 선택',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
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
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black : Colors.white,
                              width: isSelected ? 3 : 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withAlpha(128),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 아이콘 선택
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))).withAlpha(51),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          SubjectIconHelper.getIcon(_selectedIcon),
                          color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '아이콘 선택',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${SubjectIconHelper.getAllIcons().length}개',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1,
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? selectedColor.withAlpha(51)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? selectedColor : Colors.grey[300]!,
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: selectedColor.withAlpha(77),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              icon,
                              color: isSelected ? selectedColor : Colors.grey[700],
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 미리보기
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))).withAlpha(51),
                    Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))).withAlpha(26),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))).withAlpha(102),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      SubjectIconHelper.getIcon(_selectedIcon),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '미리보기',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _nameController.text.isEmpty ? '과목명을 입력하세요' : _nameController.text,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _nameController.text.isEmpty ? Colors.grey : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _saveSubject,
                style: FilledButton.styleFrom(
                  backgroundColor: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.subject == null ? Icons.add_circle_outline : Icons.check_circle_outline,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.subject == null ? '과목 추가' : '과목 수정',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
