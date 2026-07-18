import 'dart:convert';
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
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('[CsvUploadService] File picking cancelled or returned empty.');
        return [];
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('File bytes are null. Ensure withData: true is set.');
      }

      // Decode the bytes into a CSV string
      final csvString = utf8.decode(bytes);

      // Parse the CSV content
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

      if (rows.isEmpty) {
        throw Exception('The CSV file is empty.');
      }

      // Identify headers from the first row (Row 0)
      final headers = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();

      int nameIndex = headers.indexWhere((h) => h == 'name');
      int emailIndex = headers.indexWhere((h) => h == 'email');
      // Look for variants like "job title", "jobtitle", "title"
      int jobTitleIndex = headers.indexWhere((h) => h.contains('job') || h == 'title');

      if (nameIndex == -1) {
        // Fallback to column index 0 if header matching failed
        nameIndex = 0;
      }
      if (emailIndex == -1) {
        // Fallback to column index 1 if header matching failed
        emailIndex = 1 < headers.length ? 1 : -1;
      }
      if (jobTitleIndex == -1) {
        // Fallback to column index 2 if header matching failed
        jobTitleIndex = 2 < headers.length ? 2 : -1;
      }

      if (nameIndex == -1 || emailIndex == -1) {
        throw Exception('Could not locate required Name or Email columns in the CSV headers.');
      }

      final List<Map<String, dynamic>> staffList = [];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.length <= nameIndex || row.length <= emailIndex) {
          continue; // Skip malformed or empty rows
        }

        final String name = row[nameIndex].toString().trim();
        final String email = row[emailIndex].toString().trim().toLowerCase();

        // Check basic validation: skip header row repeating or empty fields
        if (name.isEmpty || email.isEmpty || email == 'email') {
          continue;
        }

        String jobTitle = '';
        if (jobTitleIndex != -1 && jobTitleIndex < row.length) {
          jobTitle = row[jobTitleIndex].toString().trim();
        }

        staffList.add({
          'name': name,
          'email': email,
          'jobTitle': jobTitle,
        });
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
