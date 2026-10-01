import 'package:flutter/material.dart';

import '../core/api.dart';

class TournamentManagementScreen extends StatefulWidget {
  const TournamentManagementScreen(
      {super.key, required this.api, required this.tournament});

  final Api api;
  final Map<String, dynamic> tournament;

  @override
  State<TournamentManagementScreen> createState() =>
      _TournamentManagementScreenState();
}

class _TournamentManagementScreenState
    extends State<TournamentManagementScreen> {
  Map<String, dynamic>? detail;
  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> courts = [];
  int? playerId;
  int? courtId;
  int? playerOneId;
  int? playerTwoId;
  int? teamId;
  int? teamMemberId;
  DateTime startsAt = DateTime.now().add(const Duration(hours: 1));
  final round = TextEditingController(text: '1');
  final matchNumber = TextEditingController(text: '1');
  final teamName = TextEditingController();
  String? error;
  bool loading = true;
  int? busyId;

  int get tournamentId => widget.tournament['id'] as int;
  List<Map<String, dynamic>> get registrations =>
      List<Map<String, dynamic>>.from(
          detail?['registrations'] as List? ?? const []);
  List<Map<String, dynamic>> get matches =>
      List<Map<String, dynamic>>.from(detail?['matches'] as List? ?? const []);
  List<Map<String, dynamic>> get teams =>
      List<Map<String, dynamic>>.from(detail?['teams'] as List? ?? const []);
  List<Map<String, dynamic>> get activeRegistrations =>
      registrations.where((item) => item['status'] != 'cancelled').toList();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    round.dispose();
    matchNumber.dispose();
    teamName.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final body =
          await widget.api.request('/organizer/tournaments/$tournamentId');
      final tournament = Map<String, dynamic>.from(body['data'] as Map);
      final branchId = tournament['branch_id'] as int;
      final result = await Future.wait([
        widget.api.request('/organizer/players'),
        widget.api.request('/branches/$branchId/courts'),
      ]);
      if (!mounted) return;
      setState(() {
        detail = tournament;
        players = List<Map<String, dynamic>>.from((result[0]['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map)));
        courts = ApiPage.parse(result[1]).items;
      });
    } catch (caught) {
      if (mounted) setState(() => error = errorMessage(caught));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addRegistration() async {
    if (playerId == null) {
      setState(() => error = 'Select a player to register.');
      return;
    }
    setState(() => busyId = -1);
    try {
      await widget.api.request(
          '/organizer/tournaments/$tournamentId/registrations',
          method: 'POST',
          data: {'user_id': playerId});
      if (mounted) {
        setState(() => playerId = null);
        await load();
      }
    } catch (caught) {
      if (mounted) setState(() => error = errorMessage(caught));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> cancelRegistration(Map<String, dynamic> registration) async {
    setState(() => busyId = registration['id'] as int);
    try {
      await widget.api.request(
          '/organizer/tournaments/$tournamentId/registrations/${registration['id']}/cancel',
          method: 'POST');
      if (mounted) await load();
    } catch (caught) {
      if (mounted) setState(() => error = errorMessage(caught));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> createTeam() async {
    if (teamName.text.trim().isEmpty) {
      setState(() => error = 'Enter a team name.');
      return;
    }
    setState(() => busyId = -3);
    try {
      await widget.api.request('/organizer/tournaments/$tournamentId/teams',
          method: 'POST', data: {'name': teamName.text.trim()});
      teamName.clear();
      if (mounted) await load();
    } catch (caught) {
      if (mounted) setState(() => error = errorMessage(caught));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> addTeamMember() async {
    if (teamId == null || teamMemberId == null) {
      setState(() => error = 'Select a team and player.');
      return;
    }
    setState(() => busyId = -4);
    try {
      await widget.api.request(
          '/organizer/tournaments/$tournamentId/teams/$teamId/members',
          method: 'POST',
          data: {'user_id': teamMemberId});
      if (mounted) await load();
    } catch (caught) {
      if (mounted) setState(() => error = errorMessage(caught));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> checkIn(Map<String, dynamic> registration) async {
    setState(() => busyId = registration['id'] as int);
    try {
      await widget.api.request(
          '/organizer/tournaments/$tournamentId/registrations/${registration['id']}/check-in',
          method: 'POST');
      if (mounted) await load();
    } catch (caught) {
      if (mounted) setState(() => error = errorMessage(caught));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> chooseMatchStart() async {
    final day = await showDatePicker(
        context: context,
        initialDate: startsAt,
        firstDate: DateUtils.dateOnly(DateTime.now()),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(startsAt));
    if (time != null) {
      setState(() => startsAt =
          DateTime(day.year, day.month, day.day, time.hour, time.minute));
    }
  }

  Future<void> scheduleMatch() async {
    final roundNumber = int.tryParse(round.text.trim());
    final number = int.tryParse(matchNumber.text.trim());
    if (roundNumber == null ||
        number == null ||
        roundNumber < 1 ||
        number < 1) {
      setState(() => error = 'Enter a positive round and match number.');
      return;
    }
    setState(() => busyId = -2);
    try {
      await widget.api.request('/organizer/tournaments/$tournamentId/matches',
          method: 'POST',
          data: {
            'court_id': courtId,
            'player_one_registration_id': playerOneId,
            'player_two_registration_id': playerTwoId,
            'round_number': roundNumber,
            'match_number': number,
            'starts_at': startsAt.toUtc().toIso8601String(),
          });
      if (mounted) await load();
    } catch (caught) {
      if (mounted) setState(() => error = errorMessage(caught));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> updateMatch(
      Map<String, dynamic> match, Map<String, dynamic> data) async {
    setState(() => busyId = match['id'] as int);
    try {
      await widget.api.request('/organizer/matches/${match['id']}',
          method: 'PATCH', data: data);
      if (mounted) await load();
    } catch (caught) {
      if (mounted) setState(() => error = errorMessage(caught));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> recordResult(Map<String, dynamic> match) async {
    final score = TextEditingController(text: '${match['score'] ?? ''}');
    int? winner = match['winner_registration_id'] as int?;
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Record match result'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<int>(
                        key: ValueKey('match-winner-$winner'),
                        initialValue: winner,
                        decoration: const InputDecoration(labelText: 'Winner'),
                        items: participantOptions(match),
                        onChanged: (value) =>
                            setDialogState(() => winner = value)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: score,
                        decoration: const InputDecoration(labelText: 'Score')),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: winner == null
                            ? null
                            : () => Navigator.pop(context, {
                                  'winner_registration_id': winner,
                                  'score': score.text.trim(),
                                  'status': 'completed'
                                }),
                        child: const Text('Save result')),
                  ],
                )));
    score.dispose();
    if (result != null && mounted) await updateMatch(match, result);
  }

  List<DropdownMenuItem<int>> participantOptions(Map<String, dynamic> match) =>
      [
        for (final id in [
          match['player_one_registration_id'],
          match['player_two_registration_id']
        ])
          if (id is int)
            DropdownMenuItem(value: id, child: Text(registrationName(id))),
      ];

  String registrationName(dynamic id) {
    final registration = registrations
        .where((item) => item['id'] == id)
        .cast<Map<String, dynamic>>()
        .firstOrNull;
    return '${registration?['player']?['name'] ?? 'Registration #$id'}';
  }

  String date(dynamic raw) {
    final value = DateTime.tryParse('$raw')?.toLocal();
    if (value == null) return 'Time not set';
    return '${MaterialLocalizations.of(context).formatMediumDate(value)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('${widget.tournament['name']}')),
      body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text('Tournament management',
                    style: Theme.of(context).textTheme.headlineSmall),
                if (loading)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator()),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(error!)),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Player registrations',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                  key: ValueKey('organizer-player-$playerId'),
                                  initialValue: playerId,
                                  decoration: const InputDecoration(
                                      labelText: 'Player'),
                                  items: players
                                      .map((player) => DropdownMenuItem(
                                          value: player['id'] as int,
                                          child: Text(
                                              '${player['name']} · ${player['email']}')))
                                      .toList(),
                                  onChanged: busyId == -1
                                      ? null
                                      : (value) =>
                                          setState(() => playerId = value)),
                              const SizedBox(height: 12),
                              FilledButton(
                                  onPressed:
                                      busyId == -1 ? null : addRegistration,
                                  child: Text(busyId == -1
                                      ? 'Registering…'
                                      : 'Register player')),
                              const SizedBox(height: 12),
                              if (registrations.isEmpty)
                                const Text('No players are registered yet.'),
                              ...registrations.map((registration) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                      '${registration['player']?['name'] ?? 'Player'}'),
                                  subtitle: Text(registration[
                                              'checked_in_at'] ==
                                          null
                                      ? '${registration['status']} · Awaiting check-in'
                                      : '${registration['status']} · Checked in'),
                                  trailing: registration['status'] ==
                                          'cancelled'
                                      ? null
                                      : Wrap(spacing: 4, children: [
                                          if (registration['checked_in_at'] ==
                                              null)
                                            TextButton(
                                                onPressed: busyId ==
                                                        registration['id']
                                                    ? null
                                                    : () =>
                                                        checkIn(registration),
                                                child: const Text('Check in')),
                                          TextButton(
                                              onPressed: busyId ==
                                                      registration['id']
                                                  ? null
                                                  : () => cancelRegistration(
                                                      registration),
                                              child: const Text('Cancel')),
                                        ]))),
                            ]))),
                const SizedBox(height: 16),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Teams',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              TextField(
                                  controller: teamName,
                                  decoration: const InputDecoration(
                                      labelText: 'Team name')),
                              const SizedBox(height: 8),
                              FilledButton(
                                  onPressed: busyId == -3 ? null : createTeam,
                                  child: const Text('Create team')),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                  key: ValueKey('team-$teamId'),
                                  initialValue: teamId,
                                  decoration:
                                      const InputDecoration(labelText: 'Team'),
                                  items: teams
                                      .map((team) => DropdownMenuItem(
                                          value: team['id'] as int,
                                          child: Text('${team['name']}')))
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => teamId = value)),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                  key: ValueKey('team-player-$teamMemberId'),
                                  initialValue: teamMemberId,
                                  decoration: const InputDecoration(
                                      labelText: 'Player'),
                                  items: players
                                      .map((player) => DropdownMenuItem(
                                          value: player['id'] as int,
                                          child: Text('${player['name']}')))
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => teamMemberId = value)),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                  onPressed:
                                      busyId == -4 ? null : addTeamMember,
                                  child: const Text('Add player to team')),
                              ...teams.map((team) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${team['name']}'),
                                  subtitle: Text(
                                      (team['members'] as List? ?? [])
                                          .map((member) => member['name'])
                                          .join(', ')))),
                            ]))),
                const SizedBox(height: 16),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Schedule match',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                  key: ValueKey('match-court-$courtId'),
                                  initialValue: courtId,
                                  decoration:
                                      const InputDecoration(labelText: 'Court'),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null,
                                        child: Text('No court assigned')),
                                    ...courts.map((court) => DropdownMenuItem(
                                        value: court['id'] as int,
                                        child: Text('${court['name']}')))
                                  ],
                                  onChanged: busyId == -2
                                      ? null
                                      : (value) =>
                                          setState(() => courtId = value)),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                  key: ValueKey('match-one-$playerOneId'),
                                  initialValue: playerOneId,
                                  decoration: const InputDecoration(
                                      labelText: 'Player one'),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null, child: Text('TBD')),
                                    ...activeRegistrations.map((registration) =>
                                        DropdownMenuItem(
                                            value: registration['id'] as int,
                                            child: Text(
                                                '${registration['player']?['name']}')))
                                  ],
                                  onChanged: busyId == -2
                                      ? null
                                      : (value) =>
                                          setState(() => playerOneId = value)),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                  key: ValueKey('match-two-$playerTwoId'),
                                  initialValue: playerTwoId,
                                  decoration: const InputDecoration(
                                      labelText: 'Player two'),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null, child: Text('TBD')),
                                    ...activeRegistrations.map((registration) =>
                                        DropdownMenuItem(
                                            value: registration['id'] as int,
                                            child: Text(
                                                '${registration['player']?['name']}')))
                                  ],
                                  onChanged: busyId == -2
                                      ? null
                                      : (value) =>
                                          setState(() => playerTwoId = value)),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                    child: TextField(
                                        controller: round,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Round'))),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: TextField(
                                        controller: matchNumber,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Match number')))
                              ]),
                              TextButton(
                                  onPressed:
                                      busyId == -2 ? null : chooseMatchStart,
                                  child: Text(
                                      'Starts: ${date(startsAt.toIso8601String())}')),
                              FilledButton(
                                  onPressed:
                                      busyId == -2 ? null : scheduleMatch,
                                  child: Text(busyId == -2
                                      ? 'Scheduling…'
                                      : 'Schedule match')),
                            ]))),
                const SizedBox(height: 16),
                Text('Matches', style: Theme.of(context).textTheme.titleLarge),
                if (!loading && matches.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No matches scheduled.')),
                ...matches.map((match) => Card(
                    child: ListTile(
                        title: Text(
                            'Round ${match['round_number']} · Match ${match['match_number']}'),
                        subtitle: Text(
                            '${registrationName(match['player_one_registration_id'])} vs ${registrationName(match['player_two_registration_id'])}\n${date(match['starts_at'])} · ${match['score'] ?? match['status']}'),
                        isThreeLine: true,
                        trailing: match['status'] == 'completed'
                            ? Chip(label: const Text('Completed'))
                            : PopupMenuButton<String>(
                                enabled: busyId != match['id'],
                                onSelected: (action) {
                                  if (action == 'ongoing') {
                                    updateMatch(match, {'status': 'ongoing'});
                                  }
                                  if (action == 'result') {
                                    recordResult(match);
                                  }
                                  if (action == 'cancel') {
                                    updateMatch(match, {'status': 'cancelled'});
                                  }
                                },
                                itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'ongoing',
                                          child: Text('Mark ongoing')),
                                      PopupMenuItem(
                                          value: 'result',
                                          child: Text('Record result')),
                                      PopupMenuItem(
                                          value: 'cancel',
                                          child: Text('Cancel match'))
                                    ])))),
              ])));
}
