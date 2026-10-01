import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/operations_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class OperationsApi extends Api {
  String? action;

  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (method == 'POST') {
      action = path;
      return {
        'data': {'id': 9, 'status': 'confirmed'}
      };
    }
    if (path == '/facilities') {
      return {
        'data': [
          {
            'id': 1,
            'name': 'Central Courts',
            'registration_open': true,
            'branches': [
              {
                'id': 2,
                'name': 'Main',
                'courts': [
                  {
                    'id': 3,
                    'name': 'Court A',
                    'sport': 'pickleball',
                    'base_price': '500.00',
                    'status': 'active'
                  }
                ]
              }
            ]
          }
        ],
        'current_page': 1,
        'last_page': 1
      };
    }
    if (path == '/organizations') {
      return {
        'data': [
          {'id': 8, 'name': 'Court Hub Sports'}
        ],
        'current_page': 1,
        'last_page': 1
      };
    }
    if (path == '/users') {
      return {
        'data': [
          {
            'id': 4,
            'name': 'Front Desk Fran',
            'email': 'fran@example.test',
            'roles': [
              {'name': 'front-desk'}
            ]
          }
        ],
        'current_page': 1,
        'last_page': 1
      };
    }
    if (path == '/bookings') {
      return {
        'data': [
          {
            'id': 9,
            'reference': 'CH-TEST',
            'starts_at': DateTime.now().toIso8601String(),
            'status': 'reserved',
            'amount': '500.00'
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
  testWidgets('operator can see facilities and confirm a reservation',
      (tester) async {
    final api = OperationsApi();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OperationsWorkspaceScreen(api: api, canManageRoles: true))));
    await tester.pumpAndSettle();
    expect(find.text('Operations workspace'), findsOneWidget);
    expect(find.text('Central Courts'), findsOneWidget);
    expect(find.text('Court A · pickleball'), findsOneWidget);
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();
    expect(api.action, '/bookings/9/confirm');
  });
}
