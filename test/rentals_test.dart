import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/rentals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RentalsApi extends Api {
  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (path == '/rentals') {
      return {
        'data': [
          {
            'id': 24,
            'quantity': 2,
            'due_at': '2026-10-02T09:00:00Z',
            'status': 'issued',
          },
        ],
        'current_page': 1,
        'last_page': 1,
      };
    }
    throw StateError('Unexpected $method $path');
  }
}

void main() {
  testWidgets('player sees only their returned rental records', (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: PlayerRentalsScreen(api: RentalsApi())));
    await tester.pumpAndSettle();

    expect(find.text('My equipment rentals'), findsOneWidget);
    expect(find.text('Rental #24'), findsOneWidget);
    expect(find.textContaining('Quantity: 2'), findsOneWidget);
    expect(find.text('issued'), findsOneWidget);
  });
}
