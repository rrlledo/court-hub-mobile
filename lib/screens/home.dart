import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/api.dart';
import '../core/session.dart';
import 'coach_workspace.dart';
import 'create_booking.dart';
import 'front_desk_workspace.dart';
import 'memberships.dart';
import 'organizer_workspace.dart';
import 'operations_workspace.dart';
import 'payment.dart';
import 'rentals.dart';
import 'staff_checkin.dart';
import 'staff_rentals.dart';
import 'super_admin_workspace.dart';

const roleLabels = {
  'super-admin': 'Super Admin',
  'court-owner': 'Court Owner',
  'facility-manager': 'Facility Manager',
  'front-desk': 'Front Desk',
  'coach': 'Coach',
  'event-organizer': 'Event Organizer',
  'player': 'Player',
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session, this.initialTab});
  final Session session;
  final String? initialTab;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  int bookingRevision = 0;

  @override
  void initState() {
    super.initState();
    selectInitialTab();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      selectInitialTab();
    }
  }

  void selectInitialTab() {
    final requested = widget.initialTab;
    if (requested == null) return;
    final position = tabNames.indexOf(requested);
    if (position >= 0) index = position;
  }

  List<String> get tabNames {
    final roles = widget.session.roles;
    final player = roles.contains('player');
    final staff = roles.any((role) =>
        ['court-owner', 'facility-manager', 'front-desk'].contains(role));
    final operator =
        roles.any((role) => ['court-owner', 'facility-manager'].contains(role));
    return [
      'home',
      'bookings',
      if (player) 'memberships',
      if (player) 'rentals',
      if (staff) 'rental-operations',
      if (staff) 'checkin',
      if (roles.contains('front-desk')) 'front-desk',
      if (operator) 'operations',
      if (roles.contains('super-admin')) 'admin',
      if (roles.contains('coach')) 'coaching',
      if (roles.contains('event-organizer')) 'events',
      'inbox',
      'account',
    ];
  }

  Future<void> createBooking() async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => CreateBookingScreen(api: widget.session.api)));
    if (mounted) {
      setState(() {
        index = 1;
        bookingRevision++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final player = session.roles.contains('player');
    final staff = session.roles.any((role) =>
        ['court-owner', 'facility-manager', 'front-desk'].contains(role));
    final coach = session.roles.contains('coach');
    final organizer = session.roles.contains('event-organizer');
    final operator = session.roles
        .any((role) => ['court-owner', 'facility-manager'].contains(role));
    final frontDesk = session.roles.contains('front-desk');
    final superAdmin = session.roles.contains('super-admin');
    final cameraEnabled =
        kIsWeb || defaultTargetPlatform != TargetPlatform.windows;
    final pages = [
      _Welcome(session: session, onBookings: () => setState(() => index = 1)),
      RecordList(
          key: ValueKey('bookings-$bookingRevision'),
          api: session.api,
          path: '/bookings/history',
          notifications: false),
      if (player) MembershipsScreen(api: session.api),
      if (player) PlayerRentalsScreen(api: session.api),
      if (staff) StaffRentalsScreen(api: session.api),
      if (staff)
        StaffCheckInScreen(api: session.api, enableCamera: cameraEnabled),
      if (frontDesk) FrontDeskWorkspaceScreen(api: session.api),
      if (operator)
        OperationsWorkspaceScreen(
            api: session.api,
            canManageRoles: session.roles.contains('court-owner')),
      if (superAdmin) SuperAdminWorkspaceScreen(api: session.api),
      if (coach) CoachWorkspaceScreen(api: session.api),
      if (organizer) OrganizerWorkspaceScreen(api: session.api),
      RecordList(
          key: const ValueKey('notifications'),
          api: session.api,
          path: '/notifications',
          notifications: true),
      _Account(session: session),
    ];
    return Scaffold(
      floatingActionButton: !superAdmin && index < 2
          ? FloatingActionButton.extended(
              onPressed: createBooking,
              icon: const Icon(Icons.add),
              label: const Text('Book a court'))
          : null,
      appBar: AppBar(
          title: Text([
        'Court Hub',
        'My bookings',
        if (player) 'Memberships',
        if (player) 'My rentals',
        if (staff) 'Rental operations',
        if (staff) 'Staff check-in',
        if (frontDesk) 'Front Desk workspace',
        if (operator) 'Operations workspace',
        if (superAdmin) 'Super Admin workspace',
        if (coach) 'Coach workspace',
        if (organizer) 'Event organizer workspace',
        'Notifications',
        'Account',
      ][index])),
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined), label: 'Bookings'),
            if (player)
              NavigationDestination(
                  icon: Icon(Icons.card_membership_outlined),
                  label: 'Memberships'),
            if (player)
              NavigationDestination(
                  icon: Icon(Icons.sports_tennis_outlined), label: 'Rentals'),
            if (staff)
              NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined), label: 'Rental desk'),
            if (staff)
              NavigationDestination(
                  icon: Icon(Icons.qr_code_scanner), label: 'Check-in'),
            if (frontDesk)
              NavigationDestination(
                  icon: Icon(Icons.point_of_sale_outlined),
                  label: 'Front desk'),
            if (operator)
              NavigationDestination(
                  icon: Icon(Icons.business_center_outlined),
                  label: 'Operations'),
            if (superAdmin)
              NavigationDestination(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  label: 'Admin'),
            if (coach)
              NavigationDestination(
                  icon: Icon(Icons.sports), label: 'Coaching'),
            if (organizer)
              NavigationDestination(
                  icon: Icon(Icons.emoji_events_outlined), label: 'Events'),
            NavigationDestination(
                icon: Icon(Icons.notifications_outlined), label: 'Inbox'),
            NavigationDestination(
                icon: Icon(Icons.person_outline), label: 'Account'),
          ]),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.session, required this.onBookings});
  final Session session;
  final VoidCallback onBookings;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        Text('Welcome, ${session.user?['name'] ?? ''}',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Wrap(
            spacing: 8,
            children: session.roles
                .map((role) => Chip(label: Text(roleLabels[role] ?? role)))
                .toList()),
        if (session.roles.length == 1 &&
            session.roles.single == 'player' &&
            session.user?['email_verified_at'] == null) ...[
          const SizedBox(height: 16),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'Verify your email before booking or paying.'),
                        TextButton(
                            onPressed: () async {
                              try {
                                await session.api.request(
                                    '/auth/email/verification-notification',
                                    method: 'POST');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Verification link sent.')));
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(errorMessage(error))));
                                }
                              }
                            },
                            child: const Text('Resend verification link')),
                      ]))),
        ],
        const SizedBox(height: 24),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.sports_tennis, size: 40),
                      const SizedBox(height: 16),
                      Text('Make time for your game',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                          'Keep track of your court reservations and updates from your facility.'),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: onBookings,
                          child: const Text('View my bookings')),
                    ]))),
        if (session.roles.any((r) => r != 'player')) ...[
          const SizedBox(height: 24),
          const Text(
              'Use the role workspace tabs for daily facility, check-in, coaching, and event tasks.'),
        ],
      ]);
}

class RecordList extends StatefulWidget {
  const RecordList(
      {super.key,
      required this.api,
      required this.path,
      required this.notifications});
  final Api api;
  final String path;
  final bool notifications;
  @override
  State<RecordList> createState() => _RecordListState();
}

class _RecordListState extends State<RecordList> {
  final List<Map<String, dynamic>> items = [];
  int page = 0;
  bool busy = false;
  bool more = false;
  String? error;
  int? cancelling;
  int? generatingQr;
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  @override
  void didUpdateWidget(covariant RecordList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      // The parent supplies distinct keys to prevent stale list requests.
      items.clear();
      page = 0;
      more = false;
      load(reset: true);
    }
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = reset ? 1 : page + 1;
      final result = ApiPage.parse(
          await widget.api.request(widget.path, query: {'page': next}));
      if (!mounted) return;
      setState(() {
        if (reset) items.clear();
        items.addAll(result.items);
        page = next;
        more = result.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> markRead(Map<String, dynamic> row) async {
    try {
      await widget.api
          .request('/notifications/${row['id']}/read', method: 'POST');
      if (mounted) {
        setState(() => row['read_at'] = DateTime.now().toIso8601String());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  Future<void> cancelBooking(Map<String, dynamic> row) async {
    final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Cancel booking?'),
              content: Text(
                  'Cancel ${row['reference']}? This releases your court reservation. Any payment refund must be arranged separately with your facility.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep booking')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Cancel booking')),
              ],
            ));
    if (approved != true || !mounted || cancelling != null) return;
    setState(() => cancelling = row['id'] as int);
    try {
      await widget.api.request('/bookings/${row['id']}/cancel', method: 'POST');
      if (!mounted) return;
      setState(() => row['status'] = 'cancelled');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => cancelling = null);
    }
  }

  Future<void> rescheduleBooking(Map<String, dynamic> row) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
            builder: (_) =>
                CreateBookingScreen(api: widget.api, booking: row)));
    if (result != null && mounted) {
      setState(() => row.addAll(result));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Booking rescheduled.')));
    }
  }

  Future<void> payBooking(Map<String, dynamic> row) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            PaymentScreen(api: widget.api, bookingId: row['id'] as int)));
    if (mounted) await load(reset: true);
  }

  Future<void> showBookingQr(Map<String, dynamic> row) async {
    setState(() => generatingQr = row['id'] as int);
    try {
      final body = await widget.api
          .request('/bookings/${row['id']}/qr-code', method: 'POST');
      final qrCode = body['data']['qr_code'] as String;
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Booking check-in code'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  QrImageView(data: qrCode, size: 220),
                  const SizedBox(height: 12),
                  SelectableText(qrCode),
                  const SizedBox(height: 8),
                  const Text('Show this code to facility staff at check-in.',
                      textAlign: TextAlign.center),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ],
              ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => generatingQr = null);
    }
  }

  String dateLabel(dynamic raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (value == null) return 'Date unavailable';
    return '${MaterialLocalizations.of(context).formatMediumDate(value)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: () => load(reset: true),
      child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Text(error!),
                    TextButton(
                        onPressed: busy ? null : () => load(reset: page == 0),
                        child: const Text('Retry')),
                  ])),
            if (!busy && error == null && items.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                      widget.notifications
                          ? 'You’re all caught up.'
                          : 'Your bookings will appear here.',
                      textAlign: TextAlign.center)),
            ...items.map((row) => Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.notifications
                            ? [
                                Text('${row['title'] ?? 'Update'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Text('${row['message'] ?? ''}'),
                                const SizedBox(height: 8),
                                Text(dateLabel(row['created_at'])),
                                if (row['read_at'] == null)
                                  TextButton(
                                      onPressed: () => markRead(row),
                                      child: const Text('Mark as read')),
                              ]
                            : [
                                Text('${row['reference'] ?? 'Booking'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Text(dateLabel(row['starts_at'])),
                                const SizedBox(height: 8),
                                Text(
                                    '${row['currency'] ?? 'PHP'} ${row['amount'] ?? '0'}'),
                                Chip(
                                    label:
                                        Text('${row['status'] ?? 'Unknown'}')),
                                if ([
                                  'reserved',
                                  'confirmed',
                                  'expired',
                                  'cancelled'
                                ].contains(row['status']))
                                  TextButton(
                                      onPressed: () => payBooking(row),
                                      child: Text(row['status'] == 'reserved'
                                          ? 'Pay / check payment'
                                          : 'Check payment')),
                                if (row['status'] == 'confirmed')
                                  TextButton(
                                      onPressed: generatingQr == null
                                          ? () => showBookingQr(row)
                                          : null,
                                      child: Text(generatingQr == row['id']
                                          ? 'Preparing QR code…'
                                          : 'Show check-in code')),
                                if (canCancelBooking(row, DateTime.now()))
                                  TextButton(
                                      onPressed: cancelling != null
                                          ? null
                                          : () => rescheduleBooking(row),
                                      child: const Text('Reschedule')),
                                if (canCancelBooking(row, DateTime.now()))
                                  TextButton(
                                      onPressed: cancelling != null
                                          ? null
                                          : () => cancelBooking(row),
                                      child: Text(cancelling == row['id']
                                          ? 'Cancelling…'
                                          : 'Cancel booking')),
                              ])))),
            if (more)
              TextButton(
                  onPressed: busy ? null : () => load(),
                  child: const Text('Load more')),
          ]));
}

bool canCancelBooking(Map<String, dynamic> row, DateTime now) {
  if (!['reserved', 'confirmed'].contains(row['status'])) return false;
  final starts = DateTime.tryParse('${row['starts_at']}');
  if (starts == null || !starts.isAfter(now)) return false;
  if (row['status'] == 'reserved') {
    final expires = DateTime.tryParse('${row['expires_at']}');
    if (expires == null || !expires.isAfter(now)) return false;
  }
  return true;
}

class _Account extends StatefulWidget {
  const _Account({required this.session});
  final Session session;
  @override
  State<_Account> createState() => _AccountState();
}

class _AccountState extends State<_Account> {
  late final name =
      TextEditingController(text: widget.session.user?['name'] as String?);
  bool busy = false;
  String? message;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> action(bool logout) async {
    if (!logout && name.text.trim().isEmpty) {
      setState(() => message = 'Enter your name.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (logout) {
        await widget.session.logout();
      } else {
        await widget.session.api.request('/profile',
            method: 'PATCH', data: {'name': name.text.trim()});
        await widget.session.hydrate();
        if (mounted) setState(() => message = 'Profile updated.');
      }
    } catch (e) {
      if (mounted) setState(() => message = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        Text('${widget.session.user?['email'] ?? ''}'),
        const SizedBox(height: 24),
        TextField(
            controller: name,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Name')),
        if (message != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(message!)),
        FilledButton(
            onPressed: busy ? null : () => action(false),
            child: const Text('Save profile')),
        const SizedBox(height: 24),
        OutlinedButton(
            onPressed: busy ? null : () => action(true),
            child: const Text('Sign out')),
      ]);
}
