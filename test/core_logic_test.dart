import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tnp_student/core/api_client.dart';
import 'package:tnp_student/core/config.dart';
import 'package:tnp_student/core/utils.dart';
import 'package:tnp_student/data/models.dart';

void main() {
  group('ApiException parses Strapi v3 errors', () {
    test('nested messages array', () {
      final msg = ApiException.messageFromBody({
        'statusCode': 400,
        'error': 'Bad Request',
        'message': [
          {
            'messages': [
              {'id': 'Auth.form.error.invalid', 'message': 'Identifier or password invalid.'},
            ],
          },
        ],
      });
      expect(msg, 'Identifier or password invalid.');
    });

    test('id-only messages (real api.tnpnsut.in response)', () {
      final msg = ApiException.messageFromBody({
        'statusCode': 400,
        'error': 'Bad Request',
        'message': [
          {
            'messages': [
              {'id': 'No authorization header was found'},
            ],
          },
        ],
      });
      expect(msg, 'No authorization header was found');
    });

    test('plain message string and nested error object', () {
      expect(ApiException.messageFromBody({'message': 'Captcha mismatch'}), 'Captcha mismatch');
      expect(ApiException.messageFromBody({'error': {'message': 'Upload failed'}}), 'Upload failed');
      expect(ApiException.messageFromBody('<html>nginx</html>'), isNull);
    });

    test('DioException without body maps to friendly text', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      expect(ApiException.from(e).message, contains('internet'));
    });

    test('401 is flagged unauthorized', () {
      final req = RequestOptions(path: '/users/me');
      final e = DioException(
        requestOptions: req,
        response: Response(requestOptions: req, statusCode: 401),
        type: DioExceptionType.badResponse,
      );
      expect(ApiException.from(e).isUnauthorized, isTrue);
    });
  });

  group('Rich content', () {
    test('Quill delta → HTML with lists and marks', () {
      const delta = '[{"insert":"Hello "},{"insert":"world","attributes":{"bold":true}},{"insert":"\\n"},'
          '{"insert":"one"},{"insert":"\\n","attributes":{"list":"bullet"}},'
          '{"insert":"two"},{"insert":"\\n","attributes":{"list":"bullet"}}]';
      final html = RichText2Html.toHtml(delta);
      expect(html, '<p>Hello <b>world</b></p><ul><li>one</li><li>two</li></ul>');
    });

    test('plain text is escaped and keeps line breaks', () {
      expect(RichText2Html.toHtml('a < b\nc'), 'a &lt; b<br/>c');
    });

    test('HTML passes through; plain preview strips tags', () {
      const html = '<p>Apply by <b>Friday</b>&nbsp;now</p>';
      expect(RichText2Html.toHtml(html), html);
      expect(RichText2Html.toPlain(html), 'Apply by Friday now');
    });
  });

  group('Models', () {
    test('placement batch follows web rule', () {
      expect(Student({'batch': '2026'}).placementBatch, '2027');
      expect(Student({'batch': '2026', 'allowed_in_next_season': false}).placementBatch, '2026');
    });

    test('eligibility uses JS truthiness (truthy flag = failed)', () {
      final el = Eligibility({
        'eligible': {
          'status': true,
          'conditions': {'cgpa': false, 'batch': 0, 'branch': 'x', 'already_applied': true},
        },
      });
      expect(el.eligible, isTrue);
      expect(el.passes('cgpa'), isTrue);
      expect(el.passes('batch'), isTrue);
      expect(el.passes('branch'), isFalse);
      expect(el.alreadyApplied, isTrue);
      expect(Eligibility({}).passes('cgpa'), isFalse, reason: 'no conditions → shown as failed, like the web');
    });

    test('company event groups branches and computes status', () {
      final e = CompanyEvent({
        '_id': 'abc',
        'company': {'Name': 'Acme'},
        'status': 'Open',
        'lastDate': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'branchesAllowed': [
          {'degree': 'BTech', 'branch': 'CSE'},
          {'degree': 'BTech', 'branch': 'IT'},
          {'degree': 'MTech', 'branch': 'PCS'},
        ],
      });
      expect(e.id, 'abc');
      expect(e.companyName, 'Acme');
      expect(e.registrationClosed, isTrue);
      expect(e.displayStatus, 'Ended');
      expect(e.branchesAllowed, {
        'BTech': ['CSE', 'IT'],
        'MTech': ['PCS'],
      });
    });

    test('last semester detection hides drop option', () {
      expect(Student({'degree': 'MTech', 'sem4_gpa': 8.1}).lastSemGpaAvailable, isTrue);
      expect(Student({'degree': 'MTech', 'sem3_gpa': 8.1}).lastSemGpaAvailable, isFalse);
    });
  });

  group('Catalog', () {
    test('course type for drop rules', () {
      final now = DateTime.now();
      final academicYear = now.month >= 6 ? now.year : now.year - 1;
      expect(Catalog.courseTypeFor('BTech', '${academicYear + 1}'), 'BTech(Final year)');
      expect(Catalog.courseTypeFor('BTech', '${academicYear + 2}'), 'BTech(Pre-Final Year)');
      expect(Catalog.courseTypeFor('MBA', '2030'), 'MBA');
      expect(Catalog.dropRules['BTech(Final year)']!.maxSubjects, 2);
    });
  });

  test('helpers', () {
    expect(initials('Netaji Subhas University'), 'NS');
    expect(displayNum(-1), '—');
    expect(displayNum('8.5'), '8.5');
    expect(Fmt.fileSizeKb(2048), '2.00 MB');
  });
}
