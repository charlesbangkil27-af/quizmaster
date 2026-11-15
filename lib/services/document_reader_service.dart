import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

class DocumentReaderException implements Exception {
  const DocumentReaderException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ExtractedDocument {
  const ExtractedDocument({
    required this.fileName,
    required this.extension,
    required this.text,
  });

  final String fileName;
  final String extension;
  final String text;

  int get characterCount => text.length;
}

class DocumentReaderService {
  static const int maxFileBytes = 15 * 1024 * 1024;
  static const int maxTextCharacters = 150000;

  Future<ExtractedDocument> extract(PlatformFile file) async {
    final extension = (file.extension ?? '').toLowerCase();

    const supported = {'pdf', 'docx', 'pptx', 'txt'};

    if (!supported.contains(extension)) {
      throw const DocumentReaderException(
        'Unsupported file. Please select PDF, DOCX, PPTX, or TXT.',
      );
    }

    final fileSize = file.lengthSync() ?? await file.length();

    if (fileSize == null) {
      throw const DocumentReaderException(
        'Could not determine the file size. Please select it again.',
      );
    }

    if (fileSize <= 0) {
      throw const DocumentReaderException('The selected file is empty.');
    }

    if (fileSize > maxFileBytes) {
      throw const DocumentReaderException(
        'File is too large. Maximum allowed size is 15 MB.',
      );
    }

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw const DocumentReaderException(
        'Could not read the file. Please select it again.',
      );
    }

    try {
      late String extractedText;

      switch (extension) {
        case 'txt':
          extractedText = utf8.decode(bytes, allowMalformed: true);
          break;

        case 'pdf':
          extractedText = _extractPdf(bytes);
          break;

        case 'docx':
          extractedText = _extractWord(bytes);
          break;

        case 'pptx':
          extractedText = _extractPowerPoint(bytes);
          break;

        default:
          throw const DocumentReaderException('Unsupported document format.');
      }

      final cleaned = _cleanText(extractedText);

      if (cleaned.isEmpty) {
        throw const DocumentReaderException(
          'No readable text was found. The document may be empty, scanned, '
          'or contain unsupported content.',
        );
      }

      if (cleaned.length > maxTextCharacters) {
        throw const DocumentReaderException(
          'The extracted document is too long. Maximum is 150,000 '
          'characters. Please use a shorter document.',
        );
      }

      return ExtractedDocument(
        fileName: file.name,
        extension: extension,
        text: cleaned,
      );
    } on DocumentReaderException {
      rethrow;
    } catch (error) {
      throw DocumentReaderException(
        'Unable to read ${file.name}. Check whether the file is valid '
        'and is not password-protected. Details: $error',
      );
    }
  }

  String _extractPdf(List<int> bytes) {
    final document = PdfDocument(inputBytes: bytes);

    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  String _extractWord(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentFile = archive.findFile('word/document.xml');

    if (documentFile == null) {
      throw const DocumentReaderException(
        'Invalid DOCX file: document content was not found.',
      );
    }

    final xml = XmlDocument.parse(
      utf8.decode(documentFile.content, allowMalformed: true),
    );

    return _extractParagraphs(xml);
  }

  String _extractPowerPoint(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    final slideFiles = archive.files
        .where(
          (file) =>
              file.isFile &&
              RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(file.name),
        )
        .toList();

    slideFiles.sort((a, b) {
      final aNumber = int.parse(
        RegExp(r'slide(\d+)\.xml$').firstMatch(a.name)!.group(1)!,
      );
      final bNumber = int.parse(
        RegExp(r'slide(\d+)\.xml$').firstMatch(b.name)!.group(1)!,
      );
      return aNumber.compareTo(bNumber);
    });

    if (slideFiles.isEmpty) {
      throw const DocumentReaderException(
        'No readable PowerPoint slides were found.',
      );
    }

    final slideTexts = <String>[];

    for (final slide in slideFiles) {
      final xml = XmlDocument.parse(
        utf8.decode(slide.content, allowMalformed: true),
      );

      final text = _extractParagraphs(xml);

      if (text.isNotEmpty) {
        slideTexts.add(text);
      }
    }

    return slideTexts.join('\n\n');
  }

  String _extractParagraphs(XmlDocument xml) {
    final paragraphs = xml.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'p',
    );

    return paragraphs
        .map(
          (paragraph) => paragraph.descendants
              .whereType<XmlElement>()
              .where((element) => element.name.local == 't')
              .map((element) => element.innerText)
              .join(),
        )
        .where((text) => text.trim().isNotEmpty)
        .join('\n');
  }

  String _cleanText(String input) {
    return input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
