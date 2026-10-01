import 'package:flutter/material.dart';

import '../core/api.dart';
import 'reports_dashboard.dart';

class OperationsWorkspaceScreen extends StatefulWidget {
  const OperationsWorkspaceScreen(
      {super.key, required this.api, required this.canManageRoles});

  final Api api;
  final bool canManageRoles;

  @override
  State<OperationsWorkspaceScreen> createState() =>
      _OperationsWorkspaceScreenState();
}

class _OperationsWorkspaceScreenState extends State<OperationsWorkspaceScreen> {
  List<Map<String, dynamic>> facilities = [];
  List<Map<String, dynamic>> organizations = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> bookings = [];
  String? error;
  bool loading = true;
  int? actionId;

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
      final today = DateUtils.dateOnly(DateTime.now()).toIso8601String();
      final result = await Future.wait([
        widget.api.request('/facilities'),
        widget.api.request('/organizations'),
        widget.api.request('/users'),
        widget.api.request('/bookings', query: {'date': today}),
      ]);
      if (mounted) {
        setState(() {
          facilities = ApiPage.parse(result[0]).items;
          organizations = ApiPage.parse(result[1]).items;
          users = ApiPage.parse(result[2]).items;
          bookings = ApiPage.parse(result[3]).items;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> run(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  List<Map<String, dynamic>> rows(dynamic value) {
    if (value is! List) return [];
    return value.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> editFacility(Map<String, dynamic> facility) async {
    final name = TextEditingController(text: '${facility['name']}');
    final address = TextEditingController(text: '${facility['address'] ?? ''}');
    final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Edit facility'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(
                    controller: address,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Address')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save')),
              ],
            ));
    if (approved == true && name.text.trim().isNotEmpty) {
      await run(() async => widget.api.request('/facilities/${facility['id']}',
          method: 'PUT',
          data: {'name': name.text.trim(), 'address': address.text.trim()}));
    }
    name.dispose();
    address.dispose();
  }

  Future<void> toggleRegistration(Map<String, dynamic> facility) =>
      run(() async {
        await widget.api.request('/facilities/${facility['id']}/registration',
            method: 'PATCH',
            data: {'registration_open': facility['registration_open'] != true});
      });

  Future<void> addFacility() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final organizationName = TextEditingController();
    int? organizationId =
        organizations.isEmpty ? null : organizations.first['id'] as int;
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Add facility'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        decoration:
                            const InputDecoration(labelText: 'Facility name')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: address,
                        maxLines: 2,
                        decoration:
                            const InputDecoration(labelText: 'Address')),
                    const SizedBox(height: 12),
                    if (organizations.isNotEmpty)
                      DropdownButtonFormField<int>(
                          initialValue: organizationId,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Organization'),
                          items: organizations
                              .map((organization) => DropdownMenuItem(
                                  value: organization['id'] as int,
                                  child: Text('${organization['name']}')))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => organizationId = value))
                    else
                      TextField(
                          controller: organizationName,
                          decoration: const InputDecoration(
                              labelText: 'Organization name')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Create facility')),
                  ],
                )));
    if (saved == true && name.text.trim().isNotEmpty) {
      await run(() async {
        var targetOrganizationId = organizationId;
        if (targetOrganizationId == null) {
          if (organizationName.text.trim().isEmpty) {
            throw StateError('Enter an organization name.');
          }
          final organization = await widget.api.request('/organizations',
              method: 'POST', data: {'name': organizationName.text.trim()});
          targetOrganizationId = organization['data']['id'] as int;
        }
        await widget.api.request('/facilities', method: 'POST', data: {
          'organization_id': targetOrganizationId,
          'name': name.text.trim(),
          'address': address.text.trim(),
        });
      });
    }
    name.dispose();
    address.dispose();
    organizationName.dispose();
  }

  Future<void> addBranch(Map<String, dynamic> facility) async {
    final name = TextEditingController();
    final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Add branch to ${facility['name']}'),
              content: TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Branch name')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Add branch')),
              ],
            ));
    if (approved == true && name.text.trim().isNotEmpty) {
      await run(() async => widget.api.request(
          '/facilities/${facility['id']}/branches',
          method: 'POST',
          data: {'name': name.text.trim()}));
    }
    name.dispose();
  }

  Future<void> editCourt(Map<String, dynamic> branch,
      [Map<String, dynamic>? court]) async {
    final name = TextEditingController(text: '${court?['name'] ?? ''}');
    final sport =
        TextEditingController(text: '${court?['sport'] ?? 'pickleball'}');
    final price = TextEditingController(text: '${court?['base_price'] ?? ''}');
    var status = '${court?['status'] ?? 'active'}';
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text(court == null ? 'Add court' : 'Edit court'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        decoration:
                            const InputDecoration(labelText: 'Court name')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: sport,
                        decoration: const InputDecoration(labelText: 'Sport')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Base hourly price (PHP)')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'maintenance', child: Text('Maintenance')),
                          DropdownMenuItem(
                              value: 'inactive', child: Text('Inactive')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => status = value ?? status)),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Save')),
                  ],
                )));
    if (saved == true &&
        name.text.trim().isNotEmpty &&
        double.tryParse(price.text.trim()) != null) {
      final data = {
        'name': name.text.trim(),
        'sport': sport.text.trim(),
        'status': status,
        'base_price': price.text.trim(),
      };
      await run(() async {
        if (court == null) {
          await widget.api.request('/branches/${branch['id']}/courts',
              method: 'POST', data: data);
        } else {
          await widget.api
              .request('/courts/${court['id']}', method: 'PUT', data: data);
        }
      });
    }
    name.dispose();
    sport.dispose();
    price.dispose();
  }

  Future<void> editHours(Map<String, dynamic> branch) async {
    List<Map<String, dynamic>> hours = [];
    try {
      final body =
          await widget.api.request('/branches/${branch['id']}/operating-hours');
      hours = rows(body['data']);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
      return;
    }
    if (!mounted) return;
    final byDay = {for (final hour in hours) hour['day_of_week'] as int: hour};
    final draft = List.generate(
        7,
        (day) => {
              'day_of_week': day,
              'opens_at': '${byDay[day]?['opens_at'] ?? '08:00'}',
              'closes_at': '${byDay[day]?['closes_at'] ?? '22:00'}',
              'is_closed': byDay[day]?['is_closed'] == true,
            });
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text('${branch['name']} hours'),
                  content: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: 7,
                          itemBuilder: (context, day) {
                            final hour = draft[day];
                            final closed = hour['is_closed'] == true;
                            return Column(children: [
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_dayName(day)),
                                  value: !closed,
                                  onChanged: (open) => setDialogState(
                                      () => hour['is_closed'] = !open)),
                              if (!closed)
                                Row(children: [
                                  Expanded(
                                      child: OutlinedButton(
                                          onPressed: () => chooseHour(
                                              hour, 'opens_at', setDialogState),
                                          child: Text(
                                              'Open ${hour['opens_at']}'))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: OutlinedButton(
                                          onPressed: () => chooseHour(hour,
                                              'closes_at', setDialogState),
                                          child: Text(
                                              'Close ${hour['closes_at']}'))),
                                ]),
                            ]);
                          })),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Save hours')),
                  ],
                )));
    if (saved == true) {
      await run(() async => widget.api.request(
          '/branches/${branch['id']}/operating-hours',
          method: 'PUT',
          data: {'hours': draft}));
    }
  }

  Future<void> chooseHour(Map<String, dynamic> hour, String field,
      void Function(void Function()) setDialogState) async {
    final initial = _time('${hour[field]}');
    final value = await showTimePicker(context: context, initialTime: initial);
    if (value != null) {
      setDialogState(() => hour[field] =
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> addStaff() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    var role = 'front-desk';
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Add staff member'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Temporary password (12+ characters)')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(
                              value: 'front-desk', child: Text('Front desk')),
                          DropdownMenuItem(
                              value: 'coach', child: Text('Coach')),
                          DropdownMenuItem(
                              value: 'event-organizer',
                              child: Text('Event organizer')),
                          DropdownMenuItem(
                              value: 'player', child: Text('Player')),
                          DropdownMenuItem(
                              value: 'facility-manager',
                              child: Text('Facility manager')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => role = value ?? role)),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Create')),
                  ],
                )));
    if (saved == true &&
        name.text.trim().isNotEmpty &&
        email.text.trim().isNotEmpty &&
        password.text.length >= 12) {
      await run(() async => widget.api.request('/users', method: 'POST', data: {
            'name': name.text.trim(),
            'email': email.text.trim(),
            'password': password.text,
            'password_confirmation': password.text,
            'roles': [role],
          }));
    }
    name.dispose();
    email.dispose();
    password.dispose();
  }

  Future<void> manageRoles(Map<String, dynamic> user) async {
    final selected =
        rows(user['roles']).map((role) => '${role['name']}').toSet();
    const choices = [
      'facility-manager',
      'front-desk',
      'coach',
      'event-organizer',
      'player'
    ];
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text('Roles for ${user['name']}'),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: choices
                          .map((role) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(role.replaceAll('-', ' ')),
                              value: selected.contains(role),
                              onChanged: (checked) => setDialogState(() {
                                    if (checked == true) {
                                      selected.add(role);
                                    } else {
                                      selected.remove(role);
                                    }
                                  })))
                          .toList()),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.pop(context, true),
                        child: const Text('Save roles')),
                  ],
                )));
    if (saved == true) {
      await run(() async => widget.api.request('/users/${user['id']}/roles',
          method: 'PUT', data: {'roles': selected.toList()}));
    }
  }

  Future<void> updateBooking(
      Map<String, dynamic> booking, String action) async {
    setState(() => actionId = booking['id'] as int);
    await run(() async => widget.api
        .request('/bookings/${booking['id']}/$action', method: 'POST'));
    if (mounted) setState(() => actionId = null);
  }

  TimeOfDay _time(String value) {
    final pieces = value.split(':');
    return TimeOfDay(
        hour: int.tryParse(pieces.first) ?? 8,
        minute: pieces.length > 1 ? int.tryParse(pieces[1]) ?? 0 : 0);
  }

  String _dayName(int day) => const [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday'
      ][day];

  String roles(Map<String, dynamic> user) {
    final values = rows(user['roles']).map((role) => '${role['name']}');
    return values.isEmpty ? 'No role' : values.join(', ');
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(
                  child: Text('Operations workspace',
                      style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(
                  tooltip: 'Reports',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReportsDashboardScreen(api: widget.api))),
                  icon: const Icon(Icons.insights_outlined)),
            ]),
            const Text(
                'Manage today’s bookings, facilities, courts, and staff.'),
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
            const SizedBox(height: 12),
            Text('Today’s bookings',
                style: Theme.of(context).textTheme.titleLarge),
            if (!loading && bookings.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No bookings are scheduled today.')),
            ...bookings.map(bookingCard),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: Text('Facilities and courts',
                      style: Theme.of(context).textTheme.titleLarge)),
              FilledButton.icon(
                  onPressed: loading ? null : addFacility,
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text('Add')),
            ]),
            if (!loading && facilities.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No facilities yet. Add your first facility.')),
            ...facilities.map(facilityCard),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: Text('Staff and accounts',
                      style: Theme.of(context).textTheme.titleLarge)),
              FilledButton.icon(
                  onPressed: loading ? null : addStaff,
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Add')),
            ]),
            if (!loading && users.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No staff accounts yet.')),
            ...users.map((user) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text('${user['name']}'),
                subtitle: Text('${user['email']} · ${roles(user)}'),
                trailing: widget.canManageRoles
                    ? TextButton(
                        onPressed: () => manageRoles(user),
                        child: const Text('Roles'))
                    : null)),
          ]));

  Widget bookingCard(Map<String, dynamic> booking) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${booking['reference']}',
                style: Theme.of(context).textTheme.titleMedium),
            Text('${booking['starts_at']} · ${booking['status']}'),
            Text('PHP ${booking['amount'] ?? '0'}'),
            if (booking['status'] == 'reserved')
              FilledButton(
                  onPressed: actionId == null
                      ? () => updateBooking(booking, 'confirm')
                      : null,
                  child: Text(actionId == booking['id']
                      ? 'Updating…'
                      : 'Confirm booking')),
            if (['reserved', 'confirmed'].contains(booking['status']))
              TextButton(
                  onPressed: actionId == null
                      ? () => updateBooking(booking, 'cancel')
                      : null,
                  child: const Text('Cancel booking')),
          ])));

  Widget facilityCard(Map<String, dynamic> facility) {
    final branches = rows(facility['branches']);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('${facility['name']}',
                        style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                    tooltip: 'Edit facility',
                    onPressed: () => editFacility(facility),
                    icon: const Icon(Icons.edit_outlined)),
              ]),
              if (facility['address'] != null) Text('${facility['address']}'),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Player self-registration'),
                  subtitle: const Text('Requires an active court.'),
                  value: facility['registration_open'] == true,
                  onChanged:
                      loading ? null : (_) => toggleRegistration(facility)),
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      onPressed: loading ? null : () => addBranch(facility),
                      icon: const Icon(Icons.add),
                      label: const Text('Add branch'))),
              ...branches.map(branchCard),
            ])));
  }

  Widget branchCard(Map<String, dynamic> branch) {
    final courts = rows(branch['courts']);
    return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${branch['name']}',
                          style: Theme.of(context).textTheme.titleSmall),
                      Wrap(spacing: 8, children: [
                        TextButton(
                            onPressed: () => editHours(branch),
                            child: const Text('Operating hours')),
                        TextButton(
                            onPressed: () => editCourt(branch),
                            child: const Text('Add court')),
                      ]),
                      if (courts.isEmpty) const Text('No courts yet.'),
                      ...courts.map((court) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${court['name']} · ${court['sport']}'),
                          subtitle: Text(
                              'PHP ${court['base_price']} / hour · ${court['status']}'),
                          trailing: IconButton(
                              tooltip: 'Edit court',
                              onPressed: () => editCourt(branch, court),
                              icon: const Icon(Icons.edit_outlined)))),
                    ]))));
  }
}
