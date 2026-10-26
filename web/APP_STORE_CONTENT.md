# Mac App Store — контент InfiniWake

Готовые тексты и ссылки для App Store Connect. Тексты написаны под **Store-версию** (песочница, флаг `APPSTORE`): в ней нет лампы Caps Lock, Accessibility и режима закрытой крышки — они только в версии для DMG. Не возвращать эти пункты в карточку, иначе описание не совпадёт с приложением.

## URLs (обязательные поля)

| Поле | URL |
|------|-----|
| Privacy Policy | https://ponravilos.ru/infiniwake/privacy.html |
| Support URL | https://ponravilos.ru/infiniwake/support.html |
| Marketing URL (опционально) | https://ponravilos.ru/infiniwake/ |
| Terms | https://ponravilos.ru/infiniwake/terms.html |
| Data policy | https://ponravilos.ru/infiniwake/data.html |

EN: `https://ponravilos.ru/infiniwake/en/…`

Поддомен https://infiniwake.ponravilos.ru/ живой (A `infiniwake` → `185.70.105.198`).

## App Privacy (questionnaire)

Рекомендуемый ответ при текущей архитектуре (без телеметрии/рекламы/аккаунтов):

- **Data Collection**: Data Not Collected
- **Tracking**: No
- Нет категорий Contact Info / Location / Identifiers / Usage Data / Diagnostics с отправкой разработчику

Примечание: добровольные письма в поддержку — вне приложения; в карточке App Privacy обычно не считаются «сбором приложением».

## Прочие поля

- Категория: Utilities (в Info.plist уже `public.app-category.utilities`)
- Цена: Free
- Encryption: своей криптографии нет, `ITSAppUsesNonExemptEncryption = NO` уже в Info.plist
- Copyright: `© 2026 Владимир Языджи`

## 🇷🇺 Русский

### Subtitle (до 30 символов)

```
Не даёт Mac заснуть
```

### Promotional Text (до 170 символов)

```
Держите Mac бодрствующим одним хоткеем. Таймер авто-выключения, значок ∞ в менюбаре, без рекламы и аккаунтов.
```

### Description

```
INFINIWAKE — KEEP AWAKE ДЛЯ MAC

InfiniWake живёт в менюбаре и не даёт Mac заснуть, пока вы работаете: сборки, долгие задачи, загрузки, презентации.

ЧТО УМЕЕТ
• Включение хоткеем (F4 по умолчанию) или кликом по иконке
• Таймер: ∞ или авто-выключение от 15 минут до 8 часов; по истечении Mac уходит в сон
• Стили иконки: ∞, лампа или ∞+лампа
• Язык интерфейса: русский / English / как в системе
• Опциональный запуск при входе в систему

ПРИВАТНОСТЬ
Настройки хранятся только на вашем Mac. Нет аккаунтов, рекламы и облачной аналитики.

ПОДДЕРЖКА
https://ponravilos.ru/infiniwake/support.html
```

### Keywords (через запятую, без пробелов после запятой, до 100 символов)

```
не засыпать,бодрствовать,сон,менюбар,таймер,хоткей,утилита,экран,keep awake,mac
```

## 🇺🇸 English

### Subtitle (до 30 символов)

```
Menu bar keep-awake
```

### Promotional Text

```
Keep your Mac awake with one hotkey. Auto-off timer, ∞ menu-bar icon, no ads, no accounts.
```

### Description

```
INFINIWAKE — KEEP AWAKE FOR MAC

InfiniWake lives in the menu bar and prevents sleep while you work: builds, long tasks, downloads, presentations.

FEATURES
• Toggle with a hotkey (F4 by default) or a click on the icon
• Timer: ∞ unlimited or auto-off from 15 minutes to 8 hours; when it ends, your Mac goes to sleep
• Icon styles: ∞, lamp, or ∞+lamp
• UI language: English / Russian / System
• Optional launch at login

PRIVACY
Settings stay on your Mac. No accounts, ads, or cloud analytics.

SUPPORT
https://ponravilos.ru/infiniwake/en/support.html
```

### Keywords

```
awake,keep awake,stay awake,prevent sleep,menu bar,sleep,mac,utility,timer,hotkey
```

Без имён чужих приложений и брендов (`caffeine` убран): это и правило проекта, и требование ревью к keywords.

## Скриншоты / иконка

- Иконка приложения: `Resources/AppIcon.icns` / `Resources/InfiniWake-icon-1024.png`
- Для лендинга: `web/assets/img/icon-512.png`
- Скриншоты Mac (минимум 1, до 10): 1280×800, 1440×900, 2560×1600 или 2880×1800. Снять меню приложения (менюбар) и окно настроек уже Store-версии, без лампы и без строки про helper. Положить в `web/assets/img/screens/`

## Заметки для ревьюера (App Review Information)

```
InfiniWake is a menu bar utility (LSUIElement, no Dock icon, no main window). Click the ∞ icon in the menu bar or press F4 to turn keep-awake on or off; right-click for the menu (timer, settings, about). It uses the public IOPMAssertion API to prevent idle sleep. When the timer ends it runs pmset sleepnow to put the Mac to sleep. No account is required, no data is collected, the app asks for no special permissions.
```

## Чеклист перед сабмитом

- [x] Задеплоить `web/` на https://ponravilos.ru/infiniwake/
- [x] A-запись `infiniwake` → `185.70.105.198`, https://infiniwake.ponravilos.ru/ отвечает 200
- [x] Privacy / Support URL открываются по HTTPS (проверено 26.10.2026)
- [x] Сборка 1.1.6 (9) загружена в App Store Connect (26.10.2026), валидация без ошибок
- [ ] Заполнить App Privacy: Data Not Collected
- [ ] Вставить Subtitle / Description / Keywords (RU и EN) и Promotional Text
- [ ] Приложить скриншоты Mac
- [ ] Выбрать build 9, указать Review Information, Submit for Review
