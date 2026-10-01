import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/home.dart';

void main() {
  testWidgets(
      'keep booking sends no request; confirmation cancels and updates history',
      (tester) async {
    final api = CancellationApi();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RecordList(
                api: api, path: '/bookings/history', notifications: false))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep booking'));
    await tester.pumpAndSettle();
    expect(api.cancellations, 0);
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel booking'));
    await tester.pumpAndSettle();
    expect(api.cancellations, 1);
    expect(find.text('cancelled'), findsOneWidget);
    expect(find.text('Cancel booking'), findsNothing);
  });
  test('cancellation is available only for upcoming active reservations', () {
    final now = DateTime.utc(2030);
    final row = <String, dynamic>{
      'status': 'reserved',
      'starts_at': now.add(const Duration(days: 1)).toIso8601String(),
      'expires_at': now.add(const Duration(minutes: 10)).toIso8601String()
    };
    expect(canCancelBooking(row, now), isTrue);
    expect(
        canCancelBooking(row, now.add(const Duration(minutes: 11))), isFalse);
    row['status'] = 'confirmed';
    expect(canCancelBooking(row, now), isTrue);
    expect(canCancelBooking(row, now.add(const Duration(days: 2))), isFalse);
    row['status'] = 'cancelled';
    expect(canCancelBooking(row, now), isFalse);
  });
}

class CancellationApi extends Api {
  int cancellations = 0;
  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (method == 'POST') {
      expect(path, '/bookings/1/cancel');
      cancellations++;
      return {
        'data': {'status': 'cancelled'}
      };
    }
    return {
      'data': [
        {
          'id': 1,
          'reference': 'CH-1',
          'status': 'confirmed',
          'starts_at':
              DateTime.now().add(const Duration(days: 1)).toIso8601String()
        }
      ]
    };
  }
}
