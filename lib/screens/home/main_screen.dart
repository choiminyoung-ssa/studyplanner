import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import 'today_screen.dart';
import '../monthly/monthly_screen.dart';
import '../weekly/weekly_screen.dart';
import '../daily/daily_screen.dart';
import '../settings/subject_management_screen.dart';
import '../statistics/statistics_screen.dart';
import '../settings/notification_settings_screen.dart';
import '../goals/goal_settings_screen.dart';
import '../../widgets/timer_bottom_sheet.dart';
import '../search/search_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userId = context.read<AuthProvider>().userId;
      if (userId == null) return;
      await context.read<NotificationProvider>().loadSettings(userId);
      await context.read<NotificationProvider>().checkAndRequestPermission(userId);
    });
  }

  final List<Widget> _screens = const [
    TodayScreen(),
    MonthlyScreen(),
    WeeklyScreen(),
    DailyScreen(),
    StatisticsScreen(),
  ];

  final List<String> _titles = const [
    '오늘',
    '월간 계획',
    '주간 계획',
    '일간 계획',
    '통계',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          if (_currentIndex == 3)
            IconButton(
              icon: const Icon(Icons.timer),
              tooltip: '학습 타이머',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => TimerBottomSheet(date: DateTime.now()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '검색',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: '필터',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen(initialOpenFilters: true)),
              );
            },
          ),
          // 설정 메뉴
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              } else if (value == 'subjects') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubjectManagementScreen(),
                  ),
                );
              } else if (value == 'notifications') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationSettingsScreen(),
                  ),
                );
              } else if (value == 'goals') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GoalSettingsScreen(),
                  ),
                );
              } else if (value == 'statistics') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StatisticsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('알림 설정'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'goals',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text('목표 설정'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'statistics',
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('통계 및 분석'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'subjects',
                child: Row(
                  children: [
                    Icon(Icons.book),
                    SizedBox(width: 8),
                    Text('과목 관리'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('로그아웃', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: '오늘',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '월간',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_week_outlined),
            selectedIcon: Icon(Icons.view_week),
            label: '주간',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: '일간',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: '통계',
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}
