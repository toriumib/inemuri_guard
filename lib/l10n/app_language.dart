import 'package:flutter/material.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// UI follows Flutter's locale resolution. Services use the same device locale.
/// English is the fallback for languages we do not yet support.
class AppLanguage {
  static Locale resolve(List<Locale> locales) {
    for (final locale in locales) {
      if (locale.languageCode == 'ja' || locale.languageCode == 'en') {
        return Locale(locale.languageCode);
      }
    }
    return const Locale('en');
  }

  static AppLocalizations get current => lookupAppLocalizations(
    resolve(WidgetsBinding.instance.platformDispatcher.locales),
  );
}

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLanguage.current;
}
