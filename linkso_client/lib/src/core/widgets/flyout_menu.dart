import 'package:flutter/services.dart';
import 'package:linkso_client/src/core/widgets/ui_flyout.dart';
import 'package:material_ui/material_ui.dart';

final class const FlyoutMenuEntry<T>({
  required final T value,
  required final String label,
  final Widget? leading,
  final Key? key,
});

class const FlyoutMenu<T>({
  required final T value,
  required final List<FlyoutMenuEntry<T>> entries,
  required final ValueChanged<Object?> onSelected,
  required final String tooltip,
  required final Widget child,
  super.key,
}) extends StatefulWidget {
  @override
  State<FlyoutMenu<T>> createState() => _FlyoutMenuState<T>();
}

class _FlyoutMenuState<T>() extends State<FlyoutMenu<T>> {
  final FocusNode _anchorFocusNode = FocusNode(debugLabel: 'Flyout menu anchor');
  bool _open = false;

  @override
  void dispose() {
    _anchorFocusNode.dispose();
    super.dispose();
  }

  void _hide() {
    if (_open) {
      setState(() => _open = false);
    }
  }

  void _select(T value) {
    _hide();
    widget.onSelected(value);
    _anchorFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Closing the overlay can restore focus to its anchor after the
      // selection callback rebuilds MaterialApp (locale/theme changes do).
      if (mounted && _anchorFocusNode.hasFocus) {
        _anchorFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color foregroundColor = theme.colorScheme.onSurface;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _hide},
      child: UiFlyout(
        isOpen: _open,
        onHideRequested: _hide,
        anchor: const UiFlyoutAnchor(offset: Offset(0, 8)),
        overlayBuilder: (context, flyout) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hide),
            ),
            flyout,
          ],
        ),
        flyoutBuilder: (context) => CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): _hide},
          child: Focus(
            autofocus: true,
            child: Material(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              elevation: 3,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final FlyoutMenuEntry<T> entry in widget.entries)
                      Semantics(
                        selected: entry.value == widget.value,
                        child: InkWell(
                          key: entry.key,
                          onTap: () => _select(entry.value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                if (entry.leading case final Widget leading) ...[
                                  SizedBox.square(dimension: 24, child: Center(child: leading)),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(child: Text(entry.label)),
                                const SizedBox(width: 12),
                                SizedBox.square(
                                  dimension: 20,
                                  child: entry.value == widget.value
                                      ? Icon(Icons.check_rounded, size: 18, color: foregroundColor)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        child: Tooltip(
          message: widget.tooltip,
          child: Semantics(
            button: true,
            expanded: _open,
            label: widget.tooltip,
            child: InkWell(
              focusNode: _anchorFocusNode,
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              onTap: () {
                _anchorFocusNode.requestFocus();
                setState(() => _open = !_open);
              },
              child: DefaultTextStyle.merge(
                style: TextStyle(color: foregroundColor),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
