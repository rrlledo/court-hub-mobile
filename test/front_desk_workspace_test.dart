import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/front_desk_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FrontDeskApi extends Api {
  String? action;

  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (method == 'POST') {
      action = path;
      return {
        'data': {'id': 7, 'status': 'confirmed'}
      };
    }
    if (path == '/booking-facilities') {
      return {
        'data': [
          {'id': 1, 'name': 'Central Courts'}
        ],
        'current_page': 1,
        'last_page': 1
      };
    }
    if (path == '/bookings') {
      return {
        'data': [
          {
            'id': 7,
            'reference': 'CH-WALKIN',
            'starts_at':
                DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
            'amount': '500.00',
            'status': 'reserved'
          }
        ],
        'current_page': 1,
        'last_page': 1
      };
    }
    throw StateError('Unexpected $method $path');
  }
}

void main() {
  testWidgets('front desk can confirm today’s reservation', (tester) async {
    final api = FrontDeskApi();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: FrontDeskWorkspaceScreen(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('Front Desk workspace'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('CH-WALKIN'), 300);
    expect(find.text('CH-WALKIN'), findsOneWidget);
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();
    expect(api.action, '/bookings/7/confirm');
  });
}
