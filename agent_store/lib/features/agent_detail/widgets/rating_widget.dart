import 'package:flutter/material.dart';
import '../../../shared/services/api_service.dart';

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
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitRating(int stars) async {
    if (!ApiService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect wallet to rate agents')));
      return;
    }
    setState(() {
      _submitting = true;
      _userRating = stars;
    });
    await ApiService.instance.rateAgent(widget.agentId, stars,
        comment: _commentCtrl.text);
    await _load();
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF81231E),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Average display
        Row(children: [
          Text(
            _average.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          _StarRow(rating: _average, size: 18),
          const SizedBox(width: 8),
          Text(
            '($_count)',
            style:
                const TextStyle(color: Color(0xFF9E8F72), fontSize: 13),
          ),
        ]),
        const SizedBox(height: 12),
        // User rating
        if (ApiService.instance.isAuthenticated) ...[
          const Text(
            'Your rating:',
            style: TextStyle(color: Color(0xFF9E8F72), fontSize: 12),
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
                    color: star <= _userRating
                        ? const Color(0xFF9B7B1A)
                        : const Color(0xFF5A5038),
                    size: 28,
                  ),
                ),
              );
            }),
          ),
        ],
      ],
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
            color: const Color(0xFF9B7B1A),
            size: size,
          );
        }),
      );
}
