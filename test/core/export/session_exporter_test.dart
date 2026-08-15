import 'package:test/test.dart';
import 'package:archive/archive.dart';
import 'package:deep_think_er/core/export/session_exporter.dart';

void main() {
  group('SessionExporter', () {
    const exporter = SessionExporter();

    test('returns non-empty bytes', () {
      final bytes = exporter.export(
        sessionName: 'test_session',
        conversationText: 'Hello world',
      );
      expect(bytes, isNotEmpty);
    });

    test('zip contains conversation.txt', () {
      final bytes = exporter.export(
        sessionName: 'my_session',
        conversationText: 'Content here',
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toList();
      expect(names.any((n) => n.endsWith('conversation.txt')), isTrue);
    });

    test('conversation.txt content matches input', () {
      const text = 'WATSON: Hello!\nDEEP: Hi there!';
      final bytes = exporter.export(
        sessionName: 'session',
        conversationText: text,
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final file = archive.files.firstWhere((f) => f.name.endsWith('conversation.txt'));
      final content = String.fromCharCodes(file.content as List<int>);
      expect(content, text);
    });

    test('includes analytics.json when provided', () {
      final bytes = exporter.export(
        sessionName: 's',
        conversationText: 'x',
        analyticsJson: '{"events":[]}',
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toList();
      expect(names.any((n) => n.endsWith('analytics.json')), isTrue);
    });

    test('omits analytics.json when null', () {
      final bytes = exporter.export(
        sessionName: 's',
        conversationText: 'x',
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(
        archive.files.any((f) => f.name.endsWith('analytics.json')),
        isFalse,
      );
    });

    test('includes research_report.md when provided', () {
      final bytes = exporter.export(
        sessionName: 's',
        conversationText: 'x',
        researchReportMd: '# Report',
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(
        archive.files.any((f) => f.name.endsWith('research_report.md')),
        isTrue,
      );
    });

    test('includes audit.csv when provided', () {
      final bytes = exporter.export(
        sessionName: 's',
        conversationText: 'x',
        auditCsv: 'col1,col2\nval1,val2',
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(
        archive.files.any((f) => f.name.endsWith('audit.csv')),
        isTrue,
      );
    });

    test('sanitises session name for folder path', () {
      final bytes = exporter.export(
        sessionName: 'my session/with:special chars!',
        conversationText: 'x',
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      // Folder name should not contain spaces, slashes or colons
      final folder = archive.files.first.name.split('/').first;
      expect(folder, isNot(contains(' ')));
      expect(folder, isNot(contains('/')));
      expect(folder, isNot(contains(':')));
    });
  });
}
