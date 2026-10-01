import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/api.dart';

class StaffCheckInScreen extends StatefulWidget {
  const StaffCheckInScreen(
      {super.key, required this.api, this.enableCamera = true});
  final Api api;
  final bool enableCamera;
  @override
  State<StaffCheckInScreen> createState() => _StaffCheckInScreenState();
}

class _StaffCheckInScreenState extends State<StaffCheckInScreen> {
  final code = TextEditingController();
  final scanner = MobileScannerController();
  Map<String, dynamic>? result;
  String? error;
  bool busy = false;

  @override
  void dispose() {
    code.dispose();
    scanner.dispose();
    super.dispose();
  }

  Future<void> submit(String value) async {
    final qrCode = value.trim();
    if (qrCode.isEmpty || busy) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    if (widget.enableCamera) {
      await scanner.stop();
    }
    try {
      final body = await widget.api.request('/check-ins/scan',
          method: 'POST', data: {'qr_code': qrCode});
      if (mounted) {
        setState(() => result = Map<String, dynamic>.from(body['data'] as Map));
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  void detect(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty) {
      final value = capture.barcodes.first.rawValue;
      if (value != null) {
        submit(value);
      }
    }
  }

  Future<void> scanAgain() async {
    code.clear();
    setState(() {
      result = null;
      error = null;
    });
    if (widget.enableCamera) {
      await scanner.start();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Staff check-in')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Scan a booking or membership QR code',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'Only confirmed bookings and currently active membership cards can be checked in.'),
            const SizedBox(height: 16),
            if (widget.enableCamera)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                    height: 280,
                    child:
                        MobileScanner(controller: scanner, onDetect: detect)),
              ),
            if (busy)
              const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator()),
            const SizedBox(height: 20),
            TextField(
              controller: code,
              enabled: !busy,
              textCapitalization: TextCapitalization.characters,
              decoration:
                  const InputDecoration(labelText: 'Enter QR code manually'),
              onSubmitted: submit,
            ),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: busy ? null : () => submit(code.text),
                child: const Text('Check in')),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(error!)),
            if (result != null) resultCard(),
          ]),
        ),
      );

  Widget resultCard() {
    final type = result!['type'] as String;
    final member = result!['member'] == null
        ? null
        : Map<String, dynamic>.from(result!['member'] as Map);
    final booking = result!['booking'] == null
        ? null
        : Map<String, dynamic>.from(result!['booking'] as Map);
    final membership = result!['membership'] == null
        ? null
        : Map<String, dynamic>.from(result!['membership'] as Map);
    final duplicate = result!['already_checked_in'] == true;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(duplicate ? 'Already checked in' : 'Check-in complete',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
              '${member?['name'] ?? 'Member'} · ${type == 'booking' ? 'Booking' : 'Membership'}'),
          if (booking != null)
            Text('Booking: ${booking['reference']} · ${booking['starts_at']}'),
          if (membership != null) ...[
            Text(
                'Membership: ${(membership['plan'] as Map?)?['name'] ?? 'Active'}'),
            if (membership['remaining_sessions'] != null)
              Text('Sessions remaining: ${membership['remaining_sessions']}'),
          ],
          const SizedBox(height: 12),
          FilledButton(
              onPressed: scanAgain, child: const Text('Scan another code')),
        ]),
      ),
    );
  }
}
