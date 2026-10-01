import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/reports_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ReportsApi extends Api {
  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    final values = {
      '/reports/dashboard': {
        'bookings': 12,
        'confirmed_bookings': 10,
        'booking_revenue': '5000.00',
        'active_memberships': 4,
        'active_rentals': 2,
      },
      '/reports/revenue': {'total': '5000.00', 'by_day': []},
      '/reports/occupancy': {
        'occupancy_percent': 25,
        'booked_minutes': 300,
        'booking_count': 10,
      },
      '/reports/peak-hours': [],
      '/reports/court-utilization': [],
      '/reports/membership-sales': {'sales_count': 2, 'by_plan': []},
      '/reports/coach-revenue': {'total': '700.00', 'by_coach': []},
      '/reports/tournament-revenue': {
        'total_estimated_revenue': '1000.00',
        'tournaments': []
      },
      '/reports/rental-revenue': {
        'rental_count': 2,
        'rental_revenue': '300.00',
        'damage_fees': '0.00',
        'total': '300.00',
      },
      '/reports/refunds': {
        'booking_refunds': {'amount': '50.00'},
        'payment_refunds': {'amount': '0.00'},
        'total_amount': '50.00',
      },
    };
    return {'data': values[path]};
  }
}

void main() {
  testWidgets('owner can review the reporting dashboard', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: ReportsDashboardScreen(api: ReportsApi())));
    await tester.pumpAndSettle();
    expect(find.text('Operations summary'), findsOneWidget);
    expect(find.text('Paid revenue: PHP 5000.00'), findsOneWidget);
    expect(find.text('25% occupied'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Refunds'), 300);
    expect(find.text('Refunds'), findsOneWidget);
  });
}
