import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

abstract interface class PushRegistrar {
  Future<void> register(Api api);
  Future<void> unregister(Api api);
  void setInteractionHandler(
      void Function(PushInteraction interaction)? handler);
  void dispose();
}

class PushInteraction {
  const PushInteraction(
      {required this.type,
      required this.title,
      required this.message,
      required this.foreground,
      this.data = const {}});

  final String type;
  final String title;
  final String message;
  final bool foreground;
  final Map<String, String> data;

  int? recordId(String key) {
    final value = int.tryParse(data[key] ?? '');
    return value != null && value > 0 ? value : null;
  }

  factory PushInteraction.fromRemoteMessage(RemoteMessage remoteMessage,
      {required bool foreground}) {
    return PushInteraction(
      type: '${remoteMessage.data['type'] ?? 'system'}',
      title: remoteMessage.notification?.title ?? 'Court Hub update',
      message: remoteMessage.notification?.body ?? '',
      foreground: foreground,
      data: remoteMessage.data.map((key, value) => MapEntry(key, '$value')),
    );
  }
}

String notificationDestination(String type, List<String> roles) {
  if (type.startsWith('booking')) return 'bookings';
  if (type.startsWith('membership') && roles.contains('player')) {
    return 'memberships';
  }
  if (type.startsWith('coaching') && roles.contains('coach')) {
    return 'coaching';
  }
  if (type.startsWith('tournament') && roles.contains('event-organizer')) {
    return 'events';
  }
  if ((type.startsWith('facility') || type.startsWith('court')) &&
      roles.any((role) => ['court-owner', 'facility-manager'].contains(role))) {
    return 'operations';
  }
  return 'inbox';
}

String? notificationRecordRoute(
    PushInteraction interaction, List<String> roles) {
  if (!roles.contains('player')) return null;

  final bookingId = interaction.recordId('booking_id');
  if (bookingId != null) return '/bookings/$bookingId/payment';

  final membershipId = interaction.recordId('membership_id');
  if (membershipId != null) return '/memberships/$membershipId/payment';

  return null;
}

class NoopPushRegistrar implements PushRegistrar {
  @override
  void dispose() {}

  @override
  Future<void> register(Api api) async {}

  @override
  Future<void> unregister(Api api) async {}

  @override
  void setInteractionHandler(
      void Function(PushInteraction interaction)? handler) {}
}

class FirebasePushRegistrar implements PushRegistrar {
  FirebasePushRegistrar({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foregroundMessages;
  StreamSubscription<RemoteMessage>? _openedMessages;
  Api? _api;
  void Function(PushInteraction interaction)? _interactionHandler;
  bool _initialMessageHandled = false;

  @override
  Future<void> register(Api api) async {
    _api = api;
    await Firebase.initializeApp();
    await _configureInteractions();
    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: true,
      );
    }
    final token = await _messaging.getToken();
    if (token != null) await _sendToken(api, token);
    _tokenRefresh ??= _messaging.onTokenRefresh.listen((token) {
      final currentApi = _api;
      if (currentApi != null) {
        unawaited(_sendToken(currentApi, token).catchError((_) {}));
      }
    });
  }

  @override
  Future<void> unregister(Api api) async {
    try {
      await Firebase.initializeApp();
      final token = await _messaging.getToken();
      if (token != null) {
        await api.request('/push/devices', method: 'DELETE', data: {
          'token': token,
        });
      }
      await _messaging.deleteToken();
    } finally {
      _api = null;
      await _tokenRefresh?.cancel();
      await _foregroundMessages?.cancel();
      await _openedMessages?.cancel();
      _tokenRefresh = null;
      _foregroundMessages = null;
      _openedMessages = null;
    }
  }

  Future<void> _sendToken(Api api, String token) => api.request(
        '/push/devices',
        method: 'POST',
        data: {
          'token': token,
          'platform':
              defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'device_name': 'Court Hub Mobile',
        },
      );

  Future<void> _configureInteractions() async {
    _foregroundMessages ??= FirebaseMessaging.onMessage.listen((message) =>
        _interactionHandler?.call(
            PushInteraction.fromRemoteMessage(message, foreground: true)));
    _openedMessages ??= FirebaseMessaging.onMessageOpenedApp.listen((message) =>
        _interactionHandler?.call(
            PushInteraction.fromRemoteMessage(message, foreground: false)));
    if (_initialMessageHandled) return;
    _initialMessageHandled = true;
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _interactionHandler?.call(
          PushInteraction.fromRemoteMessage(initialMessage, foreground: false));
    }
  }

  @override
  void setInteractionHandler(
      void Function(PushInteraction interaction)? handler) {
    _interactionHandler = handler;
  }

  @override
  void dispose() {
    _api = null;
    unawaited(_tokenRefresh?.cancel() ?? Future<void>.value());
    unawaited(_foregroundMessages?.cancel() ?? Future<void>.value());
    unawaited(_openedMessages?.cancel() ?? Future<void>.value());
    _tokenRefresh = null;
    _foregroundMessages = null;
    _openedMessages = null;
    _interactionHandler = null;
  }
}
