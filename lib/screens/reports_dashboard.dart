import 'package:flutter/material.dart';

import '../core/api.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key, required this.api});

  final Api api;

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  DateTimeRange range = DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month),
      end: DateUtils.dateOnly(DateTime.now()));
  Map<String, dynamic> dashboard = {};
  Map<String, dynamic> revenue = {};
  Map<String, dynamic> occupancy = {};
  Map<String, dynamic> membershipSales = {};
  Map<String, dynamic> coachRevenue = {};
  Map<String, dynamic> tournamentRevenue = {};
  Map<String, dynamic> rentalRevenue = {};
  Map<String, dynamic> refunds = {};
  List<Map<String, dynamic>> peakHours = [];
  List<Map<String, dynamic>> courtUtilization = [];
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  String day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  List<Map<String, dynamic>> rows(dynamic value) => value is List
      ? value.map((row) => Map<String, dynamic>.from(row as Map)).toList()
      : [];

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final query = {'from': day(range.start), 'to': day(range.end)};
    try {
      final result = await Future.wait([
        widget.api.request('/reports/dashboard', query: query),
        widget.api.request('/reports/revenue', query: query),
        widget.api.request('/reports/occupancy', query: query),
        widget.api.request('/reports/peak-hours', query: query),
        widget.api.request('/reports/court-utilization', query: query),
        widget.api.request('/reports/membership-sales', query: query),
        widget.api.request('/reports/coach-revenue', query: query),
        widget.api.request('/reports/tournament-revenue', query: query),
        widget.api.request('/reports/rental-revenue', query: query),
        widget.api.request('/reports/refunds', query: query),
      ]);
      if (mounted) {
        setState(() {
          dashboard = map(result[0]['data']);
          revenue = map(result[1]['data']);
          occupancy = map(result[2]['data']);
          peakHours = rows(result[3]['data']);
          courtUtilization = rows(result[4]['data']);
          membershipSales = map(result[5]['data']);
          coachRevenue = map(result[6]['data']);
          tournamentRevenue = map(result[7]['data']);
          rentalRevenue = map(result[8]['data']);
          refunds = map(result[9]['data']);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> chooseRange() async {
    final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(DateTime.now().year - 2),
        lastDate: DateTime.now(),
        initialDateRange: range);
    if (selected != null && mounted) {
      setState(() => range = selected);
      await load();
    }
  }

  String money(dynamic value) => 'PHP ${value ?? '0'}';

  Widget metric(String label, dynamic value) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$value', style: Theme.of(context).textTheme.titleLarge),
            Text(label, textAlign: TextAlign.center),
          ])));

  Widget section(String title, List<Widget> children) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...children,
          ])));

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                OutlinedButton.icon(
                    onPressed: loading ? null : chooseRange,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text('${day(range.start)} to ${day(range.end)}')),
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
                if (!loading && error == null) ...[
                  const SizedBox(height: 16),
                  Text('Operations summary',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    metric('Bookings', dashboard['bookings']),
                    metric('Confirmed', dashboard['confirmed_bookings']),
                    metric(
                        'Booking revenue', money(dashboard['booking_revenue'])),
                    metric(
                        'Active memberships', dashboard['active_memberships']),
                    metric('Active rentals', dashboard['active_rentals']),
                  ]),
                  const SizedBox(height: 16),
                  section('Revenue', [
                    Text('Paid revenue: ${money(revenue['total'])}'),
                    ...rows(revenue['by_day']).map((row) => Text(
                        '${row['date']}: ${money(row['amount'])} · ${row['count']} payments')),
                  ]),
                  section('Occupancy', [
                    Text('${occupancy['occupancy_percent'] ?? 0}% occupied'),
                    Text(
                        '${occupancy['booked_minutes'] ?? 0} booked minutes · ${occupancy['booking_count'] ?? 0} bookings'),
                  ]),
                  section('Peak hours', [
                    if (peakHours.isEmpty)
                      const Text('No confirmed bookings in this range.'),
                    ...peakHours.map((row) => Text(
                        '${row['hour']}: ${row['booking_count']} bookings · ${row['booked_minutes']} minutes')),
                  ]),
                  section('Court utilization', [
                    if (courtUtilization.isEmpty)
                      const Text('No court usage in this range.'),
                    ...courtUtilization.map((row) => Text(
                        'Court ${row['court_id']}: ${row['booking_count']} bookings · ${row['booked_minutes']} minutes')),
                  ]),
                  section('Membership sales', [
                    Text(
                        '${membershipSales['sales_count'] ?? 0} memberships sold'),
                    ...rows(membershipSales['by_plan']).map((row) => Text(
                        'Plan ${row['membership_plan_id']}: ${row['count']} sales')),
                  ]),
                  section('Coaching revenue', [
                    Text(
                        'Completed session revenue: ${money(coachRevenue['total'])}'),
                    ...rows(coachRevenue['by_coach']).map((row) => Text(
                        'Coach ${row['coach_id']}: ${row['sessions']} sessions · ${money(row['amount'])}')),
                  ]),
                  section('Tournament revenue', [
                    Text(
                        'Estimated revenue: ${money(tournamentRevenue['total_estimated_revenue'])}'),
                    ...rows(tournamentRevenue['tournaments']).map((row) => Text(
                        'Tournament ${row['tournament_id']}: ${row['registrations']} registrations · ${money(row['estimated_revenue'])}')),
                  ]),
                  section('Rental revenue', [
                    Text('${rentalRevenue['rental_count'] ?? 0} rentals'),
                    Text(
                        'Rental revenue: ${money(rentalRevenue['rental_revenue'])}'),
                    Text('Damage fees: ${money(rentalRevenue['damage_fees'])}'),
                    Text('Total: ${money(rentalRevenue['total'])}'),
                  ]),
                  section('Refunds', [
                    Text(
                        'Booking refunds: ${money(map(refunds['booking_refunds'])['amount'])}'),
                    Text(
                        'Payment refunds: ${money(map(refunds['payment_refunds'])['amount'])}'),
                    Text('Total refunded: ${money(refunds['total_amount'])}'),
                  ]),
                ],
              ])));
}
