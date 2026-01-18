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
import '../../models/weekly_timetable_entry.dart';
import '../../utils/date_utils.dart';
import 'daily_form_screen.dart';
import 'completion_tracker_dialog.dart';
import '../../widgets/fade_sliver_header.dart';

class DailyScreen extends StatefulWidget {
  final ValueNotifier<DateTime> selectedDateNotifier;

  const DailyScreen({super.key, required this.selectedDateNotifier});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  DateTime _selectedDate = DateTime.now();
  final FirestoreService _firestoreService = FirestoreService();
  static const int _timelineStartHour = 6;
  static const int _timelineHourCount = 24;
  static const double _timelineHourHeight = 72;
  static const double _timelineLabelWidth = 64;
  bool _showTimetableOverlay = true;

  // Index auto-retry state
  Timer? _indexRetryTimer;
  int _indexRetryCount = 0;
  final int _maxIndexRetries = 8;
  final Duration _retryInterval = Duration(seconds: 15);
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDateNotifier.value;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGoalsForDate());
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    widget.selectedDateNotifier.value = _selectedDate;
    _loadGoalsForDate();
  }

  Future<void> _loadGoalsForDate() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    final goalProvider = context.read<GoalProvider>();
    await goalProvider.loadGoals(userId, _selectedDate);
    final goal = goalProvider.dailyGoal;
    if (goal != null) {
      await goalProvider.calculateAchievement(userId, goal);
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          final maxWidth = isWide ? 1200.0 : double.infinity;
          final headerHeight = isWide ? 130.0 : 140.0;

          return SafeArea(
            top: false,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                FadeSliverHeader(
                  maxHeight: headerHeight,
                  child: _buildDateHeader(),
                ),
              ],
              body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: StreamBuilder<List<WeeklyTimetableEntry>>(
                    stream: _firestoreService.getWeeklyTimetable(userId),
                    builder: (context, timetableSnapshot) {
                      final timetableEntries = timetableSnapshot.data ?? [];
                      final dayTimetable = _filterTimetableForDate(timetableEntries);

                      return StreamBuilder<List<DailyPlan>>(
                        stream: _firestoreService.getDailyPlans(userId, _selectedDate),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            final err = snapshot.error;
                            if (err is FirestoreIndexException) {
                              final isBuilding = err.message.contains('생성 중') ||
                                  err.message.contains('빌드') ||
                                  err.message.contains('building');

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
                                        Text(
                                          '데이터 조회 오류',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          isBuilding
                                              ? '인덱스가 생성 중입니다. 잠시 후 자동으로 재시도합니다.'
                                              : '이 쿼리를 실행하려면 Firestore에 복합 인덱스가 필요합니다.',
                                        ),
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
                                                SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                                const SizedBox(width: 8),
                                                Text('자동 재시도: $_indexRetryCount/$_maxIndexRetries'),
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

                          if (isWide) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildPlanList(
                                      plans,
                                      timetableEntries: dayTimetable,
                                      showTimetableOverlay: _showTimetableOverlay,
                                      includeGoal: false,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  SizedBox(
                                    width: 320,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _buildGoalProgress(),
                                        const SizedBox(height: 16),
                                        _buildPlanSummaryCard(plans),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return _buildPlanList(
                            plans,
                            timetableEntries: dayTimetable,
                            showTimetableOverlay: _showTimetableOverlay,
                            includeGoal: true,
                            padding: const EdgeInsets.all(16),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPlan(),
        icon: const Icon(Icons.add),
        label: const Text('일정 추가'),
      ),
    );
  }

  Widget _buildDateHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
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
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                  ),
                  Text(
                    '${DateHelper.getWeekdayName(_selectedDate)}요일',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeDate(1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime.now();
                  });
                  widget.selectedDateNotifier.value = _selectedDate;
                  _loadGoalsForDate();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                icon: const Icon(Icons.today, size: 16),
                label: const Text('오늘'),
              ),
              const Spacer(),
              Text(
                '시간표 겹쳐보기',
                style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: _showTimetableOverlay,
                activeColor: colorScheme.primary,
                onChanged: (value) {
                  setState(() => _showTimetableOverlay = value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanList(
    List<DailyPlan> plans, {
    required List<WeeklyTimetableEntry> timetableEntries,
    required bool showTimetableOverlay,
    required bool includeGoal,
    required EdgeInsetsGeometry padding,
  }) {
    return ListView(
      primary: true,
      padding: padding,
      children: [
        if (includeGoal) _buildGoalProgress(),
        if (includeGoal && plans.isNotEmpty) const SizedBox(height: 8),
        if (!showTimetableOverlay && timetableEntries.isNotEmpty) ...[
          _buildTimetableSection(timetableEntries),
          const SizedBox(height: 12),
        ],
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
                  const SizedBox(height: 10),
                  Text(
                    '예시: 영어 단어 30개 암기',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _addPlan,
                    icon: const Icon(Icons.add),
                    label: const Text('일정 추가'),
                  ),
                ],
              ),
            ),
          )
        else
          _buildTimeline(plans, timetableEntries, showTimetableOverlay: showTimetableOverlay),
      ],
    );
  }

  Widget _buildTimetableSection(List<WeeklyTimetableEntry> entries) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('시간표', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildTimetableBlock(entry),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSummaryCard(List<DailyPlan> plans) {
    final totalCount = plans.length;
    final completedCount = plans.where((plan) => plan.isCompleted).length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('진행 요약', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.task_alt, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('완료 $completedCount/$totalCount'),
                const Spacer(),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<WeeklyTimetableEntry> _filterTimetableForDate(List<WeeklyTimetableEntry> entries) {
    final weekday = _selectedDate.weekday;
    final filtered = entries.where((entry) => entry.weekday == weekday).toList();
    filtered.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return filtered;
  }

  Widget _buildTimetableBlock(WeeklyTimetableEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.secondary;
    final background = colorScheme.secondaryContainer.withAlpha(140);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withAlpha(120), width: 1.1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${entry.startTime} ~ ${entry.endTime}',
              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
            ),
            if (entry.location != null && entry.location!.isNotEmpty)
              Text(
                entry.location!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgress() {
    return Consumer<GoalProvider>(
      builder: (context, goalProvider, _) {
        final errorMessage = goalProvider.errorMessage;
        final indexUrl = goalProvider.indexUrl;
        if (errorMessage != null) {
          return Card(
            color: Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '목표 조회 오류',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(errorMessage),
                  if (indexUrl != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(indexUrl),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => launchUrlString(indexUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('인덱스 생성 페이지 열기'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

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

  Widget _buildTimeline(
    List<DailyPlan> plans,
    List<WeeklyTimetableEntry> timetableEntries, {
    required bool showTimetableOverlay,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final rangeStart = _timelineStartHour * 60;
    final rangeEnd = rangeStart + _timelineHourCount * 60;
    final timelineHeight = _timelineHourCount * _timelineHourHeight;
    final planLayouts = _layoutPlans(plans, rangeStart, rangeEnd);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: SizedBox(
        height: timelineHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimelineLabels(timelineHeight),
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridWidth = constraints.maxWidth;
                  return GestureDetector(
                    onTapDown: (details) {
                      final minutesFromStart = (details.localPosition.dy / _timelineHourHeight * 60).floor();
                      final hour = (_timelineStartHour + (minutesFromStart / 60).floor()) % 24;
                      _addPlanAtTime(hour);
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Column(
                            children: List.generate(_timelineHourCount, (index) {
                              final isEven = index % 2 == 0;
                              return Container(
                                height: _timelineHourHeight,
                                decoration: BoxDecoration(
                                  color: isEven
                                      ? colorScheme.surface
                                      : colorScheme.surfaceContainerHighest.withAlpha(80),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: colorScheme.outlineVariant.withAlpha(120),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        if (showTimetableOverlay)
                          ..._buildTimetableOverlays(
                            timetableEntries,
                            rangeStart: rangeStart,
                            rangeEnd: rangeEnd,
                          ),
                        ..._buildPlanOverlays(
                          planLayouts,
                          rangeStart: rangeStart,
                          rangeEnd: rangeEnd,
                          gridWidth: gridWidth,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineLabels(double timelineHeight) {
    return SizedBox(
      width: _timelineLabelWidth,
      height: timelineHeight,
      child: Column(
        children: List.generate(_timelineHourCount, (index) {
          final hour = (_timelineStartHour + index) % 24;
          return SizedBox(
            height: _timelineHourHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildTimetableOverlays(
    List<WeeklyTimetableEntry> entries, {
    required int rangeStart,
    required int rangeEnd,
  }) {
    final overlays = <Widget>[];
    for (final entry in entries) {
      final start = entry.startMinutes;
      final end = entry.endMinutes;
      if (end <= rangeStart || start >= rangeEnd) continue;
      final clampedStart = start < rangeStart ? rangeStart : start;
      final clampedEnd = end > rangeEnd ? rangeEnd : end;
      final top = (clampedStart - rangeStart) / 60 * _timelineHourHeight;
      final height = ((clampedEnd - clampedStart) / 60 * _timelineHourHeight).clamp(32.0, 240.0);

      overlays.add(
        Positioned(
          top: top,
          left: 0,
          right: 0,
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: IgnorePointer(child: _buildTimetableBlock(entry)),
          ),
        ),
      );
    }
    return overlays;
  }

  List<Widget> _buildPlanOverlays(
    List<_PlanLayout> layouts, {
    required int rangeStart,
    required int rangeEnd,
    required double gridWidth,
  }) {
    final overlays = <Widget>[];
    const gap = 8.0;

    for (final layout in layouts) {
      final start = layout.startMinutes;
      final end = layout.endMinutes;
      if (end <= rangeStart || start >= rangeEnd) continue;
      final clampedStart = start < rangeStart ? rangeStart : start;
      final clampedEnd = end > rangeEnd ? rangeEnd : end;
      final top = (clampedStart - rangeStart) / 60 * _timelineHourHeight;
      final height = ((clampedEnd - clampedStart) / 60 * _timelineHourHeight).clamp(56.0, 320.0);

      final laneCount = layout.laneCount <= 0 ? 1 : layout.laneCount;
      final safeWidth = gridWidth < 40 ? 40.0 : gridWidth;
      final baseWidth = (safeWidth - gap * (laneCount + 1)) / laneCount;
      final laneWidth = baseWidth > 0 ? baseWidth : (safeWidth / laneCount);
      final left = gap + (laneWidth + gap) * layout.lane;

      overlays.add(
        Positioned(
          top: top,
          left: left,
          width: laneWidth,
          height: height,
          child: _buildTimeBlock(layout.plan, height: height),
        ),
      );
    }

    return overlays;
  }

  List<_PlanLayout> _layoutPlans(List<DailyPlan> plans, int rangeStart, int rangeEnd) {
    final items = plans
        .map((plan) {
          var start = _timeStringToMinutes(plan.startTime);
          var end = _timeStringToMinutes(plan.endTime);
          if (end <= start) {
            end = start + 30;
          }
          return _PlanLayout(plan: plan, startMinutes: start, endMinutes: end);
        })
        .where((item) => item.endMinutes > rangeStart && item.startMinutes < rangeEnd)
        .toList()
      ..sort((a, b) {
        final cmp = a.startMinutes.compareTo(b.startMinutes);
        return cmp != 0 ? cmp : a.endMinutes.compareTo(b.endMinutes);
      });

    final clusters = <List<_PlanLayout>>[];
    List<_PlanLayout> current = [];
    int currentEnd = -1;

    for (final item in items) {
      if (current.isEmpty || item.startMinutes < currentEnd) {
        current.add(item);
        if (item.endMinutes > currentEnd) {
          currentEnd = item.endMinutes;
        }
      } else {
        clusters.add(current);
        current = [item];
        currentEnd = item.endMinutes;
      }
    }
    if (current.isNotEmpty) {
      clusters.add(current);
    }

    for (final cluster in clusters) {
      final laneEnd = <int>[];
      for (final item in cluster) {
        var laneIndex = -1;
        for (var i = 0; i < laneEnd.length; i++) {
          if (laneEnd[i] <= item.startMinutes) {
            laneIndex = i;
            break;
          }
        }
        if (laneIndex == -1) {
          laneIndex = laneEnd.length;
          laneEnd.add(item.endMinutes);
        } else {
          laneEnd[laneIndex] = item.endMinutes;
        }
        item.lane = laneIndex;
      }
      final laneCount = laneEnd.isEmpty ? 1 : laneEnd.length;
      for (final item in cluster) {
        item.laneCount = laneCount;
      }
    }

    return items;
  }

  int _timeStringToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
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
      onTap: () => _showDailyPlanDetails(plan),
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
                        Checkbox(
                          value: plan.isCompleted,
                          onChanged: (_) => _toggleComplete(plan),
                          activeColor: Colors.green,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
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
                            if (value == 'delete') {
                              _deletePlan(plan);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
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

  void _showDailyPlanDetails(DailyPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text(
                plan.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (plan.isCompleted)
              const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Text(DateHelper.toKoreanDateString(plan.date)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18),
                  const SizedBox(width: 8),
                  Text('${plan.startTime} ~ ${plan.endTime}'),
                ],
              ),
              if (plan.subjectId != null) ...[
                const SizedBox(height: 10),
                FutureBuilder<Subject?>(
                  future: _firestoreService.getSubjectById(plan.subjectId!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox.shrink();
                    }
                    final subject = snapshot.data!;
                    final color = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
                    return Row(
                      children: [
                        Icon(SubjectIconHelper.getIcon(subject.icon), size: 18, color: color),
                        const SizedBox(width: 8),
                        Text(
                          subject.name,
                          style: TextStyle(color: color, fontWeight: FontWeight.w600),
                        ),
                      ],
                    );
                  },
                ),
              ],
              if (plan.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(plan.notes)),
                  ],
                ),
              ],
              if (plan.subtasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '세부 목표 (${plan.subtasks.where((s) => s.isCompleted).length}/${plan.subtasks.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                ...plan.subtasks.map(
                  (subtask) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          subtask.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 16,
                          color: subtask.isCompleted ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            subtask.title.isEmpty ? '제목 없음' : subtask.title,
                            style: TextStyle(
                              decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _editPlan(plan);
            },
            icon: const Icon(Icons.edit),
            label: const Text('수정'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _deletePlan(plan);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete),
            label: const Text('삭제'),
          ),
        ],
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
    final next = !plan.isCompleted;
    await _firestoreService.updateDailyPlan(
      plan.id,
      {
        'isCompleted': next,
        'completedAt': next ? DateTime.now() : null,
      },
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
              final notificationProvider = context.read<NotificationProvider>();
              try {
                await _firestoreService.deleteDailyPlan(plan.id);
                await notificationProvider.onPlanDeleted(plan.id);
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

class _PlanLayout {
  final DailyPlan plan;
  final int startMinutes;
  final int endMinutes;
  int lane;
  int laneCount;

  _PlanLayout({
    required this.plan,
    required this.startMinutes,
    required this.endMinutes,
  })  : lane = 0,
        laneCount = 1;
}
