import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/create_booking.dart';

class RescheduleApi extends Api {
  Map<String, dynamic>? submitted;
  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (method == 'PATCH') {
      expect(path, '/bookings/7/reschedule');
      submitted = data;
      return {
        'data': {'id': 7, ...data!}
      };
    }
    expect(path, '/courts/2/availability');
    return {
      'data': {'is_closed': false, 'bookings': []}
    };
  }
}

void main() {
  testWidgets(
      'rescheduling requires confirmation and sends existing booking to PATCH',
      (tester) async {
    final api = RescheduleApi();
    final start = DateTime.now().add(const Duration(days: 1));
    Map<String, dynamic>? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  CreateBookingScreen(api: api, booking: {
                                    'id': 7,
                                    'court_id': 2,
                                    'reference': 'CH-7',
                                    'starts_at':
                                        start.toUtc().toIso8601String(),
                                    'ends_at': start
                                        .add(const Duration(hours: 1))
                                        .toUtc()
                                        .toIso8601String(),
                                  })));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    await tester.ensureVisible(find.text('Check availability'));
    await tester.tap(find.text('Check availability'));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Reschedule booking');
    await tester.scrollUntilVisible(button, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep current time'));
    await tester.pumpAndSettle();
    expect(api.submitted, isNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(api.submitted!['starts_at'], start.toUtc().toIso8601String());
    expect(result!['id'], 7);
    expect(find.text('Open'), findsOneWidget);
  });
}
