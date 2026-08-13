import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// ReportPreviewWidget
// ---------------------------------------------------------------------------

/// Displays a research report Markdown string as formatted text.
///
/// Parses `#` headings, `##` subheadings, `---` dividers, `- ` list items,
/// and `>` blockquotes. No external markdown renderer dependency.
class ReportPreviewWidget extends StatelessWidget {
  /// The full Markdown report text to display.
  final String reportMarkdown;

  const ReportPreviewWidget({
    super.key,
    required this.reportMarkdown,
  });

  @override
  Widget build(BuildContext context) {
    final lines = reportMarkdown.split('\n');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) => _buildLine(line)).toList(),
      ),
    );
  }

  Widget _buildLine(String line) {
    // H1
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          line.substring(2),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // H2
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Text(
          line.substring(3),
          style: const TextStyle(
            color: Color(0xFFB0BEC5),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    // H3
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(
          line.substring(4),
          style: const TextStyle(
            color: Color(0xFF90CAF9),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Horizontal rule
    if (line.trim() == '---') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: Color(0xFF37474F), thickness: 1),
      );
    }

    // Blockquote
    if (line.startsWith('> ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 16,
              color: const Color(0xFF546E7A),
              margin: const EdgeInsets.only(right: 8, top: 2),
            ),
            Expanded(
              child: Text(
                line.substring(2),
                style: const TextStyle(
                  color: Color(0xFF90A4AE),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // List item
    if (line.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, top: 1, bottom: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 12)),
            Expanded(
              child: Text(
                line.substring(2),
                style: const TextStyle(
                  color: Color(0xFFCFD8DC),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Bold **text**
    if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          line.substring(2, line.length - 2),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Italic _text_
    if (line.startsWith('_') && line.endsWith('_') && line.length > 2) {
      return Text(
        line.substring(1, line.length - 1),
        style: const TextStyle(
          color: Color(0xFF90A4AE),
          fontSize: 11,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Empty line
    if (line.trim().isEmpty) {
      return const SizedBox(height: 4);
    }

    // Plain text
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        line,
        style: const TextStyle(
          color: Color(0xFFCFD8DC),
          fontSize: 12,
        ),
      ),
    );
  }
}
