import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/weekly_timetable_entry.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class WeeklyTimetableScreen extends StatefulWidget {
  const WeeklyTimetableScreen({super.key});

  @override
  State<WeeklyTimetableScreen> createState() => _WeeklyTimetableScreenState();
}

class _WeeklyTimetableScreenState extends State<WeeklyTimetableScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _showOverlapView = true;

  static const List<String> _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
  static const int _startHour = 6;
  static const int _endHour = 24;
  static const double _hourHeight = 68;
  static const double _minDayWidth = 56;
  static const double _minTimeLabelWidth = 56;

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다')));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colorScheme),
            Expanded(
              child: StreamBuilder<List<WeeklyTimetableEntry>>(
                stream: _firestoreService.getWeeklyTimetable(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '시간표를 불러오는 중 오류가 발생했습니다.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  final entries = snapshot.data ?? [];
                  final entriesByWeekday = <int, List<WeeklyTimetableEntry>>{};
                  for (int i = 1; i <= 7; i++) {
                    entriesByWeekday[i] = [];
                  }
                  for (final entry in entries) {
                    entriesByWeekday[entry.weekday]?.add(entry);
                  }
                  for (final list in entriesByWeekday.values) {
                    list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
                  }

                  final recentTitles = _getRecentTitles(entries);

                  return _buildTimetableGrid(userId, entriesByWeekday, recentTitles);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    final canPop = Navigator.canPop(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (canPop)
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  color: colorScheme.onPrimaryContainer,
                  tooltip: '뒤로',
                ),
              Text(
                '주간 시간표',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    '겹쳐보기',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Switch.adaptive(
                    value: _showOverlapView,
                    activeColor: colorScheme.primary,
                    onChanged: (value) {
                      setState(() => _showOverlapView = value);
                    },
                  ),
                ],
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '셀을 눌러 추가',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onPrimaryContainer.withAlpha(160),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEntrySheet(
    String userId, {
    WeeklyTimetableEntry? entry,
    int? weekday,
    TimeOfDay? presetStartTime,
    TimeOfDay? presetEndTime,
    List<String> recentTitles = const [],
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => WeeklyTimetableEntrySheet(
        userId: userId,
        entry: entry,
        presetWeekday: weekday,
        presetStartTime: presetStartTime,
        presetEndTime: presetEndTime,
        recentTitles: recentTitles,
        firestoreService: _firestoreService,
      ),
    );
  }

  Widget _buildTimetableGrid(
    String userId,
    Map<int, List<WeeklyTimetableEntry>> entriesByWeekday,
    List<String> recentTitles,
  ) {
    final totalHours = _endHour - _startHour;
    final gridHeight = totalHours * _hourHeight;
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant.withAlpha(130);
    final headerColor = colorScheme.surfaceContainerHighest;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          var timeLabelWidth = maxWidth < 520 ? _minTimeLabelWidth : 76.0;
          var dayWidth = (maxWidth - timeLabelWidth) / 7;
          if (dayWidth < _minDayWidth) {
            timeLabelWidth = _minTimeLabelWidth;
            dayWidth = (maxWidth - timeLabelWidth) / 7;
          }
          if (dayWidth < 1) dayWidth = 1;

          return SizedBox(
            width: maxWidth,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: timeLabelWidth,
                      height: 44,
                      decoration: BoxDecoration(
                        color: headerColor,
                        border: Border.all(color: borderColor),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10)),
                      ),
                      child: const Center(
                        child: Icon(Icons.schedule, size: 18),
                      ),
                    ),
                    for (int i = 0; i < 7; i++)
                      Container(
                        width: dayWidth,
                        height: 44,
                        decoration: BoxDecoration(
                          color: headerColor,
                          border: Border.all(color: borderColor),
                        ),
                        child: Center(
                          child: Text(
                            _weekdayLabels[i],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeColumn(totalHours, borderColor, timeLabelWidth),
                    for (int i = 0; i < 7; i++)
                      _buildDayColumn(
                        userId,
                        weekday: i + 1,
                        entries: entriesByWeekday[i + 1] ?? [],
                        gridHeight: gridHeight,
                        borderColor: borderColor,
                        recentTitles: recentTitles,
                        dayWidth: dayWidth,
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeColumn(int totalHours, Color borderColor, double timeLabelWidth) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: timeLabelWidth,
      height: totalHours * _hourHeight,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: Column(
        children: List.generate(totalHours, (index) {
          final hour = _startHour + index;
          return Container(
            height: _hourHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor),
                right: BorderSide(color: borderColor),
              ),
            ),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(
    String userId, {
    required int weekday,
    required List<WeeklyTimetableEntry> entries,
    required double gridHeight,
    required Color borderColor,
    required List<String> recentTitles,
    required double dayWidth,
  }) {
    final rangeStart = _startHour * 60;
    final rangeEnd = _endHour * 60;
    final layouts = _showOverlapView ? _layoutEntries(entries) : _layoutEntriesSingleLane(entries);

    return SizedBox(
      width: dayWidth,
      height: gridHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final slot = (details.localPosition.dy / _hourHeight).floor();
          final startHour = _startHour + slot;
          if (startHour < _startHour || startHour >= _endHour) return;
          final startTime = TimeOfDay(hour: startHour, minute: 0);
          final endTime = _defaultEndTime(startTime);
          _showEntrySheet(
            userId,
            weekday: weekday,
            presetStartTime: startTime,
            presetEndTime: endTime,
            recentTitles: recentTitles,
          );
        },
        child: Stack(
          children: [
            Column(
              children: List.generate(_endHour - _startHour, (index) {
                final isEven = index % 2 == 0;
                final colorScheme = Theme.of(context).colorScheme;
                return Container(
                  height: _hourHeight,
                  decoration: BoxDecoration(
                    color: isEven
                        ? colorScheme.surface
                        : colorScheme.surfaceContainerHighest.withAlpha(80),
                    border: Border(
                      top: BorderSide(color: borderColor),
                      right: BorderSide(color: borderColor),
                    ),
                  ),
                );
              }),
            ),
            for (final layout in layouts)
              _buildEntryCard(
                userId,
                entry: layout.entry,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                recentTitles: recentTitles,
                dayWidth: dayWidth,
                lane: layout.lane,
                laneCount: layout.laneCount,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(
    String userId, {
    required WeeklyTimetableEntry entry,
    required int rangeStart,
    required int rangeEnd,
    required List<String> recentTitles,
    required double dayWidth,
    required int lane,
    required int laneCount,
  }) {
    final start = entry.startMinutes;
    final end = entry.endMinutes;
    if (end <= rangeStart || start >= rangeEnd) {
      return const SizedBox.shrink();
    }
    final clampedStart = start < rangeStart ? rangeStart : start;
    final clampedEnd = end > rangeEnd ? rangeEnd : end;
    final top = (clampedStart - rangeStart) / 60 * _hourHeight;
    final height = ((clampedEnd - clampedStart) / 60 * _hourHeight).clamp(52.0, 240.0);
    final colorScheme = Theme.of(context).colorScheme;
    const gap = 6.0;
    final safeWidth = dayWidth < 40 ? 40.0 : dayWidth;
    final totalGap = gap * (laneCount + 1);
    final available = safeWidth - totalGap;
    final baseWidth = available > 0 ? available / laneCount : safeWidth / laneCount;
    final maxWidth = (safeWidth - gap * 2).clamp(24.0, safeWidth);
    final laneWidth = baseWidth.clamp(24.0, maxWidth);
    final left = gap + (laneWidth + gap) * lane;

    return Positioned(
      top: top,
      left: left,
      width: laneWidth,
      height: height,
      child: InkWell(
        onTap: () => _showEntrySheet(userId, entry: entry, recentTitles: recentTitles),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withAlpha(200),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.primary.withAlpha(160), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withAlpha(40),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${entry.startTime} ~ ${entry.endTime}',
                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
              ),
              if (entry.location != null && entry.location!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    entry.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay _defaultEndTime(TimeOfDay start) {
    if (start.hour >= 23) {
      return const TimeOfDay(hour: 23, minute: 59);
    }
    return TimeOfDay(hour: start.hour + 1, minute: start.minute);
  }

  List<String> _getRecentTitles(List<WeeklyTimetableEntry> entries) {
    if (entries.isEmpty) return const [];
    final sorted = List<WeeklyTimetableEntry>.from(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final seen = <String>{};
    final result = <String>[];
    for (final entry in sorted) {
      final title = entry.title.trim();
      if (title.isEmpty) continue;
      if (seen.add(title)) {
        result.add(title);
        if (result.length == 3) break;
      }
    }
    return result;
  }

  List<_TimetableLayout> _layoutEntries(List<WeeklyTimetableEntry> entries) {
    final items = entries
        .map((entry) {
          var start = entry.startMinutes;
          var end = entry.endMinutes;
          if (end <= start) {
            end = start + 30;
          }
          return _TimetableLayout(entry: entry, startMinutes: start, endMinutes: end);
        })
        .toList()
      ..sort((a, b) {
        final cmp = a.startMinutes.compareTo(b.startMinutes);
        return cmp != 0 ? cmp : a.endMinutes.compareTo(b.endMinutes);
      });

    final clusters = <List<_TimetableLayout>>[];
    List<_TimetableLayout> current = [];
    int currentEnd = -1;

    for (final item in items) {
      if (current.isEmpty || item.startMinutes < currentEnd) {
        current.add(item);
        if (item.endMinutes > currentEnd) currentEnd = item.endMinutes;
      } else {
        clusters.add(current);
        current = [item];
        currentEnd = item.endMinutes;
      }
    }
    if (current.isNotEmpty) clusters.add(current);

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

  List<_TimetableLayout> _layoutEntriesSingleLane(List<WeeklyTimetableEntry> entries) {
    final items = entries
        .map((entry) {
          var start = entry.startMinutes;
          var end = entry.endMinutes;
          if (end <= start) {
            end = start + 30;
          }
          return _TimetableLayout(
            entry: entry,
            startMinutes: start,
            endMinutes: end,
            lane: 0,
            laneCount: 1,
          );
        })
        .toList();
    items.sort((a, b) {
      final cmp = a.startMinutes.compareTo(b.startMinutes);
      return cmp != 0 ? cmp : a.endMinutes.compareTo(b.endMinutes);
    });
    return items;
  }
}

class _TimetableLayout {
  final WeeklyTimetableEntry entry;
  final int startMinutes;
  final int endMinutes;
  int lane;
  int laneCount;

  _TimetableLayout({
    required this.entry,
    required this.startMinutes,
    required this.endMinutes,
    this.lane = 0,
    this.laneCount = 1,
  });
}

class WeeklyTimetableEntrySheet extends StatefulWidget {
  final String userId;
  final WeeklyTimetableEntry? entry;
  final int? presetWeekday;
  final TimeOfDay? presetStartTime;
  final TimeOfDay? presetEndTime;
  final List<String> recentTitles;
  final FirestoreService firestoreService;

  const WeeklyTimetableEntrySheet({
    super.key,
    required this.userId,
    required this.firestoreService,
    this.entry,
    this.presetWeekday,
    this.presetStartTime,
    this.presetEndTime,
    this.recentTitles = const [],
  });

  @override
  State<WeeklyTimetableEntrySheet> createState() => _WeeklyTimetableEntrySheetState();
}

class _WeeklyTimetableEntrySheetState extends State<WeeklyTimetableEntrySheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  int _weekday = 1;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _saving = false;

  static const List<String> _weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      _weekday = entry.weekday;
      _startTime = _parseTime(entry.startTime);
      _endTime = _parseTime(entry.endTime);
      _titleController.text = entry.title;
      _locationController.text = entry.location ?? '';
    } else if (widget.presetWeekday != null) {
      _weekday = widget.presetWeekday!;
      _startTime = widget.presetStartTime;
      _endTime = widget.presetEndTime ?? _defaultEndTime(_startTime);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isEditing ? '시간표 수정' : '시간표 추가',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _weekday,
              decoration: const InputDecoration(
                labelText: '요일',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                7,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${_weekdayShort[index]}요일'),
                ),
              ),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _weekday = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
            ),
            if (!isEditing && widget.recentTitles.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '최근 추가한 제목',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: widget.recentTitles
                    .map(
                      (title) => ActionChip(
                        label: Text(title),
                        onPressed: () {
                          _titleController.text = title;
                          _titleController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _titleController.text.length),
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '장소 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(isStart: true),
                    child: Text(_startTime == null ? '시작 시간' : _formatTime(_startTime!)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(isStart: false),
                    child: Text(_endTime == null ? '종료 시간' : _formatTime(_endTime!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (isEditing)
                  TextButton.icon(
                    onPressed: _saving ? null : _deleteEntry,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('삭제', style: TextStyle(color: Colors.red)),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _saveEntry,
                  child: Text(isEditing ? '저장' : '추가'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 10, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _saveEntry() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('제목을 입력해주세요');
      return;
    }
    if (_startTime == null || _endTime == null) {
      _showSnackBar('시간을 선택해주세요');
      return;
    }
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    if (endMinutes <= startMinutes) {
      _showSnackBar('종료 시간이 시작 시간보다 늦어야 합니다');
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.entry == null) {
        final now = DateTime.now();
        final entry = WeeklyTimetableEntry(
          id: '',
          userId: widget.userId,
          weekday: _weekday,
          startTime: _formatTime(_startTime!),
          endTime: _formatTime(_endTime!),
          title: title,
          location: _locationController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await widget.firestoreService.createWeeklyTimetableEntry(entry);
      } else {
        await widget.firestoreService.updateWeeklyTimetableEntry(
          widget.userId,
          widget.entry!.id,
          {
            'weekday': _weekday,
            'startTime': _formatTime(_startTime!),
            'endTime': _formatTime(_endTime!),
            'title': title,
            'location': _locationController.text.trim(),
          },
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteEntry() async {
    final entry = widget.entry;
    if (entry == null) return;
    setState(() => _saving = true);
    try {
      await widget.firestoreService.deleteWeeklyTimetableEntry(widget.userId, entry.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('삭제 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  TimeOfDay? _defaultEndTime(TimeOfDay? start) {
    if (start == null) return null;
    if (start.hour >= 23) return const TimeOfDay(hour: 23, minute: 59);
    return TimeOfDay(hour: start.hour + 1, minute: start.minute);
  }
}
