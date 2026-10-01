import 'package:flutter/material.dart';
import '../core/api.dart';
import 'tournament_management.dart';

class OrganizerWorkspaceScreen extends StatefulWidget {
  const OrganizerWorkspaceScreen({super.key, required this.api});
  final Api api;
  @override
  State<OrganizerWorkspaceScreen> createState() =>
      _OrganizerWorkspaceScreenState();
}

class _OrganizerWorkspaceScreenState extends State<OrganizerWorkspaceScreen> {
  List<Map<String, dynamic>> tournaments = [];
  List<Map<String, dynamic>> facilities = [];
  List<Map<String, dynamic>> branches = [];
  int? facilityId;
  int? branchId;
  String? error;
  bool loading = true;
  int? updatingId;
  final name = TextEditingController();
  DateTime startsAt = DateTime.now().add(const Duration(days: 1));
  String format = 'singles';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Future.wait([
        widget.api.request('/organizer/tournaments'),
        widget.api.request('/booking-facilities')
      ]);
      if (mounted) {
        setState(() {
          tournaments = ApiPage.parse(result[0]).items;
          facilities = ApiPage.parse(result[1]).items;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadBranches(int? facility) async {
    setState(() {
      facilityId = facility;
      branchId = null;
      branches = [];
    });
    if (facility == null) return;
    try {
      final body = await widget.api.request('/facilities/$facility/branches');
      if (mounted) setState(() => branches = ApiPage.parse(body).items);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    }
  }

  Future<void> chooseStart() async {
    final day = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDate: startsAt);
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(startsAt));
    if (time != null) {
      setState(() => startsAt =
          DateTime(day.year, day.month, day.day, time.hour, time.minute));
    }
  }

  Future<void> create() async {
    if (branchId == null || name.text.trim().isEmpty) {
      setState(() => error = 'Choose a branch and enter a tournament name.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.request('/organizer/tournaments', method: 'POST', data: {
        'branch_id': branchId,
        'name': name.text.trim(),
        'format': format,
        'starts_at': startsAt.toUtc().toIso8601String()
      });
      name.clear();
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> updateStatus(
      Map<String, dynamic> tournament, String? status) async {
    if (status == null) return;
    setState(() => updatingId = tournament['id'] as int);
    try {
      await widget.api.request('/organizer/tournaments/${tournament['id']}',
          method: 'PATCH', data: {'status': status});
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => updatingId = null);
    }
  }

  Future<void> manage(Map<String, dynamic> tournament) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TournamentManagementScreen(
            api: widget.api, tournament: tournament)));
    if (mounted) await load();
  }

  String date(dynamic raw) {
    final value = DateTime.tryParse('$raw')?.toLocal();
    return value == null
        ? 'Schedule unavailable'
        : '${MaterialLocalizations.of(context).formatMediumDate(value)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Event organizer workspace',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text('Create tournament',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
                controller: name,
                enabled: !loading,
                decoration:
                    const InputDecoration(labelText: 'Tournament name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
                key: ValueKey(facilityId),
                initialValue: facilityId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Facility'),
                items: facilities
                    .map((facility) => DropdownMenuItem(
                        value: facility['id'] as int,
                        child: Text('${facility['name']}')))
                    .toList(),
                onChanged: loading ? null : loadBranches),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
                key: ValueKey('branch-$facilityId-$branchId'),
                initialValue: branchId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: branches
                    .map((branch) => DropdownMenuItem(
                        value: branch['id'] as int,
                        child: Text('${branch['name']}')))
                    .toList(),
                onChanged: loading
                    ? null
                    : (value) => setState(() => branchId = value)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                initialValue: format,
                decoration: const InputDecoration(labelText: 'Format'),
                items: const [
                  DropdownMenuItem(value: 'singles', child: Text('Singles')),
                  DropdownMenuItem(value: 'doubles', child: Text('Doubles')),
                  DropdownMenuItem(value: 'team', child: Text('Team'))
                ],
                onChanged: loading
                    ? null
                    : (value) => setState(() => format = value!)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: loading ? null : chooseStart,
                child: Text('Starts: ${date(startsAt.toIso8601String())}')),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: loading ? null : create,
                child: const Text('Create tournament')),
            if (loading)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator()),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(error!),
                        TextButton(onPressed: load, child: const Text('Retry'))
                      ])),
            const SizedBox(height: 16),
            Text('Tournaments', style: Theme.of(context).textTheme.titleLarge),
            if (!loading && tournaments.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No tournaments yet.')),
            ...tournaments.map(tournamentCard),
          ]));

  Widget tournamentCard(Map<String, dynamic> tournament) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${tournament['name']}',
                style: Theme.of(context).textTheme.titleMedium),
            Text('${tournament['format']} · ${date(tournament['starts_at'])}'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
                key: ValueKey(
                    'status-${tournament['id']}-${tournament['status']}'),
                initialValue: '${tournament['status']}',
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                  DropdownMenuItem(
                      value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled'))
                ],
                onChanged: updatingId == null
                    ? (value) => updateStatus(tournament, value)
                    : null),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: updatingId == null ? () => manage(tournament) : null,
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Manage registrations & matches')),
          ])));
}
