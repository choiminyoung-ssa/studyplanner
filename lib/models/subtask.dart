class Subtask {
  final String id;
  final String title;
  final bool isCompleted;
  final int estimatedMinutes;
  final int order;
  final String? pageRange; // 페이지 범위 (예: "45-67")
  final int? completedPage; // 완료한 페이지 번호

  Subtask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.estimatedMinutes = 0,
    required this.order,
    this.pageRange,
    this.completedPage,
  });

  // Firestore Map에서 Subtask 객체 생성
  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      estimatedMinutes: map['estimatedMinutes'] ?? 0,
      order: map['order'] ?? 0,
      pageRange: map['pageRange'],
      completedPage: map['completedPage'],
    );
  }

  // Subtask 객체를 Firestore Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'estimatedMinutes': estimatedMinutes,
      'order': order,
      'pageRange': pageRange,
      'completedPage': completedPage,
    };
  }

  // 불변 객체 복사
  Subtask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    int? estimatedMinutes,
    int? order,
    String? pageRange,
    int? completedPage,
  }) {
    return Subtask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      order: order ?? this.order,
      pageRange: pageRange ?? this.pageRange,
      completedPage: completedPage ?? this.completedPage,
    );
  }

  // 총 예상 시간 계산 (분)
  static int getTotalEstimatedMinutes(List<Subtask> subtasks) {
    return subtasks.fold(0, (sum, task) => sum + task.estimatedMinutes);
  }

  // 완료율 계산 (0-100)
  static double getCompletionPercentage(List<Subtask> subtasks) {
    if (subtasks.isEmpty) return 0.0;
    final completed = subtasks.where((t) => t.isCompleted).length;
    return (completed / subtasks.length) * 100;
  }

  // 완료 텍스트 (예: "3/5")
  static String getCompletionText(List<Subtask> subtasks) {
    final completed = subtasks.where((t) => t.isCompleted).length;
    return '$completed/${subtasks.length}';
  }

  // 페이지 진행도 계산 (0-100)
  double getPageProgress() {
    if (pageRange == null || completedPage == null) return 0.0;

    final parts = pageRange!.split('-');
    if (parts.length != 2) return 0.0;

    final start = int.tryParse(parts[0].trim());
    final end = int.tryParse(parts[1].trim());

    if (start == null || end == null || end <= start) return 0.0;

    final total = end - start + 1;
    final completed = completedPage! - start + 1;

    if (completed <= 0) return 0.0;
    if (completed >= total) return 100.0;

    return (completed / total) * 100;
  }

  // 페이지 진행 텍스트 (예: "52/67" 또는 "8/23페이지")
  String getPageProgressText() {
    if (pageRange == null) return '';
    if (completedPage == null) return pageRange!;

    final parts = pageRange!.split('-');
    if (parts.length != 2) return pageRange!;

    final start = int.tryParse(parts[0].trim());
    final end = int.tryParse(parts[1].trim());

    if (start == null || end == null) return pageRange!;

    final total = end - start + 1;
    final completed = completedPage! - start + 1;

    return '$completedPage/$end (${completed.clamp(0, total)}/$total페이지)';
  }
}
