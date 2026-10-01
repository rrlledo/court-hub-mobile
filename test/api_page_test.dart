import 'package:flutter_test/flutter_test.dart';
import 'package:court_hub_mobile/core/api.dart';

void main() {
  test('parses resource collection pagination', () {
    final page = ApiPage.parse({
      'data': [
        {'id': 1}
      ],
      'meta': {'current_page': 1, 'last_page': 2}
    });
    expect(page.items.single['id'], 1);
    expect(page.hasMore, isTrue);
  });
  test('parses nested Laravel paginator', () {
    final page = ApiPage.parse({
      'data': {'data': [], 'current_page': 2, 'last_page': 2}
    });
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });
  test('parses plain paginator', () {
    expect(ApiPage.parse({'data': [], 'next_page_url': null}).hasMore, isFalse);
  });
}
