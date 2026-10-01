import 'package:flutter/material.dart';
import '../core/api.dart';

class CreateBookingScreen extends StatefulWidget {
  const CreateBookingScreen({super.key, required this.api, this.booking});
  final Api api;
  final Map<String, dynamic>? booking;
  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  List<Map<String, dynamic>> facilities = [], branches = [], courts = [];
  int? facility, branch, court;
  DateTime? start, end;
  final notes = TextEditingController();
  bool busy = false, checked = false;
  String? error;
  Map<String, dynamic>? availability, reservation;
  @override
  void initState() {
    super.initState();
    if (widget.booking == null) {
      loadFacilities();
    } else {
      court = widget.booking!['court_id'] as int;
      start = DateTime.parse(widget.booking!['starts_at'] as String).toLocal();
      end = DateTime.parse(widget.booking!['ends_at'] as String).toLocal();
    }
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> all(String path) async {
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final result =
          ApiPage.parse(await widget.api.request(path, query: {'page': page}));
      rows.addAll(result.items);
      if (!result.hasMore) return rows;
      page++;
    }
  }

  Future<void> perform(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = errorMessage(e);
          checked = false;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadFacilities() => perform(() async {
        final rows = await all('/booking-facilities');
        if (mounted) setState(() => facilities = rows);
      });
  Future<void> selectFacility(int? value) => perform(() async {
        setState(() {
          facility = value;
          branch = court = null;
          branches = [];
          courts = [];
          checked = false;
          availability = null;
        });
        final rows = await all('/facilities/$value/branches');
        if (mounted) setState(() => branches = rows);
      });
  Future<void> selectBranch(int? value) => perform(() async {
        setState(() {
          branch = value;
          court = null;
          courts = [];
          checked = false;
          availability = null;
        });
        final rows = await all('/branches/$value/courts');
        if (mounted) {
          setState(() =>
              courts = rows.where((r) => r['status'] == 'active').toList());
        }
      });
  Future<void> pickTime(bool isStart) async {
    final now = DateTime.now();
    final initial =
        (isStart ? start : end) ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
        context: context,
        initialDate: initial.isBefore(now) ? now : initial,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 2));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    setState(() {
      final value =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        final duration = start != null && end != null
            ? end!.difference(start!)
            : const Duration(hours: 1);
        start = value;
        end = value.add(duration);
      } else {
        end = value;
      }
      checked = false;
      availability = null;
    });
  }

  bool validate() {
    final message = bookingValidation(court, start, end, DateTime.now());
    if (message != null) {
      setState(() => error = message);
      return false;
    }
    return true;
  }

  Future<void> check() async {
    if (!validate()) return;
    await perform(() async {
      final body = await widget.api.request('/courts/$court/availability',
          query: {'date': start!.toUtc().toIso8601String().substring(0, 10)});
      if (mounted) {
        setState(() {
          availability = Map<String, dynamic>.from(body['data'] as Map);
          checked = availability!['is_closed'] != true;
          if (!checked) {
            error = 'The court is closed on this date.';
          }
        });
      }
    });
  }

  Future<void> reserve() async {
    if (!checked || !validate()) return;
    if (widget.booking != null) {
      final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Confirm reschedule'),
                  content: Text(
                      'Move ${widget.booking!['reference']} to ${dateText(start)} – ${dateText(end)}? The price and original payment deadline must remain unchanged.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep current time')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Confirm'))
                  ]));
      if (approved != true || !mounted) return;
    }
    await perform(() async {
      final body = await widget.api.request(
          widget.booking == null
              ? '/bookings'
              : '/bookings/${widget.booking!['id']}/reschedule',
          method: widget.booking == null ? 'POST' : 'PATCH',
          data: {
            'court_id': court,
            'starts_at': start!.toUtc().toIso8601String(),
            'ends_at': end!.toUtc().toIso8601String(),
            'notes': notes.text.trim(),
          });
      if (widget.booking != null && mounted) {
        Navigator.pop(context, body['data']);
        return;
      }
      if (mounted) {
        setState(
            () => reservation = Map<String, dynamic>.from(body['data'] as Map));
      }
    });
  }

  String dateText(DateTime? value) => value == null
      ? 'Choose date and time'
      : '${MaterialLocalizations.of(context).formatMediumDate(value)} · ${TimeOfDay.fromDateTime(value).format(context)}';
  Widget picker(String label, int? value, List<Map<String, dynamic>> rows,
          void Function(int?) change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<int>(
            key: ValueKey('$label-$value-${rows.length}'),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: rows
                .map((row) => DropdownMenuItem(
                    value: row['id'] as int, child: Text('${row['name']}')))
                .toList(),
            onChanged: busy || rows.isEmpty ? null : change,
          ));
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
            title: Text(widget.booking == null
                ? 'Book a court'
                : 'Reschedule booking')),
        body: ListView(
            padding: const EdgeInsets.all(24),
            children: reservation != null
                ? [
                    const Icon(Icons.check_circle_outline, size: 56),
                    Text('Reservation created',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Text('Reference: ${reservation!['reference']}'),
                    Text('Status: ${reservation!['status']}'),
                    Text(
                        'Amount: ${reservation!['currency']} ${reservation!['amount']}'),
                    Text(
                        'Hold expires: ${dateText(DateTime.tryParse('${reservation!['expires_at']}')?.toLocal())}'),
                    const SizedBox(height: 16),
                    const Text(
                        'This is an unpaid reservation. Open My Bookings and choose Pay / check payment before the hold expires.'),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('View my bookings')),
                  ]
                : [
                    const Text(
                        'Select a court and your playing time. All selected times use your device’s time zone.'),
                    const SizedBox(height: 20),
                    if (busy) const LinearProgressIndicator(),
                    if (widget.booking == null) ...[
                      picker('Facility', facility, facilities, selectFacility),
                      if (!busy && facilities.isEmpty)
                        TextButton(
                            onPressed: loadFacilities,
                            child: const Text('No facilities loaded. Retry')),
                      picker('Branch', branch, branches, selectBranch),
                      picker(
                          'Court',
                          court,
                          courts,
                          (value) => setState(() {
                                court = value;
                                checked = false;
                                availability = null;
                              })),
                      if (facility != null && branches.isEmpty && !busy)
                        const Text(
                            'No branches available. Select the facility to retry.'),
                      if (branch != null && courts.isEmpty && !busy)
                        const Text(
                            'No active courts available. Select the branch to retry.'),
                    ] else
                      Text(
                          'Booking ${widget.booking!['reference']} · Same court\nOnly changes at the same price are supported. Contact your facility for a price adjustment.'),
                    ListTile(
                        title: const Text('Starts'),
                        subtitle: Text(dateText(start)),
                        onTap: busy ? null : () => pickTime(true)),
                    ListTile(
                        title: const Text('Ends'),
                        subtitle: Text(dateText(end)),
                        onTap: busy ? null : () => pickTime(false)),
                    if (widget.booking == null)
                      TextField(
                          controller: notes,
                          enabled: !busy,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                              labelText: 'Notes (optional)')),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(error!)),
                    OutlinedButton(
                        onPressed: busy ? null : check,
                        child: const Text('Check availability')),
                    if (availability != null) ...[
                      const Text(
                          'Existing reservations (times shown in your device’s time zone):'),
                      for (final row
                          in availability!['bookings'] as List? ?? [])
                        if (row['id'] != widget.booking?['id'])
                          Text(
                              '${dateText(DateTime.tryParse('${row['starts_at']}')?.toLocal())} – ${dateText(DateTime.tryParse('${row['ends_at']}')?.toLocal())}'),
                      const SizedBox(height: 12),
                      const Text(
                          'The server checks overlaps, operating hours, maintenance, and pricing when you reserve. The final amount is shown after the hold is created.'),
                    ],
                    FilledButton(
                        onPressed: busy || !checked ? null : reserve,
                        child: Text(busy
                            ? 'Please wait…'
                            : widget.booking == null
                                ? 'Reserve court'
                                : 'Reschedule booking')),
                  ]),
      ));
}

String? bookingValidation(
    int? court, DateTime? start, DateTime? end, DateTime now) {
  if (court == null) return 'Select a court.';
  if (start == null || end == null) return 'Choose start and end times.';
  if (!start.isAfter(now)) return 'Start time must be in the future.';
  if (!end.isAfter(start)) return 'End time must be after start time.';
  return null;
}
