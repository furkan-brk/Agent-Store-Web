import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/wallet_service.dart';

/// 5-star rating widget with optional comment + community "helpful" upvotes.
///
/// v3.7 moderation surface: each rating row gets a thumbs-up button bound to
/// `POST /agents/:id/ratings/:ratingID/helpful`. The backend enforces unique
/// votes per wallet so spam-clicking does not bump the count.
class RatingWidget extends StatefulWidget {
  final int agentId;
  const RatingWidget({super.key, required this.agentId});
  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget> {
  double _average = 0;
  int _count = 0;
  int _userRating = 0;
  bool _loading = true;
  bool _submitting = false;

  /// Recent rating list returned by /ratings — capped to 20 by the backend.
  /// Each entry is the full AgentRating JSON: {id, rating, comment, helpful, ...}.
  List<Map<String, dynamic>> _recent = const [];

  /// Tracks rating IDs the current session has already upvoted so the UI
  /// can disable the button without an extra round-trip. Session-only — the
  /// server-side dedup is authoritative across reloads.
  final Set<int> _votedHelpful = {};

  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await ApiService.instance.getRatings(widget.agentId);
    if (data != null && mounted) {
      setState(() {
        _average = (data['average'] as num?)?.toDouble() ?? 0;
        _count = (data['count'] as num?)?.toInt() ?? 0;
        _userRating = (data['user_rating'] as num?)?.toInt() ?? 0;
        _recent = ((data['ratings'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitRating(int stars) async {
    if (!ApiService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect wallet to rate agents')),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _userRating = stars;
    });
    await ApiService.instance.rateAgent(
      widget.agentId,
      stars,
      comment: _commentCtrl.text.trim(),
    );
    await _load();
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _markHelpful(int ratingId) async {
    if (!ApiService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect wallet to vote on ratings')),
      );
      return;
    }
    if (_votedHelpful.contains(ratingId)) return;
    // Optimistic update so the user sees immediate feedback; reconcile with
    // server-confirmed count when the request lands.
    setState(() {
      _votedHelpful.add(ratingId);
      final idx = _recent.indexWhere((r) => (r['id'] as num?)?.toInt() == ratingId);
      if (idx >= 0) {
        _recent[idx] = {
          ..._recent[idx],
          'helpful': ((_recent[idx]['helpful'] as num?)?.toInt() ?? 0) + 1,
        };
      }
    });
    final newCount = await ApiService.instance.markRatingHelpful(widget.agentId, ratingId);
    if (newCount != null && mounted) {
      setState(() {
        final idx = _recent.indexWhere((r) => (r['id'] as num?)?.toInt() == ratingId);
        if (idx >= 0) {
          _recent[idx] = {..._recent[idx], 'helpful': newCount};
        }
      });
    }
  }

  String? _selfWallet() => WalletService.instance.connectedWallet?.toLowerCase();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Average display ──
        Row(children: [
          Text(
            _average.toStringAsFixed(1),
            style: const TextStyle(
              color: AppTheme.textH,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          _StarRow(rating: _average, size: 18),
          const SizedBox(width: 8),
          Text(
            '($_count)',
            style: const TextStyle(color: AppTheme.textM, fontSize: 13),
          ),
        ]),
        const SizedBox(height: 16),
        // ── User rating ──
        if (ApiService.instance.isAuthenticated) ...[
          const Text(
            'Your rating:',
            style: TextStyle(color: AppTheme.textM, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: _submitting ? null : () => _submitRating(star),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    star <= _userRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: star <= _userRating ? AppTheme.gold : AppTheme.border2,
                    size: 28,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // ── Comment field (optional, posts on next star tap) ──
          TextField(
            controller: _commentCtrl,
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
            enabled: !_submitting,
            style: const TextStyle(color: AppTheme.textH, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Optional comment — what worked, what didn\'t? (max 500 chars)',
              counterStyle: TextStyle(color: AppTheme.textM, fontSize: 11),
            ),
          ),
        ],
        if (_recent.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Recent reviews',
            style: TextStyle(
              color: AppTheme.textH,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final r in _recent.take(8)) _buildRatingRow(r),
        ],
      ],
    );
  }

  Widget _buildRatingRow(Map<String, dynamic> r) {
    final id = (r['id'] as num?)?.toInt() ?? 0;
    final stars = (r['rating'] as num?)?.toInt() ?? 0;
    final comment = (r['comment'] as String?)?.trim() ?? '';
    final helpful = (r['helpful'] as num?)?.toInt() ?? 0;
    final wallet = (r['wallet'] as String?)?.toLowerCase() ?? '';
    final isSelf = wallet.isNotEmpty && wallet == _selfWallet();
    final voted = _votedHelpful.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.card2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StarRow(rating: stars.toDouble(), size: 13),
              const Spacer(),
              // Helpful button — author can't upvote their own.
              InkWell(
                onTap: (isSelf || voted) ? null : () => _markHelpful(id),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        voted
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        size: 13,
                        color: isSelf
                            ? AppTheme.border2
                            : (voted ? AppTheme.olive : AppTheme.textM),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$helpful',
                        style: TextStyle(
                          color: voted ? AppTheme.olive : AppTheme.textM,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              comment,
              style: const TextStyle(color: AppTheme.textB, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const _StarRow({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final filled = rating >= i + 1;
          final half = !filled && rating >= i + 0.5;
          return Icon(
            filled
                ? Icons.star_rounded
                : half
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            color: AppTheme.gold,
            size: size,
          );
        }),
      );
}
