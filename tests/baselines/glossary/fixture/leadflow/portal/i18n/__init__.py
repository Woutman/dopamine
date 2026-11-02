from leadflow.portal.i18n import en, nl

_LOCALES = {"nl": nl.LABELS, "en": en.LABELS}


def label(key, locale="nl"):
    return _LOCALES[locale][key]
