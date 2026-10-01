import 'package:flutter/material.dart';

import '../core/api.dart';

class SuperAdminWorkspaceScreen extends StatefulWidget {
  const SuperAdminWorkspaceScreen({super.key, required this.api});

  final Api api;

  @override
  State<SuperAdminWorkspaceScreen> createState() =>
      _SuperAdminWorkspaceScreenState();
}

class _SuperAdminWorkspaceScreenState extends State<SuperAdminWorkspaceScreen> {
  Map<String, dynamic> overview = {};
  List<Map<String, dynamic>> tenants = [];
  String? error;
  bool loading = true;
  int? updatingTenant;

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
        widget.api.request('/super-admin/overview'),
        widget.api.request('/super-admin/tenants'),
      ]);
      if (mounted) {
        setState(() {
          overview = Map<String, dynamic>.from(result[0]['data'] as Map);
          tenants = ApiPage.parse(result[1]).items;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> patchTenant(int tenantId, Map<String, dynamic> data) async {
    setState(() => updatingTenant = tenantId);
    try {
      await widget.api.request('/super-admin/tenants/$tenantId',
          method: 'PATCH', data: data);
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => updatingTenant = null);
    }
  }

  Future<void> toggleTenant(Map<String, dynamic> tenant) async {
    final active = tenant['is_active'] == true;
    if (active) {
      final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('Suspend ${tenant['name']}?'),
                content: const Text(
                    'Users in this tenant will be unable to sign in or use existing sessions until it is reactivated.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep active')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Suspend')),
                ],
              ));
      if (approved != true) return;
    }
    await patchTenant(tenant['id'] as int, {'is_active': !active});
  }

  Future<void> editTenant(Map<String, dynamic> tenant) async {
    final name = TextEditingController(text: '${tenant['name']}');
    final timezone = TextEditingController(text: '${tenant['timezone']}');
    final country = TextEditingController(text: '${tenant['country_code']}');
    final amount =
        TextEditingController(text: '${tenant['subscription_amount'] ?? 0}');
    final renewsAt = TextEditingController(
        text: '${tenant['subscription_renews_at'] ?? ''}'.split('T').first);
    var plan = '${tenant['subscription_plan'] ?? 'starter'}';
    var status = '${tenant['subscription_status'] ?? 'trial'}';
    final saved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text('Edit ${tenant['name']}'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        decoration:
                            const InputDecoration(labelText: 'Tenant name')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: timezone,
                        decoration:
                            const InputDecoration(labelText: 'Timezone')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: country,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 2,
                        decoration:
                            const InputDecoration(labelText: 'Country code')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        key: ValueKey(plan),
                        initialValue: plan,
                        decoration:
                            const InputDecoration(labelText: 'Mock plan'),
                        items: const [
                          DropdownMenuItem(
                              value: 'starter', child: Text('Starter')),
                          DropdownMenuItem(
                              value: 'growth', child: Text('Growth')),
                          DropdownMenuItem(
                              value: 'enterprise', child: Text('Enterprise')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => plan = value!)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        key: ValueKey(status),
                        initialValue: status,
                        decoration: const InputDecoration(
                            labelText: 'Mock billing status'),
                        items: const [
                          DropdownMenuItem(
                              value: 'trial', child: Text('Trial')),
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'past_due', child: Text('Past due')),
                          DropdownMenuItem(
                              value: 'cancelled', child: Text('Cancelled')),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => status = value!)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Mock monthly amount (PHP)')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: renewsAt,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                            labelText: 'Renews on (YYYY-MM-DD)')),
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
    if (saved == true && name.text.trim().isNotEmpty) {
      await patchTenant(tenant['id'] as int, {
        'name': name.text.trim(),
        'timezone': timezone.text.trim(),
        'country_code': country.text.trim().toUpperCase(),
        'subscription_plan': plan,
        'subscription_status': status,
        'subscription_amount': double.tryParse(amount.text.trim()) ?? 0,
        'subscription_renews_at':
            renewsAt.text.trim().isEmpty ? null : renewsAt.text.trim(),
      });
    }
    name.dispose();
    timezone.dispose();
    country.dispose();
    amount.dispose();
    renewsAt.dispose();
  }

  Future<void> viewTenant(Map<String, dynamic> tenant) async {
    try {
      final result = await Future.wait([
        widget.api.request('/super-admin/tenants/${tenant['id']}'),
        widget.api.request(
            '/super-admin/tenants/${tenant['id']}/subscription-invoices'),
      ]);
      final detail = Map<String, dynamic>.from(result[0]['data'] as Map);
      final invoices = ApiPage.parse(result[1]).items;
      if (!mounted) return;
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) {
            final metrics = Map<String, dynamic>.from(detail['metrics'] as Map);
            final subscription = Map<String, dynamic>.from(
                metrics['simulated_platform_subscription'] as Map);
            final users = (detail['users'] as List)
                .map((user) => Map<String, dynamic>.from(user as Map))
                .toList();
            return SafeArea(
                child: DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.75,
                    minChildSize: 0.5,
                    builder: (context, controller) => ListView(
                            controller: controller,
                            padding: const EdgeInsets.all(20),
                            children: [
                              Text('${tenant['name']} details',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall),
                              const SizedBox(height: 12),
                              Text('Bookings: ${metrics['bookings']}'),
                              Text(
                                  'Paid revenue: PHP ${metrics['paid_revenue']}'),
                              Text(
                                  'Active memberships: ${metrics['active_memberships']}'),
                              const SizedBox(height: 8),
                              Text('Simulated platform subscription',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(
                                  '${subscription['plan']} · ${subscription['status']} · PHP ${subscription['amount']}'),
                              Text(
                                  'Renews: ${subscription['renews_at'] ?? 'Not scheduled'}'),
                              Text('Simulated invoices: ${invoices.length}'),
                              const SizedBox(height: 20),
                              Text('Users',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              if (users.isEmpty)
                                const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('No users in this tenant.')),
                              ...users.map((user) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                      child: Icon(Icons.person_outline)),
                                  title: Text('${user['name']}'),
                                  subtitle: Text('${user['email']}'),
                                  trailing: TextButton(
                                      onPressed: () => revokeSessions(
                                          tenant['id'] as int, user),
                                      child: const Text('Revoke sessions')))),
                            ])));
          });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  Future<void> revokeSessions(int tenantId, Map<String, dynamic> user) async {
    final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Revoke ${user['name']} sessions?'),
              content: const Text(
                  'This signs the user out from all active Court Hub sessions.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Revoke')),
              ],
            ));
    if (approved != true) return;
    try {
      await widget.api.request(
          '/super-admin/tenants/$tenantId/users/${user['id']}/revoke-sessions',
          method: 'POST');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sessions revoked.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  Future<void> createMockInvoice(Map<String, dynamic> tenant) async {
    setState(() => updatingTenant = tenant['id'] as int);
    try {
      await widget.api.request(
          '/super-admin/tenants/${tenant['id']}/subscription-invoices',
          method: 'POST',
          data: {
            'amount':
                double.tryParse('${tenant['subscription_amount'] ?? 0}') ?? 0,
            'status': 'open',
            'notes': 'Created in the local mobile Super Admin workspace.',
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Simulated invoice created.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => updatingTenant = null);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Super Admin workspace',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'Monitor all Court Hub tenants and respond to account issues.'),
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
            if (overview.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                metric('Tenants', overview['tenants']),
                metric('Active', overview['active_tenants']),
                metric('Users', overview['users']),
                metric('Facilities', overview['facilities']),
                metric('Today’s bookings', overview['today_bookings']),
                metric('Paid revenue', 'PHP ${overview['paid_revenue']}'),
                metric('Simulated MRR',
                    'PHP ${overview['simulated_platform_mrr'] ?? 0}'),
              ]),
            ],
            const SizedBox(height: 24),
            Text('Tenants', style: Theme.of(context).textTheme.titleLarge),
            if (!loading && tenants.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No tenants have been created yet.')),
            ...tenants.map(tenantCard),
          ]));

  Widget metric(String label, dynamic value) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$value', style: Theme.of(context).textTheme.titleLarge),
            Text(label, textAlign: TextAlign.center),
          ])));

  Widget tenantCard(Map<String, dynamic> tenant) {
    final active = tenant['is_active'] == true;
    final updating = updatingTenant == tenant['id'];
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('${tenant['name']}',
                        style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                    tooltip: 'Edit tenant',
                    onPressed: updating ? null : () => editTenant(tenant),
                    icon: const Icon(Icons.edit_outlined)),
              ]),
              Text('${tenant['slug']} · ${tenant['timezone']}'),
              Text(
                  '${tenant['users_count'] ?? 0} users · ${tenant['facilities_count'] ?? 0} facilities'),
              Text(
                  'Mock ${tenant['subscription_plan'] ?? 'starter'} · ${tenant['subscription_status'] ?? 'trial'} · PHP ${tenant['subscription_amount'] ?? 0}'),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(active ? 'Active' : 'Suspended'),
                  subtitle: Text(active
                      ? 'Tenant users can access Court Hub.'
                      : 'Tenant users are blocked from Court Hub.'),
                  value: active,
                  onChanged: updating ? null : (_) => toggleTenant(tenant)),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, children: [
                  TextButton.icon(
                      onPressed: () => viewTenant(tenant),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View tenant')),
                  TextButton.icon(
                      onPressed:
                          updating ? null : () => createMockInvoice(tenant),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Create mock invoice')),
                ]),
              ),
            ])));
  }
}
