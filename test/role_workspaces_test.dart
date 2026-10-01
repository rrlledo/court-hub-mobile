import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:court_hub_mobile/core/api.dart';
import 'package:court_hub_mobile/screens/coach_workspace.dart';
import 'package:court_hub_mobile/screens/organizer_workspace.dart';
import 'package:court_hub_mobile/screens/tournament_management.dart';

class CoachApi extends Api {
  String? action;
  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (method == 'POST') {
      action = path;
      return {
        'data': {'id': 7, 'status': 'completed'}
      };
    }
    return {
      'data': {
        'profile': {'id': 1, 'name': 'Coach Casey', 'hourly_rate': '900.00'},
        'availability': [],
        'sessions': [
          {
            'id': 7,
            'status': 'scheduled',
            'starts_at':
                DateTime.now().add(const Duration(days: 1)).toIso8601String(),
            'amount': '900.00',
            'player': {'name': 'Jamie'}
          }
        ],
      }
    };
  }
}

class OrganizerApi extends Api {
  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (path == '/organizer/tournaments') {
      return {
        'data': [
          {
            'id': 2,
            'name': 'Autumn Open',
            'format': 'singles',
            'status': 'draft',
            'starts_at':
                DateTime.now().add(const Duration(days: 2)).toIso8601String()
          }
        ],
        'current_page': 1,
        'last_page': 1
      };
    }
    if (path == '/booking-facilities') {
      return {'data': [], 'current_page': 1, 'last_page': 1};
    }
    throw StateError('Unexpected $method $path');
  }
}

class OrganizerManagementApi extends Api {
  String? registrationPath;

  @override
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (path == '/organizer/tournaments/2') {
      return {
        'data': {
          'id': 2,
          'name': 'Autumn Open',
          'branch_id': 5,
          'registrations': [],
          'matches': []
        }
      };
    }
    if (path == '/organizer/players') {
      return {
        'data': [
          {'id': 8, 'name': 'Rina Player', 'email': 'rina@example.com'}
        ]
      };
    }
    if (path == '/branches/5/courts') {
      return {
        'data': [
          {'id': 4, 'name': 'Court A'}
        ],
        'current_page': 1,
        'last_page': 1
      };
    }
    if (path == '/organizer/tournaments/2/registrations' && method == 'POST') {
      registrationPath = path;
      expect(data?['user_id'], 8);
      return {
        'data': {'id': 11, 'status': 'registered'}
      };
    }
    throw StateError('Unexpected $method $path');
  }
}

void main() {
  testWidgets('coach can complete an assigned session', (tester) async {
    final api = CoachApi();
    await tester.pumpWidget(MaterialApp(home: CoachWorkspaceScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Coach Casey · PHP 900.00/hour'), findsOneWidget);
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(api.action, '/coach/sessions/7/complete');
  });

  testWidgets('organizer sees tournament workspace', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: OrganizerWorkspaceScreen(api: OrganizerApi()))));
    await tester.pumpAndSettle();
    expect(find.text('Event organizer workspace'), findsOneWidget);
    expect(find.text('Autumn Open'), findsOneWidget);
  });

  testWidgets('organizer can register a player from tournament management',
      (tester) async {
    final api = OrganizerManagementApi();
    await tester.pumpWidget(MaterialApp(
        home: TournamentManagementScreen(
            api: api, tournament: const {'id': 2, 'name': 'Autumn Open'})));
    await tester.pumpAndSettle();
    expect(find.text('Tournament management'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rina Player · rina@example.com').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Register player'));
    await tester.tap(find.text('Register player'));
    await tester.pumpAndSettle();
    expect(api.registrationPath, '/organizer/tournaments/2/registrations');
  });
}
