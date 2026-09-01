// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'LinkSo';

  @override
  String get homeTitle => 'Короткие ссылки, которые работают по вашим правилам';

  @override
  String get homeDescription =>
      'Создавайте мгновенные, защищённые паролем и рекламные ссылки, настраивайте срок действия и отслеживайте переходы в одном LinkSo.';

  @override
  String get shortenTitle => 'Сократить ссылку';

  @override
  String get shortenDescription => 'Создайте компактный адрес LinkSo для любой HTTP- или HTTPS-ссылки.';

  @override
  String get targetUrlLabel => 'Целевая ссылка';

  @override
  String get targetUrlHint => 'https://example.com/article';

  @override
  String get targetUrlRequired => 'Введите целевую ссылку';

  @override
  String get targetUrlTooLong => 'Ссылка не должна превышать 2048 символов';

  @override
  String get targetUrlInvalid => 'Введите полный адрес, например https://example.com';

  @override
  String get targetUrlUnsupportedScheme => 'Поддерживаются только HTTP- и HTTPS-ссылки';

  @override
  String get linkModeLabel => 'Тип ссылки';

  @override
  String get directModeTitle => 'Обычная';

  @override
  String get directModeDescription => 'Мгновенно перенаправляет на целевой сайт.';

  @override
  String get passwordModeTitle => 'С паролем';

  @override
  String get passwordModeDescription => 'Перед переходом запрашивает пароль.';

  @override
  String get advertisingModeTitle => 'С рекламой';

  @override
  String get advertisingModeDescription => 'Показывает рекламу и активирует кнопку «Перейти» через 5 секунд.';

  @override
  String get linkTitleLabel => 'Название (необязательно)';

  @override
  String get linkTitleHint => 'Статья для команды';

  @override
  String get linkTitleTooLong => 'Название не должно превышать 120 символов';

  @override
  String get customSlugLabel => 'Собственный slug (необязательно)';

  @override
  String get customSlugHint => 'moya-ssylka';

  @override
  String get customSlugSupporting => '3–64 буквы, цифры, дефисы или подчёркивания';

  @override
  String get customSlugTooShort => 'Slug должен содержать минимум 3 символа';

  @override
  String get customSlugTooLong => 'Slug не должен превышать 64 символа';

  @override
  String get customSlugInvalid =>
      'Используйте буквы, цифры, дефисы или подчёркивания; начните и закончите буквой или цифрой';

  @override
  String get customSlugReserved => 'Этот slug зарезервирован LinkSo';

  @override
  String get expirationLabel => 'Срок действия (необязательно)';

  @override
  String get expirationAdd => 'Выбрать дату и время';

  @override
  String get expirationClear => 'Убрать срок действия';

  @override
  String get expirationNotFuture => 'Срок действия должен быть в будущем';

  @override
  String get passwordLabel => 'Пароль ссылки';

  @override
  String get passwordHint => 'Минимум 8 символов';

  @override
  String get passwordShow => 'Показать пароль';

  @override
  String get passwordHide => 'Скрыть пароль';

  @override
  String get passwordRequired => 'Введите пароль ссылки';

  @override
  String get passwordTooShort => 'Пароль должен содержать минимум 8 символов';

  @override
  String get passwordTooLong => 'Пароль не должен превышать 128 символов';

  @override
  String get passwordAccessTitle => 'Ссылка защищена паролем';

  @override
  String get passwordAccessDescription =>
      'Введите пароль ссылки, чтобы продолжить. Целевой адрес останется скрытым до проверки сервером.';

  @override
  String get passwordSessionLoading => 'Подготавливаем безопасный переход…';

  @override
  String get passwordSessionUnavailable => 'Защищённая ссылка или сессия перехода больше недоступна.';

  @override
  String get passwordIncorrect => 'Неверный пароль';

  @override
  String passwordTemporarilyLocked(int seconds) {
    return 'Слишком много попыток. Повторите через $seconds сек.';
  }

  @override
  String get passwordContinueAction => 'Перейти';

  @override
  String get passwordVerifyingAction => 'Проверяем…';

  @override
  String get tryAgainAction => 'Попробовать снова';

  @override
  String get advertisingSessionLoading => 'Загружаем рекламу…';

  @override
  String get advertisingSponsoredLabel => 'Реклама';

  @override
  String get advertisingPlaceholderTitle => 'Пока рекламы нет';

  @override
  String get advertisingImageLabel => 'Изображение рекламной кампании';

  @override
  String advertisingCountdown(int seconds) {
    return 'Кнопка «Перейти» появится через $seconds сек.';
  }

  @override
  String get advertisingConfirming => 'Подтверждаем таймер на сервере…';

  @override
  String get advertisingContinueAction => 'Перейти';

  @override
  String get advertisingUnavailableTitle => 'Реклама недоступна';

  @override
  String get advertisingUnavailableMessage => 'Сейчас для этой ссылки нет активной рекламной кампании.';

  @override
  String get advertisingSessionExpired => 'Рекламная сессия истекла. Запустите её снова.';

  @override
  String get createLinkAction => 'Создать ссылку';

  @override
  String get creatingLinkAction => 'Создаём…';

  @override
  String get networkError => 'Сервер недоступен. Проверьте соединение и попробуйте снова.';

  @override
  String get requestTimeoutError =>
      'Время ожидания истекло. Проверьте соединение и результат операции перед повторной попыткой.';

  @override
  String get unexpectedError => 'Не удалось создать ссылку. Попробуйте снова.';

  @override
  String get linkSoTargetNotAllowed => 'Адрес LinkSo нельзя использовать как целевой';

  @override
  String get slugTaken => 'Этот slug уже занят';

  @override
  String requestReference(String requestId) {
    return 'Идентификатор запроса: $requestId';
  }

  @override
  String get resultTitle => 'Ссылка готова';

  @override
  String get shortUrlLabel => 'Короткая ссылка';

  @override
  String get copyLinkAction => 'Копировать ссылку';

  @override
  String get linkCopied => 'Ссылка скопирована';

  @override
  String get downloadQrAction => 'Сохранить или поделиться QR';

  @override
  String get createAnotherAction => 'Создать ещё одну ссылку';

  @override
  String get qrCodeLabel => 'QR-код короткой ссылки';

  @override
  String get notFoundTitle => 'Страница не найдена';

  @override
  String get notFoundMessage => 'Запрошенная страница или короткая ссылка не существует.';

  @override
  String get expiredTitle => 'Срок ссылки истёк';

  @override
  String get expiredMessage => 'Срок действия этой короткой ссылки уже закончился.';

  @override
  String get disabledTitle => 'Ссылка отключена';

  @override
  String get disabledMessage => 'Владелец временно отключил эту короткую ссылку.';

  @override
  String get blockedTitle => 'Ссылка заблокирована';

  @override
  String get blockedMessage => 'Эта короткая ссылка недоступна, потому что была заблокирована.';

  @override
  String get loginTitle => 'Вход';

  @override
  String get loginDescription => 'Используйте подтверждённый email и пароль, чтобы открыть свои ссылки.';

  @override
  String get loginAction => 'Войти';

  @override
  String get registerTitle => 'Создать аккаунт';

  @override
  String get registerDescription => 'Зарегистрируйтесь по email с паролем не короче 12 символов.';

  @override
  String get registerAction => 'Создать аккаунт';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailInvalid => 'Введите корректный email';

  @override
  String get accountPasswordLabel => 'Пароль';

  @override
  String get accountPasswordTooShort => 'Пароль должен содержать минимум 12 символов';

  @override
  String get passwordConfirmationLabel => 'Повторите пароль';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get authWorking => 'Подождите…';

  @override
  String get backToLoginAction => 'Вернуться ко входу';

  @override
  String get verificationSent => 'Аккаунт создан. Перейдите по ссылке из письма, чтобы активировать его.';

  @override
  String get verifyEmailTitle => 'Подтверждение email';

  @override
  String get verifyEmailDescription =>
      'Подтвердите почту по ссылке из письма. Если ссылка истекла, запросите новое письмо.';

  @override
  String get verificationTokenLabel => 'Код подтверждения';

  @override
  String get verifyEmailAction => 'Подтвердить email';

  @override
  String get emailVerified => 'Email подтверждён. Теперь можно войти.';

  @override
  String get passwordResetTitle => 'Восстановление пароля';

  @override
  String get passwordResetDescription =>
      'Запросите письмо для восстановления или задайте новый пароль, открыв ссылку из письма.';

  @override
  String get resendVerificationAction => 'Отправить подтверждение повторно';

  @override
  String get resendVerificationDescription =>
      'Введите почту, указанную при регистрации. Новая ссылка заменит предыдущую.';

  @override
  String get verificationResendRequested =>
      'Если для этого адреса есть неподтверждённый аккаунт, скоро придёт письмо. Проверьте входящие и спам. Если письма нет, попробуйте позже.';

  @override
  String get resetEmailRequested =>
      'Если для этого адреса есть активный аккаунт, скоро придёт письмо для сброса пароля. Проверьте входящие и спам. Если письма нет, попробуйте позже.';

  @override
  String get emailChangeLinkDescription =>
      'Подтвердите смену почты для этого аккаунта. Продолжайте, только если сами запрашивали смену.';

  @override
  String get passwordResetAction => 'Забыли пароль?';

  @override
  String get sendResetAction => 'Отправить ссылку';

  @override
  String get resetTokenLabel => 'Код восстановления';

  @override
  String get setNewPasswordAction => 'Задать новый пароль';

  @override
  String get passwordResetComplete => 'Пароль изменён, все прежние сессии завершены.';

  @override
  String get accountTitle => 'Аккаунт';

  @override
  String get logoutAction => 'Выйти';

  @override
  String get logoutAllAction => 'Выйти на всех устройствах';

  @override
  String get invalidCredentials => 'Неверный email или пароль';

  @override
  String get emailNotVerified => 'Подтвердите email перед входом';

  @override
  String get emailTaken => 'Аккаунт с таким email уже существует';

  @override
  String get authTemporarilyLimited => 'Слишком много попыток. Повторите позже.';

  @override
  String get authTokenInvalid => 'Код недействителен или его срок истёк';

  @override
  String get authUnexpectedError => 'Не удалось выполнить запрос. Попробуйте ещё раз.';

  @override
  String get myLinksTitle => 'Мои ссылки';

  @override
  String get myLinksDescription => 'Ищите, редактируйте и управляйте ссылками этого аккаунта.';

  @override
  String get refreshAction => 'Обновить';

  @override
  String get myLinksSearchLabel => 'Поиск по названию, slug или целевому URL';

  @override
  String get myLinksStatusLabel => 'Статус';

  @override
  String get filterAll => 'Все';

  @override
  String get expirationNotExpired => 'Не истекли';

  @override
  String get expirationExpired => 'Истекли';

  @override
  String get expirationNever => 'Без срока';

  @override
  String get sortLabel => 'Сортировка';

  @override
  String get sortCreatedAt => 'Дата создания';

  @override
  String get sortRedirectCount => 'Количество переходов';

  @override
  String get sortDirectionAction => 'Изменить направление сортировки';

  @override
  String get applyFiltersAction => 'Применить';

  @override
  String get clearFiltersAction => 'Сбросить';

  @override
  String get redirectCountLabel => 'Переходы';

  @override
  String get createdAtLabel => 'Создана';

  @override
  String get actionsLabel => 'Действия';

  @override
  String redirectCountValue(int count) {
    return 'Переходов: $count';
  }

  @override
  String paginationLabel(int page, int pages) {
    return 'Страница $page из $pages';
  }

  @override
  String get showQrAction => 'Показать QR-код';

  @override
  String get editAction => 'Редактировать';

  @override
  String get enableAction => 'Включить';

  @override
  String get disableAction => 'Отключить';

  @override
  String get deleteAction => 'Удалить';

  @override
  String get closeAction => 'Закрыть';

  @override
  String get cancelAction => 'Отмена';

  @override
  String get saveAction => 'Сохранить';

  @override
  String get statusActive => 'Активна';

  @override
  String get statusDisabled => 'Отключена';

  @override
  String get statusBlocked => 'Заблокирована';

  @override
  String get myLinksEmpty => 'У вас пока нет ссылок.';

  @override
  String get myLinksFilteredEmpty => 'По выбранным фильтрам ссылки не найдены.';

  @override
  String get myLinksLoadError => 'Не удалось загрузить ссылки. Попробуйте ещё раз.';

  @override
  String get enableLinkTitle => 'Включить ссылку?';

  @override
  String get enableLinkMessage => 'Публичная ссылка снова станет доступна.';

  @override
  String get disableLinkTitle => 'Отключить ссылку?';

  @override
  String get disableLinkMessage => 'Посетители не смогут перейти по ней, пока вы снова её не включите.';

  @override
  String get deleteLinkTitle => 'Удалить ссылку?';

  @override
  String get deleteLinkMessage =>
      'Ссылка перестанет работать и исчезнет из списка. В интерфейсе отменить это действие нельзя.';

  @override
  String get editLinkTitle => 'Редактировать ссылку';

  @override
  String get editPasswordSupporting => 'Оставьте пустым, чтобы сохранить текущий пароль.';

  @override
  String get editLinkError => 'Не удалось сохранить ссылку. Проверьте поля и попробуйте ещё раз.';

  @override
  String get customSlugRequired => 'Введите slug';

  @override
  String get tagsLabel => 'Теги';

  @override
  String get tagsHint => 'работа, запуск продукта';

  @override
  String get tagsSupporting => 'Разделяйте теги запятыми. До 10 тегов по 32 символа.';

  @override
  String get tagsAccountSupporting => 'Необязательно, доступно после входа. Разделяйте теги запятыми.';

  @override
  String get tagTooLong => 'Тег должен быть не длиннее 32 символов';

  @override
  String get tooManyTags => 'У ссылки может быть не больше 10 тегов';

  @override
  String get invalidTag => 'Введите корректные названия тегов';

  @override
  String get tagsAuthenticationRequired => 'Войдите, чтобы создать ссылку с тегами';

  @override
  String tagFilterValue(String name, int count) {
    return '$name ($count)';
  }

  @override
  String get analyticsTitle => 'Аналитика';

  @override
  String get analyticsDescription => 'Реальные переходы за выбранный период. Автоматический трафик показан отдельно.';

  @override
  String linkAnalyticsTitle(String name) {
    return 'Аналитика: $name';
  }

  @override
  String get analyticsAction => 'Открыть аналитику';

  @override
  String get analyticsLinks => 'Ссылки';

  @override
  String get analyticsHumanRedirects => 'Переходы людей';

  @override
  String get analyticsBotRedirects => 'Переходы ботов';

  @override
  String get analyticsByDay => 'Переходы по дням';

  @override
  String get advertisingFunnelTitle => 'Рекламная воронка';

  @override
  String get advertisingImpressions => 'Показы';

  @override
  String get advertisingTimerCompletions => 'Таймер завершён';

  @override
  String get advertisingRedirects => 'Переходы после рекламы';

  @override
  String get analyticsLoadError => 'Не удалось загрузить аналитику. Попробуйте ещё раз.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsDescription => 'Просматривайте профиль и управляйте текущей сессией аккаунта.';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileId => 'ID аккаунта';

  @override
  String get profileCreatedAt => 'Дата регистрации';

  @override
  String get emailVerificationLabel => 'Подтверждение email';

  @override
  String get emailVerificationConfirmed => 'Подтверждён';

  @override
  String get emailVerificationPending => 'Ожидает подтверждения';

  @override
  String get sessionSettingsTitle => 'Сессии';

  @override
  String get profileLoadError => 'Не удалось загрузить профиль. Попробуйте ещё раз.';

  @override
  String get displayNameLabel => 'Отображаемое имя';

  @override
  String get displayNameSupporting => 'Необязательно, до 120 символов.';

  @override
  String get displayNameInvalid => 'Введите отображаемое имя длиной до 120 символов.';

  @override
  String get appearanceSettingsTitle => 'Язык, тема и часовой пояс';

  @override
  String get languageLabel => 'Язык';

  @override
  String get themeLabel => 'Тема';

  @override
  String get timezoneLabel => 'Часовой пояс';

  @override
  String get preferenceSystem => 'Как в системе';

  @override
  String get languageEnglish => 'Английский';

  @override
  String get languageRussian => 'Русский';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeSystem => 'Системная';

  @override
  String get savePreferencesAction => 'Сохранить настройки';

  @override
  String get changeEmailTitle => 'Изменение email';

  @override
  String get changeEmailDescription =>
      'Новый адрес станет активным только после подтверждения. Остальные сессии будут завершены.';

  @override
  String get newEmailLabel => 'Новый email';

  @override
  String get currentPasswordLabel => 'Текущий пароль';

  @override
  String get requestEmailChangeAction => 'Запросить подтверждение';

  @override
  String get emailConfirmationTokenLabel => 'Код подтверждения';

  @override
  String get emailConfirmationTokenSupporting => 'Вставьте код из письма подтверждения.';

  @override
  String get confirmEmailChangeAction => 'Подтвердить новый email';

  @override
  String get emailChangeRequested => 'Подтверждение нового email запрошено.';

  @override
  String get emailChanged => 'Email изменён.';

  @override
  String get emailUnchanged => 'Введите email, отличный от текущего.';

  @override
  String get changePasswordTitle => 'Изменение пароля';

  @override
  String get newPasswordLabel => 'Новый пароль';

  @override
  String get changePasswordAction => 'Изменить пароль';

  @override
  String get passwordChanged => 'Пароль изменён. Остальные сессии завершены.';

  @override
  String get currentPasswordInvalid => 'Текущий пароль указан неверно.';

  @override
  String get currentSessionLabel => 'Текущая сессия';

  @override
  String get otherSessionLabel => 'Другая сессия';

  @override
  String sessionLastSeen(String date) {
    return 'Последняя активность: $date';
  }

  @override
  String get revokeSessionAction => 'Завершить сессию';

  @override
  String get sessionRevoked => 'Сессия завершена.';

  @override
  String get sessionsEmpty => 'Активных сессий нет.';

  @override
  String get sessionsLoadError => 'Не удалось загрузить активные сессии.';

  @override
  String get dangerZoneTitle => 'Опасная зона';

  @override
  String get deleteAccountTitle => 'Удалить аккаунт?';

  @override
  String get deleteAccountAction => 'Удалить аккаунт';

  @override
  String get deleteAccountConsequences =>
      'Аккаунт будет обезличен, а все принадлежащие ему ссылки отключены и удалены. Отменить действие нельзя.';

  @override
  String get deleteConfirmationLabel => 'Введите DELETE';

  @override
  String get deleteConfirmationInvalid => 'Для подтверждения введите DELETE без изменений.';

  @override
  String get settingsFieldsRequired => 'Заполните все обязательные поля.';

  @override
  String get settingsUnexpectedError => 'Не удалось изменить настройки. Попробуйте ещё раз.';
}
