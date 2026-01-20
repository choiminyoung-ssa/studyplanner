import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/daily_plan.dart';
import '../../models/priority_matrix.dart';
import '../../utils/date_utils.dart';
import '../daily/completion_tracker_dialog.dart';

/// 아이젠하워 매트릭스 (중요도/긴급도 4분면) 화면
class PriorityMatrixScreen extends StatefulWidget {
  const PriorityMatrixScreen({super.key});

  @override
  State<PriorityMatrixScreen> createState() => _PriorityMatrixScreenState();
}

class _PriorityMatrixScreenState extends State<PriorityMatrixScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('중요도/긴급도 매트릭스'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '도움말',
            onPressed: _showHelp,
          ),
        ],
      ),
      body: Column(
        children: [
          // 날짜 선택 헤더
          _buildDateSelector(colorScheme),

          // 매트릭스
          Expanded(
            child: StreamBuilder<List<DailyPlan>>(
              stream: _firestoreService.getDailyPlans(userId, _selectedDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('오류: ${snapshot.error}'));
                }

                final plans = snapshot.data ?? [];

                // 사분면별로 분류
                final q1Plans = plans.where((p) => p.quadrant == Quadrant.q1).toList();
                final q2Plans = plans.where((p) => p.quadrant == Quadrant.q2).toList();
                final q3Plans = plans.where((p) => p.quadrant == Quadrant.q3).toList();
                final q4Plans = plans.where((p) => p.quadrant == Quadrant.q4).toList();

                return _buildMatrix(
                  colorScheme,
                  q1Plans: q1Plans,
                  q2Plans: q2Plans,
                  q3Plans: q3Plans,
                  q4Plans: q4Plans,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(ColorScheme colorScheme) {
    final isToday = DateHelper.isToday(_selectedDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: isToday ? colorScheme.primary.withAlpha(20) : colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isToday ? colorScheme.primary : colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: isToday ? colorScheme.primary : colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateHelper.toKoreanDateString(_selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isToday ? colorScheme.primary : colorScheme.onSurface,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '오늘',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMatrix(
    ColorScheme colorScheme, {
    required List<DailyPlan> q1Plans,
    required List<DailyPlan> q2Plans,
    required List<DailyPlan> q3Plans,
    required List<DailyPlan> q4Plans,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Y축 라벨 (중요도)
          Row(
            children: [
              const SizedBox(width: 60),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Text(
                      '중요도 ↑',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 매트릭스 그리드
          Expanded(
            child: Row(
              children: [
                // Y축 라벨
                const RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    '긴급도 →',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 그리드
                Expanded(
                  child: Column(
                    children: [
                      // 상단 행 (Q2, Q1)
                      Expanded(
                        child: Row(
                          children: [
                            // Q2: 중요하지만 긴급하지 않음 (왼쪽 위)
                            Expanded(
                              child: _buildQuadrant(
                                colorScheme,
                                quadrant: Quadrant.q2,
                                plans: q2Plans,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Q1: 긴급하고 중요 (오른쪽 위)
                            Expanded(
                              child: _buildQuadrant(
                                colorScheme,
                                quadrant: Quadrant.q1,
                                plans: q1Plans,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 하단 행 (Q4, Q3)
                      Expanded(
                        child: Row(
                          children: [
                            // Q4: 여유있고 덜 중요 (왼쪽 아래)
                            Expanded(
                              child: _buildQuadrant(
                                colorScheme,
                                quadrant: Quadrant.q4,
                                plans: q4Plans,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Q3: 긴급하지만 덜 중요 (오른쪽 아래)
                            Expanded(
                              child: _buildQuadrant(
                                colorScheme,
                                quadrant: Quadrant.q3,
                                plans: q3Plans,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuadrant(
    ColorScheme colorScheme, {
    required Quadrant quadrant,
    required List<DailyPlan> plans,
  }) {
    final color = Color(quadrant.colorValue);

    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(100), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(40),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      quadrant.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        quadrant.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${plans.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  quadrant.shortName,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // 일정 목록
          Expanded(
            child: plans.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 32,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '일정 없음',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: plans.length,
                    itemBuilder: (context, index) {
                      return _buildPlanCard(plans[index], color);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(DailyPlan plan, Color accentColor) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => CompletionTrackerDialog(
            plan: plan,
            firestoreService: _firestoreService,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: plan.isCompleted
              ? Colors.grey[100]
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: plan.isCompleted ? Colors.grey[300]! : accentColor.withAlpha(100),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      decoration: plan.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (plan.isCompleted)
                  Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${plan.startTime} - ${plan.endTime}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
                if (plan.subject.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      plan.subject,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, size: 28),
            SizedBox(width: 12),
            Text('아이젠하워 매트릭스'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '중요도와 긴급도를 기준으로 일정을 4가지 사분면으로 분류합니다.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildHelpQuadrant(Quadrant.q1),
              const SizedBox(height: 12),
              _buildHelpQuadrant(Quadrant.q2),
              const SizedBox(height: 12),
              _buildHelpQuadrant(Quadrant.q3),
              const SizedBox(height: 12),
              _buildHelpQuadrant(Quadrant.q4),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpQuadrant(Quadrant quadrant) {
    final color = Color(quadrant.colorValue);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(quadrant.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quadrant.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            quadrant.shortName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            quadrant.description,
            style: const TextStyle(fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}
