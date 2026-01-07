enum PlanType { daily, weekly, monthly }

class SearchResult {
  final String id;
  final PlanType type;
  final DateTime date; // primary date to display
  final String title;
  final String notes;
  final String? subjectId;
  final String? subject;
  final int priority;
  final bool isCompleted;

  SearchResult({
    required this.id,
    required this.type,
    required this.date,
    required this.title,
    required this.notes,
    this.subjectId,
    this.subject,
    this.priority = 2,
    this.isCompleted = false,
  });

  @override
  String toString() => 'SearchResult($type,$title)';
}
