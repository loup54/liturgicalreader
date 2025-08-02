import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReadingContentWidget extends StatelessWidget {
  final String title;
  final String source;
  final String liturgicalContext;
  final String content;
  final double textScaleFactor;
  final Function(String)? onTextSelection;

  const ReadingContentWidget({
    Key? key,
    required this.title,
    required this.source,
    required this.liturgicalContext,
    required this.content,
    this.textScaleFactor = 1.0,
    this.onTextSelection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Liturgical Context Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              liturgicalContext,
              style: GoogleFonts.inter(
                fontSize: 12 * textScaleFactor,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Reading Source
          Text(
            source,
            style: GoogleFonts.crimsonText(
              fontSize: 20 * textScaleFactor,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),

          // Reading Content
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SelectableText.rich(
              TextSpan(
                children: _buildTextSpans(content, context),
              ),
              style: GoogleFonts.crimsonText(
                fontSize: 18 * textScaleFactor,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.left,
              selectionControls: MaterialTextSelectionControls(),
              showCursor: true,
              cursorColor: Theme.of(context).colorScheme.primary,
              onSelectionChanged: (selection, cause) {
                if (selection.isValid && onTextSelection != null) {
                  final selectedText = content.substring(
                    selection.baseOffset,
                    selection.extentOffset,
                  );
                  if (selectedText.trim().isNotEmpty) {
                    onTextSelection!(selectedText);
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          // Response or closing
          if (content.contains('The word of the Lord') ||
              content.contains('The Gospel of the Lord'))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                content.contains('The word of the Lord')
                    ? 'Thanks be to God.'
                    : 'Praise to you, Lord Jesus Christ.',
                style: GoogleFonts.crimsonText(
                  fontSize: 16 * textScaleFactor,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.secondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String content, BuildContext context) {
    final List<TextSpan> spans = [];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check for response lines (starting with R.)
      if (line.trim().startsWith('R.')) {
        spans.add(TextSpan(
          text: line + (i < lines.length - 1 ? '\n' : ''),
          style: GoogleFonts.crimsonText(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ));
      }
      // Check for closing lines
      else if (line.trim().startsWith('The word of the Lord') ||
          line.trim().startsWith('The Gospel of the Lord')) {
        spans.add(TextSpan(
          text: line + (i < lines.length - 1 ? '\n' : ''),
          style: GoogleFonts.crimsonText(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ));
      }
      // Check for quoted speech
      else if (line.contains('"')) {
        spans.add(_buildQuotedTextSpan(
            line + (i < lines.length - 1 ? '\n' : ''), context));
      }
      // Regular text
      else {
        spans.add(TextSpan(
          text: line + (i < lines.length - 1 ? '\n' : ''),
        ));
      }
    }

    return spans;
  }

  TextSpan _buildQuotedTextSpan(String line, BuildContext context) {
    final List<TextSpan> lineSpans = [];
    final RegExp quoteRegex = RegExp(r'"([^"]*)"');
    int lastEnd = 0;

    for (final match in quoteRegex.allMatches(line)) {
      // Add text before quote
      if (match.start > lastEnd) {
        lineSpans.add(TextSpan(
          text: line.substring(lastEnd, match.start),
        ));
      }

      // Add quoted text with special styling
      lineSpans.add(TextSpan(
        text: match.group(0),
        style: GoogleFonts.crimsonText(
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
        ),
      ));

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < line.length) {
      lineSpans.add(TextSpan(
        text: line.substring(lastEnd),
      ));
    }

    return TextSpan(children: lineSpans);
  }
}
