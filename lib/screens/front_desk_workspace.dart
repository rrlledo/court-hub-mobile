import 'package:flutter/material.dart';

import '../core/api.dart';
import 'staff_checkin.dart';

class FrontDeskWorkspaceScreen extends StatefulWidget {
  const FrontDeskWorkspaceScreen({super.key, required this.api});

  final Api api;

  @override
  State<FrontDeskWorkspaceScreen> createState() =>
      _FrontDeskWorkspaceScreenState();
}

class _FrontDeskWorkspaceScreenState extends State<FrontDeskWorkspaceScreen> {
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> facilities = [];
  List<Map<String, dynamic>> branches = [];
  List<Map<String, dynamic>> courts = [];
  int? facilityId;
  int? branchId;
  int? courtId;
  DateTime startsAt = DateTime.now().add(const Duration(hours: 1));
  int duration = 60;
  String? error;
  bool loading = true;
  bool creating = false;
  int? actionId;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<List<Map<String, dynamic>>> all(String path) async {
    final result = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final next =
          ApiPage.parse(await widget.api.request(path, query: {'page': page}));
      result.addAll(next.items);
      if (!next.hasMore) return result;
      page++;
    }
  }

  String get today => DateUtils.dateOnly(DateTime.now()).toIso8601String();

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Future.wait([
        widget.api.request('/bookings', query: {'date': today}),
        all('/booking-facilities'),
      ]);
      if (mounted) {
        setState(() {
          bookings = ApiPage.parse(result[0]).items;
          facilities = List<Map<String, dynamic>>.from(result[1] as List);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> selectFacility(int? id) async {
    setState(() {
      facilityId = id;
      branchId = courtId = null;
      branches = [];
      courts = [];
    });
    if (id == null) return;
    try {
      final result = await all('/facilities/$id/branches');
      if (mounted) setState(() => branches = result);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    }
  }

  Future<void> selectBranch(int? id) async {
    setState(() {
      branchId = id;
      courtId = null;
      courts = [];
    });
    if (id == null) return;
    try {
      final result = await all('/branches/$id/courts');
      if (mounted) {
        setState(() => courts =
            result.where((court) => court['status'] == 'active').toList());
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    }
  }

  Future<void> chooseStart() async {
    final now = DateTime.now();
    final initial =
        startsAt.isAfter(now) ? startsAt : now.add(const Duration(hours: 1));
    final day = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 1),
        initialDate: initial);
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time != null && mounted) {
      setState(() => startsAt =
          DateTime(day.year, day.month, day.day, time.hour, time.minute));
    }
  }

  Future<void> createWalkIn() async {
    if (courtId == null) {
      setState(() => error = 'Select a facility, branch, and active court.');
      return;
    }
    if (!startsAt.isAfter(DateTime.now())) {
      setState(() => error = 'Walk-in start time must be in the future.');
      return;
    }
    setState(() {
      creating = true;
      error = null;
    });
    try {
      await widget.api.request('/bookings/walk-in', method: 'POST', data: {
        'court_id': courtId,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at':
            startsAt.add(Duration(minutes: duration)).toUtc().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Walk-in reservation created.')));
        await load();
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> bookingAction(
      Map<String, dynamic> booking, String action) async {
    if (action == 'cancel') {
      final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Cancel booking?'),
                content: Text(
                    'Cancel ${booking['reference']} and release the court?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep booking')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Cancel booking')),
                ],
              ));
      if (approved != true) return;
    }
    setState(() => actionId = booking['id'] as int);
    try {
      await widget.api
          .request('/bookings/${booking['id']}/$action', method: 'POST');
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => actionId = null);
    }
  }

  String dateLabel(DateTime value) =>
      '${MaterialLocalizations.of(context).formatMediumDate(value)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}';

  Widget picker(String label, int? value, List<Map<String, dynamic>> values,
          ValueChanged<int?> onChanged) =>
      DropdownButtonFormField<int>(
          key: ValueKey('$label-$value-${values.length}'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: values
              .map((value) => DropdownMenuItem(
                  value: value['id'] as int, child: Text('${value['name']}')))
              .toList(),
          onChanged: creating || values.isEmpty ? null : onChanged);

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Front Desk workspace',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'Create walk-in reservations and manage today’s arrivals.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StaffCheckInScreen(api: widget.api))),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Open QR check-in')),
            if (loading)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator()),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(error!)),
            const SizedBox(height: 12),
            Text('New walk-in reservation',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            picker('Facility', facilityId, facilities, selectFacility),
            const SizedBox(height: 12),
            picker('Branch', branchId, branches, selectBranch),
            const SizedBox(height: 12),
            picker('Court', courtId, courts,
                (value) => setState(() => courtId = value)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: creating ? null : chooseStart,
                child: Text('Starts: ${dateLabel(startsAt)}')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
                initialValue: duration,
                decoration: const InputDecoration(labelText: 'Duration'),
                items: const [
                  DropdownMenuItem(value: 60, child: Text('1 hour')),
                  DropdownMenuItem(value: 90, child: Text('1 hour 30 minutes')),
                  DropdownMenuItem(value: 120, child: Text('2 hours')),
                ],
                onChanged: creating
                    ? null
                    : (value) => setState(() => duration = value ?? duration)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: creating ? null : createWalkIn,
                child: Text(creating ? 'Creating…' : 'Create walk-in')),
            const SizedBox(height: 24),
            Text('Today’s bookings',
                style: Theme.of(context).textTheme.titleLarge),
            if (!loading && bookings.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No bookings are scheduled today.')),
            ...bookings.map(bookingCard),
          ]));

  Widget bookingCard(Map<String, dynamic> booking) {
    final starts = DateTime.tryParse('${booking['starts_at']}')?.toLocal();
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${booking['reference']}',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(starts == null ? 'Time unavailable' : dateLabel(starts)),
              Text('PHP ${booking['amount']} · ${booking['status']}'),
              if (booking['status'] == 'reserved')
                FilledButton(
                    onPressed: actionId == null
                        ? () => bookingAction(booking, 'confirm')
                        : null,
                    child: Text(actionId == booking['id']
                        ? 'Updating…'
                        : 'Confirm booking')),
              if (['reserved', 'confirmed'].contains(booking['status']))
                TextButton(
                    onPressed: actionId == null
                        ? () => bookingAction(booking, 'cancel')
                        : null,
                    child: const Text('Cancel booking')),
            ])));
  }
}
