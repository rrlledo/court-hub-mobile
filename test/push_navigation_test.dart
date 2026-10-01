import 'package:court_hub_mobile/core/push.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification type maps to the appropriate available workspace', () {
    expect(
        notificationDestination('booking_confirmed', ['player']), 'bookings');
    expect(notificationDestination('membership_active', ['player']),
        'memberships');
    expect(notificationDestination('coaching_session', ['coach']), 'coaching');
    expect(notificationDestination('tournament_open', ['event-organizer']),
        'events');
    expect(notificationDestination('facility_update', ['facility-manager']),
        'operations');
    expect(
        notificationDestination('membership_active', ['front-desk']), 'inbox');
  });

  test('payment notification opens the referenced player record', () {
    const booking = PushInteraction(
        type: 'payment',
        title: 'Booking confirmed',
        message: '',
        foreground: false,
        data: {'payment_id': '17', 'booking_id': '9'});
    const membership = PushInteraction(
        type: 'payment',
        title: 'Membership active',
        message: '',
        foreground: false,
        data: {'payment_id': '18', 'membership_id': '12'});

    expect(notificationRecordRoute(booking, ['player']), '/bookings/9/payment');
    expect(notificationRecordRoute(membership, ['player']),
        '/memberships/12/payment');
    expect(notificationRecordRoute(booking, ['front-desk']), isNull);
  });
}
