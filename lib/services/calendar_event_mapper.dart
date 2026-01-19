import 'dart:math';

import 'package:googleapis/calendar/v3.dart' as calendar;
import '../models/daily_plan.dart';
import '../models/weekly_plan.dart';
import '../models/monthly_plan.dart';
import '../models/weekly_timetable_entry.dart';
import '../models/subject.dart';

class CalendarEventMapper {
  static const Map<String, String> _googleEventColors = {
    '1': '#A4BDFC', // Lavender
    '2': '#7AE7BF', // Sage
    '3': '#DBADFF', // Grape
    '4': '#FF887C', // Flamingo
    '5': '#FBD75B', // Banana
    '6': '#FFB878', // Tangerine
    '7': '#46D6DB', // Peacock
    '8': '#E1E1E1', // Graphite
    '9': '#5484ED', // Blueberry
    '10': '#51B749', // Basil
    '11': '#DC2127', // Tomato
  };

  static calendar.Event fromDailyPlan(DailyPlan plan, {Subject? subject}) {
    final start = _safeDateTime(plan.date, plan.startTime);
    final end = _safeDateTime(plan.date, plan.endTime, fallback: start.add(const Duration(minutes: 60)));
    final adjustedEnd = end.isAfter(start) ? end : start.add(const Duration(minutes: 30));

    return calendar.Event(
      summary: _buildSummary(plan.title, subject?.name ?? plan.subject),
      description: _buildDescription(
        typeLabel: 'Daily Plan',
        notes: plan.notes,
        subjectName: subject?.name ?? plan.subject,
        tag: plan.tag,
        priority: plan.priority,
        pageRanges: plan.pageRanges,
        subtaskTitles: plan.subtasks.map((s) => s.title).toList(),
      ),
      start: calendar.EventDateTime(dateTime: start),
      end: calendar.EventDateTime(dateTime: adjustedEnd),
      colorId: _pickColorId(subject, priority: plan.priority),
      extendedProperties: calendar.EventExtendedProperties(private: {
        'source': 'studyplanner',
        'type': 'daily',
        'localId': plan.id,
      }),
    );
  }

  static calendar.Event fromWeeklyPlan(WeeklyPlan plan, {Subject? subject}) {
    final startDate = _startOfDay(plan.date);
    final endDate = startDate.add(const Duration(days: 1));
    final baseTitle =
        plan.title.trim().isEmpty ? 'Weekly Plan' : 'Weekly: ${plan.title}';

    return calendar.Event(
      summary: _buildSummary(baseTitle, subject?.name ?? plan.subject),
      description: _buildDescription(
        typeLabel: 'Weekly Plan',
        notes: plan.notes,
        subjectName: subject?.name ?? plan.subject,
        tag: plan.tag,
        priority: plan.priority,
        pageRanges: plan.pageRanges,
        subtaskTitles: plan.subtasks.map((s) => s.title).toList(),
      ),
      start: calendar.EventDateTime(date: startDate),
      end: calendar.EventDateTime(date: endDate),
      colorId: _pickColorId(subject, priority: plan.priority),
      extendedProperties: calendar.EventExtendedProperties(private: {
        'source': 'studyplanner',
        'type': 'weekly',
        'localId': plan.id,
      }),
    );
  }

  static calendar.Event fromMonthlyPlan(MonthlyPlan plan, {Subject? subject}) {
    final range = _resolveMonthlyRange(plan);
    final startDate = _startOfDay(range.$1);
    final endDate = _startOfDay(range.$2);
    final baseTitle =
        plan.title.trim().isEmpty ? 'Monthly Plan' : 'Monthly: ${plan.title}';

    return calendar.Event(
      summary: _buildSummary(baseTitle, subject?.name ?? plan.subject),
      description: _buildDescription(
        typeLabel: 'Monthly Plan',
        notes: plan.notes,
        subjectName: subject?.name ?? plan.subject,
        tag: plan.tag,
        priority: plan.priority,
        pageRanges: plan.pageRanges,
        subtaskTitles: plan.subtasks.map((s) => s.title).toList(),
      ),
      start: calendar.EventDateTime(date: startDate),
      end: calendar.EventDateTime(date: endDate),
      colorId: _pickColorId(subject, priority: plan.priority),
      extendedProperties: calendar.EventExtendedProperties(private: {
        'source': 'studyplanner',
        'type': 'monthly',
        'localId': plan.id,
      }),
    );
  }

  static calendar.Event fromWeeklyTimetableEntry(WeeklyTimetableEntry entry) {
    final startDate = _nextOccurrence(DateTime.now(), entry.weekday, entry.startTime);
    final start = _safeDateTime(startDate, entry.startTime);
    final end = _safeDateTime(startDate, entry.endTime, fallback: start.add(const Duration(minutes: 60)));
    final adjustedEnd = end.isAfter(start) ? end : start.add(const Duration(minutes: 30));

    return calendar.Event(
      summary: entry.title,
      location: entry.location,
      description: _buildDescription(
        typeLabel: 'Weekly Timetable',
        notes: entry.location == null ? '' : 'Location: ${entry.location}',
        subjectName: '',
        tag: '',
        priority: null,
        pageRanges: const [],
        subtaskTitles: const [],
      ),
      start: calendar.EventDateTime(dateTime: start),
      end: calendar.EventDateTime(dateTime: adjustedEnd),
      recurrence: [
        'RRULE:FREQ=WEEKLY;BYDAY=${_weekdayToByDay(entry.weekday)}',
      ],
      colorId: _pickColorId(null, priority: null),
      extendedProperties: calendar.EventExtendedProperties(private: {
        'source': 'studyplanner',
        'type': 'timetable',
        'localId': entry.id,
      }),
    );
  }

  static String? _pickColorId(Subject? subject, {int? priority}) {
    final subjectColor = subject?.color;
    if (subjectColor != null && subjectColor.isNotEmpty) {
      final colorId = _closestColorId(subjectColor);
      if (colorId != null) return colorId;
    }

    if (priority == null) return null;
    switch (priority) {
      case 1:
        return '11';
      case 2:
        return '5';
      case 3:
      default:
        return '8';
    }
  }

  static String _buildSummary(String title, String? subjectName) {
    final trimmedTitle = title.trim();
    final trimmedSubject = subjectName?.trim();
    if (trimmedTitle.isEmpty) {
      return trimmedSubject == null || trimmedSubject.isEmpty
          ? 'Study Plan'
          : trimmedSubject;
    }
    if (trimmedSubject == null || trimmedSubject.isEmpty) {
      return trimmedTitle;
    }
    return '[$trimmedSubject] $trimmedTitle';
  }

  static String _buildDescription({
    required String typeLabel,
    required String notes,
    required String subjectName,
    required String tag,
    required int? priority,
    required List<String> pageRanges,
    required List<String> subtaskTitles,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('StudyPlanner');
    buffer.writeln('Type: $typeLabel');

    final subject = subjectName.trim();
    if (subject.isNotEmpty) {
      buffer.writeln('Subject: $subject');
    }

    if (tag.trim().isNotEmpty) {
      buffer.writeln('Tag: ${tag.trim()}');
    }

    if (priority != null) {
      buffer.writeln('Priority: $priority');
    }

    if (pageRanges.isNotEmpty) {
      buffer.writeln('Pages: ${pageRanges.join(', ')}');
    }

    if (subtaskTitles.isNotEmpty) {
      buffer.writeln('Subtasks:');
      for (final title in subtaskTitles) {
        if (title.trim().isEmpty) continue;
        buffer.writeln('- ${title.trim()}');
      }
    }

    if (notes.trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(notes.trim());
    }

    return buffer.toString().trim();
  }

  static DateTime _safeDateTime(DateTime date, String time, {DateTime? fallback}) {
    final parts = time.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    }

    final fallbackTime = fallback ?? DateTime(date.year, date.month, date.day, 9, 0);
    return DateTime(
      date.year,
      date.month,
      date.day,
      fallbackTime.hour,
      fallbackTime.minute,
    );
  }

  static DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static (DateTime, DateTime) _resolveMonthlyRange(MonthlyPlan plan) {
    if (plan.startDate != null && plan.endDate != null) {
      return (plan.startDate!, plan.endDate!.add(const Duration(days: 1)));
    }
    if (plan.startDate != null) {
      return (plan.startDate!, plan.startDate!.add(const Duration(days: 1)));
    }
    if (plan.endDate != null) {
      final start = plan.endDate!;
      return (start, start.add(const Duration(days: 1)));
    }

    final monthStart = _parseMonthStart(plan.month);
    if (monthStart != null) {
      final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
      return (monthStart, nextMonth);
    }

    final today = DateTime.now();
    return (today, today.add(const Duration(days: 1)));
  }

  static DateTime? _parseMonthStart(String value) {
    final parts = value.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return null;
    return DateTime(year, month, 1);
  }

  static DateTime _nextOccurrence(DateTime from, int weekday, String time) {
    final base = DateTime(from.year, from.month, from.day);
    final delta = (weekday - base.weekday + 7) % 7;
    var target = base.add(Duration(days: delta));
    final start = _safeDateTime(target, time);
    if (start.isBefore(from)) {
      target = target.add(const Duration(days: 7));
    }
    return target;
  }

  static String _weekdayToByDay(int weekday) {
    const map = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    if (weekday < 1 || weekday > 7) return 'MO';
    return map[weekday - 1];
  }

  static String? _closestColorId(String hexColor) {
    final rgb = _parseHex(hexColor);
    if (rgb == null) return null;

    var bestId = '';
    var bestDistance = double.infinity;
    _googleEventColors.forEach((id, hex) {
      final candidate = _parseHex(hex);
      if (candidate == null) return;
      final distance = _colorDistance(rgb, candidate);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestId = id;
      }
    });

    return bestId.isEmpty ? null : bestId;
  }

  static List<int>? _parseHex(String hex) {
    var cleaned = hex.trim().replaceAll('#', '');
    if (cleaned.length == 3) {
      cleaned = cleaned.split('').map((c) => '$c$c').join();
    }
    if (cleaned.length != 6) return null;
    final r = int.tryParse(cleaned.substring(0, 2), radix: 16);
    final g = int.tryParse(cleaned.substring(2, 4), radix: 16);
    final b = int.tryParse(cleaned.substring(4, 6), radix: 16);
    if (r == null || g == null || b == null) return null;
    return [r, g, b];
  }

  static double _colorDistance(List<int> a, List<int> b) {
    final dr = a[0] - b[0];
    final dg = a[1] - b[1];
    final db = a[2] - b[2];
    return sqrt((dr * dr + dg * dg + db * db).toDouble());
  }
}
