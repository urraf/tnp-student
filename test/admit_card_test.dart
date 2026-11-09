import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tnp_student/data/models.dart';
import 'package:tnp_student/ui/screens/profile/admit_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hall card PDF is generated with the web QR payload', () async {
    final s = Student({
      'id': 's1',
      'Name': 'Aarav Sharma',
      'rollNumber': '2022UCS1234',
      'email': 'aarav@nsut.ac.in',
      'branch': 'CSE',
      'degree': 'BTech',
      'batch': '2026',
    });
    expect(admitQrData(s), '{"student_name":"Aarav Sharma","student_roll":"2022UCS1234","student_email":"aarav@nsut.ac.in","studentID":"s1"}');
    final bytes = await buildAdmitCardPdf(s);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final out = Platform.environment['PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });
}
