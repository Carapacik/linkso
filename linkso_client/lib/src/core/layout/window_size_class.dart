enum WindowSizeClass() {
  compact,
  medium,
  expanded,
  large,
  extraLarge;

  static WindowSizeClass fromWidth(double width) {
    if (width < 600) {
      return compact;
    }
    if (width < 840) {
      return medium;
    }
    if (width < 1200) {
      return expanded;
    }
    if (width < 1600) {
      return large;
    }
    return extraLarge;
  }

  bool get isCompact => this == WindowSizeClass.compact;

  bool get showsNavigationLabels => this == WindowSizeClass.large || this == WindowSizeClass.extraLarge;

  double get contentPadding => switch (this) {
    WindowSizeClass.compact => 16,
    WindowSizeClass.medium => 24,
    WindowSizeClass.expanded => 32,
    WindowSizeClass.large || WindowSizeClass.extraLarge => 40,
  };
}
