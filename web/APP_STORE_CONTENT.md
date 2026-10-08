# Mac App Store — контент InfiniWake

Готовые тексты и ссылки для App Store Connect.

## URLs (обязательные поля)

| Поле | URL |
|------|-----|
| Privacy Policy | https://ponravilos.ru/infiniwake/privacy.html |
| Support URL | https://ponravilos.ru/infiniwake/support.html |
| Marketing URL (опционально) | https://ponravilos.ru/infiniwake/ |
| Terms | https://ponravilos.ru/infiniwake/terms.html |
| Data policy | https://ponravilos.ru/infiniwake/data.html |

EN: `https://ponravilos.ru/infiniwake/en/…`

Поддомен `https://ponravilos.ru/infiniwake` настроен в Caddy; нужен A-запись в Hostkey DNS: `infiniwake` → `185.70.105.198`.

## App Privacy (questionnaire)

Рекомендуемый ответ при текущей архитектуре (без телеметрии/рекламы/аккаунтов):

- **Data Collection**: Data Not Collected
- **Tracking**: No
- Нет категорий Contact Info / Location / Identifiers / Usage Data / Diagnostics с отправкой разработчику

Примечание: добровольные письма в поддержку — вне приложения; в карточке App Privacy обычно не считаются «сбором приложением».

## 🇷🇺 Русский

### Subtitle (до 30 символов)

```
Keep Mac awake · менюбар
```

### Promotional Text (до 170 символов)

```
Держите Mac бодрствующим одним хоткеем. Caps Lock LED как индикатор, таймер авто-выключения, стили ∞ в менюбаре. Лёгкая утилита без рекламы.
```

### Description

```
INFINIWAKE — KEEP AWAKE ДЛЯ MAC

InfiniWake живёт в менюбаре и не даёт Mac заснуть, пока вы работаете: агенты, сборки, длинные задачи, презентации.

ЧТО УМЕЕТ
• Включение keep-awake хоткеем (F4 по умолчанию) или кликом по иконке
• Caps Lock как физическая лампа-индикатор — без настоящего CAPS в тексте (нужен Accessibility)
• Таймер: ∞ или авто-выключение от 15 минут до 8 часов
• Стили иконки: ∞, лампа или ∞+лампа
• Язык интерфейса: русский / English / как в системе
• Опциональный запуск при входе

ПРИВАТНОСТЬ
Настройки хранятся только на вашем Mac. Нет аккаунтов, рекламы и облачной аналитики.

ПОДДЕРЖКА
https://ponravilos.ru/infiniwake/support.html
```

### Keywords (через запятую, без пробелов после запятой по правилам ASC)

```
awake,caffeine,keep awake,menu bar,caps lock,pmset,sleep,mac,utility,timer
```

## 🇺🇸 English

### Subtitle

```
Menu bar keep-awake
```

### Promotional Text

```
Keep your Mac awake with one hotkey. Caps Lock LED as an indicator, auto-off timer, ∞ menu-bar styles. Lightweight, no ads.
```

### Description

```
INFINIWAKE — KEEP AWAKE FOR MAC

InfiniWake lives in the menu bar and prevents sleep while you work: agents, builds, long tasks, presentations.

FEATURES
• Toggle keep-awake with a hotkey (F4 by default) or a click on the icon
• Caps Lock as a physical LED indicator — without real CAPS typing (Accessibility required)
• Timer: ∞ unlimited or auto-off from 15 minutes to 8 hours
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
awake,caffeine,keep awake,menu bar,caps lock,pmset,sleep,mac,utility,timer
```

## Скриншоты / иконка

- Иконка приложения: `Resources/AppIcon.icns` / `Resources/InfiniWake-icon-1024.png`
- Для лендинга: `web/assets/img/icon-512.png`
- Скриншоты менюбара — снять на Mac (menu bar + Settings) перед сабмитом; положить в `web/assets/img/screens/` при появлении

## Чеклист перед сабмитом

- [x] Задеплоить `web/` на https://ponravilos.ru/infiniwake/
- [ ] (Опционально) A-запись `infiniwake` → `185.70.105.198` в Hostkey → https://ponravilos.ru/infiniwake
- [ ] Проверить открытие Privacy / Support URL без редиректов с ошибкой
- [ ] Заполнить App Privacy: Data Not Collected
- [ ] Вставить Subtitle / Description / Keywords
- [ ] Приложить скриншоты Mac
- [ ] Encryption: standard HTTPS only / exempt if applicable (нет кастомной криптографии сверх системного TLS для веб-страниц)
