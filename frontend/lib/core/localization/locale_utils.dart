import 'package:flutter/material.dart';

import 'app_localizations.dart';

class LocaleTracker {
  static Locale? _current;

  static void update(Locale locale) {
    _current = locale;
  }

  static Locale currentLocale() {
    return _current ?? WidgetsBinding.instance.platformDispatcher.locale;
  }
}

extension LocaleTextX on BuildContext {
  Locale get _currentLocale => Localizations.localeOf(this);

  bool get isChinese => _currentLocale.languageCode.toLowerCase().startsWith('zh');

  String tr(String zh, [String? en]) {
    LocaleTracker.update(_currentLocale);
    if (isChinese) {
      return zh;
    }
    if (en != null && en.isNotEmpty) {
      return en;
    }
    return AppLocalizations.of(this).translate(zh);
  }
}

String trStatic(String zh, [String? en]) {
  final current = LocaleTracker.currentLocale();
  final isChinese = current.languageCode.toLowerCase().startsWith('zh');
  if (isChinese) {
    return zh;
  }
  if (en != null && en.isNotEmpty) {
    return en;
  }
  return AppLocalizations.translateStatic(zh);
}

extension LocaleStringX on String {
  String tr([String? en]) => trStatic(this, en);
}
