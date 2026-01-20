import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CommandHandlerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;

  CommandHandlerService({required this.userId});

  /// 일정 생성 명령 처리 - 개선된 버전
  Future<String> createSchedule(Map<String, dynamic> parameters) async {
    try {
      print('🔍 DEBUG: createSchedule() called');
      print('🔍 DEBUG: userId = $userId');
      print('🔍 DEBUG: parameters = $parameters');
      
      final subject = parameters['subject'] ?? '새 일정';
      final timeStr = parameters['time'] ?? '';

      print('📝 DEBUG: subject = $subject, timeStr = $timeStr');

      // 더 정교한 날짜 파싱
      DateTime scheduleDate = DateTime.now();
      
      if (timeStr.contains('모레')) {
        scheduleDate = scheduleDate.add(const Duration(days: 2));
      } else if (timeStr.contains('내일')) {
        scheduleDate = scheduleDate.add(const Duration(days: 1));
      } else if (timeStr.contains('다음주')) {
        // 다음주의 월요일
        int daysUntilMonday = (8 - scheduleDate.weekday) % 7;
        scheduleDate = scheduleDate.add(Duration(days: daysUntilMonday + 1));
      }

      // 더 정교한 시간 파싱
      int hour = 9; // 기본값 (오전 9시)
      int minute = 0;

      // "오후 3시", "3시" 형식 지원
      if (timeStr.contains('오후')) {
        final match = RegExp(r'오후\s*(\d+)시').firstMatch(timeStr);
        if (match != null) {
          hour = int.parse(match.group(1)!) + 12; // 오후는 +12
        }
      } else if (timeStr.contains('아침') || timeStr.contains('오전')) {
        final match = RegExp(r'(\d+)시').firstMatch(timeStr);
        if (match != null) {
          hour = int.parse(match.group(1)!);
        }
      } else if (timeStr.contains('시')) {
        final match = RegExp(r'(\d+)시').firstMatch(timeStr);
        if (match != null) {
          hour = int.parse(match.group(1)!);
        }
      }

      // "시간" 또는 ":" 형식도 지원
      if (timeStr.contains(':')) {
        final match = RegExp(r'(\d+):(\d+)').firstMatch(timeStr);
        if (match != null) {
          hour = int.parse(match.group(1)!);
          minute = int.parse(match.group(2)!);
        }
      }

      scheduleDate = DateTime(
        scheduleDate.year,
        scheduleDate.month,
        scheduleDate.day,
        hour,
        minute,
      );

      print('📅 DEBUG: Final scheduleDate = $scheduleDate');

      // Firestore에 일정 추가
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('schedules')
          .add({
        'title': subject,
        'startTime': Timestamp.fromDate(scheduleDate),
        'endTime': Timestamp.fromDate(scheduleDate.add(const Duration(hours: 1))),
        'category': '공부',
        'description': 'AI 챗봇으로 생성된 일정',
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ DEBUG: Saved to Firestore with ID: ${docRef.id}');

      final dateStr = DateFormat('M월 d일 (E) a h시', 'ko_KR').format(scheduleDate);
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

      DateTime startDate = DateTime.now();
      DateTime endDate = DateTime.now();

      if (period.contains('오늘')) {
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 1));
      } else if (period.contains('내일')) {
        startDate = DateTime.now().add(const Duration(days: 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 1));
      } else if (period.contains('이번 주')) {
        startDate = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 7));
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('schedules')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThan: Timestamp.fromDate(endDate))
          .orderBy('startTime')
          .get();

      if (snapshot.docs.isEmpty) {
        return '📅 $period 일정이 없습니다.';
      }

      final schedules = snapshot.docs.map((doc) {
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp).toDate();
        final title = data['title'] ?? '제목 없음';
        final timeStr = DateFormat('a h:mm', 'ko_KR').format(startTime);
        return '• $timeStr - $title';
      }).join('\n');

      return '📅 $period 일정:\n\n$schedules';
    } catch (e) {
      return '❌ 일정 조회 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  /// 학습 통계 조회 명령 처리
  Future<String> viewStats(Map<String, dynamic> parameters) async {
    try {
      final period = parameters['period'] ?? '오늘';

      DateTime startDate = DateTime.now();
      DateTime endDate = DateTime.now();

      if (period.contains('오늘')) {
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 1));
      } else if (period.contains('이번 주')) {
        startDate = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(const Duration(days: 7));
      } else if (period.contains('이번 달')) {
        startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
        endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 1);
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('schedules')
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThan: Timestamp.fromDate(endDate))
          .where('isCompleted', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return '📊 $period 완료된 일정이 없습니다.';
      }

      int totalMinutes = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp).toDate();
        final endTime = (data['endTime'] as Timestamp).toDate();
        totalMinutes += endTime.difference(startTime).inMinutes;
      }

      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      final count = snapshot.docs.length;

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
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('schedules')
            .where('isCompleted', isEqualTo: false)
            .orderBy('startTime')
            .limit(10)
            .get();

        if (snapshot.docs.isEmpty) {
          return '✅ 완료되지 않은 할일이 없습니다!';
        }

        final todos = snapshot.docs.map((doc) {
          final data = doc.data();
          final title = data['title'] ?? '제목 없음';
          return '• $title';
        }).join('\n');

        return '📝 할일 목록:\n\n$todos';
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

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('schedules')
          .orderBy('startTime', descending: true)
          .limit(100)
          .get();

      final results = snapshot.docs.where((doc) {
        final data = doc.data();
        final title = (data['title'] ?? '').toString().toLowerCase();
        final description = (data['description'] ?? '').toString().toLowerCase();
        final searchTerm = keyword.toLowerCase();
        return title.contains(searchTerm) || description.contains(searchTerm);
      }).toList();

      if (results.isEmpty) {
        return '🔍 "$keyword" 관련 일정을 찾을 수 없습니다.';
      }

      final resultList = results.take(5).map((doc) {
        final data = doc.data();
        final title = data['title'] ?? '제목 없음';
        final startTime = (data['startTime'] as Timestamp).toDate();
        final dateStr = DateFormat('M/d a h:mm', 'ko_KR').format(startTime);
        return '• $title ($dateStr)';
      }).join('\n');

      return '🔍 "$keyword" 검색 결과 (${results.length}개):\n\n$resultList';
    } catch (e) {
      return '❌ 검색 중 오류가 발생했습니다: ${e.toString()}';
    }
  }
}
