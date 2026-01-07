import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../models/search_result.dart';
import '../../providers/auth_provider.dart';


class SearchScreen extends StatefulWidget {
  final bool initialOpenFilters;
  const SearchScreen({super.key, this.initialOpenFilters = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _qController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedSubjectId;
  String _completedFilter = 'all'; // all, completed, incomplete
  Set<int> _priorities = {};

  List<SearchResult> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _qController.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    setState(() {
      _isLoading = true;
    });

    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    final svc = FirestoreService();
    final results = await svc.searchPlans(
      userId: userId,
      query: _qController.text.trim(),
      start: _startDate,
      end: _endDate,
      subjectId: _selectedSubjectId,
      completed: _completedFilter == 'all' ? null : (_completedFilter == 'completed'),
      priorities: _priorities.isEmpty ? null : _priorities.toList(),
    );

    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  void _clearFilters() {
    setState(() {
      _qController.clear();
      _startDate = null;
      _endDate = null;
      _selectedSubjectId = null;
      _completedFilter = 'all';
      _priorities.clear();
      _results = [];
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('검색'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearFilters,
            tooltip: '필터 초기화',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _doSearch,
            tooltip: '검색 실행',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _qController,
            decoration: const InputDecoration(
              hintText: '제목 및 메모 검색',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (_) => _doSearch(),
          ),
          const SizedBox(height: 12),

          // Date range
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                  child: Text(_startDate != null ? '시작: ${_startDate!.toLocal().toString().split(' ').first}' : '시작일'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                  child: Text(_endDate != null ? '종료: ${_endDate!.toLocal().toString().split(' ').first}' : '종료일'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Subject dropdown
          FutureBuilder<List<Map<String, String>>>(
            future: FirestoreService().getSubjectIdNamePairs(context.read<AuthProvider>().userId!),
            builder: (context, snapshot) {
              final subjects = snapshot.data ?? [];
              return DropdownButtonFormField<String>(
                initialValue: _selectedSubjectId,
                decoration: const InputDecoration(labelText: '과목'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('전체')),
                  ...subjects.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['name']!))).toList(),
                ],
                onChanged: (v) => setState(() => _selectedSubjectId = v),
              );
            },
          ),

          const SizedBox(height: 8),

          // Completed filter
          Row(
            children: [
              const Text('완료 상태: '),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _completedFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('전체')),
                  DropdownMenuItem(value: 'completed', child: Text('완료됨')),
                  DropdownMenuItem(value: 'incomplete', child: Text('미완료')),
                ],
                onChanged: (v) => setState(() => _completedFilter = v ?? 'all'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Priorities
          Wrap(
            spacing: 8,
            children: [
              for (var p in [1, 2, 3]) ChoiceChip(
                label: Text('P$p'),
                selected: _priorities.contains(p),
                onSelected: (sel) {
                  setState(() {
                    if (sel) _priorities.add(p); else _priorities.remove(p);
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _doSearch,
            child: const Text('검색'),
          ),

          const SizedBox(height: 16),

          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Results
          if (!_isLoading)
            ..._results.map((r) {
              return ListTile(
                leading: _leadingForType(r.type),
                title: Text(r.title),
                subtitle: Text('${r.date.toLocal().toString().split(' ').first} • ${r.subject ?? ''}'),
                trailing: r.isCompleted ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () {
                  // Open the appropriate detail / edit screen
                },
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _leadingForType(PlanType type) {
    switch (type) {
      case PlanType.daily:
        return const Icon(Icons.schedule);
      case PlanType.weekly:
        return const Icon(Icons.view_week);
      case PlanType.monthly:
        return const Icon(Icons.calendar_month);
    }
  }
}
