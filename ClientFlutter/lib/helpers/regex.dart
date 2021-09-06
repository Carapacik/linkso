final passwordRegex = RegExp(r"^[\S]+$");
final loginRegex = RegExp(r"^[A-Za-z0-9_]+$");
final emailRegex = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$",
);
final linkRegex = RegExp(
  r"^(http(s)?:\/\/.)?(www\.)?[-0-9\p{L}@:%._\+~#=]{0,256}\.[a-z]{0,6}\b([-0-9\p{L}@:%_\+.~#?&//=]*)$",
  unicode: true,
);
