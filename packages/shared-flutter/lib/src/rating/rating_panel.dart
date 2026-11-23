import 'package:flutter/material.dart';

import 'job_rating.dart';

/// Builds the app's own primary button so the panel matches each app.
typedef RatingButtonBuilder = Widget Function(
  String label,
  VoidCallback? onPressed,
  bool loading,
);

/// Bolt/Uber-style rating card shown when a move ends.
///
/// Stars first; once a score is chosen the matching quick tags appear
/// (praise for 4-5 stars, what went wrong for 1-3) with an optional comment.
/// After sending it shows a thank-you, with Edit while the server still
/// allows changes.
class RatingPanel extends StatefulWidget {
  const RatingPanel({
    super.key,
    required this.title,
    required this.status,
    required this.onSubmit,
    required this.buttonBuilder,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final JobRatingStatus status;
  final Future<void> Function(int score, List<String> tags, String? comment)
  onSubmit;
  final RatingButtonBuilder buttonBuilder;

  @override
  State<RatingPanel> createState() => _RatingPanelState();
}

class _RatingPanelState extends State<RatingPanel> {
  late int _score = widget.status.score ?? 0;
  late final Set<String> _tags = {...widget.status.tags};
  late final TextEditingController _comment = TextEditingController(
    text: widget.status.comment ?? '',
  );
  late bool _editing = !widget.status.rated;
  late bool _showComment = (widget.status.comment ?? '').isNotEmpty;
  bool _sending = false;

  /// Set once this panel sent a rating, before the parent reloads status.
  int? _sentScore;
  String? _error;

  @override
  void didUpdateWidget(covariant RatingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.status.rated && widget.status.rated) _editing = false;
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _setScore(int score) {
    setState(() {
      // Tags of the other tone no longer fit the new score.
      if ((score >= 4) != (_score >= 4)) _tags.clear();
      _score = score;
      _error = null;
    });
  }

  Future<void> _send() async {
    if (_score == 0 || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _score,
        _tags.toList(growable: false),
        _comment.text,
      );
      if (mounted) {
        setState(() {
          _editing = false;
          _sentScore = _score;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send your rating. Try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = widget.status;
    if (!_editing && (status.rated || _sentScore != null)) {
      return _thanks(context, colors);
    }
    if (!status.canRate) return const SizedBox.shrink();

    final tags = _score == 0 ? const <String>[] : status.tagsFor(_score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i star${i == 1 ? '' : 's'}',
                onPressed: _sending ? null : () => _setScore(i),
                iconSize: 38,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  i <= _score ? Icons.star_rounded : Icons.star_border_rounded,
                  color: i <= _score ? colors.tertiary : colors.outline,
                ),
              ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _score == 0
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _score >= 4
                          ? '${ratingScoreWord(_score)}! What went well?'
                          : '${ratingScoreWord(_score)}. What went wrong?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tags)
                          FilterChip(
                            label: Text(ratingTagLabel(tag)),
                            selected: _tags.contains(tag),
                            showCheckmark: false,
                            selectedColor: colors.primary.withValues(
                              alpha: 0.14,
                            ),
                            side: BorderSide(
                              color: _tags.contains(tag)
                                  ? colors.primary
                                  : colors.outlineVariant,
                            ),
                            onSelected: _sending
                                ? null
                                : (on) => setState(
                                    () =>
                                        on ? _tags.add(tag) : _tags.remove(tag),
                                  ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_showComment)
                      TextField(
                        controller: _comment,
                        maxLength: 500,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Anything else? (optional)',
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => setState(() => _showComment = true),
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Add a comment'),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.error, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 4),
                    widget.buttonBuilder(
                      status.rated ? 'Update rating' : 'Submit rating',
                      _send,
                      _sending,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ratings are anonymous.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _thanks(BuildContext context, ColorScheme colors) {
    final score = _sentScore ?? widget.status.score ?? _score;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                i <= score ? Icons.star_rounded : Icons.star_border_rounded,
                size: 22,
                color: i <= score ? colors.tertiary : colors.outline,
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Thanks for your rating',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        if (widget.status.canRate)
          TextButton(
            onPressed: () => setState(() => _editing = true),
            child: const Text('Edit rating'),
          ),
      ],
    );
  }
}
