import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/api.dart';
import 'core/push.dart';
import 'core/session.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/payment.dart';

final pushRegistrarProvider = Provider<PushRegistrar>((ref) {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
    return NoopPushRegistrar();
  }
  return FirebasePushRegistrar();
});

final sessionProvider = Provider<Session>((ref) {
  final session =
      Session(Api(), SecureTokenStore(), ref.read(pushRegistrarProvider));
  ref.onDispose(session.dispose);
  return session;
});

void main() => runApp(const ProviderScope(child: CourtHubApp()));

class CourtHubApp extends ConsumerStatefulWidget {
  const CourtHubApp({super.key});
  @override
  ConsumerState<CourtHubApp> createState() => _CourtHubAppState();
}

class _CourtHubAppState extends ConsumerState<CourtHubApp> {
  late final Session session;
  late final GoRouter router;
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  PushInteraction? pendingPushInteraction;
  @override
  void initState() {
    super.initState();
    session = ref.read(sessionProvider);
    router = GoRouter(
        refreshListenable: session,
        initialLocation: '/startup',
        redirect: (context, state) {
          if (session.loading || session.restoreError != null) {
            return '/startup';
          }
          if (!session.signedIn) return '/login';
          if (state.matchedLocation == '/startup' ||
              state.matchedLocation == '/login') {
            return '/';
          }
          return null;
        },
        routes: [
          GoRoute(
              path: '/startup',
              builder: (_, __) => Scaffold(
                    body: Center(
                        child: ListenableBuilder(
                      listenable: session,
                      builder: (_, __) => session.restoreError == null
                          ? const CircularProgressIndicator()
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(session.restoreError!,
                                        textAlign: TextAlign.center),
                                    const SizedBox(height: 16),
                                    FilledButton(
                                        onPressed: session.restore,
                                        child: const Text('Retry')),
                                  ])),
                    )),
                  )),
          GoRoute(
              path: '/login',
              builder: (_, __) => LoginScreen(session: session)),
          GoRoute(
              path: '/',
              builder: (_, state) => HomeScreen(
                  session: session,
                  initialTab: state.uri.queryParameters['tab'])),
          GoRoute(
              path: '/bookings/:bookingId/payment',
              builder: (_, state) {
                final bookingId =
                    int.tryParse(state.pathParameters['bookingId'] ?? '');
                return bookingId == null
                    ? HomeScreen(session: session, initialTab: 'bookings')
                    : PaymentScreen(api: session.api, bookingId: bookingId);
              }),
          GoRoute(
              path: '/memberships/:membershipId/payment',
              builder: (_, state) {
                final membershipId =
                    int.tryParse(state.pathParameters['membershipId'] ?? '');
                return membershipId == null
                    ? HomeScreen(session: session, initialTab: 'memberships')
                    : PaymentScreen(
                        api: session.api, membershipId: membershipId);
              }),
        ]);
    ref
        .read(pushRegistrarProvider)
        .setInteractionHandler(handlePushInteraction);
    session.addListener(openPendingPushInteraction);
    session.restore();
  }

  void openPendingPushInteraction() {
    final interaction = pendingPushInteraction;
    if (interaction == null || session.loading || !session.signedIn) return;
    pendingPushInteraction = null;
    openPushDestination(
        interaction, notificationDestination(interaction.type, session.roles));
  }

  void handlePushInteraction(PushInteraction interaction) {
    final destination =
        notificationDestination(interaction.type, session.roles);
    if (!interaction.foreground) {
      if (session.loading || !session.signedIn) {
        pendingPushInteraction = interaction;
        return;
      }
      openPushDestination(interaction, destination);
      return;
    }
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(interaction.message.isEmpty
            ? interaction.title
            : '${interaction.title}: ${interaction.message}'),
        action: SnackBarAction(
            label: 'Open',
            onPressed: () => openPushDestination(interaction, destination))));
  }

  void openPushDestination(PushInteraction interaction, String destination) {
    if (!session.signedIn) return;
    final recordRoute = notificationRecordRoute(interaction, session.roles);
    router.go(recordRoute ?? '/?tab=$destination');
  }

  @override
  void dispose() {
    session.removeListener(openPendingPushInteraction);
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Court Hub',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: scaffoldMessengerKey,
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b50)),
          scaffoldBackgroundColor: const Color(0xfff5f7f3),
          inputDecorationTheme:
              const InputDecorationTheme(border: OutlineInputBorder()),
        ),
      );
}
