import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/staff_checkin.dart';

class CheckInApi extends Api {
  String? code;
  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    expect(path, '/check-ins/scan');
    expect(method, 'POST');
    code = data?['qr_code'] as String?;
    return {
      'data': {
        'type': 'membership',
        'member': {'id': 2, 'name': 'Jamie Player'},
        'membership': {
          'remaining_sessions': 6,
          'plan': {'name': 'Gold'}
        },
      }
    };
  }
}

void main() {
  testWidgets('staff can manually check in an active membership card',
      (tester) async {
    final api = CheckInApi();
    await tester.pumpWidget(
        MaterialApp(home: StaffCheckInScreen(api: api, enableCamera: false)));
    await tester.enterText(find.byType(TextField), 'MEMBER-QR');
    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    expect(api.code, 'MEMBER-QR');
    expect(find.text('Check-in complete'), findsOneWidget);
    expect(find.text('Jamie Player · Membership'), findsOneWidget);
    expect(find.text('Sessions remaining: 6'), findsOneWidget);
  });
}
