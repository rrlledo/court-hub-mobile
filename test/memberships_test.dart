import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/memberships.dart';

class MembershipApi extends Api {
  String? requestedPurchase;
  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (path == '/player/membership-plans') {
      return {
        'data': [
          {
            'id': 1,
            'name': 'Gold',
            'price': '1200.00',
            'currency': 'PHP',
            'duration_days': 30,
            'session_count': 8
          },
        ],
        'current_page': 1,
        'last_page': 1
      };
    }
    if (path == '/player/memberships' && method == 'POST') {
      requestedPurchase = '${data?['membership_plan_id']}';
      return {
        'data': {'id': 7, 'status': 'pending'}
      };
    }
    if (path == '/player/memberships') {
      return {'data': [], 'current_page': 1, 'last_page': 1};
    }
    if (path == '/player/memberships/7/payment-status') {
      return {
        'data': {
          'payment': null,
          'checkout_url': null,
          'membership': {'id': 7, 'status': 'pending'},
        }
      };
    }
    throw StateError('Unexpected $method $path');
  }
}

void main() {
  testWidgets('player can choose a membership plan and start checkout',
      (tester) async {
    final api = MembershipApi();
    await tester.pumpWidget(MaterialApp(home: MembershipsScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('PHP 1200.00 · 30 days'), findsOneWidget);
    await tester.tap(find.text('Buy membership'));
    await tester.pumpAndSettle();
    expect(api.requestedPurchase, '1');
    expect(find.text('Membership payment'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
