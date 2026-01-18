import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/monthly_plan.dart';
import '../models/weekly_plan.dart';
import '../models/daily_plan.dart';
import '../models/subject.dart';
import '../models/search_result.dart';
import '../models/study_session.dart';
import '../models/study_goal.dart';
import '../models/notification_settings.dart';
import '../models/notification_log.dart';
import '../models/weekly_timetable_entry.dart';
import '../models/backlog_task.dart';
import '../models/study_resource.dart';

class FirestoreIndexException implements Exception {
  final String message;
  final String? indexUrl;

  FirestoreIndexException(this.message, [this.indexUrl]);

  @override
  String toString() => indexUrl != null ? '$message\n인덱스 생성 링크: $indexUrl' : message;
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // helper: extract index URL from Firestore error messages
  String? _extractIndexUrl(String message) {
    final urlRe1 = RegExp(r'https?://[^\s]*create_composite[^\s]*');
    final urlRe2 = RegExp(r'https?://[^\s]*indexes[^\s]*');
    final match1 = urlRe1.firstMatch(message);
    if (match1 != null) return match1.group(0);
    final match2 = urlRe2.firstMatch(message);
    if (match2 != null) return match2.group(0);
    return null;
  }

  FirestoreIndexException? _maybeIndexException(Object error) {
    final raw = error.toString();
    final url = _extractIndexUrl(raw);
    if (url == null) return null;
    final isBuilding = raw.contains('building') || raw.contains('생성 중') || raw.contains('빌드');
    final message = isBuilding
        ? '인덱스가 생성 중입니다. 잠시 후 다시 시도하세요.'
        : '쿼리에 필요한 Firestore 인덱스가 설정되어 있지 않거나 권한이 없습니다.';
    return FirestoreIndexException(message, url);
  }

  // helper: transform stream to map + friendly error handling
  Stream<List<T>> _snapshotStreamToList<T>(Query<Map<String, dynamic>> query, T Function(DocumentSnapshot<Map<String, dynamic>> doc) mapper) {
    return query.snapshots().transform(
      StreamTransformer<QuerySnapshot<Map<String, dynamic>>, List<T>>.fromHandlers(
        handleData: (QuerySnapshot<Map<String, dynamic>> snapshot, EventSink<List<T>> sink) {
          try {
            sink.add(snapshot.docs.map(mapper).toList());
          } catch (e) {
            sink.addError(e);
          }
        },
        handleError: (error, stackTrace, sink) {
          final indexException = _maybeIndexException(error);
          if (indexException != null) {
            sink.addError(indexException);
            return;
          }
          sink.addError(
            FirestoreIndexException('쿼리에 필요한 Firestore 인덱스가 설정되어 있지 않거나 권한이 없습니다.'),
          );
        },

      ),
    );
  }

  // Subject id/name helper (used by search UI)
  Future<List<Map<String, String>>> getSubjectIdNamePairs(String userId) async {
    final q = _db.collection('subjects').where('userId', isEqualTo: userId);
    final snap = await q.get();
    return snap.docs.map((d) => {'id': d.id, 'name': (d.data()['name'] ?? '').toString()}).toList();
  }

  // ========== 월간 계획 CRUD ==========

  // 월간 계획 생성
  Future<String> createMonthlyPlan(MonthlyPlan plan) async {
    try {
      DocumentReference docRef = await _db.collection('monthly_plans').add(plan.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('월간 계획 생성 실패: $e');
    }
  }

  // 월간 계획 조회 (특정 월)
  Stream<List<MonthlyPlan>> getMonthlyPlans(String userId, String month) {
    final monthStart = _parseMonthStart(month);
    final monthEnd = monthStart != null ? DateTime(monthStart.year, monthStart.month + 1, 0) : null;

    return getAllMonthlyPlans(userId).map((plans) {
      final filtered = plans.where((plan) {
        if (monthStart == null || monthEnd == null) {
          return plan.month == month;
        }

        final range = _getMonthlyPlanRange(plan);
        if (range == null) {
          return plan.month == month;
        }

        final start = _normalizeDate(range.start);
        final end = _normalizeDate(range.end);

        if (end.isBefore(monthStart)) return false;
        if (start.isAfter(monthEnd)) return false;
        return true;
      }).toList();

      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered;
    });
  }

  // 월간 계획 조회 (모든 월)
  Stream<List<MonthlyPlan>> getAllMonthlyPlans(String userId) {
    final q = _db.collection('monthly_plans').where('userId', isEqualTo: userId).orderBy('month', descending: true);
    return _snapshotStreamToList<MonthlyPlan>(q, (doc) => MonthlyPlan.fromFirestore(doc));
  }

  DateTime? _parseMonthStart(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final monthValue = int.tryParse(parts[1]);
    if (year == null || monthValue == null) return null;
    return DateTime(year, monthValue, 1);
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  _PlanRange? _getMonthlyPlanRange(MonthlyPlan plan) {
    if (plan.startDate == null && plan.endDate == null) {
      return null;
    }

    final start = plan.startDate ?? plan.endDate!;
    final end = plan.endDate ?? plan.startDate!;

    if (start.isAfter(end)) {
      return _PlanRange(end, start);
    }
    return _PlanRange(start, end);
  }

  // 월간 계획 수정
  Future<void> updateMonthlyPlan(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _db.collection('monthly_plans').doc(id).update(updates);
    } catch (e) {
      throw Exception('월간 계획 수정 실패: $e');
    }
  }

  // 월간 계획 삭제
  Future<void> deleteMonthlyPlan(String id) async {
    try {
      await _db.collection('monthly_plans').doc(id).delete();
    } catch (e) {
      throw Exception('월간 계획 삭제 실패: $e');
    }
  }

  // 월간 계획에 주간 계획 ID 추가
  Future<void> addWeeklyIdToMonthly(String monthlyId, String weeklyId) async {
    try {
      await _db.collection('monthly_plans').doc(monthlyId).update({
        'relatedWeeklyIds': FieldValue.arrayUnion([weeklyId]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('월간 계획에 주간 계획 연결 실패: $e');
    }
  }

  // 월간 계획에서 주간 계획 ID 제거
  Future<void> removeWeeklyIdFromMonthly(String monthlyId, String weeklyId) async {
    try {
      await _db.collection('monthly_plans').doc(monthlyId).update({
        'relatedWeeklyIds': FieldValue.arrayRemove([weeklyId]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('월간 계획에서 주간 계획 연결 해제 실패: $e');
    }
  }

  // ========== 주간 계획 CRUD ==========

  // 주간 계획 생성
  Future<String> createWeeklyPlan(WeeklyPlan plan) async {
    try {
      DocumentReference docRef = await _db.collection('weekly_plans').add(plan.toFirestore());

      // 부모 월간 계획이 있다면 연결
      if (plan.parentMonthlyId != null && plan.parentMonthlyId!.isNotEmpty) {
        await addWeeklyIdToMonthly(plan.parentMonthlyId!, docRef.id);
      }

      return docRef.id;
    } catch (e) {
      throw Exception('주간 계획 생성 실패: $e');
    }
  }

  // 주간 계획 조회 (특정 주)
  Stream<List<WeeklyPlan>> getWeeklyPlans(String userId, DateTime weekStart, DateTime weekEnd) {
    final q = _db.collection('weekly_plans')
      .where('userId', isEqualTo: userId)
      .where('weekStartDate', isEqualTo: Timestamp.fromDate(weekStart))
      .where('weekEndDate', isEqualTo: Timestamp.fromDate(weekEnd))
      .orderBy('date');

    return _snapshotStreamToList<WeeklyPlan>(q, (doc) => WeeklyPlan.fromFirestore(doc));
  }

  // 주간 계획 조회 (날짜 범위)
  Stream<List<WeeklyPlan>> getWeeklyPlansByDateRange(String userId, DateTime start, DateTime end) {
    final q = _db.collection('weekly_plans')
      .where('userId', isEqualTo: userId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));

    return _snapshotStreamToList<WeeklyPlan>(q, (doc) => WeeklyPlan.fromFirestore(doc)).map((plans) {
      plans.sort((a, b) => a.date.compareTo(b.date));
      return plans;
    });
  }

  // Search across daily/weekly/monthly plans using server-side filters where possible
  Future<List<SearchResult>> searchPlans({
    required String userId,
    String? query,
    DateTime? start,
    DateTime? end,
    String? subjectId,
    bool? completed,
    List<int>? priorities,
  }) async {
    final results = <SearchResult>[];

    // Daily plans query
    Query dailyQ = _db.collection('daily_plans').where('userId', isEqualTo: userId);
    if (start != null) dailyQ = dailyQ.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    if (end != null) dailyQ = dailyQ.where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));
    if (subjectId != null) dailyQ = dailyQ.where('subjectId', isEqualTo: subjectId);
    if (completed != null) dailyQ = dailyQ.where('isCompleted', isEqualTo: completed);
    if (priorities != null && priorities.isNotEmpty) dailyQ = dailyQ.where('priority', whereIn: priorities);

    final dailySnapshot = await dailyQ.get();
    for (final doc in dailySnapshot.docs) {
      final dp = DailyPlan.fromFirestore(doc);
      results.add(SearchResult(
        id: dp.id,
        type: PlanType.daily,
        date: dp.date,
        title: dp.title,
        notes: dp.notes,
        subjectId: dp.subjectId,
        subject: dp.subject,
        priority: dp.priority,
        isCompleted: dp.isCompleted,
      ));
    }

    // Weekly plans
    Query weeklyQ = _db.collection('weekly_plans').where('userId', isEqualTo: userId);
    if (start != null) weeklyQ = weeklyQ.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    if (end != null) weeklyQ = weeklyQ.where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));
    if (subjectId != null) weeklyQ = weeklyQ.where('subjectId', isEqualTo: subjectId);
    if (completed != null) weeklyQ = weeklyQ.where('isCompleted', isEqualTo: completed);
    if (priorities != null && priorities.isNotEmpty) weeklyQ = weeklyQ.where('priority', whereIn: priorities);

    final weeklySnapshot = await weeklyQ.get();
    for (final doc in weeklySnapshot.docs) {
      final wp = WeeklyPlan.fromFirestore(doc);
      results.add(SearchResult(
        id: wp.id,
        type: PlanType.weekly,
        date: wp.date,
        title: wp.title,
        notes: wp.notes,
        subjectId: wp.subjectId,
        subject: wp.subject,
        priority: wp.priority,
        isCompleted: wp.isCompleted,
      ));
    }

    // Monthly plans (filter by start/end overlap)
    Query monthlyQ = _db.collection('monthly_plans').where('userId', isEqualTo: userId);
    if (subjectId != null) monthlyQ = monthlyQ.where('subjectId', isEqualTo: subjectId);
    if (completed != null) monthlyQ = monthlyQ.where('isCompleted', isEqualTo: completed);
    if (priorities != null && priorities.isNotEmpty) monthlyQ = monthlyQ.where('priority', whereIn: priorities);

    final monthlySnapshot = await monthlyQ.get();
    for (final doc in monthlySnapshot.docs) {
      final mp = MonthlyPlan.fromFirestore(doc);
      // If start/end provided, check overlap with monthly plan range
      if (start != null || end != null) {
        final s = mp.startDate ?? DateTime.parse('${mp.month}-01');
        final e = mp.endDate ?? DateTime(s.year, s.month + 1, 0);
        if (start != null && e.isBefore(start)) continue;
        if (end != null && s.isAfter(end)) continue;
      }
      results.add(SearchResult(
        id: mp.id,
        type: PlanType.monthly,
        date: mp.startDate ?? DateTime.parse('${mp.month}-01'),
        title: mp.title,
        notes: mp.notes,
        subjectId: mp.subjectId,
        subject: mp.subject,
        priority: mp.priority,
        isCompleted: mp.isCompleted,
      ));
    }

    // Client-side text filtering (title + notes)
    if (query != null && query.isNotEmpty) {
      final qLower = query.toLowerCase();
      return results.where((r) => r.title.toLowerCase().contains(qLower) || r.notes.toLowerCase().contains(qLower)).toList();
    }

    // Sort by date desc
    results.sort((a, b) => b.date.compareTo(a.date));
    return results;
  }

  // 주간 계획 수정
  Future<void> updateWeeklyPlan(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _db.collection('weekly_plans').doc(id).update(updates);
    } catch (e) {
      throw Exception('주간 계획 수정 실패: $e');
    }
  }

  // 주간 계획 삭제
  Future<void> deleteWeeklyPlan(String id) async {
    try {
      await _db.collection('weekly_plans').doc(id).delete();
    } catch (e) {
      throw Exception('주간 계획 삭제 실패: $e');
    }
  }

  // 주간 계획에 일간 계획 ID 추가
  Future<void> addDailyIdToWeekly(String weeklyId, String dailyId) async {
    try {
      await _db.collection('weekly_plans').doc(weeklyId).update({
        'relatedDailyIds': FieldValue.arrayUnion([dailyId]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('주간 계획에 일간 계획 연결 실패: $e');
    }
  }

  // 주간 계획에서 일간 계획 ID 제거
  Future<void> removeDailyIdFromWeekly(String weeklyId, String dailyId) async {
    try {
      await _db.collection('weekly_plans').doc(weeklyId).update({
        'relatedDailyIds': FieldValue.arrayRemove([dailyId]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('주간 계획에서 일간 계획 연결 해제 실패: $e');
    }
  }

  // ========== 일간 계획 CRUD ==========

  // 일간 계획 생성
  Future<String> createDailyPlan(DailyPlan plan) async {
    try {
      DocumentReference docRef = await _db.collection('daily_plans').add(plan.toFirestore());

      // 부모 주간 계획이 있다면 연결
      if (plan.parentWeeklyId != null && plan.parentWeeklyId!.isNotEmpty) {
        await addDailyIdToWeekly(plan.parentWeeklyId!, docRef.id);
      }

      return docRef.id;
    } catch (e) {
      throw Exception('일간 계획 생성 실패: $e');
    }
  }

  // 일간 계획 조회 (특정 날짜)
  Stream<List<DailyPlan>> getDailyPlans(String userId, DateTime date) {
    // 날짜의 시작과 끝
    DateTime startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final q = _db
        .collection('daily_plans')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('date')
        .orderBy('startTime');

    return _snapshotStreamToList<DailyPlan>(q, (doc) => DailyPlan.fromFirestore(doc));
  }

  // 일간 계획 조회 (기간)
  Future<List<DailyPlan>> getDailyPlansByDateRange(String userId, DateTime start, DateTime end) async {
    try {
      final startOfDay = DateTime(start.year, start.month, start.day, 0, 0, 0);
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
      final q = _db
          .collection('daily_plans')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('date')
          .orderBy('startTime');

      final snapshot = await q.get();
      return snapshot.docs.map((doc) => DailyPlan.fromFirestore(doc)).toList();
    } catch (e) {
      final indexException = _maybeIndexException(e);
      if (indexException != null) throw indexException;
      throw Exception('일간 계획 조회 실패: $e');
    }
  }

  // 일간 계획 수정
  Future<void> updateDailyPlan(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _db.collection('daily_plans').doc(id).update(updates);
    } catch (e) {
      throw Exception('일간 계획 수정 실패: $e');
    }
  }

  // 일간 계획 삭제
  Future<void> deleteDailyPlan(String id) async {
    try {
      await _db.collection('daily_plans').doc(id).delete();
    } catch (e) {
      throw Exception('일간 계획 삭제 실패: $e');
    }
  }

  // ========== 연관 데이터 조회 ==========

  // 특정 월간 계획과 연결된 주간 계획들 조회
  Future<List<WeeklyPlan>> getRelatedWeeklyPlans(List<String> weeklyIds) async {
    if (weeklyIds.isEmpty) return [];

    try {
      List<WeeklyPlan> plans = [];
      // Firestore는 in 쿼리가 10개 제한이 있으므로 분할 처리
      for (int i = 0; i < weeklyIds.length; i += 10) {
        int end = (i + 10 < weeklyIds.length) ? i + 10 : weeklyIds.length;
        List<String> batch = weeklyIds.sublist(i, end);

        QuerySnapshot snapshot = await _db
            .collection('weekly_plans')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        plans.addAll(snapshot.docs.map((doc) => WeeklyPlan.fromFirestore(doc)).toList());
      }
      return plans;
    } catch (e) {
      final url = _extractIndexUrl(e.toString());
      if (url != null) throw FirestoreIndexException('연관 주간 계획 조회 실패: Firestore 인덱스가 필요합니다.', url);
      throw Exception('연관 주간 계획 조회 실패: $e');
    }
  }

  // 특정 주간 계획과 연결된 일간 계획들 조회
  Future<List<DailyPlan>> getRelatedDailyPlans(List<String> dailyIds) async {
    if (dailyIds.isEmpty) return [];

    try {
      List<DailyPlan> plans = [];
      for (int i = 0; i < dailyIds.length; i += 10) {
        int end = (i + 10 < dailyIds.length) ? i + 10 : dailyIds.length;
        List<String> batch = dailyIds.sublist(i, end);

        QuerySnapshot snapshot = await _db
            .collection('daily_plans')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        plans.addAll(snapshot.docs.map((doc) => DailyPlan.fromFirestore(doc)).toList());
      }
      return plans;
    } catch (e) {      final url = _extractIndexUrl(e.toString());
      if (url != null) throw FirestoreIndexException('연관 주간 계획 조회 실패: Firestore 인덱스가 필요합니다.', url);      throw Exception('연관 일간 계획 조회 실패: $e');
    }
  }

  // 특정 일간 계획의 부모 주간 계획 조회
  Future<WeeklyPlan?> getParentWeeklyPlan(String weeklyId) async {
    try {
      DocumentSnapshot doc = await _db.collection('weekly_plans').doc(weeklyId).get();
      if (doc.exists) {
        return WeeklyPlan.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('부모 주간 계획 조회 실패: $e');
    }
  }

  // 특정 주간 계획의 부모 월간 계획 조회
  Future<MonthlyPlan?> getParentMonthlyPlan(String monthlyId) async {
    try {
      DocumentSnapshot doc = await _db.collection('monthly_plans').doc(monthlyId).get();
      if (doc.exists) {
        return MonthlyPlan.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('부모 월간 계획 조회 실패: $e');
    }
  }

  // ========== 알림 설정 ==========

  Future<NotificationSettings> getNotificationSettings(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).collection('settings').doc('notifications').get();
      if (!doc.exists || doc.data() == null) {
        return NotificationSettings();
      }
      return NotificationSettings.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('알림 설정 조회 실패: $e');
    }
  }

  Future<void> saveNotificationSettings(String userId, NotificationSettings settings) async {
    try {
      await _db.collection('users').doc(userId).collection('settings').doc('notifications').set({
        ...settings.toMap(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('알림 설정 저장 실패: $e');
    }
  }

  // ========== 학습 세션 ==========

  Future<String> saveStudySession(StudySession session) async {
    try {
      final docRef = await _db.collection('study_sessions').add(session.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('학습 세션 저장 실패: $e');
    }
  }

  // ========== 학습 목표 ==========

  Future<String> createStudyGoal(StudyGoal goal) async {
    try {
      final docRef = await _db.collection('study_goals').add({
        'userId': goal.userId,
        'period': goal.period.name,
        'targetMinutes': goal.targetMinutes,
        'specificDate': goal.specificDate != null ? Timestamp.fromDate(goal.specificDate!) : null,
        'weekId': goal.weekId,
        'month': goal.month,
        'subjectTargets': goal.subjectTargets,
        'isActive': goal.isActive,
        'createdAt': Timestamp.fromDate(goal.createdAt),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('학습 목표 생성 실패: $e');
    }
  }

  Future<StudyGoal?> getDailyGoal(String userId, DateTime date) async {
    try {
      final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final end = DateTime(date.year, date.month, date.day, 23, 59, 59);
      final snapshot = await _db
          .collection('study_goals')
          .where('userId', isEqualTo: userId)
          .where('period', isEqualTo: GoalPeriod.daily.name)
          .where('specificDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('specificDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return _mapStudyGoal(snapshot.docs.first);
    } catch (e) {
      final indexException = _maybeIndexException(e);
      if (indexException != null) throw indexException;
      throw Exception('일간 목표 조회 실패: $e');
    }
  }

  Future<StudyGoal?> getWeeklyGoal(String userId, String weekId) async {
    try {
      final snapshot = await _db
          .collection('study_goals')
          .where('userId', isEqualTo: userId)
          .where('period', isEqualTo: GoalPeriod.weekly.name)
          .where('weekId', isEqualTo: weekId)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return _mapStudyGoal(snapshot.docs.first);
    } catch (e) {
      final indexException = _maybeIndexException(e);
      if (indexException != null) throw indexException;
      throw Exception('주간 목표 조회 실패: $e');
    }
  }

  Future<StudyGoal?> getMonthlyGoal(String userId, String month) async {
    try {
      final snapshot = await _db
          .collection('study_goals')
          .where('userId', isEqualTo: userId)
          .where('period', isEqualTo: GoalPeriod.monthly.name)
          .where('month', isEqualTo: month)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return _mapStudyGoal(snapshot.docs.first);
    } catch (e) {
      final indexException = _maybeIndexException(e);
      if (indexException != null) throw indexException;
      throw Exception('월간 목표 조회 실패: $e');
    }
  }

  StudyGoal _mapStudyGoal(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudyGoal(
      id: doc.id,
      userId: data['userId'] ?? '',
      period: GoalPeriod.values.firstWhere(
        (p) => p.name == data['period'],
        orElse: () => GoalPeriod.daily,
      ),
      targetMinutes: data['targetMinutes'] ?? 0,
      specificDate: data['specificDate'] != null ? (data['specificDate'] as Timestamp).toDate() : null,
      weekId: data['weekId'],
      month: data['month'],
      subjectTargets: (data['subjectTargets'] as Map?)?.map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      ),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // ========== 과목 CRUD ==========

  // 과목 생성
  Future<String> createSubject(Subject subject) async {
    try {
      DocumentReference docRef = await _db.collection('subjects').add(subject.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('과목 생성 실패: $e');
    }
  }

  // 과목 조회 (사용자별, 활성화된 것만)
  Stream<List<Subject>> getSubjects(String userId) {
    final q = _db
        .collection('subjects')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('displayOrder');

    return _snapshotStreamToList<Subject>(q, (doc) => Subject.fromFirestore(doc));
  }

  // 과목 조회 (모든 것, 관리 화면용)
  Stream<List<Subject>> getAllSubjects(String userId) {
    final q = _db
        .collection('subjects')
        .where('userId', isEqualTo: userId)
        .orderBy('displayOrder');

    return _snapshotStreamToList<Subject>(q, (doc) => Subject.fromFirestore(doc));
  }

  // 과목 수정
  Future<void> updateSubject(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _db.collection('subjects').doc(id).update(updates);
    } catch (e) {
      throw Exception('과목 수정 실패: $e');
    }
  }

  // 과목 삭제 (soft delete)
  Future<void> deleteSubject(String id) async {
    try {
      await _db.collection('subjects').doc(id).update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('과목 삭제 실패: $e');
    }
  }

  // 과목 복구
  Future<void> restoreSubject(String id) async {
    try {
      await _db.collection('subjects').doc(id).update({
        'isActive': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('과목 복구 실패: $e');
    }
  }

  // 과목 영구 삭제
  Future<void> deleteSubjectForever(String id) async {
    try {
      await _db.collection('subjects').doc(id).delete();
    } catch (e) {
      throw Exception('과목 영구 삭제 실패: $e');
    }
  }

  // 과목 순서 변경 (배치 업데이트)
  Future<void> updateSubjectOrders(List<Subject> subjects) async {
    try {
      final batch = _db.batch();
      for (int i = 0; i < subjects.length; i++) {
        final docRef = _db.collection('subjects').doc(subjects[i].id);
        batch.update(docRef, {
          'displayOrder': i,
          'updatedAt': Timestamp.now(),
        });
      }
      await batch.commit();
    } catch (e) {
      throw Exception('과목 순서 변경 실패: $e');
    }
  }

  // 특정 과목 조회 (단일)
  Future<Subject?> getSubjectById(String id) async {
    try {
      DocumentSnapshot doc = await _db.collection('subjects').doc(id).get();
      if (doc.exists) {
        return Subject.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('과목 조회 실패: $e');
    }
  }

  // ========== 주간 시간표 ==========

  Stream<List<WeeklyTimetableEntry>> getWeeklyTimetable(String userId) {
    final q = _db
        .collection('users')
        .doc(userId)
        .collection('weekly_timetable')
        .orderBy('weekday');

    return _snapshotStreamToList<WeeklyTimetableEntry>(q, (doc) => WeeklyTimetableEntry.fromFirestore(doc));
  }

  Future<String> createWeeklyTimetableEntry(WeeklyTimetableEntry entry) async {
    try {
      final docRef = await _db
          .collection('users')
          .doc(entry.userId)
          .collection('weekly_timetable')
          .add(entry.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('시간표 생성 실패: $e');
    }
  }

  Future<void> updateWeeklyTimetableEntry(String userId, String entryId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _db
          .collection('users')
          .doc(userId)
          .collection('weekly_timetable')
          .doc(entryId)
          .update(updates);
    } catch (e) {
      throw Exception('시간표 수정 실패: $e');
    }
  }

  Future<void> deleteWeeklyTimetableEntry(String userId, String entryId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('weekly_timetable')
          .doc(entryId)
          .delete();
    } catch (e) {
      throw Exception('시간표 삭제 실패: $e');
    }
  }

  // ========== 할일 보관함 ==========

  Stream<List<BacklogTask>> getBacklogTasks(String userId) {
    final q = _db
        .collection('users')
        .doc(userId)
        .collection('backlog_tasks')
        .orderBy('updatedAt', descending: true);
    return _snapshotStreamToList<BacklogTask>(q, (doc) => BacklogTask.fromFirestore(doc));
  }

  Future<String> createBacklogTask(BacklogTask task) async {
    try {
      final docRef = await _db
          .collection('users')
          .doc(task.userId)
          .collection('backlog_tasks')
          .add(task.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('할일 생성 실패: $e');
    }
  }

  Future<void> updateBacklogTask(String userId, String taskId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _db
          .collection('users')
          .doc(userId)
          .collection('backlog_tasks')
          .doc(taskId)
          .update(updates);
    } catch (e) {
      throw Exception('할일 수정 실패: $e');
    }
  }

  Future<void> deleteBacklogTask(String userId, String taskId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('backlog_tasks')
          .doc(taskId)
          .delete();
    } catch (e) {
      throw Exception('할일 삭제 실패: $e');
    }
  }

  // ========== 알림 로그 ==========

  Future<void> addNotificationLog(NotificationLog log) async {
    try {
      await _db.collection('notification_logs').add(log.toFirestore());
    } catch (e) {
      throw Exception('알림 로그 저장 실패: $e');
    }
  }

  Stream<List<NotificationLog>> getNotificationLogs(String userId, {int limit = 20}) {
    final q = _db
        .collection('notification_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    return _snapshotStreamToList<NotificationLog>(q, (doc) => NotificationLog.fromFirestore(doc));
  }

  // ========== 학습 자료(강의/문제집) ==========

  Stream<List<StudyResource>> getStudyResources(String userId) {
    final q = _db
        .collection('users')
        .doc(userId)
        .collection('study_resources')
        .orderBy('updatedAt', descending: true);
    return _snapshotStreamToList<StudyResource>(q, (doc) => StudyResource.fromFirestore(doc));
  }

  Future<String> createStudyResource(StudyResource resource) async {
    try {
      final docRef = await _db
          .collection('users')
          .doc(resource.userId)
          .collection('study_resources')
          .add(resource.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('학습 자료 생성 실패: $e');
    }
  }

  Future<void> updateStudyResource(String userId, String resourceId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _db
          .collection('users')
          .doc(userId)
          .collection('study_resources')
          .doc(resourceId)
          .update(updates);
    } catch (e) {
      throw Exception('학습 자료 수정 실패: $e');
    }
  }

  Future<void> deleteStudyResource(String userId, String resourceId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('study_resources')
          .doc(resourceId)
          .delete();
    } catch (e) {
      throw Exception('학습 자료 삭제 실패: $e');
    }
  }
}

class _PlanRange {
  final DateTime start;
  final DateTime end;

  const _PlanRange(this.start, this.end);
}
