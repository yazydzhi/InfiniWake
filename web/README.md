# InfiniWake web (лендинг + Store docs)

Статический сайт по образцу Convertik (`convertik.ponravilos.ru`): маркетинговая страница и юридические URL для Mac App Store.

## Структура

```
web/
├── index.html              # RU лендинг
├── privacy.html            # Политика конфиденциальности
├── terms.html              # Пользовательское соглашение
├── data.html               # Политика обработки данных
├── support.html            # Поддержка (Support URL)
├── en/                     # English mirrors
├── assets/css/styles.css
├── assets/img/             # favicon, apple-touch-icon, icon-512
├── APP_STORE_CONTENT.md    # тексты для App Store Connect
└── README.md
```

## Локальный просмотр

```bash
cd web && python3 -m http.server 8765
# http://127.0.0.1:8765/
```

## Публичные URL

Сейчас (основной домен, HTTPS готов):

- https://ponravilos.ru/infiniwake/
- https://ponravilos.ru/infiniwake/privacy.html
- https://ponravilos.ru/infiniwake/support.html
- https://ponravilos.ru/infiniwake/en/

Поддомен (Caddy уже настроен): `https://ponravilos.ru/infiniwake`  
Нужна A-запись в панели Hostkey DNS: имя `infiniwake`, тип A, значение `185.70.105.198`.

## Деплой

```bash
./web/deploy.sh
# → root@ponravilos.ru:/opt/www/html/infiniwake/
```

Тексты для ASC: [`APP_STORE_CONTENT.md`](./APP_STORE_CONTENT.md).
