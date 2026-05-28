import 'dart:io';

class OCRService {
  OCRService._();
  static final OCRService instance = OCRService._();

  /// Placeholder: implement ML Kit or Tesseract integration
  Future<Map<String, dynamic>> parseReceipt(File image) async {
    // Return a minimal parsed result for now.
    return {
      'amount': null,
      'date': null,
      'vendor': null,
      'rawText': '',
    };
  }
}
