import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/super_admin_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SuperAdminApi extends Api {
  String? patchPath;

  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (method == 'PATCH') {
      patchPath = path;
      return {
        'data': {'id': 2, 'is_active': false}
      };
    }
    if (path == '/super-admin/overview') {
      return {
        'data': {
          'tenants': 2,
          'active_tenants': 2,
          'users': 10,
          'facilities': 3,
          'today_bookings': 5,
          'paid_revenue': '9000.00',
          'active_memberships': 4,
          'simulated_platform_mrr': '2499.00',
        }
      };
    }
    if (path == '/super-admin/tenants') {
      return {
        'data': [
          {
            'id': 2,
            'name': 'Central Sports',
            'slug': 'central-sports',
            'timezone': 'Asia/Manila',
            'is_active': true,
            'users_count': 4,
            'facilities_count': 2,
            'subscription_plan': 'growth',
            'subscription_status': 'active',
            'subscription_amount': '2499.00',
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
  testWidgets('super admin can inspect and suspend a tenant', (tester) async {
    final api = SuperAdminApi();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SuperAdminWorkspaceScreen(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('Super Admin workspace'), findsOneWidget);
    expect(find.text('Central Sports'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(Switch), 300);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();
    expect(api.patchPath, '/super-admin/tenants/2');
  });
}
