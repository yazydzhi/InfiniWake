# AGENTS — InfiniWake

Сборка, запуск и границы этого репозитория. Канон продукта и сайта — в локальных документах (в git не входят):

- `/Users/azg/docs/9-Tools/InfiniWake/README.md`
- `/Users/azg/docs/9-Tools/InfiniWake/product.md`
- `/Users/azg/docs/9-Tools/InfiniWake/site.md`

## Запуск

```bash
./scripts/build-app.sh
./scripts/build-dmg.sh 1.1.6
./scripts/install-helper.sh
cd web && python3 -m http.server 8765
```

Деплой сайта — только по явной просьбе: `./web/deploy.sh`.

## Границы

- Публичные тексты без имён конкурентов и чужих брендов.
- Не добавлять телеметрию, аккаунты и рекламу.
- Helper принимает только `on`, `off`, `display-sleep`.
- Версия — `Sources/InfiniWake/AppInfo.swift`.
