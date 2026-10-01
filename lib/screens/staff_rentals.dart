import 'package:flutter/material.dart';

import '../core/api.dart';

class StaffRentalsScreen extends StatefulWidget {
  const StaffRentalsScreen({super.key, required this.api});

  final Api api;

  @override
  State<StaffRentalsScreen> createState() => _StaffRentalsScreenState();
}

class _StaffRentalsScreenState extends State<StaffRentalsScreen> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> rentals = [];
  int? playerId;
  int? itemId;
  DateTime dueAt = DateTime.now().add(const Duration(days: 1));
  int quantity = 1;
  bool loading = true;
  int? busyRental;
  String? error;

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
      final result = await Future.wait([
        widget.api.request('/inventory-items'),
        widget.api.request('/rental-users'),
        widget.api.request('/rentals'),
      ]);
      if (!mounted) return;
      setState(() {
        items = ApiPage.parse(result[0])
            .items
            .where((item) => (item['quantity_available'] as num? ?? 0) > 0)
            .toList();
        players = List<Map<String, dynamic>>.from((result[1]['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map)));
        rentals = ApiPage.parse(result[2]).items;
      });
    } catch (caught) {
      if (mounted) setState(() => error = errorMessage(caught));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> issue() async {
    if (playerId == null || itemId == null || quantity < 1) {
      setState(() =>
          error = 'Select a player and equipment item, then enter a quantity.');
      return;
    }
    setState(() {
      busyRental = -1;
      error = null;
    });
    try {
      await widget.api.request('/rentals', method: 'POST', data: {
        'user_id': playerId,
        'inventory_item_id': itemId,
        'quantity': quantity,
        'due_at': dueAt.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Equipment issued.')));
      setState(() {
        itemId = null;
        quantity = 1;
      });
      await load();
    } catch (caught) {
      if (mounted) setState(() => error = errorMessage(caught));
    } finally {
      if (mounted) setState(() => busyRental = null);
    }
  }

  Future<void> chooseDueDate({Map<String, dynamic>? rental}) async {
    final initial = rental == null
        ? dueAt
        : DateTime.tryParse('${rental['due_at']}')?.toLocal() ?? dueAt;
    final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateUtils.dateOnly(DateTime.now()),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    final selected =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (rental == null) {
      setState(() => dueAt = selected);
      return;
    }
    await rentalAction(
        rental, 'extend', {'due_at': selected.toUtc().toIso8601String()});
  }

  Future<void> rentalAction(Map<String, dynamic> rental, String action,
      [Map<String, dynamic>? data]) async {
    setState(() {
      busyRental = rental['id'] as int;
      error = null;
    });
    try {
      await widget.api.request('/rentals/${rental['id']}/$action',
          method: 'POST', data: data);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Rental ${action}ed.')));
      await load();
    } catch (caught) {
      if (mounted) setState(() => error = errorMessage(caught));
    } finally {
      if (mounted) setState(() => busyRental = null);
    }
  }

  Future<void> closeWithDamage(Map<String, dynamic> rental) async {
    final controller = TextEditingController(text: '0');
    final amount = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Close rental'),
              content: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Damage fee')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(
                        context, double.tryParse(controller.text.trim()) ?? 0),
                    child: const Text('Close rental')),
              ],
            ));
    controller.dispose();
    if (amount != null && mounted) {
      await rentalAction(rental, 'close', {'damage_fee': amount});
    }
  }

  String date(dynamic raw) {
    final value = DateTime.tryParse('$raw')?.toLocal();
    if (value == null) return 'No due date';
    return '${MaterialLocalizations.of(context).formatMediumDate(value)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Equipment rentals',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'Issue equipment, extend due dates, receive returns, and record damage fees.'),
            if (loading)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator()),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 16), child: Text(error!)),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Issue equipment',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                              key: ValueKey('rental-player-$playerId'),
                              initialValue: playerId,
                              decoration:
                                  const InputDecoration(labelText: 'Player'),
                              items: players
                                  .map((player) => DropdownMenuItem(
                                      value: player['id'] as int,
                                      child: Text(
                                          '${player['name']} · ${player['email']}')))
                                  .toList(),
                              onChanged: loading
                                  ? null
                                  : (value) =>
                                      setState(() => playerId = value)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                              key: ValueKey('rental-item-$itemId'),
                              initialValue: itemId,
                              decoration:
                                  const InputDecoration(labelText: 'Equipment'),
                              items: items
                                  .map((item) => DropdownMenuItem(
                                      value: item['id'] as int,
                                      child: Text(
                                          '${item['name']} · ${item['quantity_available']} available')))
                                  .toList(),
                              onChanged: loading
                                  ? null
                                  : (value) => setState(() => itemId = value)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                              key: ValueKey('rental-quantity-$quantity'),
                              initialValue: quantity,
                              decoration:
                                  const InputDecoration(labelText: 'Quantity'),
                              items: List.generate(10, (index) => index + 1)
                                  .map((value) => DropdownMenuItem(
                                      value: value, child: Text('$value')))
                                  .toList(),
                              onChanged: loading
                                  ? null
                                  : (value) =>
                                      setState(() => quantity = value ?? 1)),
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed:
                                  busyRental == -1 ? null : chooseDueDate,
                              child: Text(
                                  'Due: ${date(dueAt.toIso8601String())}')),
                          FilledButton(
                              onPressed: busyRental == -1 ? null : issue,
                              child: Text(busyRental == -1
                                  ? 'Issuing…'
                                  : 'Issue equipment')),
                        ]))),
            const SizedBox(height: 16),
            Text('Active and past rentals',
                style: Theme.of(context).textTheme.titleLarge),
            if (!loading && rentals.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No rentals found.')),
            ...rentals.map((rental) {
              final active = rental['status'] == 'active';
              final busy = busyRental == rental['id'];
              final item = rental['inventory_item'] as Map?;
              final player = rental['user'] as Map?;
              return Card(
                  child: ListTile(
                      title: Text(
                          '${item?['name'] ?? 'Equipment'} · ${player?['name'] ?? 'Player'}'),
                      subtitle: Text(
                          'Qty ${rental['quantity']} · Due: ${date(rental['due_at'])}'),
                      trailing: active
                          ? PopupMenuButton<String>(
                              enabled: !busy,
                              onSelected: (action) {
                                if (action == 'return') {
                                  rentalAction(rental, 'return');
                                }
                                if (action == 'extend') {
                                  chooseDueDate(rental: rental);
                                }
                                if (action == 'close') {
                                  closeWithDamage(rental);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'return',
                                    child: Text('Return equipment')),
                                PopupMenuItem(
                                    value: 'extend',
                                    child: Text('Extend due date')),
                                PopupMenuItem(
                                    value: 'close',
                                    child: Text('Close with damage fee')),
                              ],
                            )
                          : Chip(label: Text('${rental['status']}'))));
            }),
          ]));
}
