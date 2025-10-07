import 'package:intl/intl.dart';

class AppDateFormatter {
  AppDateFormatter._();

  static final DateFormat monthDay = DateFormat('M月d日', 'zh_CN');
  static final DateFormat weekday = DateFormat('EEEE', 'zh_CN');
  static final DateFormat fullDate = DateFormat('yyyy-MM-dd');
}