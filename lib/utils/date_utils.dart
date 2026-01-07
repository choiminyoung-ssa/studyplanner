import 'package:intl/intl.dart';

class DateHelper {
  // 날짜를 YYYY-MM 형식으로 변환
  static String toMonthString(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  // 날짜를 YYYY-MM-DD 형식으로 변환
  static String toDateString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // 시간을 HH:mm 형식으로 변환
  static String toTimeString(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  // 날짜를 한글 형식으로 변환 (예: 2026년 1월 14일)
  static String toKoreanDateString(DateTime date) {
    return DateFormat('yyyy년 M월 d일', 'ko_KR').format(date);
  }

  // 주의 시작일(월요일) 가져오기
  static DateTime getWeekStartDate(DateTime date) {
    int weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  // 주의 종료일(일요일) 가져오기
  static DateTime getWeekEndDate(DateTime date) {
    int weekday = date.weekday;
    return date.add(Duration(days: 7 - weekday));
  }

  // 해당 주의 모든 날짜 가져오기 (월~일)
  static List<DateTime> getWeekDates(DateTime date) {
    DateTime weekStart = getWeekStartDate(date);
    List<DateTime> weekDates = [];
    for (int i = 0; i < 7; i++) {
      weekDates.add(weekStart.add(Duration(days: i)));
    }
    return weekDates;
  }

  // 두 날짜가 같은 날인지 확인
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // 오늘인지 확인
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  // 월의 첫 날 가져오기
  static DateTime getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  // 월의 마지막 날 가져오기
  static DateTime getLastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  // 요일 이름 가져오기 (한글)
  static String getWeekdayName(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return weekdays[date.weekday - 1];
  }

  // 주차 ID (예: 2025-W02)
  static String getWeekId(DateTime date) {
    final weekStart = getWeekStartDate(date);
    final firstWeekStart = getWeekStartDate(DateTime(date.year, 1, 4));
    final diff = weekStart.difference(firstWeekStart).inDays;
    final weekNumber = (diff / 7).floor() + 1;
    return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  // 시간 문자열을 DateTime으로 변환
  static DateTime timeStringToDateTime(String timeString, DateTime date) {
    final parts = timeString.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  // 두 시간 문자열 비교 (startTime < endTime)
  static bool isValidTimeRange(String startTime, String endTime) {
    final start = startTime.split(':').map(int.parse).toList();
    final end = endTime.split(':').map(int.parse).toList();

    int startMinutes = start[0] * 60 + start[1];
    int endMinutes = end[0] * 60 + end[1];

    return startMinutes < endMinutes;
  }
}
