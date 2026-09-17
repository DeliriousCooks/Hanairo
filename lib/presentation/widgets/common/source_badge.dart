import 'package:flutter/material.dart';
import '../../../domain/entities/post.dart';

class SourceBadge extends StatelessWidget {
  final BooruSource source;
  final bool large;

  const SourceBadge({super.key, required this.source, this.large = false});

  Color get _color {
    switch (source) {
      case BooruSource.rule34xxx:
        return const Color(0xFF7C6FFF);
      case BooruSource.e621:
        return const Color(0xFF4ECDC4);
      case BooruSource.gelbooru:
        return const Color(0xFFFF7CA0);
      case BooruSource.paheal:
        return const Color(0xFFFFCC7C);
      default:
        return const Color(0xFF7C8FFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 6,
        vertical: large ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(large ? 8 : 5),
      ),
      child: Text(
        source.shortName,
        style: TextStyle(
          fontSize: large ? 11 : 8,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
