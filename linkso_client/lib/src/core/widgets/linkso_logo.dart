import 'package:linkso_client/src/core/widgets/linkso_logo_paths.g.dart';
import 'package:material_ui/material_ui.dart';

/// The approved SVG mark rendered as paths, without an SVG runtime dependency.
class const LinkSoLogo({final double size = 32, final Color? color, super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LinkSoLogoPainter(color: color ?? Theme.of(context).colorScheme.primary)),
    ),
  );
}

class const _LinkSoLogoPainter({required final Color color}) extends CustomPainter {
  static final List<Path> _paths = createLinkSoLogoPaths();

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / linkSoLogoViewBox.width;
    final paint = Paint()..color = color;
    canvas
      ..save()
      ..translate(
        (size.width - linkSoLogoViewBox.width * scale) / 2,
        (size.height - linkSoLogoViewBox.height * scale) / 2,
      )
      ..scale(scale)
      ..translate(-linkSoLogoViewBox.left, -linkSoLogoViewBox.top);
    for (final Path path in _paths) {
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LinkSoLogoPainter oldDelegate) => color != oldDelegate.color;
}
