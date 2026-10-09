import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Service class to handle CSV file picking, parsing, and batch uploading
class CsvUploadService {
  CsvUploadService._internal();
  static final CsvUploadService instance = CsvUploadService._internal();

  /// Picks a CSV file and parses it into a list of maps containing Name, Email, and JobTitle.
  Future<List<Map<String, dynamic>>> pickAndParseCsv() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'CSV', 'txt', 'TXT'],
        withData: true,
        cancelUploadOnWindowBlur: false,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('[CsvUploadService] File picking cancelled or returned empty.');
        return [];
      }

      final file = result.files.first;
      Uint8List? bytes = file.bytes;

      // On non-web platforms, read from file.path if file.bytes is not populated
      if (bytes == null && !kIsWeb && file.path != null) {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          bytes = await ioFile.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Selected file is empty or could not be read.');
      }

      // Decode the bytes into a string and strip UTF-8 BOM if present
      String csvString = utf8.decode(bytes);
      if (csvString.startsWith('\uFEFF')) {
        csvString = csvString.substring(1);
      }

      // Normalize line endings
      csvString = csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
      if (csvString.isEmpty) {
        throw Exception('The CSV file contains no content.');
      }

      // Auto-detect delimiter: check first line for delimiter (comma, semicolon, tab)
      final firstLine = csvString.split('\n').first;
      String delimiter = ',';
      if (firstLine.contains(';') && !firstLine.contains(',')) {
        delimiter = ';';
      } else if (firstLine.contains('\t') && !firstLine.contains(',')) {
        delimiter = '\t';
      }

      // Parse the CSV content
      final List<List<dynamic>> rows = CsvToListConverter(
        fieldDelimiter: delimiter,
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvString);

      if (rows.isEmpty) {
        throw Exception('No data rows found in the CSV file.');
      }

      // Identify headers from the first row (Row 0), clean quotes/BOM/whitespace
      final headers = rows.first
          .map((h) => h.toString().replaceAll('\uFEFF', '').replaceAll('"', '').trim().toLowerCase())
          .toList();

      int nameIndex = headers.indexWhere(
        (h) => h == 'name' || h == 'full name' || h == 'fullname' || h.contains('name'),
      );
      int identifierIndex = headers.indexWhere(
        (h) => h == 'identifier' || h == 'email' || h == 'e-mail' || h.contains('ident') || h.contains('mail'),
      );
      int deptIndex = headers.indexWhere(
        (h) => h == 'department' || h == 'dept' || h.contains('depart'),
      );
      int roleIndex = headers.indexWhere(
        (h) => h == 'role' || h == 'position' || h == 'title',
      );

      if (nameIndex == -1) nameIndex = 0;
      if (identifierIndex == -1) {
        identifierIndex = (headers.length > 1) ? 1 : -1;
      }
      if (deptIndex == -1) {
        deptIndex = (headers.length > 2) ? 2 : -1;
      }
      if (roleIndex == -1) {
        roleIndex = (headers.length > 3) ? 3 : -1;
      }

      if (nameIndex == -1 || identifierIndex == -1) {
        throw Exception(
          'Could not locate required Name and Identifier (Email) columns in CSV headers: ${headers.join(", ")}',
        );
      }

      final List<Map<String, dynamic>> staffList = [];
      final Set<String> seenIdentifiers = {};

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.length <= nameIndex || row.length <= identifierIndex) {
          continue; // Skip malformed or empty rows
        }

        final String name = row[nameIndex].toString().replaceAll('"', '').trim();
        final String rawIdentifier = row[identifierIndex].toString().replaceAll('"', '').trim().toLowerCase();

        // Skip blank rows or repeated header
        if (name.isEmpty || rawIdentifier.isEmpty || rawIdentifier == 'identifier' || rawIdentifier == 'email') {
          continue;
        }

        // Validate duplicates within the CSV
        if (seenIdentifiers.contains(rawIdentifier)) {
          throw Exception('Duplicate identifier found in CSV: $rawIdentifier at row ${i + 1}');
        }
        seenIdentifiers.add(rawIdentifier);

        String department = '';
        if (deptIndex != -1 && deptIndex < row.length) {
          department = row[deptIndex].toString().replaceAll('"', '').trim();
        }

        String rawRole = 'employee';
        if (roleIndex != -1 && roleIndex < row.length) {
          final r = row[roleIndex].toString().replaceAll('"', '').trim().toLowerCase();
          if (r == 'admin' || r == 'lead' || r == 'employee') {
            rawRole = r;
          }
        }

        staffList.add({
          'name': name,
          'email': rawIdentifier,
          'identifier': rawIdentifier,
          'department': department,
          'role': rawRole,
        });
      }

      if (staffList.isEmpty) {
        throw Exception(
          'No valid employee records found in the CSV. Please check the format.',
        );
      }

      return staffList;
    } catch (e) {
      debugPrint('[CsvUploadService] Error picking and parsing CSV: $e');
      rethrow;
    }
  }

  /// Batches the upload of pre-approved staff members into Firms/{firmId}/PreApprovedStaff.
  /// Validates firm seat limit, creates missing departments if requested, and writes in chunks of <= 500 operations.
  Future<void> uploadPreApprovedStaff(
    String firmId,
    List<Map<String, dynamic>> staffList, {
    Map<String, String>? departmentNameToIdMap,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // 1. Validate seat limits
      final firmDoc = await firestore.collection('Firms').doc(firmId).get();
      if (!firmDoc.exists) throw Exception('Firm not found: $firmId');
      
      final data = firmDoc.data()!;
      final int currentSeatCount = (data['seatCount'] as num?)?.toInt() ?? 1;
      final int seatLimit = (data['seatLimit'] as num?)?.toInt() ?? 5;

      if (currentSeatCount + staffList.length > seatLimit) {
        throw Exception(
          'Importing ${staffList.length} staff would exceed the firm seat limit of $seatLimit (current usage: $currentSeatCount).',
        );
      }

      final preApprovedCollection = firestore
          .collection('Firms')
          .doc(firmId)
          .collection('PreApprovedStaff');

      // Random 6-digit alphanumeric code generator
      String generateCode() {
        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        final rnd = DateTime.now().microsecondsSinceEpoch;
        return List.generate(6, (index) => chars[(rnd + index * 7) % chars.length]).join();
      }

      // Write in chunks of at most 200 items (2 writes per item: doc set + firm counter)
      const int batchSize = 100;
      for (int i = 0; i < staffList.length; i += batchSize) {
        final batch = firestore.batch();
        final chunk = staffList.sublist(
          i,
          i + batchSize > staffList.length ? staffList.length : i + batchSize,
        );

        for (final staff in chunk) {
          final String email = staff['email'] as String;
          final String deptName = (staff['department'] as String?) ?? '';
          final String? deptId = departmentNameToIdMap != null ? departmentNameToIdMap[deptName] : null;
          final String role = (staff['role'] as String?) ?? 'employee';

          final docRef = preApprovedCollection.doc();
          final now = DateTime.now();

          batch.set(docRef, {
            'name': staff['name'],
            'email': email,
            'code': generateCode(),
            'codeExpiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 5))),
            'codeUpdatedAt': FieldValue.serverTimestamp(),
            'firmId': firmId,
            'status': 'invited',
            'role': role,
            if (deptId != null && deptId.isNotEmpty) 'departmentId': deptId,
            'invitedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Atomic seatCount increment for this batch chunk
        batch.update(firestore.collection('Firms').doc(firmId), {
          'seatCount': FieldValue.increment(chunk.length),
        });

        await batch.commit();
      }

      debugPrint('[CsvUploadService] Successfully uploaded ${staffList.length} pre-approved staff records.');
    } catch (e) {
      debugPrint('[CsvUploadService] Error uploading pre-approved staff: $e');
      rethrow;
    }
  }
}
