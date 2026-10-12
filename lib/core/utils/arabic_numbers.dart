/// Legacy `ar(n)`: Western digits shown as Arabic-Indic digits (٠١٢…).
String arabicDigits(Object value) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return value.toString().replaceAllMapped(
    RegExp('[0-9]'),
    (m) => digits[int.parse(m[0]!)],
  );
}
