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
      int emailIndex = headers.indexWhere(
        (h) => h == 'email' || h == 'e-mail' || h.contains('email') || h.contains('mail'),
      );
      int jobTitleIndex = headers.indexWhere(
        (h) => h.contains('job') || h.contains('title') || h == 'role' || h == 'position',
      );

      if (nameIndex == -1) {
        nameIndex = 0;
      }
      if (emailIndex == -1) {
        emailIndex = 1 < headers.length ? 1 : -1;
      }
      if (jobTitleIndex == -1) {
        jobTitleIndex = 2 < headers.length ? 2 : -1;
      }

      if (nameIndex == -1 || emailIndex == -1) {
        throw Exception(
          'Could not locate required Name and Email columns in headers: ${headers.join(", ")}',
        );
      }

      final List<Map<String, dynamic>> staffList = [];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.length <= nameIndex || row.length <= emailIndex) {
          continue; // Skip malformed or empty rows
        }

        final String name = row[nameIndex].toString().replaceAll('"', '').trim();
        final String email = row[emailIndex].toString().replaceAll('"', '').trim().toLowerCase();

        // Skip blank rows or repeated header
        if (name.isEmpty || email.isEmpty || email == 'email') {
          continue;
        }

        String jobTitle = '';
        if (jobTitleIndex != -1 && jobTitleIndex < row.length) {
          jobTitle = row[jobTitleIndex].toString().replaceAll('"', '').trim();
        }

        staffList.add({
          'name': name,
          'email': email,
          'jobTitle': jobTitle,
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

  /// Batches the upload of pre-approved staff members into the Firms/{firmId}/PreApprovedStaff subcollection.
  Future<void> uploadPreApprovedStaff(String firmId, List<Map<String, dynamic>> staffList) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final preApprovedCollection = firestore
          .collection('Firms')
          .doc(firmId)
          .collection('PreApprovedStaff');

      // Write in chunks of 500 (Firestore WriteBatch limit)
      const int batchSize = 500;
      for (int i = 0; i < staffList.length; i += batchSize) {
        final batch = firestore.batch();
        final chunk = staffList.sublist(
          i,
          i + batchSize > staffList.length ? staffList.length : i + batchSize,
        );

        for (final staff in chunk) {
          final String email = staff['email'] as String;
          // Document ID is the lowercased email for instant O(1) lookups
          final docRef = preApprovedCollection.doc(email);

          batch.set(docRef, {
            'name': staff['name'],
            'email': email,
            'jobTitle': staff['jobTitle'],
            'firmId': firmId,
            'status': 'invited',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }

      debugPrint('[CsvUploadService] Successfully uploaded ${staffList.length} pre-approved staff records.');
    } catch (e) {
      debugPrint('[CsvUploadService] Error uploading pre-approved staff: $e');
      rethrow;
    }
  }
}
