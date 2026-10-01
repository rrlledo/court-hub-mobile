import 'package:flutter/material.dart';
import '../core/api.dart';

class CoachWorkspaceScreen extends StatefulWidget {
  const CoachWorkspaceScreen({super.key, required this.api});
  final Api api;
  @override
  State<CoachWorkspaceScreen> createState() => _CoachWorkspaceScreenState();
}

class _CoachWorkspaceScreenState extends State<CoachWorkspaceScreen> {
  Map<String, dynamic>? workspace;
  List<Map<String, dynamic>> students = [];
  String? error;
  int? actionId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final body = await widget.api.request('/coach/workspace');
      List<Map<String, dynamic>> roster = [];
      try {
        final rosterBody = await widget.api.request('/coach/students');
        roster = (rosterBody['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      } catch (_) {
        // Keep the established workspace usable while an older API lacks rosters.
      }
      if (mounted) {
        setState(() {
          workspace = Map<String, dynamic>.from(body['data'] as Map);
          students = roster;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> changeSession(
      Map<String, dynamic> session, String action) async {
    setState(() => actionId = session['id'] as int);
    try {
      await widget.api
          .request('/coach/sessions/${session['id']}/$action', method: 'POST');
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => actionId = null);
    }
  }

  String date(dynamic raw) {
    final value = DateTime.tryParse('$raw')?.toLocal();
    return value == null
        ? 'Schedule unavailable'
        : '${MaterialLocalizations.of(context).formatMediumDate(value)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  @override
  Widget build(BuildContext context) {
    final profile = workspace?['profile'] == null
        ? null
        : Map<String, dynamic>.from(workspace!['profile'] as Map);
    final sessions = workspace?['sessions'] is List
        ? List<Map<String, dynamic>>.from((workspace!['sessions'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map)))
        : <Map<String, dynamic>>[];
    final availability = workspace?['availability'] is List
        ? workspace!['availability'] as List
        : [];
    return RefreshIndicator(
        onRefresh: load,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text('Coach workspace',
                  style: Theme.of(context).textTheme.headlineSmall),
              if (profile != null)
                Text('${profile['name']} · PHP ${profile['hourly_rate']}/hour'),
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
                          TextButton(
                              onPressed: load, child: const Text('Retry'))
                        ])),
              const SizedBox(height: 16),
              Text('Availability',
                  style: Theme.of(context).textTheme.titleLarge),
              if (!loading && availability.isEmpty)
                const Text(
                    'No availability has been set by facility management.'),
              ...availability.map((slot) => ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text('Day ${slot['day_of_week']}'),
                  subtitle: Text('${slot['starts_at']} – ${slot['ends_at']}'))),
              const SizedBox(height: 16),
              Text('Sessions', style: Theme.of(context).textTheme.titleLarge),
              if (!loading && sessions.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No coaching sessions are assigned to you.')),
              ...sessions.map(sessionCard),
              const SizedBox(height: 16),
              Text('My students',
                  style: Theme.of(context).textTheme.titleLarge),
              if (!loading && students.isEmpty)
                const Text('No students have been assigned to you yet.'),
              ...students.map((student) {
                final player = student['player'] == null
                    ? null
                    : Map<String, dynamic>.from(student['player'] as Map);
                return ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('${player?['name'] ?? 'Player'}'),
                    subtitle: Text(
                        '${student['revenue_share_percent']}% revenue share · ${student['notes'] ?? 'No notes'}'));
              }),
            ]));
  }

  Widget sessionCard(Map<String, dynamic> session) {
    final player = session['player'] == null
        ? null
        : Map<String, dynamic>.from(session['player'] as Map);
    final scheduled = session['status'] == 'scheduled';
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(player?['name'] ?? 'Player',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(date(session['starts_at'])),
              Text('PHP ${session['amount']} · ${session['status']}'),
              if (session['notes'] != null && '${session['notes']}'.isNotEmpty)
                Text('${session['notes']}'),
              if (scheduled)
                Wrap(spacing: 8, children: [
                  FilledButton(
                      onPressed: actionId == null
                          ? () => changeSession(session, 'complete')
                          : null,
                      child: Text(actionId == session['id']
                          ? 'Updating…'
                          : 'Complete')),
                  OutlinedButton(
                      onPressed: actionId == null
                          ? () => changeSession(session, 'cancel')
                          : null,
                      child: const Text('Cancel')),
                ]),
            ])));
  }
}
