import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:csv/csv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('CSV Parsing Tests', () {
    test('CSV list converter parses valid format correctly', () {
      const csvData = 'Name,Email,JobTitle\r\nAlice,alice@company.com,Developer\r\nBob,bob@company.com,Designer';
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvData);

      expect(rows.length, equals(3));
      expect(rows[0], equals(['Name', 'Email', 'JobTitle']));
      expect(rows[1], equals(['Alice', 'alice@company.com', 'Developer']));
      expect(rows[2], equals(['Bob', 'bob@company.com', 'Designer']));
    });

    test('Helper mappings correctly parse headers', () {
      final headers = ['name', 'email', 'job title'];
      int nameIndex = headers.indexOf('name');
      int emailIndex = headers.indexOf('email');
      int jobTitleIndex = headers.indexWhere((h) => h.contains('job') || h == 'title');

      expect(nameIndex, equals(0));
      expect(emailIndex, equals(1));
      expect(jobTitleIndex, equals(2));
    });
  });
}
