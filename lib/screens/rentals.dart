import 'package:flutter/material.dart';

import '../core/api.dart';

class PlayerRentalsScreen extends StatefulWidget {
  const PlayerRentalsScreen({super.key, required this.api});

  final Api api;

  @override
  State<PlayerRentalsScreen> createState() => _PlayerRentalsScreenState();
}

class _PlayerRentalsScreenState extends State<PlayerRentalsScreen> {
  List<Map<String, dynamic>> rentals = [];
  bool loading = true;
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
      final page = ApiPage.parse(await widget.api.request('/rentals'));
      if (mounted) setState(() => rentals = page.items);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String dueLabel(dynamic value) {
    final due = DateTime.tryParse('$value')?.toLocal();
    if (due == null) return 'No due date';
    return MaterialLocalizations.of(context).formatMediumDate(due);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('My equipment rentals',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'This list includes only equipment assigned to your account. Contact the front desk to extend or return an item.'),
            if (loading)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator()),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(error!),
                        TextButton(
                            onPressed: loading ? null : load,
                            child: const Text('Retry')),
                      ])),
            if (!loading && error == null && rentals.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('You have no equipment rentals.')),
            ...rentals.map((rental) => Card(
                child: ListTile(
                    title: Text('Rental #${rental['id']}'),
                    subtitle: Text(
                        'Quantity: ${rental['quantity']} · Due: ${dueLabel(rental['due_at'])}'),
                    trailing: Chip(label: Text('${rental['status']}'))))),
          ]));
}
