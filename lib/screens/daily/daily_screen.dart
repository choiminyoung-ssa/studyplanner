import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/goal_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/daily_plan.dart';
import '../../models/subject.dart';
import '../../utils/date_utils.dart';
import 'daily_form_screen.dart';
import 'completion_tracker_dialog.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  DateTime _selectedDate = DateTime.now();
  final FirestoreService _firestoreService = FirestoreService();

  // Index auto-retry state
  Timer? _indexRetryTimer;
  int _indexRetryCount = 0;
  final int _maxIndexRetries = 8;
  final Duration _retryInterval = Duration(seconds: 15);
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGoalsForDate());
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadGoalsForDate();
  }

  Future<void> _loadGoalsForDate() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    await context.read<GoalProvider>().loadGoals(userId, _selectedDate);
    final goal = context.read<GoalProvider>().dailyGoal;
    if (goal != null) {
      await context.read<GoalProvider>().calculateAchievement(userId, goal);
    }
  }

  void _startIndexRetry() {
    if (_isRetrying) return;
    _isRetrying = true;
    _indexRetryCount = 0;
    _indexRetryTimer = Timer.periodic(_retryInterval, (timer) {
      _indexRetryCount++;
      if (mounted) setState(() {});
      // stop after max attempts
      if (_indexRetryCount >= _maxIndexRetries) {
        _stopIndexRetry();
      }
    });
  }

  void _stopIndexRetry() {
    _indexRetryTimer?.cancel();
    _indexRetryTimer = null;
    _isRetrying = false;
    _indexRetryCount = 0;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;

    if (userId == null) {
      return const Center(child: Text('로그인이 필요합니다'));
    }

    return Scaffold(
      body: Column(
        children: [
          // 날짜 선택기
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeDate(-1),
                    ),
                    Column(
                      children: [
                        Text(
                          DateHelper.toKoreanDateString(_selectedDate),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '${DateHelper.getWeekdayName(_selectedDate)}요일',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeDate(1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime.now();
                    });
                  },
                  icon: const Icon(Icons.today),
                  label: const Text('오늘'),
                ),
              ],
            ),
          ),

          // 타임라인
          Expanded(
            child: StreamBuilder<List<DailyPlan>>(
              stream: _firestoreService.getDailyPlans(userId, _selectedDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  final err = snapshot.error;
                  if (err is FirestoreIndexException) {
                    final isBuilding = err.message.contains('생성 중') || err.message.contains('빌드') || err.message.contains('building');

                    // Start or stop auto-retry appropriately (use post-frame to avoid starting from build repeatedly)
                    if (isBuilding && !_isRetrying) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _startIndexRetry());
                    } else if (!isBuilding && _isRetrying) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _stopIndexRetry());
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('데이터 조회 오류', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(isBuilding ? '인덱스가 생성 중입니다. 잠시 후 자동으로 재시도합니다.' : '이 쿼리를 실행하려면 Firestore에 복합 인덱스가 필요합니다.'),
                              const SizedBox(height: 8),

                              if (err.indexUrl != null) ...[
                                SelectableText(err.indexUrl!),
                                const SizedBox(height: 8),

                                // Action row: open index page + manual refresh
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => launchUrlString(err.indexUrl!),
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('인덱스 생성 페이지 열기'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        // manual immediate retry
                                        _indexRetryCount = 0;
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('새로고침'),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Auto-retry status
                                if (_isRetrying) ...[
                                  Row(
                                    children: [
                                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                      const SizedBox(width: 8),
                                      Text('자동 재시도: \\$_indexRetryCount/\\$_maxIndexRetries'),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () => _stopIndexRetry(),
                                        icon: const Icon(Icons.stop),
                                        label: const Text('중지'),
                                      ),
                                    ],
                                  ),
                                ],

                              ] else ...[
                                ElevatedButton.icon(
                                  onPressed: () => setState(() {}),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('재시도'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Center(child: Text('오류: ${snapshot.error}'));
                }

                final plans = snapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildGoalProgress(),
                    if (plans.isNotEmpty) const SizedBox(height: 8),
                    if (plans.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.event_available, size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                '이 날짜에 계획이 없습니다',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // 타임라인 블록들
                      _buildTimeline(plans),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPlan(),
        icon: const Icon(Icons.add),
        label: const Text('일정 추가'),
      ),
    );
  }

  Widget _buildGoalProgress() {
    return Consumer<GoalProvider>(
      builder: (context, goalProvider, _) {
        final goal = goalProvider.dailyGoal;
        final achievement = goalProvider.currentAchievement;

        if (goal == null || achievement == null) {
          return const SizedBox.shrink();
        }

        final progress = (achievement.achievementRate / 100).clamp(0.0, 1.0);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('오늘의 목표', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${achievement.actualMinutes}분 / ${goal.targetMinutes}분'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                Text(
                  achievement.statusEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeline(List<DailyPlan> plans) {
    // 시간순으로 정렬
    plans.sort((a, b) => a.startTime.compareTo(b.startTime));

    // 24시간을 6시부터 시작하도록 재정렬
    final hours = List.generate(24, (i) => (i + 6) % 24);

    return Column(
          children: [
            // 시간 눈금 표시 (6:00부터 시작하는 24시간)
            for (int hour in hours)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 시간 라벨
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // 타임라인 영역
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _addPlanAtTime(hour),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 1.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.grey[300]!, Colors.grey[200]!],
                              ),
                            ),
                          ),
                          // 이 시간대에 있는 계획들 표시 (높이는 지속시간 기반)
                          ...plans.where((plan) {
                            final startHour = int.parse(plan.startTime.split(':')[0]);
                            return startHour == hour;
                          }).map((plan) {
                            // duration 계산
                            final partsStart = plan.startTime.split(':');
                            final partsEnd = plan.endTime.split(':');
                            final startMin = int.parse(partsStart[0]) * 60 + int.parse(partsStart[1]);
                            final endMin = int.parse(partsEnd[0]) * 60 + int.parse(partsEnd[1]);
                            int duration = endMin - startMin;
                            if (duration <= 0) duration = 30; // 최소 30분
                            final height = (duration * 1.2).clamp(70.0, 300.0).toDouble(); // 높이 증가

                            return Container(
                              height: height,
                              margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 12),
                              child: _buildTimeBlock(plan, height: height),
                            );
                          }),
                          // 빈 공간 (클릭 영역)
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
    );
  }

  Widget _buildTimeBlock(DailyPlan plan, {required double height}) {
    // 과목 정보를 가져와서 배경색에 적용
    if (plan.subjectId != null) {
      return StreamBuilder<Subject?>(
        stream: _firestoreService.getSubjectById(plan.subjectId!).asStream(),
        builder: (context, snapshot) {
          Color? subjectColor;
          if (snapshot.hasData && snapshot.data != null) {
            final subject = snapshot.data!;
            subjectColor = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
          }
          return _buildTimeBlockContent(plan, subjectColor, height);
        },
      );
    }
    return _buildTimeBlockContent(plan, null, height);
  }

  Widget _buildTimeBlockContent(DailyPlan plan, Color? subjectColor, double height) {
    // 과목 색상이 있으면 투명도를 낮춰서 배경에 사용
    final backgroundColor = plan.isCompleted
        ? Colors.green.withAlpha(77)  // 완료된 경우 녹색
        : subjectColor != null
            ? subjectColor.withAlpha(51)  // 과목 색상 (투명도 20%)
            : Theme.of(context).colorScheme.primaryContainer.withAlpha(128);

    final borderColor = plan.isCompleted
        ? Colors.green.withAlpha(179)
        : subjectColor != null
            ? subjectColor.withAlpha(153)  // 과목 색상 (투명도 60%)
            : Theme.of(context).colorScheme.primary.withAlpha(128);

    final isCompact = height < 90;
    final isTight = height < 70;
    final verticalPadding = isCompact ? 4.0 : 6.0;
    final showDetails = !isCompact;
    final showMetaRow = !isTight;

    return GestureDetector(
      onTap: () => _showCompletionTracker(plan),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (subjectColor ?? Theme.of(context).colorScheme.primary).withAlpha(51),
              blurRadius: 8.0,
              offset: const Offset(0, 2.0),
            ),
          ],
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Subject color bar (왼쪽 강조 바)
            if (subjectColor != null)
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
              ),
                // Main content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleComplete(plan),
                          child: Icon(
                            plan.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: isCompact ? 20 : 24,
                            color: plan.isCompleted ? Colors.green : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                plan.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // 세부 목표 진행도 표시
                              if (showDetails && plan.subtasks.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.checklist, size: 11, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${plan.subtasks.where((s) => s.isCompleted).length}/${plan.subtasks.length} 완료',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${(plan.subtasks.where((s) => s.isCompleted).length / plan.subtasks.length * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      LinearProgressIndicator(
                                        value: plan.subtasks.isEmpty ? 0 : plan.subtasks.where((s) => s.isCompleted).length / plan.subtasks.length,
                                        minHeight: 2.5,
                                        backgroundColor: Colors.grey[300],
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                      ),
                                    ],
                                  ),
                                ),
                              // 예상 시간 표시
                              if (showDetails && plan.subtasks.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Row(
                                    children: [
                                      Icon(Icons.timer_outlined, size: 11, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        '예상: ${plan.subtasks.fold<int>(0, (sum, s) => sum + s.estimatedMinutes)}분',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 2),
                              if (showMetaRow)
                                Row(
                                  children: [
                                    // Subject icon and name
                                    if (plan.subjectId != null)
                                      Flexible(
                                        child: StreamBuilder<Subject?>(
                                          stream: _firestoreService.getSubjectById(plan.subjectId!).asStream(),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData && snapshot.data != null) {
                                              final subject = snapshot.data!;
                                              final color = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    SubjectIconHelper.getIcon(subject.icon),
                                                    size: 14,
                                                    color: color,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      subject.name,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: color,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${plan.startTime} - ${plan.endTime}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'complete') {
                              _toggleComplete(plan);
                            } else if (value == 'delete') {
                              _deletePlan(plan);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'complete',
                              child: Row(
                                children: [
                                  Icon(plan.isCompleted ? Icons.undo : Icons.check),
                                  const SizedBox(width: 8),
                                  Text(plan.isCompleted ? '완료 취소' : '완료'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('삭제', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
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

  // 완료도 추적 다이얼로그 표시
  void _showCompletionTracker(DailyPlan plan) {
    showDialog(
      context: context,
      builder: (context) => CompletionTrackerDialog(
        plan: plan,
        firestoreService: _firestoreService,
        onEdit: () => _editPlan(plan),
      ),
    );
  }

  void _addPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyFormScreen(date: _selectedDate),
      ),
    );
  }

  void _addPlanAtTime(int hour) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyFormScreen(
          date: _selectedDate,
          initialStartTime: '${hour.toString().padLeft(2, '0')}:00',
          initialEndTime: '${(hour + 1).toString().padLeft(2, '0')}:00',
        ),
      ),
    );
  }

  void _editPlan(DailyPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyFormScreen(date: _selectedDate, plan: plan),
      ),
    );
  }

  Future<void> _toggleComplete(DailyPlan plan) async {
    await _firestoreService.updateDailyPlan(
      plan.id,
      {'isCompleted': !plan.isCompleted},
    );
  }

  void _deletePlan(DailyPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('정말 이 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _firestoreService.deleteDailyPlan(plan.id);
                await context.read<NotificationProvider>().onPlanDeleted(plan.id);
                if (!mounted) return;
                navigator.pop();
              } catch (e) {
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopIndexRetry();
    super.dispose();
  }
}
