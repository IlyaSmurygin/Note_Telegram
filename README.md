# Telegram Bot для заметок с AI-анализом

Микросервис для управления заметками, задачами и напоминаниями через Telegram бота с использованием AI (GPT-4) для анализа текста и голосовой транскрипцией (Whisper).

## Особенности

- **AI-анализ сообщений** - автоматическая классификация и извлечение сущностей с помощью GPT-4
- **Голосовые сообщения** - транскрипция через Whisper API
- **Напоминания** - автоматическая отправка в заданное время (с поддержкой timezone)
- **Графовая база данных** - Neo4j для хранения связей между заметками, задачами и тегами
- **Микросервисная архитектура** - асинхронная обработка через RabbitMQ
- **n8n Workflows** - визуальная оркестрация бизнес-логики

## Архитектура

```
Telegram → n8n Webhook → RabbitMQ → n8n Workflows → Neo4j/Redis
                              ↓
                    AI Services (GPT-4, Whisper)
```

### Компоненты

- **n8n** - оркестрация workflows
- **RabbitMQ** - очереди сообщений
- **Neo4j** - графовая база данных
- **Redis** - кэш и временное хранилище
- **OpenAI API** - GPT-4 для анализа, Whisper для транскрипции
- **Telegram Bot API** - интерфейс пользователя

### Очереди RabbitMQ

| Очередь         | Назначение                              |
|-----------------|-----------------------------------------|
| text_input      | Текстовые сообщения от пользователей    |
| voice_transcribe| Голосовые сообщения на транскрипцию     |
| ai_analyze      | Анализ текста с помощью AI              |
| pending_action  | Ожидание подтверждения от пользователя  |
| callback_input  | Обработка callback-кнопок               |
| db_ops          | Операции с базой данных                 |
| http_errors     | Обработка ошибок                        |
| log_events      | Логирование событий                     |

## Требования

- Docker и Docker Compose
- Telegram Bot Token
- OpenAI API Key
- Минимум 2GB RAM
- Доступ к интернету для webhook

## Быстрый старт

### 1. Клонирование репозитория

```bash
git clone https://github.com/yourusername/Note_Telegram.git
cd Note_Telegram
```

### 2. Настройка окружения

Создайте `.env` файл в корне проекта:

```env
# Telegram
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_WEBHOOK_URL=https://your-domain.com/webhook/telegram

# OpenAI
OPENAI_API_KEY=your_openai_api_key_here

# RabbitMQ
RABBITMQ_HOST=rabbitmq-notes
RABBITMQ_PORT=5672
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=your_rabbitmq_password

# Redis
REDIS_HOST=redis-notes
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password

# Neo4j
NEO4J_URI=http://neo4j-notes:7474
NEO4J_USER=neo4j
NEO4J_PASSWORD=your_neo4j_password

# n8n
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_WEBHOOK_URL=https://your-domain.com
```

### 3. Запуск Docker контейнеров

```bash
# Запустить все сервисы
docker-compose up -d

# Проверить статус
docker-compose ps
```

### 4. Настройка инфраструктуры

Выполните скрипты настройки в следующем порядке:

```bash
# 1. Очистка Neo4j (при первом запуске)
bash scripts/01-cleanup-neo4j.sh

# 2. Настройка RabbitMQ очередей
bash scripts/02-setup-rabbitmq.sh

# 3. Очистка Redis (опционально)
bash scripts/03-cleanup-redis.sh

# 4. Настройка схемы Neo4j
bash scripts/06-setup-neo4j-schema.sh

# 5. Настройка SSL/Nginx (для production)
bash scripts/07-setup-nginx-ssl.sh
```

### 5. Импорт workflows в n8n

1. Откройте n8n: `http://localhost:5678`
2. Войдите в систему (создайте аккаунт при первом входе)
3. Импортируйте workflows из папки `workflows/`:
   - `01-webhook-trigger.json` - точка входа для Telegram
   - `02-text-input-processor.json` - обработка текстовых сообщений
   - `03-voice-transcription.json` - транскрипция голоса
   - `04-ai-analyzer.json` - AI анализ с GPT-4
   - `05-pending-action.json` - подтверждение действий
   - `06-callback-processor.json` - обработка callback-кнопок
   - `07-db-operations-http-api.json` - операции с Neo4j
   - `08-reminder-scheduler.json` - планировщик напоминаний

4. Активируйте все workflows

### 6. Настройка Telegram webhook

```bash
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://your-domain.com/webhook/telegram"}'
```

## Структура workflows

### Основной поток обработки

```
Webhook Trigger (01)
    ↓
Text Input (02) ← Voice Transcription (03)
    ↓
AI Analyzer (04)
    ↓
Pending Action (05) → Callback Processor (06)
    ↓
DB Operations (07)
```

### Планировщик напоминаний

```
Schedule Trigger (каждую минуту)
    ↓
Find Ready Reminders
    ↓
Send to User
    ↓
Delete Reminder
```

## Использование

### Создание заметки

Просто отправьте текст боту:

```
Купить молоко и хлеб #покупки
```

Бот предложит подтверждение с кнопками:
- ✅ Сохранить
- ❌ Отменить

### Создание задачи

```
Сделать презентацию к пятнице #работа
```

### Создание напоминания

```
Напомни мне позвонить маме завтра в 18:00
```

Напоминание будет автоматически отправлено в указанное время.

### Голосовые сообщения

Отправьте голосовое сообщение - оно будет автоматически транскрибировано и обработано.

### Команды

- `/list` - показать все заметки
- `/stats` - статистика
- Поиск: "найди заметки с тегом #работа"
- Удаление: "удали заметку с id ..."

## Конфигурация

### Timezone для напоминаний

По умолчанию используется `Europe/Moscow` (UTC+3). Для изменения отредактируйте:

**workflows/08-reminder-scheduler.json**:
- Нода "Get Current DateTime" - московское время
- Нода "Find Ready Reminders" - `datetime({timezone: 'Europe/Moscow'})`

**workflows/07-db-operations-http-api.json**:
- Нода "Save Reminder to Neo4j" - формат datetime с offset `+03:00`

### RabbitMQ настройки

Очереди создаются с параметрами:
- `durable: true` - сохраняются при перезапуске
- `x-message-ttl: 86400000` - TTL 24 часа
- `x-max-length: 100000` - максимум 100k сообщений

### Neo4j схема

**Узлы (Nodes)**:
- `User` - пользователи (telegram_id, username)
- `Note` - заметки (id, text, original_text, created_at)
- `Task` - задачи (id, text, status, due_date)
- `Reminder` - напоминания (id, text, remind_at, status)
- `Tag` - теги (name)

**Связи (Relationships)**:
- `(User)-[:CREATED]->(Note|Task|Reminder)`
- `(Note|Task|Reminder)-[:TAGGED_WITH]->(Tag)`
- `(Note)-[:RELATED_TO]->(Note)`

## Документация

Подробная документация в папке `docs/system/`:

- `algorithm.md` - детальный алгоритм работы системы
- `implementation-guide.md` - руководство по реализации
- `n8n-node-rules.md` - правила написания n8n нод

## Мониторинг

### Проверка состояния сервисов

```bash
# RabbitMQ Management UI
http://localhost:15672
Login: admin / your_password

# Neo4j Browser
http://localhost:7474
Login: neo4j / your_password

# n8n
http://localhost:5678

# Redis CLI
docker exec -it redis-notes redis-cli
```

### Логи

```bash
# n8n логи
docker logs -f n8n-notes

# RabbitMQ логи
docker logs -f rabbitmq-notes

# Neo4j логи
docker logs -f neo4j-notes
```

## Troubleshooting

### Напоминания не отправляются

1. Проверьте что workflow 08 активен
2. Проверьте timezone настройки
3. Проверьте формат datetime в Neo4j:
   ```cypher
   MATCH (r:Reminder) RETURN r.remind_at, r.status LIMIT 5
   ```

### Ошибки при сохранении в Redis

Проверьте что Redis запущен и доступен:
```bash
docker exec -it redis-notes redis-cli PING
```

### RabbitMQ очереди пустые

Проверьте что webhook настроен правильно:
```bash
curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo
```

## Разработка

### Структура проекта

```
Note_Telegram/
├── docs/system/          # Документация
├── scripts/              # Скрипты настройки
├── workflows/            # n8n workflows (JSON)
├── docker-compose.yml    # Docker конфигурация
└── README.md            # Эта инструкция
```

### Добавление нового workflow

1. Создайте workflow в n8n UI
2. Экспортируйте в JSON
3. Сохраните в `workflows/`
4. Добавьте в git
5. Обновите документацию

### Тестирование

Используйте тестовые сообщения в Telegram:

```
Тест заметки #тест
Напомни тест через 2 минуты
```

Проверяйте логи n8n для отладки.

## Production Deployment

### Требования

- SSL сертификат (Let's Encrypt)
- Доменное имя
- Nginx reverse proxy
- Firewall настройки

### Рекомендации

1. Используйте отдельные пароли для всех сервисов
2. Настройте регулярные backup Neo4j
3. Ограничьте доступ к RabbitMQ management UI
4. Используйте Docker secrets для чувствительных данных
5. Настройте мониторинг (Prometheus + Grafana)
6. Включите rate limiting в Telegram webhook

## Лицензия

MIT

## Поддержка

Если у вас возникли вопросы или проблемы:
1. Проверьте раздел Troubleshooting
2. Изучите документацию в `docs/system/`
3. Создайте issue в GitHub

---

**Версия:** 1.0.0
**Последнее обновление:** 2025-11-14
