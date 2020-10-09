import 'dart:math';

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

DateTime calcMaxDate(List<DateTime> dates) {
  DateTime maxDate = dates[0];
  dates.forEach((date) {
    if (date.isAfter(maxDate)) {
      maxDate = date;
    }
  });
  return maxDate;
}
