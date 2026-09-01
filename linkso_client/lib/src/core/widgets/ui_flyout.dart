import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

typedef UiFlyoutOverlayBuilder = Widget Function(BuildContext context, Widget flyout);

abstract interface class FlyoutController() {
  void hide();
}

class const FlyoutScope({required final FlyoutController controller, required super.child, super.key})
    extends InheritedWidget {
  static FlyoutScope? maybeOf(BuildContext context, {bool listen = true}) => listen
      ? context.dependOnInheritedWidgetOfExactType<FlyoutScope>()
      : context.getInheritedWidgetOfExactType<FlyoutScope>();

  static FlyoutScope of(BuildContext context, {bool listen = true}) {
    final FlyoutScope? scope = maybeOf(context, listen: listen);
    assert(scope != null, 'No FlyoutScope found in context.');
    return scope!;
  }

  @override
  bool updateShouldNotify(FlyoutScope oldWidget) => controller != oldWidget.controller;
}

enum UiFlyoutWidth() {
  fixed,
  fill,
}

@immutable
class const UiFlyoutAnchor({
  final Offset offset = Offset.zero,
  final AlignmentGeometry anchorAlignment = AlignmentDirectional.bottomEnd,
  final AlignmentGeometry flyoutAlignment = AlignmentDirectional.topEnd,
}) {
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiFlyoutAnchor &&
          other.offset == offset &&
          other.anchorAlignment == anchorAlignment &&
          other.flyoutAlignment == flyoutAlignment;

  @override
  int get hashCode => Object.hash(offset, anchorAlignment, flyoutAlignment);
}

/// A headless overlay anchored to [child].
///
/// Adapted from Sizzle Starter's `UiFlyout`: the delegate flips an overflowing
/// flyout to the opposite side and clamps it to the available overlay bounds.
class const UiFlyout({
  required final bool isOpen,
  required final WidgetBuilder flyoutBuilder,
  required final Widget child,
  final UiFlyoutAnchor anchor = const UiFlyoutAnchor(),
  final UiFlyoutOverlayBuilder? overlayBuilder,
  final VoidCallback? onHideRequested,
  final UiFlyoutWidth width = UiFlyoutWidth.fixed,
  super.key,
}) extends StatefulWidget {
  @override
  State<UiFlyout> createState() => _UiFlyoutState();
}

class _UiFlyoutState() extends State<UiFlyout> implements FlyoutController {
  late final OverlayPortalController _overlayPortalController;
  ScrollNotificationObserverState? _scrollNotificationObserver;

  @override
  void initState() {
    super.initState();
    _overlayPortalController = OverlayPortalController();
    _scheduleChangeVisibility();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateScrollObserver();
  }

  @override
  void didUpdateWidget(UiFlyout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      _scheduleChangeVisibility();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateScrollObserver();
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollNotificationObserver?.removeListener(_handleScrollNotification);
    super.dispose();
  }

  void _updateScrollObserver() {
    _scrollNotificationObserver?.removeListener(_handleScrollNotification);
    _scrollNotificationObserver = ScrollNotificationObserver.maybeOf(context);
    if (widget.isOpen) {
      _scrollNotificationObserver?.addListener(_handleScrollNotification);
    }
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (mounted &&
        widget.isOpen &&
        notification is ScrollUpdateNotification &&
        defaultScrollNotificationPredicate(notification)) {
      setState(() {});
    }
  }

  @override
  void hide() => widget.onHideRequested?.call();

  void _scheduleChangeVisibility() {
    final bool isOpen = widget.isOpen;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (isOpen) {
        _overlayPortalController.show();
      } else {
        _overlayPortalController.hide();
      }
    });
  }

  Widget _overlayChildBuilder(BuildContext flyoutContext) => FlyoutScope(
    controller: this,
    child: Builder(
      builder: (scopeContext) => LayoutBuilder(
        builder: (_, constraints) {
          final TextDirection direction = Directionality.of(context);
          final target = context.findRenderObject()! as RenderBox;
          final overlay = Overlay.of(flyoutContext).context.findRenderObject()! as RenderBox;
          final Offset targetOffset = overlay.globalToLocal(target.localToGlobal(Offset.zero));
          final Rect targetRect = targetOffset & target.size;
          final Widget flyout = CustomSingleChildLayout(
            delegate: _UiFlyoutDelegate(
              anchor: widget.anchor,
              targetRect: targetRect,
              direction: direction,
              width: widget.width,
            ),
            child: widget.flyoutBuilder(scopeContext),
          );
          return widget.overlayBuilder?.call(scopeContext, flyout) ?? flyout;
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _overlayPortalController,
    overlayChildBuilder: _overlayChildBuilder,
    child: widget.child,
  );
}

class const _UiFlyoutDelegate({
  required final UiFlyoutAnchor anchor,
  required final Rect targetRect,
  required final TextDirection direction,
  required final UiFlyoutWidth width,
}) extends SingleChildLayoutDelegate {
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => switch (width) {
    UiFlyoutWidth.fixed => constraints.loosen(),
    UiFlyoutWidth.fill => BoxConstraints(
      minWidth: targetRect.width,
      maxWidth: targetRect.width,
      maxHeight: constraints.maxHeight,
    ),
  };

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final Alignment anchorAlignment = anchor.anchorAlignment.resolve(direction);
    final Alignment flyoutAlignment = anchor.flyoutAlignment.resolve(direction);
    Offset position = _calculatePosition(
      anchorAlignment: anchorAlignment,
      flyoutAlignment: flyoutAlignment,
      childSize: childSize,
      offset: anchor.offset,
    );
    position = _flipIfOverflowing(
      position: position,
      anchorAlignment: anchorAlignment,
      flyoutAlignment: flyoutAlignment,
      offset: anchor.offset,
      childSize: childSize,
      availableSize: size,
    );
    return _clampToAvailableSpace(position, childSize, size);
  }

  Offset _flipIfOverflowing({
    required Offset position,
    required Alignment anchorAlignment,
    required Alignment flyoutAlignment,
    required Offset offset,
    required Size childSize,
    required Size availableSize,
  }) {
    final bool flipHorizontal = position.dx < 0 || position.dx + childSize.width > availableSize.width;
    final bool flipVertical = position.dy < 0 || position.dy + childSize.height > availableSize.height;
    if (!flipHorizontal && !flipVertical) {
      return position;
    }
    final Offset flippedPosition = _calculatePosition(
      anchorAlignment: Alignment(
        flipHorizontal ? -anchorAlignment.x : anchorAlignment.x,
        flipVertical ? -anchorAlignment.y : anchorAlignment.y,
      ),
      flyoutAlignment: Alignment(
        flipHorizontal ? -flyoutAlignment.x : flyoutAlignment.x,
        flipVertical ? -flyoutAlignment.y : flyoutAlignment.y,
      ),
      childSize: childSize,
      offset: Offset(flipHorizontal ? -offset.dx : offset.dx, flipVertical ? -offset.dy : offset.dy),
    );
    return _calculateOverflow(flippedPosition, childSize, availableSize) == 0 ? flippedPosition : position;
  }

  Offset _clampToAvailableSpace(Offset position, Size childSize, Size availableSize) => Offset(
    position.dx.clamp(0, (availableSize.width - childSize.width).clamp(0, double.infinity)),
    position.dy.clamp(0, (availableSize.height - childSize.height).clamp(0, double.infinity)),
  );

  Offset _calculatePosition({
    required Alignment anchorAlignment,
    required Alignment flyoutAlignment,
    required Size childSize,
    required Offset offset,
  }) {
    final anchorPoint = Offset(
      targetRect.left + targetRect.width * ((anchorAlignment.x + 1) / 2),
      targetRect.top + targetRect.height * ((anchorAlignment.y + 1) / 2),
    );
    final flyoutPoint = Offset(
      childSize.width * ((flyoutAlignment.x + 1) / 2),
      childSize.height * ((flyoutAlignment.y + 1) / 2),
    );
    return anchorPoint - flyoutPoint + offset;
  }

  double _calculateOverflow(Offset position, Size childSize, Size availableSize) {
    double overflow = 0;
    if (position.dx < 0) {
      overflow -= position.dx;
    }
    if (position.dy < 0) {
      overflow -= position.dy;
    }
    if (position.dx + childSize.width > availableSize.width) {
      overflow += position.dx + childSize.width - availableSize.width;
    }
    if (position.dy + childSize.height > availableSize.height) {
      overflow += position.dy + childSize.height - availableSize.height;
    }
    return overflow;
  }

  @override
  bool shouldRelayout(_UiFlyoutDelegate oldDelegate) =>
      anchor != oldDelegate.anchor ||
      targetRect != oldDelegate.targetRect ||
      direction != oldDelegate.direction ||
      width != oldDelegate.width;
}
