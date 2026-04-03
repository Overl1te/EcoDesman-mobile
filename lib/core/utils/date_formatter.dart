import "package:intl/intl.dart";

final _postDateFormat = DateFormat("d MMMM, HH:mm", "ru_RU");
final _eventDateFormat = DateFormat("d MMMM, HH:mm", "ru_RU");

String formatPostDate(DateTime value) {
  return _postDateFormat.format(value);
}

String formatEventRange(DateTime? start, DateTime? end) {
  if (start == null) {
    return "Дата уточняется";
  }
  if (end == null || end.isAtSameMomentAs(start)) {
    return _eventDateFormat.format(start);
  }
  return "${_eventDateFormat.format(start)} - ${_eventDateFormat.format(end)}";
}
