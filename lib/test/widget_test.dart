import 'package:flutter_test/flutter_test.dart';
import 'package:flixgo/utils.dart';

void main() {
  test('fmtBytes formats sizes', () {
    expect(fmtBytes(0), isNotEmpty);
    expect(fmtBytes(1024 * 1024), isNotEmpty);
  });
}
