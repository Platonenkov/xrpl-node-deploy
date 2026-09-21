# XRPL Node Config Pack

Этот набор конфигураций помогает быстро выбрать режим работы вашей ноды XRPL:

| Конфиг | История | Диск | RAM | Назначение |
|-------|---------|------|-----|-------------|
| `rippled-light.cfg` | 5–10 мин | 6–12 GB | 2–4 GB | Кошельки, сервисы |
| `rippled-api.cfg` | 2–3 часа | 50–150 GB | 4–8 GB | Backend/API |
| `rippled-extended.cfg` | 24 часа | 400–800 GB | 8–16 GB | Аналитика |
| `rippled-validator.cfg` | 30–60 мин | 20–50 GB | 16–32 GB | Валидатор |
| `rippled-full.cfg` | Full History | 12–20 TB | 64–128 GB | Архив/XRPL Explorer |

## Как использовать

1. Поместите нужный конфиг под именем: `/etc/xrpld/xrpld.cfg`

2. Перезапустите сервис: `sudo systemctl restart xrpld`

3. Проверка: `rippled server_info`

после добавления поправок для их активации надо сбросить все т.к. они запускаются только на 1 запуске в 1 леджере

```
docker compose down
rm -rf ./data-standalone/*
docker compose up -d
```