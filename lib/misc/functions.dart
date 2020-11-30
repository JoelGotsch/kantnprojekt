import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

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
    return this.year == other.year && this.month == other.month && this.day == other.day;
  }
}

int weekYearNumber(DateTime date) {
  // returns 202001 for each day in the first week of 2020, which is defined as the first week with a Wednesday in 2020 (ISOxyz).
  int dayOfYear = int.parse(DateFormat("D").format(date));
  int weekNr = ((dayOfYear - date.weekday + 10) / 7).floor();
  int yearWeek = date.year * 100 + weekNr;
  return yearWeek;
}

int dayWeekYearNumber(DateTime date) {
  // returns 20200101 for each day in the first Monday in first week of 2020, which is defined as the first week with a Wednesday in 2020 (ISOxyz).
  int yearWeek = weekYearNumber(date);
  return yearWeek * 100 + date.weekday;
}

dynamic getFromJson(String key, Map<String, dynamic> json, dynamic defaultVal) {
  if (json.containsKey(key)) {
    // print("parsing json: $key found.");
    return (json[key]);
  } else {
    // print("parsing json: $key not found.");
    return (defaultVal);
  }
}
