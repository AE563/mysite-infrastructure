# mysite-infrastructure

## Что это

Общая инфраструктура для нескольких Django-проектов на одном VPS.

Вместо того чтобы каждый проект держал собственный PostgreSQL и Redis,
здесь они запущены один раз и доступны всем проектам через Docker-сеть `shared_net`.
nginx принимает запросы снаружи и направляет их в нужный контейнер по субдомену.

```
Интернет
    ↓
[nginx :80/:443]       ← этот репо
    ↓           ↓
[groceries_web] [trading_web] ...   ← отдельные репо проектов
    ↓
[shared_db]  [shared_redis]        ← этот репо
```

## Структура

```
docker-compose.yml      — nginx + postgres + redis + сеть shared_net
nginx/nginx.conf        — роутинг субдоменов + WebSocket-заголовки
init-db/01-init.sh      — создаёт БД при первом старте postgres
.env.example            — переменные (пароль postgres)
```

## Первый запуск на VPS

```bash
git clone git@github.com:AE563/mysite-infrastructure.git
cd mysite-infrastructure

cp .env.example .env
# Задать POSTGRES_PASSWORD в .env

docker compose up -d
```

После этого `shared_net`, `shared_db` и `shared_redis` готовы к использованию.

## Деплой проекта (например, home-shop-list)

```bash
cd ~/home-shop-list
cp .env.example .env
# Задать SECRET_KEY, DB_PASSWORD, DB_HOST=shared_db, REDIS_URL=redis://shared_redis:6379/0

docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec web python manage.py loaddata fixtures/units.json
docker compose -f docker-compose.prod.yml exec web python manage.py createsuperuser
```

## Добавление нового проекта

**1. Создать базу данных** — добавить строку в `init-db/01-init.sh`:
```bash
CREATE DATABASE trading_db;
```
Применяется только при первом старте postgres. Если postgres уже запущен:
```bash
docker exec -it shared_db psql -U postgres -c "CREATE DATABASE trading_db;"
```

**2. Добавить субдомен** — добавить блок в `nginx/nginx.conf`:
```nginx
server {
    listen 80;
    server_name trading.ae563.ru;

    location / {
        proxy_pass http://trading_web:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**3. Перезагрузить nginx:**
```bash
docker compose exec nginx nginx -s reload
```

## Имена контейнеров (DNS внутри shared_net)

| Контейнер | Hostname | Используется в |
|-----------|----------|----------------|
| `shared_db` | `shared_db` | `DB_HOST` в .env проекта |
| `shared_redis` | `shared_redis` | `REDIS_URL` в .env проекта |

## .env значения для проектов в продакшне

```ini
DB_ENGINE=django.db.backends.postgresql
DB_HOST=shared_db
DB_USER=postgres
DB_NAME=groceries_db        # или trading_db, budget_db
DB_PASSWORD=<из .env этого репо>

REDIS_URL=redis://shared_redis:6379/0
```

## SSL (позже)

SSL настраивается отдельно через certbot или nginx-proxy + Let's Encrypt.
После добавления SSL в `nginx.conf` добавить порт `443:443` в docker-compose.yml.
