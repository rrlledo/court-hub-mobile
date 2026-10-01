import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/payment.dart';

class PaymentApi extends Api {
  String status = 'pending';
  Map<String, dynamic>? submitted;
  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (method == 'POST') {
      expect(path, '/payments/intents');
      submitted = data;
    } else {
      expect(path, '/bookings/1/payment-status');
    }
    return {
      'data': {
        'payment': submitted == null
            ? null
            : {
                'status': status,
                'amount': '500.00',
                'currency': 'PHP',
                'reference': 'PAY-1',
                'invoice_number': 'INV-1'
              },
        'checkout_url':
            submitted == null ? null : 'https://checkout.paymongo.com/cs_test',
        'booking': {
          'status': status == 'paid' ? 'confirmed' : 'reserved',
          'expires_at':
              DateTime.now().add(const Duration(minutes: 10)).toIso8601String()
        }
      }
    };
  }
}

class MockXenditPaymentApi extends Api {
  bool completed = false;
  String? submittedProvider;

  Map<String, dynamic> response({bool payment = false}) => {
        'data': {
          'payment': payment
              ? {
                  'id': 9,
                  'status': completed ? 'paid' : 'pending',
                  'amount': '500.00',
                  'currency': 'PHP',
                  'reference': 'PAY-9',
                  'invoice_number': 'INV-9'
                }
              : null,
          'checkout_url':
              payment ? 'https://checkout.xendit.test/invoices/PAY-9' : null,
          'booking': {
            'status': completed ? 'confirmed' : 'reserved',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toIso8601String(),
          }
        }
      };

  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (path == '/payments/providers') {
      return {
        'data': [
          {'name': 'xendit', 'configured': true, 'mock': true}
        ]
      };
    }
    if (path == '/bookings/1/payment-status') {
      return response(payment: completed);
    }
    if (path == '/payments/intents' && method == 'POST') {
      submittedProvider = '${data?['provider']}';
      return response(payment: true);
    }
    if (path == '/payments/mock/xendit/9/complete' && method == 'POST') {
      completed = true;
      return response(payment: true);
    }
    throw StateError('Unexpected $method $path');
  }
}

void main() {
  testWidgets('opening checkout does not confirm payment; server status does',
      (tester) async {
    final api = PaymentApi();
    Uri? opened;
    await tester.pumpWidget(MaterialApp(
        home: PaymentScreen(
            api: api,
            bookingId: 1,
            openCheckout: (url) async {
              opened = url;
              return true;
            })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();
    expect(opened?.host, 'checkout.paymongo.com');
    expect(api.submitted?.containsKey('amount'), isFalse);
    expect(find.text('Payment received — booking confirmed'), findsNothing);
    api.status = 'paid';
    await tester.ensureVisible(find.text('Check payment status'));
    await tester.tap(find.text('Check payment status'));
    await tester.pumpAndSettle();
    expect(find.text('Payment received — booking confirmed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mock Xendit payment completes without opening a browser',
      (tester) async {
    final api = MockXenditPaymentApi();
    await tester
        .pumpWidget(MaterialApp(home: PaymentScreen(api: api, bookingId: 1)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Complete simulated payment'));
    await tester.pumpAndSettle();

    expect(api.submittedProvider, 'xendit');
    expect(api.completed, isTrue);
    expect(find.text('Payment received — booking confirmed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
