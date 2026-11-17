import 'package:flutter_test/flutter_test.dart';
import 'package:tnp_student/core/updater.dart';

void main() {
  test('version comparison is numeric and ignores v / build suffixes', () {
    int c(String a, String b) => Updater.compareVersions(a, b);
    expect(c('1.1.0', '1.0.0'), greaterThan(0));
    expect(c('v1.10.0', '1.9.9'), greaterThan(0), reason: '10 > 9 numerically, not as text');
    expect(c('1.1.0', 'v1.1.0'), 0);
    expect(c('1.1.0+3', '1.1.0+2'), 0, reason: 'build number is not a newer release');
    expect(c('1.1', '1.1.0'), 0);
    expect(c('2.0.0-beta', '1.9.0'), greaterThan(0));
    expect(c('1.0.9', '1.1.0'), lessThan(0));
  });
}
