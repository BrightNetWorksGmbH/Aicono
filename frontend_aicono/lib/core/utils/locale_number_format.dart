import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Locale-aware number formatting for display (decimal style, thousands separator).
/// Uses app locale (e.g. EN: 1,234.56 · DE: 1.234,56).
class LocaleNumberFormat {
  LocaleNumberFormat._();

  static String _localeTag(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    if (code == 'de') return 'de_DE';
    return code;
  }

  static NumberFormat _decimalFormat(String localeTag, int decimalDigits) {
    final fraction = decimalDigits > 0 ? '.' + ('0' * decimalDigits) : '';
    return NumberFormat('#,##0$fraction', localeTag);
  }

  /// Format a number with optional decimal places (locale-specific decimal/thousands).
  static String formatNum(
    dynamic value, {
    required Locale locale,
    int? decimalDigits,
    String fallback = '–',
  }) {
    if (value == null) return fallback;
    final num? n = value is num ? value : num.tryParse(value.toString());
    if (n == null) return fallback;
    final tag = _localeTag(locale);
    final formatter = decimalDigits != null
        ? _decimalFormat(tag, decimalDigits)
        : NumberFormat.decimalPattern(tag);
    return formatter.format(n);
  }

  /// Format an integer (no decimals, with thousands separator).
  static String formatInt(
    dynamic value, {
    required Locale locale,
    String fallback = '–',
  }) {
    if (value == null) return fallback;
    final num? n = value is num ? value : num.tryParse(value.toString());
    if (n == null) return fallback;
    final tag = _localeTag(locale);
    return _decimalFormat(tag, 0).format(n.round());
  }

  /// Compact format for charts (e.g. 1.2K, 1.5M) with locale-aware decimal separator.
  static String formatCompact(
    double value, {
    required Locale locale,
  }) {
    final tag = _localeTag(locale);
    if (value >= 1e6) {
      final v = value / 1e6;
      return '${_decimalFormat(tag, 1).format(v)}M';
    }
    if (value >= 1e3) {
      final v = value / 1e3;
      return '${_decimalFormat(tag, 1).format(v)}K';
    }
    if (value >= 1) {
      return _decimalFormat(tag, 0).format(value.round());
    }
    return _decimalFormat(tag, 2).format(value);
  }

  /// Format a decimal for display (e.g. 3 decimal places) with locale.
  static String formatDecimal(
    dynamic value, {
    required Locale locale,
    int decimalDigits = 3,
    String fallback = '–',
  }) {
    return formatNum(value, locale: locale, decimalDigits: decimalDigits, fallback: fallback);
  }
}
