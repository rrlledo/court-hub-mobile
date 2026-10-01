import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/create_booking.dart';

class BookingApi extends Api {
  Map<String, dynamic>? submitted;
  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (path == '/bookings' && method == 'POST') {
      submitted = data;
      return {
        'data': {
          'reference': 'CH-TEST',
          'status': 'reserved',
          'amount': '500.00',
          'currency': 'PHP',
          'expires_at': DateTime.now()
              .add(const Duration(minutes: 10))
              .toUtc()
              .toIso8601String()
        }
      };
    }
    if (path.endsWith('/availability')) {
      return {
        'data': {'is_closed': false, 'bookings': [], 'maintenance': []}
      };
    }
    return {
      'data': [
        {
          'id': 1,
          'name': path == '/booking-facilities'
              ? 'Sports Center'
              : path.endsWith('/branches')
                  ? 'Main Branch'
                  : 'Court One',
          'status': 'active'
        }
      ]
    };
  }
}

void main() {
  testWidgets(
      'selects a court and creates an unpaid reservation with server pricing',
      (tester) async {
    final api = BookingApi();
    await tester.pumpWidget(MaterialApp(home: CreateBookingScreen(api: api)));
    await tester.pumpAndSettle();
    for (final (index, label) in [
      (0, 'Sports Center'),
      (1, 'Main Branch'),
      (2, 'Court One')
    ]) {
      final dropdown = find.byType(DropdownButtonFormField<int>).at(index);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Starts'));
    await tester.tap(find.text('Starts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Check availability'));
    await tester.tap(find.text('Check availability'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Reserve court'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Reserve court'));
    await tester.pumpAndSettle();
    expect(find.text('Reservation created'), findsOneWidget);
    expect(find.text('Reference: CH-TEST'), findsOneWidget);
    expect(api.submitted?['court_id'], 1);
    expect(api.submitted?.containsKey('amount'), isFalse);
    expect(DateTime.parse(api.submitted!['starts_at'] as String).isUtc, isTrue);
  });
}
