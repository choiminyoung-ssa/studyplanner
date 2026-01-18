import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/daily_plan.dart';
import '../providers/auth_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/timer_provider.dart';
import '../services/firestore_service.dart';
import '../services/timer_service.dart';

enum TimerMode { stopwatch, pomodoro }

class TimerBottomSheet extends StatefulWidget {
  final DateTime date;

  const TimerBottomSheet({super.key, required this.date});

  @override
  State<TimerBottomSheet> createState() => _TimerBottomSheetState();
}

class _TimerBottomSheetState extends State<TimerBottomSheet> {
  TimerMode _mode = TimerMode.stopwatch;
  String? _selectedPlanId;

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerProvider>(
      builder: (context, timerProvider, _) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                '학습 타이머',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<TimerMode>(
                segments: const [
                  ButtonSegment(value: TimerMode.stopwatch, label: Text('스톱워치')),
                  ButtonSegment(value: TimerMode.pomodoro, label: Text('포모도로')),
                ],
                selected: {_mode},
                onSelectionChanged: (Set<TimerMode> newSelection) {
                  setState(() => _mode = newSelection.first);
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  timerProvider.formattedTime,
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              _buildPlanSelector(),
              const SizedBox(height: 16),
              if (_selectedPlanId != null) _buildTimeComparison(),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (timerProvider.state == TimerState.idle)
                    _buildControlButton('시작', Icons.play_arrow, () {
                      if (_mode == TimerMode.stopwatch) {
                        timerProvider.startStopwatch();
                      } else {
                        timerProvider.startPomodoro();
                      }
                    }),
                  if (timerProvider.state == TimerState.running)
                    _buildControlButton('일시정지', Icons.pause, timerProvider.pause),
                  if (timerProvider.state == TimerState.paused)
                    _buildControlButton('재개', Icons.play_arrow, timerProvider.resume),
                  if (timerProvider.state != TimerState.idle)
                    _buildControlButton('정지', Icons.stop, () async {
                      final userId = context.read<AuthProvider>().userId;
                      if (userId == null) return;
                      final goalProvider = context.read<GoalProvider>();
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await timerProvider.stop(userId, _selectedPlanId);
                      final goal = goalProvider.dailyGoal;
                      if (goal != null) {
                        await goalProvider.calculateAchievement(userId, goal);
                      }
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('학습 시간이 저장되었습니다')),
                      );
                    }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanSelector() {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<DailyPlan>>(
      stream: FirestoreService().getDailyPlans(userId, widget.date),
      builder: (context, snapshot) {
        final plans = snapshot.data ?? [];
        final availableIds = plans.map((plan) => plan.id).toSet();
        final selectedId = availableIds.contains(_selectedPlanId) ? _selectedPlanId : null;

        if (plans.isEmpty) {
          return const Text('오늘 일정이 없습니다. 타이머를 단독으로 사용할 수 있어요.');
        }

        return DropdownButtonFormField<String>(
          initialValue: selectedId,
          decoration: InputDecoration(
            labelText: '연결할 일정',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.link),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('연결 안 함'),
            ),
            ...plans.map((plan) {
              return DropdownMenuItem<String>(
                value: plan.id,
                child: Text('${plan.title} (${plan.startTime} ~ ${plan.endTime})'),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedPlanId = value;
            });
          },
        );
      },
    );
  }

  Widget _buildTimeComparison() {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<DailyPlan>>(
      stream: FirestoreService().getDailyPlans(userId, widget.date),
      builder: (context, snapshot) {
        final plans = snapshot.data ?? [];
        final plan = plans.firstWhere(
          (item) => item.id == _selectedPlanId,
          orElse: () => DailyPlan(
            id: '',
            userId: userId,
            date: widget.date,
            startTime: '00:00',
            endTime: '00:00',
            title: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (plan.id.isEmpty) return const SizedBox.shrink();

        final estimated = plan.estimatedMinutes;
        final actual = plan.actualMinutes;
        final ratio = estimated > 0 ? (actual / estimated).clamp(0.0, 2.0).toDouble() : 0.0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '예상 vs 실제',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('예상 $estimated분'),
                    Text('실제 $actual분'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: ratio > 1.0 ? 1.0 : ratio,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text(
                  '정확도 ${(plan.timeAccuracy).toStringAsFixed(0)}%',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
