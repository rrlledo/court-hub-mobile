import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/staff_rentals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class StaffRentalsApi extends Api {
  Map<String, dynamic>? issued;

  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (path == '/inventory-items') {
      return {
        'data': [
          {'id': 2, 'name': 'Paddle', 'quantity_available': 4}
        ],
        'current_page': 1,
        'last_page': 1,
      };
    }
    if (path == '/rental-users') {
      return {
        'data': [
          {'id': 3, 'name': 'Rina Player', 'email': 'rina@example.com'}
        ]
      };
    }
    if (path == '/rentals') {
      if (method == 'POST') {
        issued = data;
        return {
          'data': {'id': 4}
        };
      }
      return {
        'data': [
          {
            'id': 4,
            'quantity': 1,
            'due_at': '2026-10-02T09:00:00Z',
            'status': 'active',
            'inventory_item': {'name': 'Paddle'},
            'user': {'name': 'Rina Player'},
          }
        ],
        'current_page': 1,
        'last_page': 1,
      };
    }
    throw StateError('Unexpected $method $path');
  }
}

void main() {
  testWidgets('staff can select a player and issue equipment', (tester) async {
    final api = StaffRentalsApi();
    await tester.pumpWidget(MaterialApp(home: StaffRentalsScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Equipment rentals'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rina Player · rina@example.com').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paddle · 4 available').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue equipment').last);
    await tester.pumpAndSettle();

    expect(api.issued?['user_id'], 3);
    expect(api.issued?['inventory_item_id'], 2);
  });
}
