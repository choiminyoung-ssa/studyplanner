import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/study_goal.dart';
import '../../models/subject.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/date_utils.dart';

class GoalSettingsScreen extends StatefulWidget {
  const GoalSettingsScreen({super.key});

  @override
  State<GoalSettingsScreen> createState() => _GoalSettingsScreenState();
}

class _GoalSettingsScreenState extends State<GoalSettingsScreen> {
  GoalPeriod _selectedPeriod = GoalPeriod.daily;
  int _targetHours = 3;
  int _targetMinutes = 0;
  bool _useSubjectTargets = false;
  final Map<String, int> _subjectTargets = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGoals());
  }

  Future<void> _loadGoals() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    await context.read<GoalProvider>().loadGoals(userId, DateTime.now());
    final goal = context.read<GoalProvider>().dailyGoal;
    if (goal != null) {
      await context.read<GoalProvider>().calculateAchievement(userId, goal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('목표 설정')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SegmentedButton<GoalPeriod>(
            segments: const [
              ButtonSegment(value: GoalPeriod.daily, label: Text('일간')),
              ButtonSegment(value: GoalPeriod.weekly, label: Text('주간')),
              ButtonSegment(value: GoalPeriod.monthly, label: Text('월간')),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (set) async {
              final next = set.first;
              setState(() => _selectedPeriod = next);
              final userId = context.read<AuthProvider>().userId;
              if (userId == null) return;
              final goalProvider = context.read<GoalProvider>();
              final goal = next == GoalPeriod.daily
                  ? goalProvider.dailyGoal
                  : next == GoalPeriod.weekly
                      ? goalProvider.weeklyGoal
                      : goalProvider.monthlyGoal;
              if (goal != null) {
                await goalProvider.calculateAchievement(userId, goal);
              }
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getPeriodLabel(_selectedPeriod),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Text('목표 시간: '),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    suffixText: '시간',
                                  ),
                                  onChanged: (value) {
                                    _targetHours = int.tryParse(value) ?? 0;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    suffixText: '분',
                                  ),
                                  onChanged: (value) {
                                    _targetMinutes = int.tryParse(value) ?? 0;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            title: const Text('과목별 목표 설정'),
                            value: _useSubjectTargets,
                            onChanged: (value) {
                              setState(() => _useSubjectTargets = value ?? false);
                            },
                          ),
                          if (_useSubjectTargets) _buildSubjectTargets(),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _saveGoal,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: const Text('목표 저장하기'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCurrentProgress(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectTargets() {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<List<Subject>>(
      stream: FirestoreService().getSubjects(userId),
      builder: (context, snapshot) {
        final subjects = snapshot.data ?? [];
        if (subjects.isEmpty) {
          return const Text('등록된 과목이 없습니다');
        }

        return Column(
          children: subjects.map((subject) {
            final currentValue = _subjectTargets[subject.id] ?? 0;
            return ListTile(
              leading: Icon(SubjectIconHelper.getIcon(subject.icon)),
              title: Text(subject.name),
              trailing: SizedBox(
                width: 80,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixText: '분',
                  ),
                  onChanged: (value) {
                    final minutes = int.tryParse(value) ?? 0;
                    _subjectTargets[subject.id] = minutes;
                  },
                  controller: TextEditingController(
                    text: currentValue > 0 ? currentValue.toString() : '',
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCurrentProgress() {
    return Consumer<GoalProvider>(
      builder: (context, goalProvider, _) {
        final goal = _selectedPeriod == GoalPeriod.daily
            ? goalProvider.dailyGoal
            : _selectedPeriod == GoalPeriod.weekly
                ? goalProvider.weeklyGoal
                : goalProvider.monthlyGoal;
        final achievement = goalProvider.currentAchievement;

        if (goal == null || achievement == null) {
          return const SizedBox.shrink();
        }

        final double rate = achievement.achievementRate.clamp(0, 200).toDouble();
        final double progress = (rate / 100.0).clamp(0.0, 1.0);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 진행도',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${achievement.actualMinutes}분 / ${goal.targetMinutes}분'),
                    Text('${rate.toStringAsFixed(0)}%'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
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

  String _getPeriodLabel(GoalPeriod period) {
    switch (period) {
      case GoalPeriod.daily:
        return '일간 목표';
      case GoalPeriod.weekly:
        return '주간 목표';
      case GoalPeriod.monthly:
        return '월간 목표';
    }
  }

  Future<void> _saveGoal() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    final totalMinutes = _targetHours * 60 + _targetMinutes;
    final now = DateTime.now();
    final goal = StudyGoal(
      id: '',
      userId: userId,
      period: _selectedPeriod,
      targetMinutes: totalMinutes,
      specificDate: _selectedPeriod == GoalPeriod.daily ? now : null,
      weekId: _selectedPeriod == GoalPeriod.weekly ? DateHelper.getWeekId(now) : null,
      month: _selectedPeriod == GoalPeriod.monthly ? DateHelper.toMonthString(now) : null,
      subjectTargets: _useSubjectTargets ? _subjectTargets : null,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await context.read<GoalProvider>().setGoal(userId, goal);
    await context.read<GoalProvider>().calculateAchievement(userId, goal);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('목표가 저장되었습니다')),
      );
    }
  }
}
