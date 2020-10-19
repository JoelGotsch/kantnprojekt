import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

DateTime calcMaxDate(List<DateTime> dates) {
  if (dates == null || dates.length == 0) {
    //
    return (DateTime.parse("2020-01-01"));
  }
  DateTime maxDate = dates[0];
  dates.forEach((date) {
    if (date.isAfter(maxDate)) {
      maxDate = date;
    }
  });
  return maxDate;
}

String generateMd5(String input) {
  return md5.convert(utf8.encode(input)).toString();
}

extension dateOnlyCompare on DateTime {
  bool isSameDate(DateTime other) {
    return this.year == other.year &&
        this.month == other.month &&
        this.day == other.day;
  }
}

int weekNumber(DateTime date) {
  int dayOfYear = int.parse(DateFormat("D").format(date));
  return ((dayOfYear - date.weekday + 10) / 7).floor();
}
