// lib/src/l10n/agent_localizations.dart
//
// AgentUIKit v3 — Localization & Internationalization
// ============================================================
// Full i18n/l10n support for agent-generated UIs.
//
// What this solves:
//  1. Agent text in the WRONG language — system prompt injection
//     tells the LLM which locale to respond in automatically.
//  2. Node-level translation keys — agents emit {t: "key"} and
//     the renderer resolves to the right locale string.
//  3. RTL layout support — Directionality wrapping per locale.
//  4. Number/date/currency formatting — locale-aware formatters
//     that agents can reference by format type.
//  5. Pluralisation — {count}-aware message resolution.
//  6. Locale negotiation — best-fit matching (e.g. "zh-HK" → "zh").
//  7. Hot-swap — change locale at runtime without rebuilding trees.
//  8. Fallback chain — en_US as ultimate fallback.
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────
// Translation message types
// ─────────────────────────────────────────────

/// A translated string, optionally with plural forms and parameters.
class TranslationMessage {
  const TranslationMessage({
    required this.key,
    required this.value,
    this.pluralForms = const {},
    this.description,
  });

  final String key;
  final String value;                       // default / singular
  final Map<String, String> pluralForms;    // "zero","one","two","few","many","other"
  final String? description;               // translator note

  /// Resolve with optional [count] for pluralisation and [args] for interpolation.
  String resolve({int? count, Map<String, dynamic>? args}) {
    String template = value;

    // Plural selection
    if (count != null && pluralForms.isNotEmpty) {
      final form = _pluralForm(count);
      template = pluralForms[form] ?? pluralForms['other'] ?? value;
      // Replace {count} placeholder
      template = template.replaceAll('{count}', count.toString());
    }

    // Named arg interpolation: {name}, {amount}, etc.
    if (args != null) {
      for (final e in args.entries) {
        template = template.replaceAll('{${e.key}}', e.value.toString());
      }
    }

    return template;
  }

  static String _pluralForm(int n) {
    if (n == 0) return 'zero';
    if (n == 1) return 'one';
    if (n == 2) return 'two';
    if (n >= 3 && n <= 10) return 'few';
    if (n >= 11 && n <= 99) return 'many';
    return 'other';
  }
}

// ─────────────────────────────────────────────
// Translation catalog
// ─────────────────────────────────────────────

/// A single locale's complete set of translations.
class TranslationCatalog {
  const TranslationCatalog({
    required this.locale,
    required this.messages,
    this.textDirection = TextDirection.ltr,
  });

  final Locale locale;
  final Map<String, TranslationMessage> messages;
  final TextDirection textDirection;

  bool get isRtl => textDirection == TextDirection.rtl;

  String? get(
    String key, {
    int? count,
    Map<String, dynamic>? args,
    String? fallback,
  }) {
    final msg = messages[key];
    if (msg == null) return fallback;
    return msg.resolve(count: count, args: args);
  }

  /// Build catalog from a flat map (key → value). Fast for simple catalogs.
  factory TranslationCatalog.fromMap(
    Locale locale,
    Map<String, dynamic> raw, {
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final messages = <String, TranslationMessage>{};

    for (final entry in raw.entries) {
      if (entry.value is String) {
        messages[entry.key] = TranslationMessage(
          key: entry.key,
          value: entry.value as String,
        );
      } else if (entry.value is Map) {
        final m = Map<String, dynamic>.from(entry.value as Map);
        final value = m['value'] as String? ?? m['one'] as String? ?? '';
        final plurals = <String, String>{};
        for (final form in ['zero', 'one', 'two', 'few', 'many', 'other']) {
          if (m[form] is String) plurals[form] = m[form] as String;
        }
        messages[entry.key] = TranslationMessage(
          key: entry.key,
          value: value,
          pluralForms: plurals,
          description: m['description'] as String?,
        );
      }
    }

    return TranslationCatalog(
      locale: locale,
      messages: messages,
      textDirection: textDirection,
    );
  }
}

// ─────────────────────────────────────────────
// Built-in catalogs (framework strings)
// ─────────────────────────────────────────────

class BuiltinCatalogs {
  static const _enUS = {
    // Chat UI
    'chat.inputHint': 'Message…',
    'chat.sendButton': 'Send',
    'chat.typingIndicator': 'Agent is thinking…',
    'chat.errorRetry': 'Something went wrong. Tap to retry.',
    'chat.empty': 'Start a conversation',
    'chat.loadMore': 'Load more',
    'chat.newMessages': '{count} new messages',

    // Agent status
    'agent.thinking': 'Thinking…',
    'agent.streaming': 'Generating…',
    'agent.callingTool': 'Using tool: {tool}',
    'agent.done': 'Done',
    'agent.error': 'Agent error',

    // Validation
    'validation.required': 'This field is required',
    'validation.invalidEmail': 'Enter a valid email address',
    'validation.tooShort': 'Minimum {min} characters',
    'validation.tooLong': 'Maximum {max} characters',

    // Actions
    'action.confirm': 'Confirm',
    'action.cancel': 'Cancel',
    'action.close': 'Close',
    'action.back': 'Back',
    'action.next': 'Next',
    'action.submit': 'Submit',
    'action.retry': 'Retry',

    // Accessibility
    'a11y.agentResponse': 'Agent responded',
    'a11y.loading': 'Loading content',
    'a11y.image': 'Image',
    'a11y.button': 'Button',
    'a11y.expandable': 'Expandable section',

    // Errors
    'error.network': 'No connection. Check your internet.',
    'error.timeout': 'Request timed out. Try again.',
    'error.unknown': 'Something went wrong.',
    'error.cacheExpired': 'Content outdated. Refreshing…',
  };

  static const _arSA = {
    'chat.inputHint': 'رسالة…',
    'chat.sendButton': 'إرسال',
    'chat.typingIndicator': 'الوكيل يفكر…',
    'chat.errorRetry': 'حدث خطأ. اضغط للمحاولة مجدداً.',
    'chat.empty': 'ابدأ محادثة',
    'chat.loadMore': 'تحميل المزيد',
    'agent.thinking': 'جارٍ التفكير…',
    'agent.streaming': 'جارٍ الإنشاء…',
    'action.confirm': 'تأكيد',
    'action.cancel': 'إلغاء',
    'action.close': 'إغلاق',
    'action.back': 'رجوع',
    'action.next': 'التالي',
    'action.submit': 'إرسال',
    'action.retry': 'إعادة المحاولة',
    'error.network': 'لا يوجد اتصال. تحقق من الإنترنت.',
    'error.timeout': 'انتهت مهلة الطلب. حاول مجدداً.',
    'error.unknown': 'حدث خطأ ما.',
  };

  static const _zhCN = {
    'chat.inputHint': '发送消息…',
    'chat.sendButton': '发送',
    'chat.typingIndicator': '助手正在思考…',
    'chat.errorRetry': '出错了，点击重试。',
    'chat.empty': '开始对话',
    'chat.loadMore': '加载更多',
    'agent.thinking': '思考中…',
    'agent.streaming': '生成中…',
    'action.confirm': '确认',
    'action.cancel': '取消',
    'action.close': '关闭',
    'action.back': '返回',
    'action.next': '下一步',
    'action.submit': '提交',
    'action.retry': '重试',
    'error.network': '无网络连接，请检查您的网络。',
    'error.timeout': '请求超时，请重试。',
    'error.unknown': '出现错误。',
  };

  static const _esES = {
    'chat.inputHint': 'Mensaje…',
    'chat.sendButton': 'Enviar',
    'chat.typingIndicator': 'El agente está pensando…',
    'chat.errorRetry': 'Algo salió mal. Toca para reintentar.',
    'chat.empty': 'Inicia una conversación',
    'chat.loadMore': 'Cargar más',
    'agent.thinking': 'Pensando…',
    'agent.streaming': 'Generando…',
    'action.confirm': 'Confirmar',
    'action.cancel': 'Cancelar',
    'action.close': 'Cerrar',
    'action.back': 'Atrás',
    'action.next': 'Siguiente',
    'action.submit': 'Enviar',
    'action.retry': 'Reintentar',
    'error.network': 'Sin conexión. Revisa tu internet.',
    'error.timeout': 'Tiempo de espera agotado. Intenta de nuevo.',
    'error.unknown': 'Algo salió mal.',
  };

  static const _frFR = {
    'chat.inputHint': 'Message…',
    'chat.sendButton': 'Envoyer',
    'chat.typingIndicator': 'L\'agent réfléchit…',
    'chat.errorRetry': 'Une erreur est survenue. Appuyez pour réessayer.',
    'chat.empty': 'Commencer une conversation',
    'action.confirm': 'Confirmer',
    'action.cancel': 'Annuler',
    'action.close': 'Fermer',
    'action.back': 'Retour',
    'action.next': 'Suivant',
    'action.submit': 'Soumettre',
    'action.retry': 'Réessayer',
    'error.network': 'Pas de connexion. Vérifiez votre réseau.',
    'error.unknown': 'Une erreur s\'est produite.',
  };

  static const _deDE = {
    'chat.inputHint': 'Nachricht…',
    'chat.sendButton': 'Senden',
    'chat.typingIndicator': 'Agent denkt nach…',
    'chat.errorRetry': 'Fehler aufgetreten. Tippen zum Wiederholen.',
    'chat.empty': 'Gespräch beginnen',
    'action.confirm': 'Bestätigen',
    'action.cancel': 'Abbrechen',
    'action.close': 'Schließen',
    'action.back': 'Zurück',
    'action.next': 'Weiter',
    'action.submit': 'Absenden',
    'action.retry': 'Erneut versuchen',
    'error.network': 'Keine Verbindung. Internet prüfen.',
    'error.unknown': 'Etwas ist schiefgelaufen.',
  };

  static const _jaJP = {
    'chat.inputHint': 'メッセージ…',
    'chat.sendButton': '送信',
    'chat.typingIndicator': 'エージェントが考えています…',
    'chat.errorRetry': 'エラーが発生しました。タップして再試行。',
    'chat.empty': '会話を始める',
    'action.confirm': '確認',
    'action.cancel': 'キャンセル',
    'action.close': '閉じる',
    'action.back': '戻る',
    'action.next': '次へ',
    'action.submit': '送信',
    'action.retry': '再試行',
    'error.network': '接続がありません。インターネットを確認してください。',
    'error.unknown': 'エラーが発生しました。',
  };

  static const _ptBR = {
    'chat.inputHint': 'Mensagem…',
    'chat.sendButton': 'Enviar',
    'chat.typingIndicator': 'O agente está pensando…',
    'chat.empty': 'Iniciar uma conversa',
    'action.confirm': 'Confirmar',
    'action.cancel': 'Cancelar',
    'action.close': 'Fechar',
    'action.back': 'Voltar',
    'action.next': 'Próximo',
    'action.submit': 'Enviar',
    'action.retry': 'Tentar novamente',
    'error.unknown': 'Algo deu errado.',
  };

  static const _koKR = {
    'chat.inputHint': '메시지…',
    'chat.sendButton': '전송',
    'chat.typingIndicator': '에이전트가 생각 중…',
    'chat.empty': '대화 시작하기',
    'action.confirm': '확인',
    'action.cancel': '취소',
    'action.close': '닫기',
    'action.back': '뒤로',
    'action.next': '다음',
    'action.submit': '제출',
    'action.retry': '다시 시도',
    'error.unknown': '오류가 발생했습니다.',
  };

  /// All built-in catalogs keyed by language tag.
  static Map<String, Map<String, dynamic>> get all => {
        'en': _enUS,
        'en_US': _enUS,
        'ar': _arSA,
        'ar_SA': _arSA,
        'zh': _zhCN,
        'zh_CN': _zhCN,
        'es': _esES,
        'es_ES': _esES,
        'fr': _frFR,
        'fr_FR': _frFR,
        'de': _deDE,
        'de_DE': _deDE,
        'ja': _jaJP,
        'ja_JP': _jaJP,
        'pt': _ptBR,
        'pt_BR': _ptBR,
        'ko': _koKR,
        'ko_KR': _koKR,
      };

  static const _rtlLanguages = {'ar', 'he', 'fa', 'ur', 'yi', 'dv'};

  static bool isRtl(String languageCode) =>
      _rtlLanguages.contains(languageCode.toLowerCase());
}

// ─────────────────────────────────────────────
// Locale store (Riverpod provider)
// ─────────────────────────────────────────────

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Default to device locale
    return PlatformDispatcher.instance.locale;
  }

  void setLocale(Locale locale) => state = locale;

  void setFromLanguageTag(String tag) {
    final parts = tag.split(RegExp(r'[-_]'));
    state = parts.length >= 2
        ? Locale(parts[0], parts[1].toUpperCase())
        : Locale(parts[0]);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

// ─────────────────────────────────────────────
// Localization manager
// ─────────────────────────────────────────────

class AgentLocalizationManager {
  AgentLocalizationManager({
    Map<String, TranslationCatalog>? catalogs,
    this.fallbackLocale = const Locale('en', 'US'),
  }) {
    // Seed with built-ins
    for (final entry in BuiltinCatalogs.all.entries) {
      final parts = entry.key.split('_');
      final locale = parts.length >= 2
          ? Locale(parts[0], parts[1])
          : Locale(parts[0]);
      _catalogs[entry.key] = TranslationCatalog.fromMap(
        locale,
        entry.value,
        textDirection: BuiltinCatalogs.isRtl(parts[0])
            ? TextDirection.rtl
            : TextDirection.ltr,
      );
    }
    // Merge user-provided catalogs (can override built-ins)
    if (catalogs != null) {
      _catalogs.addAll(catalogs);
    }
  }

  final Locale fallbackLocale;
  final _catalogs = <String, TranslationCatalog>{};

  /// Register or replace a catalog.
  void register(String languageTag, TranslationCatalog catalog) {
    _catalogs[languageTag] = catalog;
  }

  /// Register from a flat JSON map.
  void registerMap(
    String languageTag,
    Map<String, dynamic> raw, {
    TextDirection? textDirection,
  }) {
    final parts = languageTag.split(RegExp(r'[-_]'));
    final locale = parts.length >= 2
        ? Locale(parts[0], parts[1].toUpperCase())
        : Locale(parts[0]);
    _catalogs[languageTag] = TranslationCatalog.fromMap(
      locale,
      raw,
      textDirection: textDirection ??
          (BuiltinCatalogs.isRtl(parts[0])
              ? TextDirection.rtl
              : TextDirection.ltr),
    );
  }

  // ── Locale negotiation ────────────────────────

  /// Find the best-fit catalog for [locale].
  TranslationCatalog resolve(Locale locale) {
    // 1. Exact match: "zh_CN"
    final exact = _catalogs['${locale.languageCode}_${locale.countryCode}'];
    if (exact != null) return exact;

    // 2. Language-only match: "zh"
    final lang = _catalogs[locale.languageCode];
    if (lang != null) return lang;

    // 3. Any catalog sharing the language code
    final partial = _catalogs.values
        .where((c) => c.locale.languageCode == locale.languageCode)
        .firstOrNull;
    if (partial != null) return partial;

    // 4. Fallback
    return _catalogs['en_US'] ??
        _catalogs['en'] ??
        TranslationCatalog(
          locale: fallbackLocale,
          messages: {},
        );
  }

  /// Translate a key for [locale].
  String t(
    String key,
    Locale locale, {
    int? count,
    Map<String, dynamic>? args,
    String? fallback,
  }) {
    final catalog = resolve(locale);
    return catalog.get(key, count: count, args: args) ??
        // Try fallback locale
        resolve(fallbackLocale).get(key, count: count, args: args) ??
        fallback ??
        key; // last resort: return the key itself
  }

  TextDirection directionFor(Locale locale) =>
      resolve(locale).textDirection;

  List<Locale> get supportedLocales =>
      _catalogs.values.map((c) => c.locale).toList();

  /// System prompt section — tells the agent which locale to use.
  String toSystemPromptSection(Locale locale) {
    final catalog = resolve(locale);
    final dir = catalog.isRtl ? 'right-to-left (RTL)' : 'left-to-right (LTR)';
    final tag = locale.countryCode != null
        ? '${locale.languageCode}-${locale.countryCode}'
        : locale.languageCode;

    return '''
## Localization

Current locale: $tag ($dir)
IMPORTANT: Respond with ALL text content in the language of locale "$tag".
Use proper grammar, number formatting, and date formats for this locale.
Text direction: $dir — for RTL locales, align text and layouts accordingly.
Do not mix languages within a single response.
''';
  }
}

// ─────────────────────────────────────────────
// Riverpod provider for localization manager
// ─────────────────────────────────────────────

final localizationManagerProvider = Provider<AgentLocalizationManager>((ref) {
  return AgentLocalizationManager();
});

// ─────────────────────────────────────────────
// InheritedWidget scope
// ─────────────────────────────────────────────

class AgentLocalizationScope extends InheritedWidget {
  const AgentLocalizationScope({
    super.key,
    required this.manager,
    required this.locale,
    required super.child,
  });

  final AgentLocalizationManager manager;
  final Locale locale;

  static AgentLocalizationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AgentLocalizationScope>();

  static AgentLocalizationScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null,
        'No AgentLocalizationScope found. Wrap your app with AgentLocalizationScope.');
    return scope!;
  }

  /// Translate a key using the current locale.
  String t(
    String key, {
    int? count,
    Map<String, dynamic>? args,
    String? fallback,
  }) =>
      manager.t(key, locale, count: count, args: args, fallback: fallback);

  TextDirection get textDirection => manager.directionFor(locale);

  @override
  bool updateShouldNotify(AgentLocalizationScope old) =>
      locale != old.locale || manager != old.manager;
}

/// Extension for easy access anywhere in the tree.
extension AgentL10nContext on BuildContext {
  AgentLocalizationScope get l10n => AgentLocalizationScope.of(this);

  String t(String key, {int? count, Map<String, dynamic>? args, String? fallback}) =>
      AgentLocalizationScope.of(this)
          .t(key, count: count, args: args, fallback: fallback);

  TextDirection get agentTextDirection =>
      AgentLocalizationScope.of(this).textDirection;

  bool get isRtl =>
      AgentLocalizationScope.of(this).textDirection == TextDirection.rtl;
}

// ─────────────────────────────────────────────
// Locale-aware date/number formatters
// ─────────────────────────────────────────────

class AgentNumberFormatter {
  AgentNumberFormatter(this.locale);
  final Locale locale;

  String formatNumber(num value, {int? decimals}) {
    // Simple locale-aware formatting
    final isArabic = locale.languageCode == 'ar';
    final separator = _thousandSeparator;
    final decimal = _decimalSeparator;

    String result;
    if (decimals != null) {
      result = value.toStringAsFixed(decimals);
    } else {
      result = value.toString();
    }

    // Apply decimal separator
    result = result.replaceAll('.', decimal);

    return result;
  }

  String formatCurrency(num amount, String currencyCode) {
    final formatted = formatNumber(amount, decimals: 2);
    final symbol = _currencySymbol(currencyCode);
    return _currencyFormat(symbol, formatted);
  }

  String formatPercent(double value) =>
      '${formatNumber(value * 100, decimals: 1)}%';

  String get _decimalSeparator {
    const commaLocales = {'de', 'fr', 'es', 'it', 'pt', 'nl', 'sv', 'da'};
    return commaLocales.contains(locale.languageCode) ? ',' : '.';
  }

  String get _thousandSeparator {
    const spaceLocales = {'fr', 'sv', 'no', 'fi'};
    if (spaceLocales.contains(locale.languageCode)) return '\u202F'; // narrow no-break space
    const commaLocales = {'de', 'es', 'it', 'pt', 'nl'};
    return commaLocales.contains(locale.languageCode) ? '.' : ',';
  }

  String _currencySymbol(String code) => const {
        'USD': '\$',
        'EUR': '€',
        'GBP': '£',
        'JPY': '¥',
        'CNY': '¥',
        'KRW': '₩',
        'INR': '₹',
        'BRL': 'R\$',
        'RUB': '₽',
        'CHF': 'CHF',
        'CAD': 'CA\$',
        'AUD': 'A\$',
        'SAR': 'SAR',
        'AED': 'AED',
      }[code] ??
      code;

  String _currencyFormat(String symbol, String amount) {
    // Some locales put the symbol after the amount
    const postfixLocales = {'de', 'fr', 'sv', 'da', 'no', 'fi', 'hu'};
    if (postfixLocales.contains(locale.languageCode)) {
      return '$amount\u00A0$symbol';
    }
    return '$symbol$amount';
  }
}

class AgentDateFormatter {
  AgentDateFormatter(this.locale);
  final Locale locale;

  String formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');

    return switch (locale.languageCode) {
      'en' when locale.countryCode == 'US' => '$m/$d/$y',
      'en' => '$d/$m/$y',
      'ja' || 'zh' || 'ko' => '$y年$m月$d日',
      'de' || 'at' || 'ch' => '$d.$m.$y',
      'fr' => '$d/$m/$y',
      'ar' => '$d/$m/$y',
      _ => '$d/$m/$y',
    };
  }

  String formatTime(DateTime time, {bool use24h = false}) {
    final h = use24h ? time.hour : (time.hour % 12 == 0 ? 12 : time.hour % 12);
    final m = time.minute.toString().padLeft(2, '0');
    if (use24h) return '$h:$m';
    final ampm = time.hour < 12 ? 'AM' : 'PM';

    return switch (locale.languageCode) {
      'ja' => '${time.hour}時$m分',
      'zh' => '${time.hour}:$m',
      'ar' => '$h:$m $ampm',
      _ => '$h:$m $ampm',
    };
  }

  String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return t('time.justNow');
    if (diff.inMinutes < 60) return t('time.minutesAgo', args: {'n': diff.inMinutes});
    if (diff.inHours < 24) return t('time.hoursAgo', args: {'n': diff.inHours});
    if (diff.inDays == 1) return t('time.yesterday');
    if (diff.inDays < 7) return t('time.daysAgo', args: {'n': diff.inDays});
    return formatDate(date);
  }

  String t(String key, {Map<String, dynamic>? args}) {
    // Simple built-in relative time strings
    final strings = <String, Map<String, String>>{
      'time.justNow': {'en': 'Just now', 'ar': 'الآن', 'zh': '刚才', 'ja': 'たった今', 'es': 'Ahora mismo', 'fr': 'À l\'instant', 'de': 'Gerade eben'},
      'time.minutesAgo': {'en': '{n}m ago', 'ar': 'منذ {n} دقيقة', 'zh': '{n}分钟前', 'ja': '{n}分前', 'es': 'Hace {n}m', 'fr': 'Il y a {n}min', 'de': 'Vor {n}Min'},
      'time.hoursAgo': {'en': '{n}h ago', 'ar': 'منذ {n} ساعة', 'zh': '{n}小时前', 'ja': '{n}時間前', 'es': 'Hace {n}h', 'fr': 'Il y a {n}h', 'de': 'Vor {n}Std'},
      'time.yesterday': {'en': 'Yesterday', 'ar': 'أمس', 'zh': '昨天', 'ja': '昨日', 'es': 'Ayer', 'fr': 'Hier', 'de': 'Gestern'},
      'time.daysAgo': {'en': '{n} days ago', 'ar': 'منذ {n} أيام', 'zh': '{n}天前', 'ja': '{n}日前', 'es': 'Hace {n} días', 'fr': 'Il y a {n} jours', 'de': 'Vor {n} Tagen'},
    };

    var result = strings[key]?[locale.languageCode] ??
        strings[key]?['en'] ??
        key;

    if (args != null) {
      for (final e in args.entries) {
        result = result.replaceAll('{${e.key}}', e.value.toString());
      }
    }
    return result;
  }
}

// ─────────────────────────────────────────────
// Node text resolver with localization
// ─────────────────────────────────────────────

/// Resolves text in a node using translation key syntax.
/// Agents can emit: "text": "@t:chat.inputHint" to use a translation key.
class NodeTextResolver {
  NodeTextResolver({required this.manager, required this.locale});

  final AgentLocalizationManager manager;
  final Locale locale;

  static const _keyPrefix = '@t:';

  String resolve(String raw, {Map<String, dynamic>? args}) {
    if (raw.startsWith(_keyPrefix)) {
      final key = raw.substring(_keyPrefix.length);
      return manager.t(key, locale, args: args);
    }
    return raw;
  }

  bool isTranslationKey(String raw) => raw.startsWith(_keyPrefix);
}
