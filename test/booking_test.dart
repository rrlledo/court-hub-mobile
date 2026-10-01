import 'package:flutter_test/flutter_test.dart';
import 'package:court_hub_mobile/screens/create_booking.dart';

void main() {
  final now = DateTime(2030, 1, 1, 10);
  test('requires a court and a future positive interval', () {
    expect(bookingValidation(null, now, now, now), isNotNull);
    expect(bookingValidation(1, null, null, now), isNotNull);
    expect(bookingValidation(1, now, now.add(const Duration(hours: 1)), now),
        isNotNull);
    final future = now.add(const Duration(hours: 1));
    expect(bookingValidation(1, future, future, now), isNotNull);
    expect(
        bookingValidation(1, future, future.add(const Duration(hours: 1)), now),
        isNull);
  });
}
