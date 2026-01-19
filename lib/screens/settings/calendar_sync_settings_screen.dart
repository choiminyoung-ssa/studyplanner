import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/calendar_sync_provider.dart';
import '../../models/calendar_sync_settings.dart';

class CalendarSyncSettingsScreen extends StatefulWidget {
  const CalendarSyncSettingsScreen({super.key});

  @override
  State<CalendarSyncSettingsScreen> createState() =>
      _CalendarSyncSettingsScreenState();
}

class _CalendarSyncSettingsScreenState
    extends State<CalendarSyncSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Sync'),
      ),
      body: Consumer<CalendarSyncProvider>(
        builder: (context, syncProvider, _) {
          final settings = syncProvider.settings;

          if (settings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Connection Status Card
              _buildConnectionCard(context, syncProvider),
              const SizedBox(height: 24),

              // Master Toggle
              _buildMasterToggle(context, syncProvider, settings),
              const SizedBox(height: 24),

              // Sync Options
              if (settings.isEnabled) ...[
                _buildSyncOptionsCard(context, syncProvider, settings),
                const SizedBox(height: 24),

                // Advanced Settings
                _buildAdvancedSettings(context, syncProvider, settings),
                const SizedBox(height: 24),

                // Action Buttons
                _buildActionButtons(context, syncProvider),
              ],

              // Error Display
              if (syncProvider.errors.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildErrorsCard(context, syncProvider),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildConnectionCard(
      BuildContext context, CalendarSyncProvider syncProvider) {
    final isAuthenticated = syncProvider.isAuthenticated;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAuthenticated ? Icons.check_circle : Icons.cloud_off,
                  color: isAuthenticated ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Google Account',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isAuthenticated) ...[
              const Text('Connected to Google Calendar'),
              if (syncProvider.lastSyncAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Last synced: ${_formatLastSync(syncProvider.lastSyncAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: syncProvider.isSyncing
                    ? null
                    : () => _handleDisconnect(context, syncProvider),
                icon: const Icon(Icons.logout),
                label: const Text('Disconnect'),
              ),
            ] else ...[
              const Text('Not connected'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: syncProvider.isSyncing
                    ? null
                    : () => _handleConnect(context, syncProvider),
                icon: const Icon(Icons.login),
                label: const Text('Connect Google Account'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMasterToggle(BuildContext context,
      CalendarSyncProvider syncProvider, CalendarSyncSettings settings) {
    return Card(
      child: SwitchListTile(
        title: const Text('Enable Calendar Sync'),
        subtitle: const Text('Automatically sync with Google Calendar'),
        value: settings.isEnabled && syncProvider.isAuthenticated,
        onChanged: syncProvider.isAuthenticated
            ? (value) => _handleToggleSync(context, syncProvider, value)
            : null,
      ),
    );
  }

  Widget _buildSyncOptionsCard(BuildContext context,
      CalendarSyncProvider syncProvider, CalendarSyncSettings settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Daily Plans'),
              subtitle: const Text('Sync daily time blocks'),
              value: settings.syncDailyPlans,
              onChanged: (value) => _updateSettings(
                context,
                syncProvider,
                settings.copyWith(syncDailyPlans: value),
              ),
            ),
            CheckboxListTile(
              title: const Text('Monthly Plans'),
              subtitle: const Text('Sync monthly goals and schedules'),
              value: settings.syncMonthlyPlans,
              onChanged: (value) => _updateSettings(
                context,
                syncProvider,
                settings.copyWith(syncMonthlyPlans: value),
              ),
            ),
            CheckboxListTile(
              title: const Text('Weekly Plans'),
              subtitle: const Text('Sync weekly goals and tasks'),
              value: settings.syncWeeklyPlans,
              onChanged: (value) => _updateSettings(
                context,
                syncProvider,
                settings.copyWith(syncWeeklyPlans: value),
              ),
            ),
            CheckboxListTile(
              title: const Text('Weekly Timetable'),
              subtitle: const Text('Sync recurring class schedule'),
              value: settings.syncWeeklyTimetable,
              onChanged: (value) => _updateSettings(
                context,
                syncProvider,
                settings.copyWith(syncWeeklyTimetable: value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings(BuildContext context,
      CalendarSyncProvider syncProvider, CalendarSyncSettings settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Sync Frequency'),
              subtitle: Text(_getSyncFrequencyLabel(settings.syncFrequency)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showSyncFrequencyDialog(
                  context, syncProvider, settings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, CalendarSyncProvider syncProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: syncProvider.isSyncing
              ? null
              : () => _handleManualSync(context, syncProvider),
          icon: syncProvider.isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync),
          label: Text(syncProvider.isSyncing ? 'Syncing...' : 'Sync Now'),
        ),
      ],
    );
  }

  Widget _buildErrorsCard(
      BuildContext context, CalendarSyncProvider syncProvider) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Sync Errors',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.red.shade700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...syncProvider.errors.take(3).map((error) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${_formatTime(error.timestamp)}: ${error.message}',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                )),
            if (syncProvider.errors.length > 3)
              Text(
                'And ${syncProvider.errors.length - 3} more errors...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade700,
                    ),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => syncProvider.clearErrors(),
              child: const Text('Clear Errors'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConnect(
      BuildContext context, CalendarSyncProvider syncProvider) async {
    final success = await syncProvider.authenticate();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('구글 캘린더와 연동되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncProvider.errors.isNotEmpty
                ? syncProvider.errors.last.message
                : '구글 캘린더 연동에 실패했습니다.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleDisconnect(
      BuildContext context, CalendarSyncProvider syncProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Calendar?'),
        content: const Text(
          'This will stop syncing with Google Calendar. Your existing events will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await syncProvider.disconnect();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('구글 캘린더 연동이 해제되었습니다.'),
        ),
      );
    }
  }

  Future<void> _handleManualSync(
      BuildContext context, CalendarSyncProvider syncProvider) async {
    final success = await syncProvider.performManualSync();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('구글 캘린더와 동기화되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final errorMessage = syncProvider.errors.isNotEmpty
        ? syncProvider.errors.last.message
        : '동기화에 실패했습니다.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _handleToggleSync(BuildContext context,
      CalendarSyncProvider syncProvider, bool value) async {
    final settings = syncProvider.settings;
    if (settings == null) return;

    await _updateSettings(
      context,
      syncProvider,
      settings.copyWith(isEnabled: value),
    );
  }

  Future<void> _updateSettings(
    BuildContext context,
    CalendarSyncProvider syncProvider,
    CalendarSyncSettings newSettings,
  ) async {
    await syncProvider.updateSettings(newSettings);
  }

  Future<void> _showSyncFrequencyDialog(
    BuildContext context,
    CalendarSyncProvider syncProvider,
    CalendarSyncSettings settings,
  ) async {
    final frequencies = {
      '15min': '15 minutes',
      '30min': '30 minutes',
      '1hour': '1 hour',
      'manual': 'Manual only',
    };

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sync Frequency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: frequencies.entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: settings.syncFrequency,
              onChanged: (value) => Navigator.pop(dialogContext, value),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null && selected != settings.syncFrequency) {
      if (!mounted) return;

      await _updateSettings(
        context,
        syncProvider,
        settings.copyWith(syncFrequency: selected),
      );
    }
  }

  String _formatLastSync(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getSyncFrequencyLabel(String? frequency) {
    switch (frequency) {
      case '15min':
        return 'Every 15 minutes';
      case '30min':
        return 'Every 30 minutes';
      case '1hour':
        return 'Every 1 hour';
      case 'manual':
        return 'Manual only';
      default:
        return 'Every 30 minutes';
    }
  }
}
