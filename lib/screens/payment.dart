import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen(
      {super.key,
      required this.api,
      this.bookingId,
      this.membershipId,
      this.openCheckout})
      : assert((bookingId == null) != (membershipId == null));
  final Api api;
  final int? bookingId;
  final int? membershipId;
  final Future<bool> Function(Uri)? openCheckout;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? data;
  String method = 'gcash';
  String provider = 'paymongo';
  List<Map<String, dynamic>> providers = [];
  String? error;
  bool busy = false;
  Timer? timer;
  int polls = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    check();
    loadProviders();
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (polls++ < 30 && !terminal) check();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  bool get isMembership => widget.membershipId != null;
  String get subject => isMembership ? 'membership' : 'booking';
  String? get status => data?['payment']?['status'] as String?;
  bool get terminal =>
      ['paid', 'paid_review', 'expired', 'rejected'].contains(status);
  bool get expired {
    if (isMembership) return false;
    final raw = data?['booking']?['expires_at'];
    final deadline = DateTime.tryParse('$raw');
    return data?['booking']?['status'] == 'expired' ||
        data?['booking']?['status'] == 'cancelled' ||
        (deadline != null && !deadline.isAfter(DateTime.now()));
  }

  Future<void> loadProviders() async {
    try {
      final body = await widget.api.request('/payments/providers');
      final values = List<Map<String, dynamic>>.from(
          (body['data'] as List? ?? const [])
              .map((value) => Map<String, dynamic>.from(value as Map))
              .where((value) => value['configured'] == true));
      if (mounted) setState(() => providers = values);
    } catch (_) {
      // Existing deployments may not yet expose provider discovery.
    }
  }

  String get selectedProvider =>
      providers.any((item) => item['name'] == provider)
          ? provider
          : (providers.isNotEmpty ? '${providers.first['name']}' : provider);

  bool get simulatedProvider => selectedProvider == 'xendit';

  Future<void> check() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final path = isMembership
          ? '/player/memberships/${widget.membershipId}/payment-status'
          : '/bookings/${widget.bookingId}/payment-status';
      final body = await widget.api.request(path);
      if (mounted) {
        setState(() {
          data = Map<String, dynamic>.from(body['data'] as Map);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pay() async {
    if (busy || expired) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final body =
          await widget.api.request('/payments/intents', method: 'POST', data: {
        if (isMembership)
          'membership_id': widget.membershipId
        else
          'booking_id': widget.bookingId,
        'provider': selectedProvider,
        'method': method,
      });
      if (!mounted) return;
      setState(() => data = Map<String, dynamic>.from(body['data'] as Map));
      if (simulatedProvider) {
        final paymentId = data?['payment']?['id'];
        if (paymentId is! int) {
          throw StateError('The simulated payment is unavailable.');
        }
        final completed = await widget.api.request(
            '/payments/mock/xendit/$paymentId/complete',
            method: 'POST');
        if (mounted) {
          setState(
              () => data = Map<String, dynamic>.from(completed['data'] as Map));
        }
        return;
      }
      final url = Uri.tryParse('${data?['checkout_url']}');
      if (status == 'paid' || status == 'paid_review') return;
      if (url == null ||
          url.scheme != 'https' ||
          url.host != 'checkout.paymongo.com') {
        setState(() => error =
            'Checkout is still being prepared. Check status; contact your facility if it remains unavailable.');
        return;
      }
      final opened = await (widget.openCheckout?.call(url) ??
          launchUrl(url, mode: LaunchMode.externalApplication));
      if (!opened && mounted) {
        setState(
            () => error = 'Could not open checkout. Try opening it again.');
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text('${isMembership ? 'Membership' : 'Booking'} payment')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (busy) const LinearProgressIndicator(),
        Text(
            status == 'paid'
                ? (isMembership
                    ? 'Payment received — membership active'
                    : (data?['booking']?['status'] == 'confirmed'
                        ? 'Payment received — booking confirmed'
                        : 'Payment received — booking ${data?['booking']?['status']}'))
                : status == 'paid_review'
                    ? 'Payment received — contact your facility'
                    : expired
                        ? 'Reservation expired or cancelled'
                        : 'Complete your payment',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (data?['payment'] != null) ...[
          Text('${data!['payment']['currency']} ${data!['payment']['amount']}'),
          Text('Reference: ${data!['payment']['reference']}'),
          if (status == 'paid')
            Text('Receipt: ${data!['payment']['invoice_number']}'),
        ],
        if (status == 'paid_review')
          Text(
              'The payment arrived but could not confirm this $subject. Your facility must arrange a resolution or refund. Do not pay again.'),
        if (!terminal && !expired) ...[
          if (data?['attempt_failed'] == true)
            const Text(
                'The last payment attempt failed. Reopen checkout to try again.'),
          Text(simulatedProvider
              ? 'Xendit is simulated in this environment. Completing payment does not contact a payment provider or charge a customer.'
              : 'Pay securely on PayMongo. Return here afterwards to verify the result. Closing checkout does not confirm or cancel a payment.'),
          const SizedBox(height: 16),
          if (providers.isNotEmpty) ...[
            DropdownButtonFormField<String>(
                initialValue: selectedProvider,
                decoration:
                    const InputDecoration(labelText: 'Payment provider'),
                items: providers
                    .map((item) => DropdownMenuItem(
                        value: '${item['name']}',
                        child: Text(item['mock'] == true
                            ? 'Xendit (simulated)'
                            : 'PayMongo')))
                    .toList(),
                onChanged: busy || data?['payment'] != null
                    ? null
                    : (value) => setState(() => provider = value!)),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: const [
                DropdownMenuItem(value: 'gcash', child: Text('GCash')),
                DropdownMenuItem(value: 'maya', child: Text('Maya')),
                DropdownMenuItem(value: 'card', child: Text('Card'))
              ],
              onChanged: busy || data?['payment'] != null
                  ? null
                  : (v) => setState(() => method = v!)),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: busy || data == null ? null : pay,
              child: Text(simulatedProvider
                  ? 'Complete simulated payment'
                  : (data?['checkout_url'] == null
                      ? 'Pay now'
                      : 'Reopen checkout'))),
        ],
        if (status == 'rejected')
          FilledButton(
              onPressed: busy || expired ? null : pay,
              child: const Text('Retry checkout')),
        if (error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(error!)),
        OutlinedButton(
            onPressed: busy ? null : check,
            child: const Text('Check payment status')),
        if (terminal || expired)
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text('Back to ${isMembership ? 'memberships' : 'bookings'}')),
      ]));
}
