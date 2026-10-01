import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/api.dart';
import 'payment.dart';

class MembershipsScreen extends StatefulWidget {
  const MembershipsScreen({super.key, required this.api});
  final Api api;
  @override
  State<MembershipsScreen> createState() => _MembershipsScreenState();
}

class _MembershipsScreenState extends State<MembershipsScreen> {
  List<Map<String, dynamic>> plans = [];
  List<Map<String, dynamic>> memberships = [];
  String? error;
  int? busyId;
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
      final result = await Future.wait([
        widget.api.request('/player/membership-plans'),
        widget.api.request('/player/memberships'),
      ]);
      if (mounted) {
        setState(() {
          plans = ApiPage.parse(result[0]).items;
          memberships = ApiPage.parse(result[1]).items;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> buy(Map<String, dynamic> plan) async {
    setState(() => busyId = plan['id'] as int);
    try {
      final body = await widget.api.request('/player/memberships',
          method: 'POST', data: {'membership_plan_id': plan['id']});
      final membership = Map<String, dynamic>.from(body['data'] as Map);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PaymentScreen(
              api: widget.api, membershipId: membership['id'] as int)));
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> renew(Map<String, dynamic> membership) async {
    setState(() => busyId = membership['id'] as int);
    try {
      final body = await widget.api.request(
          '/player/memberships/${membership['id']}/renew',
          method: 'POST');
      final renewal = Map<String, dynamic>.from(body['data'] as Map);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PaymentScreen(
              api: widget.api, membershipId: renewal['id'] as int)));
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  String price(Map<String, dynamic> plan) =>
      '${plan['currency'] ?? 'PHP'} ${plan['price'] ?? '0.00'}';
  String date(dynamic value) => DateTime.tryParse('$value') == null
      ? 'Unavailable'
      : MaterialLocalizations.of(context)
          .formatMediumDate(DateTime.parse('$value'));

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('My memberships',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Buy an active plan or renew a membership. Your card appears after payment is confirmed.'),
          if (loading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator()),
          if (error != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(error!),
                      TextButton(
                          onPressed: loading ? null : load,
                          child: const Text('Retry')),
                    ])),
          if (!loading && memberships.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Your memberships',
                style: Theme.of(context).textTheme.titleLarge),
            ...memberships.map(membershipCard),
          ],
          const SizedBox(height: 24),
          Text('Available plans',
              style: Theme.of(context).textTheme.titleLarge),
          if (!loading && plans.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                    'No membership plans are available at your facility.')),
          ...plans.map(planCard),
        ],
      ));

  Widget membershipCard(Map<String, dynamic> membership) {
    final plan = Map<String, dynamic>.from((membership['plan'] ?? {}) as Map);
    final card = membership['card'] == null
        ? null
        : Map<String, dynamic>.from(membership['card'] as Map);
    final pending = membership['status'] == 'pending';
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${plan['name'] ?? 'Membership'}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                  '${membership['status']} · ${date(membership['starts_on'])} – ${date(membership['ends_on'])}'),
              if (membership['remaining_sessions'] != null)
                Text('Sessions remaining: ${membership['remaining_sessions']}'),
              if (card != null) ...[
                const SizedBox(height: 12),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MEMBERSHIP CARD'),
                          Text('${card['card_number']}',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          Center(
                              child: QrImageView(
                                  data: '${card['qr_code']}', size: 180)),
                          SelectableText('${card['qr_code']}',
                              style: const TextStyle(letterSpacing: 1.4)),
                        ])),
              ],
              const SizedBox(height: 8),
              if (pending)
                TextButton(
                    onPressed: busyId == membership['id']
                        ? null
                        : () => Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => PaymentScreen(
                                    api: widget.api,
                                    membershipId: membership['id'] as int)))
                            .then((_) => load()),
                    child: const Text('Complete payment')),
              if (!pending)
                TextButton(
                    onPressed: busyId == membership['id']
                        ? null
                        : () => renew(membership),
                    child: Text(busyId == membership['id']
                        ? 'Preparing renewal…'
                        : 'Renew membership')),
            ])));
  }

  Widget planCard(Map<String, dynamic> plan) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${plan['name']}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('${price(plan)} · ${plan['duration_days']} days'),
            if (plan['session_count'] != null)
              Text('${plan['session_count']} sessions'),
            if (plan['priority_booking'] == true)
              const Text('Priority booking included'),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: busyId == plan['id'] ? null : () => buy(plan),
                child: Text(busyId == plan['id']
                    ? 'Preparing checkout…'
                    : 'Buy membership')),
          ])));
}
