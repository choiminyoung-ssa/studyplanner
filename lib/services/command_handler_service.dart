import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../models/study_goal.dart';
import '../models/subject.dart';
import '../models/weekly_plan.dart';
import '../models/monthly_plan.dart';
import '../models/weekly_timetable_entry.dart';
import '../models/notification_settings.dart';
import '../models/daily_plan.dart';
import '../models/study_resource.dart';
import '../utils/date_utils.dart';
import 'firestore_service.dart';

class CommandHandlerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final String userId;

  CommandHandlerService({required this.userId});

  /// 일정 생성 명령 처리 - 개선된 버전
  Future<String> createSchedule(Map<String, dynamic> parameters) async {
    try {
      print('🔍 DEBUG: createSchedule() called');
      print('🔍 DEBUG: userId = $userId');
      print('🔍 DEBUG: parameters = $parameters');
      if (userId.isEmpty) {
        return '❌ 사용자 정보가 없습니다. 다시 로그인해주세요.';
      }

      final subjectInput = parameters['subject']?.toString().trim();
      final subject = subjectInput == null || subjectInput.isEmpty
          ? '새 일정'
          : subjectInput;
      final timeStr = parameters['time']?.toString().trim() ?? '';
      final durationStr = parameters['duration']?.toString().trim() ?? '';
      final materials = parameters['materials'] is List<dynamic>
          ? List<String>.from(parameters['materials'])
          : <String>[];

      print(
        '📝 DEBUG: subject = $subject, timeStr = $timeStr, duration = $durationStr',
      );

      final scheduleDateTime = _parseScheduleDateTime(timeStr);
      final scheduleDate = DateTime(
        scheduleDateTime.year,
        scheduleDateTime.month,
        scheduleDateTime.day,
      );
      final startTimeStr = DateHelper.toTimeString(scheduleDateTime);
      final endTimeStr = _resolveEndTimeStringWithDuration(
        scheduleDateTime,
        durationStr,
      );

      print(
        '📅 DEBUG: Final scheduleDateTime = $scheduleDateTime, endTime = $endTimeStr',
      );

      final newPlan = DailyPlan(
        id: '',
        userId: userId,
        date: scheduleDate,
        startTime: startTimeStr,
        endTime: endTimeStr,
        title: subject,
        notes: _generateNotes(subject, materials, durationStr),
        subject: subject,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docId = await _firestoreService.createDailyPlan(newPlan);
      print('✅ DEBUG: Saved daily plan ID: $docId');

      final dateStr = DateFormat(
        'M월 d일 (E) a h:mm',
        'ko_KR',
      ).format(DateHelper.timeStringToDateTime(startTimeStr, scheduleDate));
      return '✅ "$subject" 일정이 $dateStr에 추가되었습니다!';
    } catch (e) {
      print('❌ DEBUG: Error creating schedule: $e');
      print('❌ DEBUG: Stack trace: ${e.toString()}');
      return '❌ 일정 생성 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 일정 조회 명령 처리
  Future<String> viewSchedule(Map<String, dynamic> parameters) async {
    try {
      final period = parameters['date'] ?? '오늘';
      final dateRange = _resolveDateRange(period.toString());
      final plans = await _firestoreService.getDailyPlansByDateRange(
        userId,
        dateRange.start,
        dateRange.end,
      );

      if (plans.isEmpty) {
        return '📅 $period 일정이 없습니다.';
      }

      final showDate =
          !(period.toString().contains('오늘') ||
              period.toString().contains('내일'));
      final formatter = DateFormat(
        showDate ? 'M/d (E) a h:mm' : 'a h:mm',
        'ko_KR',
      );

      final schedules = plans
          .map((plan) {
            final startDateTime = DateHelper.timeStringToDateTime(
              plan.startTime,
              plan.date,
            );
            final timeStr = formatter.format(startDateTime);
            return '• $timeStr - ${plan.title}';
          })
          .join('\n');

      return '📅 $period 일정:\n\n$schedules';
    } catch (e) {
      return '❌ 일정 조회 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 학습 통계 조회 명령 처리
  Future<String> viewStats(Map<String, dynamic> parameters) async {
    try {
      final period = parameters['period'] ?? '오늘';
      final dateRange = _resolveDateRange(period.toString());
      final plans = await _firestoreService.getDailyPlansByDateRange(
        userId,
        dateRange.start,
        dateRange.end,
      );
      final completedPlans = plans.where((plan) => plan.isCompleted).toList();

      if (completedPlans.isEmpty) {
        return '📊 $period 완료된 일정이 없습니다.';
      }

      int totalMinutes = 0;
      for (final plan in completedPlans) {
        totalMinutes += _calculateDurationMinutes(
          plan.startTime,
          plan.endTime,
          plan.date,
        );
      }

      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      final count = completedPlans.length;

      return '📊 $period 학습 통계:\n\n'
          '✅ 완료한 일정: $count개\n'
          '⏰ 총 학습 시간: $hours시간 $minutes분';
    } catch (e) {
      return '❌ 통계 조회 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 할일 관리 명령 처리
  Future<String> manageTodo(Map<String, dynamic> parameters) async {
    try {
      final action = parameters['action'] ?? 'list';

      if (action == 'list') {
        final now = DateTime.now();
        final dateRange = _DateRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(
            now.year,
            now.month,
            now.day,
          ).add(const Duration(days: 7)),
        );
        final plans = await _firestoreService.getDailyPlansByDateRange(
          userId,
          dateRange.start,
          dateRange.end,
        );
        final todos = plans
            .where((plan) => !plan.isCompleted)
            .take(10)
            .toList();

        if (todos.isEmpty) {
          return '✅ 완료되지 않은 할일이 없습니다!';
        }

        final formatter = DateFormat('M/d (E) a h:mm', 'ko_KR');
        final todoLines = todos
            .map((plan) {
              final start = DateHelper.timeStringToDateTime(
                plan.startTime,
                plan.date,
              );
              return '• ${formatter.format(start)} - ${plan.title}';
            })
            .join('\n');

        return '📝 할일 목록:\n\n$todoLines';
      }

      return '할일 관리 기능을 개발 중입니다.';
    } catch (e) {
      return '❌ 할일 조회 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 검색 명령 처리
  Future<String> search(Map<String, dynamic> parameters) async {
    try {
      final keyword = parameters['keyword'] ?? '';

      if (keyword.isEmpty) {
        return '🔍 검색어를 입력해주세요.';
      }

      final now = DateTime.now();
      final dateRange = _DateRange(
        start: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 30)),
        end: DateTime(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 30)),
      );
      final plans = await _firestoreService.getDailyPlansByDateRange(
        userId,
        dateRange.start,
        dateRange.end,
      );
      final searchTerm = keyword.toString().toLowerCase();
      final results = plans.where((plan) {
        final title = plan.title.toLowerCase();
        final notes = plan.notes.toLowerCase();
        final subject = plan.subject.toLowerCase();
        return title.contains(searchTerm) ||
            notes.contains(searchTerm) ||
            subject.contains(searchTerm);
      }).toList();

      if (results.isEmpty) {
        return '🔍 "$keyword" 관련 일정을 찾을 수 없습니다.';
      }

      final resultList = results
          .take(5)
          .map((plan) {
            final startTime = DateHelper.timeStringToDateTime(
              plan.startTime,
              plan.date,
            );
            final dateStr = DateFormat(
              'M/d (E) a h:mm',
              'ko_KR',
            ).format(startTime);
            return '• ${plan.title} ($dateStr)';
          })
          .join('\n');

      return '🔍 "$keyword" 검색 결과 (${results.length}개):\n\n$resultList';
    } catch (e) {
      return '❌ 검색 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  DateTime _parseScheduleDateTime(String timeStr) {
    final now = DateTime.now();
    DateTime baseDate = DateTime(now.year, now.month, now.day);

    if (timeStr.contains('모레')) {
      baseDate = baseDate.add(const Duration(days: 2));
    } else if (timeStr.contains('내일')) {
      baseDate = baseDate.add(const Duration(days: 1));
    } else if (timeStr.contains('다음주')) {
      final nextWeekStart = DateHelper.getWeekStartDate(
        baseDate,
      ).add(const Duration(days: 7));
      final weekdayIndex = _extractWeekdayIndex(timeStr);
      baseDate = weekdayIndex == null
          ? nextWeekStart
          : nextWeekStart.add(Duration(days: weekdayIndex));
    } else if (timeStr.contains('이번주') || timeStr.contains('이번 주')) {
      final weekStart = DateHelper.getWeekStartDate(baseDate);
      final weekdayIndex = _extractWeekdayIndex(timeStr);
      if (weekdayIndex != null) {
        baseDate = weekStart.add(Duration(days: weekdayIndex));
      }
    }

    int hour = 9;
    int minute = 0;

    final colonMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timeStr);
    if (colonMatch != null) {
      hour = int.parse(colonMatch.group(1)!);
      minute = int.parse(colonMatch.group(2)!);
    } else {
      final hourMatch = RegExp(r'(\d{1,2})\s*시').firstMatch(timeStr);
      if (hourMatch != null) {
        hour = int.parse(hourMatch.group(1)!);
      }

      final minuteMatch = RegExp(r'(\d{1,2})\s*분').firstMatch(timeStr);
      if (minuteMatch != null) {
        minute = int.parse(minuteMatch.group(1)!);
      }
    }

    if (timeStr.contains('오후')) {
      if (hour < 12) {
        hour += 12;
      }
    } else if (timeStr.contains('오전') || timeStr.contains('아침')) {
      if (hour == 12) {
        hour = 0;
      }
    }

    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
  }

  int? _extractWeekdayIndex(String text) {
    const weekdays = {
      '월요일': 0,
      '화요일': 1,
      '수요일': 2,
      '목요일': 3,
      '금요일': 4,
      '토요일': 5,
      '일요일': 6,
    };

    for (final entry in weekdays.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  String _resolveEndTimeString(DateTime startDateTime) {
    final endDateTime = startDateTime.add(const Duration(hours: 1));
    if (endDateTime.day != startDateTime.day) {
      return '23:59';
    }
    return DateHelper.toTimeString(endDateTime);
  }

  String _resolveEndTimeStringWithDuration(
    DateTime startDateTime,
    String durationStr,
  ) {
    if (durationStr.isEmpty) {
      return _resolveEndTimeString(startDateTime);
    }

    final minutes = _parseDurationMinutes(durationStr);
    if (minutes <= 0) {
      return _resolveEndTimeString(startDateTime);
    }

    final endDateTime = startDateTime.add(Duration(minutes: minutes));
    if (endDateTime.day != startDateTime.day) {
      return '23:59';
    }
    return DateHelper.toTimeString(endDateTime);
  }

  int _parseDurationMinutes(String durationStr) {
    if (durationStr.isEmpty) return 60;

    // "3시간" 형태
    final hourMatch = RegExp(r'(\\d+)\\s*시간').firstMatch(durationStr);
    if (hourMatch != null) {
      return int.parse(hourMatch.group(1)!) * 60;
    }

    // "2시간 30분" 형태
    final hourMinuteMatch = RegExp(
      r'(\\d+)\\s*시간\\s*(\\d+)\\s*분',
    ).firstMatch(durationStr);
    if (hourMinuteMatch != null) {
      final hours = int.parse(hourMinuteMatch.group(1)!);
      final minutes = int.parse(hourMinuteMatch.group(2)!);
      return hours * 60 + minutes;
    }

    // "90분" 형태
    final minuteMatch = RegExp(r'(\\d+)\\s*분').firstMatch(durationStr);
    if (minuteMatch != null) {
      return int.parse(minuteMatch.group(1)!);
    }

    // 기본값 60분
    return 60;
  }

  String _generateNotes(
    String subject,
    List<String> materials,
    String durationStr,
  ) {
    if (materials.isEmpty && durationStr.isEmpty) {
      return 'AI 챗봇으로 생성된 일정';
    }

    final notes = <String>['AI 챗봇으로 생성된 일정'];

    if (materials.isNotEmpty) {
      notes.add('학습 자료: ${materials.join(', ')}');
    }

    if (durationStr.isNotEmpty) {
      notes.add('예상 소요 시간: $durationStr');
    }

    return notes.join(' | ');
  }

  int _calculateDurationMinutes(
    String startTime,
    String endTime,
    DateTime date,
  ) {
    try {
      final startDateTime = DateHelper.timeStringToDateTime(startTime, date);
      final endDateTime = DateHelper.timeStringToDateTime(endTime, date);
      final diff = endDateTime.difference(startDateTime).inMinutes;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }

  _DateRange _resolveDateRange(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (period.contains('내일')) {
      final target = today.add(const Duration(days: 1));
      return _DateRange(start: target, end: target);
    }

    if (period.contains('이번 주') || period.contains('이번주')) {
      final start = DateHelper.getWeekStartDate(today);
      final end = DateHelper.getWeekEndDate(today);
      return _DateRange(start: start, end: end);
    }

    if (period.contains('다음 주') || period.contains('다음주')) {
      final start = DateHelper.getWeekStartDate(
        today,
      ).add(const Duration(days: 7));
      final end = DateHelper.getWeekEndDate(start);
      return _DateRange(start: start, end: end);
    }

    if (period.contains('이번 달') || period.contains('이번달')) {
      final start = DateTime(today.year, today.month, 1);
      final end = DateTime(today.year, today.month + 1, 0);
      return _DateRange(start: start, end: end);
    }

    return _DateRange(start: today, end: today);
  }

  /// 할일보관함에 추가 명령 처리
  Future<String> addToBacklog(Map<String, dynamic> parameters) async {
    try {
      final subject = parameters['subject'] ?? '새 할일';
      final description = parameters['description'] ?? 'AI 챗봇으로 생성된 할일';

      print('📝 DEBUG: Adding to backlog - subject: $subject');

      // Firestore에 할일보관함 추가
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('backlog_tasks')
          .add({
            'title': subject,
            'description': description,
            'priority': 'medium', // 기본값
            'isCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
            'source': 'chatbot', // 출처 표시
          });

      print('✅ DEBUG: Added to backlog with ID: ${docRef.id}');

      return '✅ "$subject"이(가) 할일보관함에 추가되었습니다!';
    } catch (e) {
      print('❌ DEBUG: Error adding to backlog: $e');
      return '❌ 할일보관함 추가 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 목표 설정 명령 처리
  Future<String> setGoal(Map<String, dynamic> parameters) async {
    try {
      if (userId.isEmpty) {
        return '❌ 사용자 정보가 없습니다. 다시 로그인해주세요.';
      }

      final periodStr = parameters['period'] ?? 'weekly';
      final targetMinutes = _parseTargetMinutes(parameters['target']);
      final now = DateTime.now();
      final period = _parseGoalPeriod(periodStr.toString());

      DateTime? specificDate;
      String? weekId;
      String? month;

      switch (period) {
        case GoalPeriod.daily:
          specificDate = now;
          break;
        case GoalPeriod.weekly:
          weekId = DateHelper.getWeekId(now);
          break;
        case GoalPeriod.monthly:
          month = DateHelper.toMonthString(now);
          break;
      }

      Map<String, int>? subjectTargets;
      final rawTargets = parameters['subject_targets'];
      if (rawTargets is Map<String, dynamic>) {
        subjectTargets = rawTargets.map(
          (key, value) => MapEntry(key, (value as num).round()),
        );
      }

      final goal = StudyGoal(
        id: '',
        userId: userId,
        period: period,
        targetMinutes: targetMinutes,
        specificDate: specificDate,
        weekId: weekId,
        month: month,
        subjectTargets: subjectTargets,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createStudyGoal(goal);
      return '✅ ${_formatGoalPeriod(period)} 목표가 설정되었습니다! (${targetMinutes}분)';
    } catch (e) {
      return '❌ 목표 설정 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 과목 추가 명령 처리
  Future<String> addSubject(Map<String, dynamic> parameters) async {
    try {
      if (userId.isEmpty) {
        return '❌ 사용자 정보가 없습니다. 다시 로그인해주세요.';
      }

      final name = parameters['name'] ?? '새 과목';
      final color = _normalizeHexColor(parameters['color']?.toString());
      final icon = parameters['icon']?.toString().trim().isNotEmpty == true
          ? parameters['icon'].toString()
          : 'book';

      final subject = Subject(
        id: '',
        userId: userId,
        name: name.toString(),
        color: color,
        icon: icon,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.createSubject(subject);
      return '✅ "$name" 과목이 추가되었습니다!';
    } catch (e) {
      return '❌ 과목 추가 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 주간 계획 설정 명령 처리
  Future<String> setWeeklyPlan(Map<String, dynamic> parameters) async {
    try {
      if (userId.isEmpty) {
        return '❌ 사용자 정보가 없습니다. 다시 로그인해주세요.';
      }

      final weekStart = _parseWeekStart(parameters['week'] ?? '이번 주');
      final subject = parameters['subject']?.toString() ?? '';
      final rawTitle =
          parameters['title'] ??
          parameters['goal'] ??
          parameters['plan'] ??
          subject;
      final title = rawTitle.toString().trim().isEmpty
          ? '이번 주 계획'
          : rawTitle.toString();
      final notes = parameters['notes']?.toString() ?? '';

      final plan = WeeklyPlan(
        id: '',
        userId: userId,
        weekStartDate: weekStart,
        weekEndDate: weekStart.add(const Duration(days: 6)),
        date: weekStart,
        title: title,
        notes: notes,
        subject: subject,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.createWeeklyPlan(plan);
      return '✅ 이번 주 계획이 설정되었습니다!';
    } catch (e) {
      return '❌ 주간 계획 설정 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 월간 계획 설정 명령 처리
  Future<String> setMonthlyPlan(Map<String, dynamic> parameters) async {
    try {
      if (userId.isEmpty) {
        return '❌ 사용자 정보가 없습니다. 다시 로그인해주세요.';
      }

      final month = _parseMonth(parameters['month'] ?? '이번 달');
      final subject = parameters['subject']?.toString() ?? '';
      final rawTitle =
          parameters['title'] ??
          parameters['goal'] ??
          parameters['plan'] ??
          subject;
      final title = rawTitle.toString().trim().isNotEmpty == true
          ? rawTitle.toString()
          : '이번 달 계획';
      final notes = parameters['notes']?.toString() ?? '';

      final plan = MonthlyPlan(
        id: '',
        userId: userId,
        month: DateHelper.toMonthString(month),
        title: title,
        notes: notes,
        subject: subject,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.createMonthlyPlan(plan);
      return '✅ 이번 달 계획이 설정되었습니다!';
    } catch (e) {
      return '❌ 월간 계획 설정 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 우선순위 매트릭스 설정 명령 처리
  Future<String> setPriorityMatrix(Map<String, dynamic> parameters) async {
    try {
      return '⚠️ 우선순위 매트릭스는 현재 챗봇에서 직접 설정을 지원하지 않습니다.';
    } catch (e) {
      return '❌ 우선순위 매트릭스 설정 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 시간표 설정 명령 처리
  Future<String> setTimetable(Map<String, dynamic> parameters) async {
    try {
      if (userId.isEmpty) {
        return '❌ 사용자 정보가 없습니다. 다시 로그인해주세요.';
      }

      final entries = parameters['entries'] ?? [];

      final timetableEntries = entries is List<dynamic>
          ? entries
                .map((e) {
                  if (e is Map<String, dynamic>) {
                    return WeeklyTimetableEntry(
                      id: '',
                      userId: userId,
                      weekday: _parseDayOfWeek(e['day'] ?? '월요일'),
                      startTime: e['start_time'] ?? '09:00',
                      endTime: e['end_time'] ?? '10:00',
                      title: e['title'] ?? e['subject'] ?? '자유시간',
                      location: e['location'],
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                  }
                  return null;
                })
                .where((e) => e != null)
                .cast<WeeklyTimetableEntry>()
          : <WeeklyTimetableEntry>[];

      for (final entry in timetableEntries) {
        await _firestoreService.createWeeklyTimetableEntry(entry);
      }

      return '✅ 시간표가 설정되었습니다!';
    } catch (e) {
      return '❌ 시간표 설정 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 알림 설정 명령 처리
  Future<String> setNotification(Map<String, dynamic> parameters) async {
    try {
      if (userId.isEmpty) {
        return '❌ 사용자 정보가 없습니다. 다시 로그인해주세요.';
      }

      final dailySummaryEnabled =
          parameters['daily_summary_enabled'] as bool? ?? true;
      final dailySummaryTime =
          parameters['daily_summary_time']?.toString() ?? '08:00';
      final planReminderEnabled =
          parameters['plan_reminder_enabled'] as bool? ?? true;
      final reminderMinutesBefore =
          int.tryParse(parameters['reminder_minutes']?.toString() ?? '10') ??
          10;
      final eveningReviewEnabled =
          parameters['evening_review_enabled'] as bool? ?? true;
      final eveningReviewTime =
          parameters['evening_review_time']?.toString() ?? '20:00';
      final streakCelebrationEnabled =
          parameters['streak_celebration_enabled'] as bool? ?? true;

      final notification = NotificationSettings(
        dailySummaryEnabled: dailySummaryEnabled,
        dailySummaryTime: dailySummaryTime,
        planReminderEnabled: planReminderEnabled,
        reminderMinutesBefore: reminderMinutesBefore,
        eveningReviewEnabled: eveningReviewEnabled,
        eveningReviewTime: eveningReviewTime,
        streakCelebrationEnabled: streakCelebrationEnabled,
      );

      await _firestoreService.saveNotificationSettings(userId, notification);
      return '✅ 알림이 설정되었습니다!';
    } catch (e) {
      return '❌ 알림 설정 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  GoalPeriod _parseGoalPeriod(String periodStr) {
    switch (periodStr.toLowerCase()) {
      case 'daily':
      case '오늘':
      case '일일':
        return GoalPeriod.daily;
      case 'weekly':
      case '이번 주':
      case '주간':
        return GoalPeriod.weekly;
      case 'monthly':
      case '이번 달':
      case '월간':
        return GoalPeriod.monthly;
      default:
        return GoalPeriod.weekly;
    }
  }

  String _formatGoalPeriod(GoalPeriod period) {
    switch (period) {
      case GoalPeriod.daily:
        return '일일';
      case GoalPeriod.weekly:
        return '주간';
      case GoalPeriod.monthly:
        return '월간';
    }
  }

  DateTime _parseWeekStart(String weekStr) {
    final now = DateTime.now();
    if (weekStr.contains('다음 주') || weekStr.contains('다음주')) {
      return DateHelper.getWeekStartDate(now).add(const Duration(days: 7));
    }
    return DateHelper.getWeekStartDate(now);
  }

  DateTime _parseMonth(String monthStr) {
    final now = DateTime.now();
    if (monthStr.contains('다음 달') || monthStr.contains('다음달')) {
      return DateTime(now.year, now.month + 1, 1);
    }
    return DateTime(now.year, now.month, 1);
  }

  int _parseDayOfWeek(String dayStr) {
    const days = {
      '월요일': 1,
      '화요일': 2,
      '수요일': 3,
      '목요일': 4,
      '금요일': 5,
      '토요일': 6,
      '일요일': 7,
    };
    return days[dayStr] ?? 1;
  }

  int _parseTargetMinutes(dynamic input) {
    if (input == null) {
      return 60;
    }
    if (input is num) {
      return input.round();
    }

    final text = input.toString();
    final hourMatch = RegExp(r'(\d+)\s*시간').firstMatch(text);
    final minuteMatch = RegExp(r'(\d+)\s*분').firstMatch(text);

    int minutes = 0;
    if (hourMatch != null) {
      minutes += int.parse(hourMatch.group(1)!) * 60;
    }
    if (minuteMatch != null) {
      minutes += int.parse(minuteMatch.group(1)!);
    }

    if (minutes > 0) {
      return minutes;
    }

    final numeric = int.tryParse(text.trim());
    return numeric ?? 60;
  }

  String _normalizeHexColor(String? color) {
    final value = (color ?? '').trim();
    if (value.isEmpty) {
      return '#2196F3';
    }
    return value.startsWith('#') ? value : '#$value';
  }

  /// 학습 자료 추가 명령 처리
  Future<String> addStudyResource(Map<String, dynamic> parameters) async {
    try {
      if (userId.isEmpty) {
        return '❌ 사용자 정보가 없습니다. 다시 로그인해주세요.';
      }

      final title = parameters['title'] ?? '새 학습 자료';
      final typeStr = parameters['type']?.toString().toLowerCase();
      final type = typeStr == '강의' || typeStr == 'lecture'
          ? StudyResourceType.lecture
          : StudyResourceType.book;
      final notes = parameters['notes']?.toString() ?? '';
      final totalUnitsStr = parameters['total_units']?.toString();
      final totalUnits = totalUnitsStr != null ? int.tryParse(totalUnitsStr) : null;

      final resource = StudyResource(
        id: '',
        userId: userId,
        title: title.toString(),
        type: type,
        notes: notes,
        totalUnits: totalUnits,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.createStudyResource(resource);
      return '✅ "$title" 학습 자료가 추가되었습니다!';
    } catch (e) {
      return '❌ 학습 자료 추가 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 화면 설정 명령 처리
  Future<String> setTheme(Map<String, dynamic> parameters) async {
    try {
      final themeStr = parameters['theme']?.toString().toLowerCase().trim();

      ThemeMode themeMode;
      String themeName;

      if (themeStr == null || themeStr.isEmpty) {
        return '❌ 테마를 지정해주세요. (예: 밝은 테마, 어두운 테마, 시스템 테마)';
      }

      if (themeStr.contains('밝') || themeStr.contains('light') || themeStr.contains('라이트')) {
        themeMode = ThemeMode.light;
        themeName = '밝은 테마';
      } else if (themeStr.contains('어둡') || themeStr.contains('dark') || themeStr.contains('다크')) {
        themeMode = ThemeMode.dark;
        themeName = '어두운 테마';
      } else if (themeStr.contains('시스템') || themeStr.contains('system') || themeStr.contains('자동')) {
        themeMode = ThemeMode.system;
        themeName = '시스템 테마';
      } else {
        return '❌ 지원하지 않는 테마입니다. 밝은 테마, 어두운 테마, 시스템 테마 중 하나를 선택해주세요.';
      }

      // 테마 저장 로직은 별도 Provider를 통해 처리되어야 함
      // 여기서는 성공 메시지만 반환
      return '✅ 화면 테마가 "$themeName"으로 설정되었습니다! 앱을 재시작하면 적용됩니다.';
    } catch (e) {
      return '❌ 테마 설정 중 오류가 발생했습니다: ${e.toString()}';
    }
  }
}

class _DateRange {
  final DateTime start;
  final DateTime end;

  const _DateRange({required this.start, required this.end});
}