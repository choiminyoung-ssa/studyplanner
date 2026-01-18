import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../models/notification_log.dart';
import '../../models/notification_settings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/firestore_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  Future<void> _loadSettings() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    final notificationProvider = context.read<NotificationProvider>();
    await notificationProvider.loadSettings(userId);
    if (kIsWeb) return;
    final granted = await notificationProvider.checkAndRequestPermission(userId);
    if (!mounted) return;
    if (!granted) {
      await _showPermissionDialog();
    }
  }

  Future<void> _showPermissionDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 권한이 필요합니다'),
        content: const Text(
          '일정 시작 전 알림을 받으려면 알림 권한이 필요합니다.\n'
          '설정에서 권한을 허용해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickTime(BuildContext context, String current) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return null;
    final hour = picked.hour.toString().padLeft(2, '0');
    final minute = picked.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().userId;

    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;

        return Scaffold(
          appBar: AppBar(
            title: const Text('알림 설정'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildToggleCard(
                title: '아침 일일 요약 알림',
                subtitle: '하루 일정 요약을 받아보세요',
                value: settings.dailySummaryEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(dailySummaryEnabled: value),
                ),
                trailing: TextButton(
                  onPressed: settings.dailySummaryEnabled
                      ? () async {
                          final time = await _pickTime(context, settings.dailySummaryTime);
                          if (time != null) {
                            await _updateSettings(settings.copyWith(dailySummaryTime: time));
                          }
                        }
                      : null,
                  child: Text(settings.dailySummaryTime),
                ),
              ),
              const SizedBox(height: 12),
              _buildToggleCard(
                title: '일정 시작 전 알림',
                subtitle: '일정 시작 전 리마인더를 받아요',
                value: settings.planReminderEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(planReminderEnabled: value),
                ),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${settings.reminderMinutesBefore}분 전'),
                    Slider(
                      value: settings.reminderMinutesBefore.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      label: '${settings.reminderMinutesBefore}분',
                      onChanged: settings.planReminderEnabled
                          ? (value) async {
                              await _updateSettings(
                                settings.copyWith(reminderMinutesBefore: value.round()),
                              );
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildToggleCard(
                title: '저녁 미완료 리마인더',
                subtitle: '하루 마무리를 도와줘요',
                value: settings.eveningReviewEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(eveningReviewEnabled: value),
                ),
                trailing: TextButton(
                  onPressed: settings.eveningReviewEnabled
                      ? () async {
                          final time = await _pickTime(context, settings.eveningReviewTime);
                          if (time != null) {
                            await _updateSettings(settings.copyWith(eveningReviewTime: time));
                          }
                        }
                      : null,
                  child: Text(settings.eveningReviewTime),
                ),
              ),
              const SizedBox(height: 12),
              _buildToggleCard(
                title: '연속 학습일 축하',
                subtitle: '연속 학습일에 축하 알림',
                value: settings.streakCelebrationEnabled,
                onChanged: (value) => _updateSettings(
                  settings.copyWith(streakCelebrationEnabled: value),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: provider.permissionGranted
                    ? () {
                        if (userId == null) return;
                        provider.showTestNotification(userId);
                      }
                    : null,
                icon: const Icon(Icons.notifications_active),
                label: const Text('테스트 알림 보내기'),
              ),
              const SizedBox(height: 16),
              if (userId != null) _buildNotificationLogSection(userId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? trailing,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
            if (trailing != null) ...[
              const SizedBox(height: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateSettings(NotificationSettings settings) async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    await context.read<NotificationProvider>().updateSettings(userId, settings);
  }

  Widget _buildNotificationLogSection(String userId) {
    return StreamBuilder<List<NotificationLog>>(
      stream: FirestoreService().getNotificationLogs(userId),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('최근 알림 로그', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (logs.isEmpty)
                  Text('표시할 로그가 없습니다.', style: TextStyle(color: Colors.grey[600])),
                ...logs.map(
                  (log) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications),
                    title: Text(log.title),
                    subtitle: Text('${log.body}\\n${log.createdAt.toLocal()}'),
                    isThreeLine: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
