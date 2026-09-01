import 'package:material_ui/material_ui.dart';
import 'package:qr/qr.dart';

class const LinkSoQrCode({required final String data, final double size = 220, super.key}) extends StatefulWidget {
  @override
  State<LinkSoQrCode> createState() => _LinkSoQrCodeState();
}

class _LinkSoQrCodeState() extends State<LinkSoQrCode> {
  late QrImage _image = _createImage();

  @override
  void didUpdateWidget(covariant LinkSoQrCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _image = _createImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        key: const ValueKey<String>('linkso-qr-painter'),
        painter: _LinkSoQrPainter(
          image: _image,
          backgroundColor: backgroundColor,
          moduleColor: _inverted(backgroundColor),
        ),
      ),
    );
  }

  QrImage _createImage() {
    final code = QrCode(payload: QrPayload.fromString(widget.data));
    return QrImage(code);
  }

  Color _inverted(Color color) => Color.fromARGB(
    (color.a * 255).round(),
    255 - (color.r * 255).round(),
    255 - (color.g * 255).round(),
    255 - (color.b * 255).round(),
  );
}

// The smooth module construction is adapted from PrettyQrSmoothSymbol.
class const _LinkSoQrPainter({
  required final QrImage image,
  required final Color backgroundColor,
  required final Color moduleColor,
}) extends CustomPainter {
  static const double _roundFactor = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final double moduleSize = size.shortestSide / image.moduleCount;
    final double qrSize = moduleSize * image.moduleCount;
    final origin = Offset((size.width - qrSize) / 2, (size.height - qrSize) / 2);
    final modules = Path();

    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    for (var row = 0; row < image.moduleCount; row++) {
      for (var column = 0; column < image.moduleCount; column++) {
        final moduleRect = Rect.fromLTWH(
          origin.dx + (column * moduleSize),
          origin.dy + (row * moduleSize),
          moduleSize,
          moduleSize,
        );
        final _QrNeighbours neighbours = _neighbours(row, column);
        if (_isDark(row, column)) {
          modules.addRRect(_darkModule(moduleRect, neighbours));
        } else {
          modules.addPath(_innerCorners(moduleRect, neighbours), Offset.zero);
        }
      }
    }

    canvas.drawPath(
      modules,
      Paint()
        ..color = moduleColor
        ..isAntiAlias = true,
    );
  }

  RRect _darkModule(Rect rect, _QrNeighbours neighbours) {
    final radius = Radius.circular(rect.shortestSide * 0.5 * _roundFactor);
    if (!neighbours.hasClosest) {
      return RRect.fromRectAndRadius(rect, radius / 2);
    }
    return RRect.fromRectAndCorners(
      rect,
      topLeft: neighbours.top || neighbours.left ? Radius.zero : radius,
      topRight: neighbours.top || neighbours.right ? Radius.zero : radius,
      bottomLeft: neighbours.bottom || neighbours.left ? Radius.zero : radius,
      bottomRight: neighbours.bottom || neighbours.right ? Radius.zero : radius,
    );
  }

  Path _innerCorners(Rect rect, _QrNeighbours neighbours) {
    final path = Path();
    final double padding = rect.shortestSide * 0.5 * _roundFactor;
    if (neighbours.top && neighbours.left && neighbours.topLeft) {
      path.addPath(
        _innerCorner(rect.topLeft.translate(0, padding), rect.topLeft, rect.topLeft.translate(padding, 0)),
        Offset.zero,
      );
    }
    if (neighbours.top && neighbours.right && neighbours.topRight) {
      path.addPath(
        _innerCorner(rect.topRight.translate(-padding, 0), rect.topRight, rect.topRight.translate(0, padding)),
        Offset.zero,
      );
    }
    if (neighbours.bottom && neighbours.left && neighbours.bottomLeft) {
      path.addPath(
        _innerCorner(rect.bottomLeft.translate(0, -padding), rect.bottomLeft, rect.bottomLeft.translate(padding, 0)),
        Offset.zero,
      );
    }
    if (neighbours.bottom && neighbours.right && neighbours.bottomRight) {
      path.addPath(
        _innerCorner(
          rect.bottomRight.translate(-padding, 0),
          rect.bottomRight,
          rect.bottomRight.translate(0, -padding),
        ),
        Offset.zero,
      );
    }
    return path;
  }

  Path _innerCorner(Offset first, Offset center, Offset last) => Path()
    ..moveTo(first.dx, first.dy)
    ..quadraticBezierTo(center.dx, center.dy, last.dx, last.dy)
    ..lineTo(center.dx, center.dy)
    ..close();

  _QrNeighbours _neighbours(int row, int column) => _QrNeighbours(
    topLeft: _isDark(row - 1, column - 1),
    top: _isDark(row - 1, column),
    topRight: _isDark(row - 1, column + 1),
    left: _isDark(row, column - 1),
    right: _isDark(row, column + 1),
    bottomLeft: _isDark(row + 1, column - 1),
    bottom: _isDark(row + 1, column),
    bottomRight: _isDark(row + 1, column + 1),
  );

  bool _isDark(int row, int column) =>
      row >= 0 && row < image.moduleCount && column >= 0 && column < image.moduleCount && image.isDark(row, column);

  @override
  bool shouldRepaint(covariant _LinkSoQrPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.moduleColor != moduleColor;
}

class const _QrNeighbours({
  required final bool topLeft,
  required final bool top,
  required final bool topRight,
  required final bool left,
  required final bool right,
  required final bool bottomLeft,
  required final bool bottom,
  required final bool bottomRight,
});

extension on _QrNeighbours {
  bool get hasClosest => top || left || right || bottom;
}
