enum LinkKind() {
  direct,
  password,
  advertising;

  String get apiValue => name;
}
