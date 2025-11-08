# Инструкция по реализации микросервиса заметок

## Содержание
1. [Подготовка окружения](#подготовка-окружения)
2. [Настройка инфраструктуры](#настройка-инфраструктуры)
3. [Реализация Workflows в n8n](#реализация-workflows-в-n8n)
4. [Настройка Neo4j](#настройка-neo4j)
5. [Интеграция AI сервисов](#интеграция-ai-сервисов)
6. [Тестирование](#тестирование)
7. [Деплой и мониторинг](#деплой-и-мониторинг)

---

## Подготовка окружения

### Необходимые компоненты

1. **RabbitMQ** (версия 3.12+)
2. **Redis** (версия 7.0+)
3. **Neo4j** (версия 5.0+)
4. **n8n** (версия 1.0+)
5. **Docker & Docker Compose**

### Установка через Docker Compose

Создайте файл `docker-compose.yml`:

```yaml
version: '3.8'

services:
  rabbitmq:
    image: rabbitmq:3.12-management
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: admin
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  neo4j:
    image: neo4j:5-community
    ports:
      - "7474:7474"
      - "7687:7687"
    environment:
      NEO4J_AUTH: neo4j/password
      NEO4J_PLUGINS: '["apoc"]'
    volumes:
      - neo4j_data:/data

  n8n:
    image: n8nio/n8n:latest
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=admin
      - WEBHOOK_URL=https://your-domain.com
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - rabbitmq
      - redis
      - neo4j

volumes:
  rabbitmq_data:
  redis_data:
  neo4j_data:
  n8n_data:
```

Запуск:
```bash
docker-compose up -d
```

### Получение API ключей

1. **Telegram Bot Token**:
   - Создайте бота через [@BotFather](https://t.me/botfather)
   - Сохраните токен

2. **Claude API Key**:
   - Зарегистрируйтесь на [console.anthropic.com](https://console.anthropic.com)
   - Создайте API ключ

3. **OpenAI API Key** (для Whisper):
   - Зарегистрируйтесь на [platform.openai.com](https://platform.openai.com)
   - Создайте API ключ

---

## Настройка инфраструктуры

### 1. Настройка RabbitMQ

Подключитесь к веб-интерфейсу RabbitMQ: `http://localhost:15672`

Создайте очереди (вручную или через API):

```bash
# Скрипт для создания очередей
curl -u admin:admin -X PUT http://localhost:15672/api/queues/%2F/text_input \
  -H "content-type:application/json" \
  -d '{"durable":true}'

curl -u admin:admin -X PUT http://localhost:15672/api/queues/%2F/voice_transcribe \
  -H "content-type:application/json" \
  -d '{"durable":true}'

curl -u admin:admin -X PUT http://localhost:15672/api/queues/%2F/ai_analyze \
  -H "content-type:application/json" \
  -d '{"durable":true}'

curl -u admin:admin -X PUT http://localhost:15672/api/queues/%2F/pending_action \
  -H "content-type:application/json" \
  -d '{"durable":true}'

curl -u admin:admin -X PUT http://localhost:15672/api/queues/%2F/callback_input \
  -H "content-type:application/json" \
  -d '{"durable":true}'

curl -u admin:admin -X PUT http://localhost:15672/api/queues/%2F/db_ops \
  -H "content-type:application/json" \
  -d '{"durable":true}'

curl -u admin:admin -X PUT http://localhost:15672/api/queues/%2F/http_errors \
  -H "content-type:application/json" \
  -d '{"durable":true,"arguments":{"x-dead-letter-exchange":"dlx"}}'

curl -u admin:admin -X PUT http://localhost:15672/api/queues/%2F/log_events \
  -H "content-type:application/json" \
  -d '{"durable":true}'
```

### 2. Настройка Redis

Redis работает "из коробки", но настройте структуру ключей:

```
pending:{pending_id} -> JSON объект с данными
session:{user_id} -> JSON объект с сессией
cache:{key} -> кэшированные данные
```

### 3. Настройка Telegram Webhook

Установите webhook для вашего бота:

```bash
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://your-n8n-domain.com/webhook/telegram",
    "allowed_updates": ["message", "callback_query"]
  }'
```

---

## Настройка Neo4j

### Схема графовой модели

Подключитесь к Neo4j Browser: `http://localhost:7474`

#### Типы узлов (Labels)

1. **User** - пользователи
2. **Note** - заметки
3. **Task** - задачи
4. **Reminder** - напоминания
5. **Tag** - теги

#### Типы связей (Relationships)

- `CREATED` - пользователь создал объект
- `TAGGED_WITH` - объект помечен тегом
- `RELATED_TO` - связь между объектами
- `PARENT_OF` - иерархическая связь
- `MENTIONS` - упоминание объекта в другом

#### Создание индексов и ограничений

```cypher
// Индексы для User
CREATE CONSTRAINT user_id_unique IF NOT EXISTS
FOR (u:User) REQUIRE u.telegram_id IS UNIQUE;

CREATE INDEX user_username IF NOT EXISTS
FOR (u:User) ON (u.username);

// Индексы для Note
CREATE INDEX note_created_at IF NOT EXISTS
FOR (n:Note) ON (n.created_at);

CREATE INDEX note_text IF NOT EXISTS
FOR (n:Note) ON (n.text);

// Индексы для Task
CREATE INDEX task_status IF NOT EXISTS
FOR (t:Task) ON (t.status);

CREATE INDEX task_due_date IF NOT EXISTS
FOR (t:Task) ON (t.due_date);

// Индексы для Reminder
CREATE INDEX reminder_datetime IF NOT EXISTS
FOR (r:Reminder) ON (r.remind_at);

// Индексы для Tag
CREATE CONSTRAINT tag_name_unique IF NOT EXISTS
FOR (t:Tag) REQUIRE t.name IS UNIQUE;
```

#### Примеры Cypher-запросов

**Создание пользователя:**
```cypher
MERGE (u:User {telegram_id: $telegram_id})
ON CREATE SET
  u.username = $username,
  u.first_name = $first_name,
  u.created_at = datetime()
RETURN u
```

**Создание заметки с тегами:**
```cypher
MATCH (u:User {telegram_id: $telegram_id})
CREATE (n:Note {
  id: randomUUID(),
  text: $text,
  improved_text: $improved_text,
  created_at: datetime()
})
CREATE (u)-[:CREATED]->(n)
WITH n
UNWIND $tags AS tag_name
MERGE (t:Tag {name: tag_name})
CREATE (n)-[:TAGGED_WITH]->(t)
RETURN n
```

**Поиск заметок по тегу:**
```cypher
MATCH (u:User {telegram_id: $telegram_id})-[:CREATED]->(n:Note)-[:TAGGED_WITH]->(t:Tag {name: $tag})
RETURN n
ORDER BY n.created_at DESC
LIMIT 20
```

**Создание связи между объектами:**
```cypher
MATCH (u:User {telegram_id: $telegram_id})-[:CREATED]->(n1)
MATCH (u)-[:CREATED]->(n2)
WHERE n1.id = $id1 AND n2.id = $id2
MERGE (n1)-[r:RELATED_TO]->(n2)
SET r.created_at = datetime()
RETURN n1, r, n2
```

**Статистика пользователя:**
```cypher
MATCH (u:User {telegram_id: $telegram_id})
OPTIONAL MATCH (u)-[:CREATED]->(n:Note)
OPTIONAL MATCH (u)-[:CREATED]->(t:Task)
OPTIONAL MATCH (u)-[:CREATED]->(r:Reminder)
RETURN
  u.username as username,
  count(DISTINCT n) as notes_count,
  count(DISTINCT t) as tasks_count,
  count(DISTINCT r) as reminders_count
```

---

## Реализация Workflows в n8n

### Workflow 1: Webhook Trigger (Точка входа)

**Назначение:** Прием всех событий от Telegram и маршрутизация в соответствующие очереди

**Узлы:**

1. **Webhook**
   - Method: POST
   - Path: `/webhook/telegram`
   - Response: Return Data

2. **IF - Проверка типа события**
   - Conditions:
     - `{{ $json.callback_query }}` exists → True
     - `{{ $json.message.text }}` exists → False
     - `{{ $json.message.voice }}` exists → False

3. **Switch - Маршрутизация**
   - Mode: Rules
   - Rules:
     - callback_query exists → callback_input
     - message.text exists → text_input
     - message.voice exists → voice_transcribe
     - Default → http_errors

4. **RabbitMQ Send - text_input**
   - Queue: text_input
   - Message:
     ```json
     {
       "user_id": "{{ $json.message.from.id }}",
       "chat_id": "{{ $json.message.chat.id }}",
       "text": "{{ $json.message.text }}",
       "message_id": "{{ $json.message.message_id }}",
       "timestamp": "{{ $json.message.date }}"
     }
     ```

5. **RabbitMQ Send - voice_transcribe**
   - Queue: voice_transcribe
   - Message:
     ```json
     {
       "user_id": "{{ $json.message.from.id }}",
       "chat_id": "{{ $json.message.chat.id }}",
       "file_id": "{{ $json.message.voice.file_id }}",
       "message_id": "{{ $json.message.message_id }}"
     }
     ```

6. **RabbitMQ Send - callback_input**
   - Queue: callback_input
   - Message:
     ```json
     {
       "user_id": "{{ $json.callback_query.from.id }}",
       "chat_id": "{{ $json.callback_query.message.chat.id }}",
       "callback_data": "{{ $json.callback_query.data }}",
       "callback_id": "{{ $json.callback_query.id }}",
       "message_id": "{{ $json.callback_query.message.message_id }}"
     }
     ```

7. **RabbitMQ Send - http_errors**
   - Queue: http_errors
   - Message: Original payload

---

### Workflow 2: Text Input Processing

**Назначение:** Обработка текстовых сообщений и отправка на анализ

**Узлы:**

1. **RabbitMQ Trigger**
   - Queue: text_input

2. **RabbitMQ Send - ai_analyze**
   - Queue: ai_analyze
   - Message: Pass through from trigger

3. **RabbitMQ Send - log_events**
   - Queue: log_events
   - Message:
     ```json
     {
       "event": "text_received",
       "user_id": "{{ $json.user_id }}",
       "timestamp": "{{ $now }}"
     }
     ```

---

### Workflow 3: Voice Transcription

**Назначение:** Получение голосового файла и транскрипция через Whisper

**Узлы:**

1. **RabbitMQ Trigger**
   - Queue: voice_transcribe

2. **HTTP Request - Get File Path**
   - Method: GET
   - URL: `https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/getFile`
   - Parameters:
     - file_id: `{{ $json.file_id }}`

3. **HTTP Request - Download File**
   - Method: GET
   - URL: `https://api.telegram.org/file/bot{{ $env.TELEGRAM_BOT_TOKEN }}/{{ $json.result.file_path }}`
   - Response Format: File

4. **HTTP Request - Whisper API**
   - Method: POST
   - URL: `https://api.openai.com/v1/audio/transcriptions`
   - Authentication: Bearer Token
   - Headers:
     - Authorization: `Bearer {{ $env.OPENAI_API_KEY }}`
   - Body (multipart/form-data):
     - file: Binary from previous step
     - model: whisper-1
     - language: ru

5. **IF - Check Success**
   - Condition: `{{ $json.text }}` exists

6. **RabbitMQ Send - text_input** (True branch)
   - Queue: text_input
   - Message:
     ```json
     {
       "user_id": "{{ $node['RabbitMQ Trigger'].json.user_id }}",
       "chat_id": "{{ $node['RabbitMQ Trigger'].json.chat_id }}",
       "text": "{{ $json.text }}",
       "type": "voice_transcribed"
     }
     ```

7. **RabbitMQ Send - http_errors** (False branch)
   - Queue: http_errors
   - Message: Error details

---

### Workflow 4: AI Analysis (Claude)

**Назначение:** Анализ текста через Claude API и классификация

**Узлы:**

1. **RabbitMQ Trigger**
   - Queue: ai_analyze

2. **HTTP Request - Claude API**
   - Method: POST
   - URL: `https://api.anthropic.com/v1/messages`
   - Headers:
     - x-api-key: `{{ $env.ANTHROPIC_API_KEY }}`
     - anthropic-version: 2023-06-01
     - content-type: application/json
   - Body:
     ```json
     {
       "model": "claude-3-5-sonnet-20241022",
       "max_tokens": 1024,
       "messages": [{
         "role": "user",
         "content": "Проанализируй текст и верни JSON:\n{\n  \"type\": \"note|task|reminder|command\",\n  \"improved_text\": \"улучшенный текст\",\n  \"tags\": [\"тег1\", \"тег2\"],\n  \"command_type\": \"search|delete|update|link|stats\",\n  \"command_params\": {}\n}\n\nТекст: {{ $json.text }}"
       }]
     }
     ```

3. **Code - Parse Response**
   - JavaScript:
     ```javascript
     const content = $input.item.json.content[0].text;
     const parsed = JSON.parse(content);
     return { json: { ...parsed, original_data: $input.item.json } };
     ```

4. **Switch - Route by Type**
   - Rules:
     - type === "command" → db_ops
     - type in ["note", "task", "reminder"] → pending_action

5. **RabbitMQ Send - pending_action**
   - Queue: pending_action

6. **RabbitMQ Send - db_ops**
   - Queue: db_ops

---

### Workflow 5: Pending Action (Согласование)

**Назначение:** Отправка пользователю сообщения с inline-кнопками для согласования

**Узлы:**

1. **RabbitMQ Trigger**
   - Queue: pending_action

2. **Code - Generate Pending ID**
   - JavaScript:
     ```javascript
     const crypto = require('crypto');
     const pending_id = crypto.randomUUID();
     return { json: { ...items[0].json, pending_id } };
     ```

3. **Redis - Save Pending**
   - Operation: Set
   - Key: `pending:{{ $json.pending_id }}`
   - Value: `{{ JSON.stringify($json) }}`
   - TTL: 3600 (1 час)

4. **Code - Generate Keyboard**
   - JavaScript:
     ```javascript
     const pending_id = items[0].json.pending_id;
     return {
       json: {
         keyboard: {
           inline_keyboard: [[
             { text: "✅ Сохранить", callback_data: `save:${pending_id}` },
             { text: "❌ Отменить", callback_data: `cancel:${pending_id}` }
           ]]
         }
       }
     };
     ```

5. **HTTP Request - Send Message**
   - Method: POST
   - URL: `https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage`
   - Body:
     ```json
     {
       "chat_id": "{{ $node['RabbitMQ Trigger'].json.chat_id }}",
       "text": "Создать {{ $node['RabbitMQ Trigger'].json.type }}?\n\n{{ $node['RabbitMQ Trigger'].json.improved_text }}\n\nТеги: {{ $node['RabbitMQ Trigger'].json.tags.join(', ') }}",
       "reply_markup": "{{ $json.keyboard }}"
     }
     ```

---

### Workflow 6: Callback Input Processing

**Назначение:** Обработка нажатий на inline-кнопки

**Узлы:**

1. **RabbitMQ Trigger**
   - Queue: callback_input

2. **Code - Parse Callback Data**
   - JavaScript:
     ```javascript
     const [action, pending_id] = items[0].json.callback_data.split(':');
     return { json: { action, pending_id, ...items[0].json } };
     ```

3. **Redis - Get Pending**
   - Operation: Get
   - Key: `pending:{{ $json.pending_id }}`

4. **Code - Parse Pending Data**
   - JavaScript:
     ```javascript
     const pending = JSON.parse(items[0].json);
     return { json: pending };
     ```

5. **Switch - Route by Action**
   - Rules:
     - action === "save" → db_ops (save)
     - action === "cancel" → delete from Redis

6. **RabbitMQ Send - db_ops**
   - Queue: db_ops
   - Message:
     ```json
     {
       "operation": "{{ $node['Code - Parse Callback Data'].json.action }}",
       "data": "{{ $json }}"
     }
     ```

7. **HTTP Request - Answer Callback Query**
   - Method: POST
   - URL: `https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/answerCallbackQuery`
   - Body:
     ```json
     {
       "callback_query_id": "{{ $node['RabbitMQ Trigger'].json.callback_id }}",
       "text": "✅ Готово!"
     }
     ```

8. **Redis - Delete Pending**
   - Operation: Delete
   - Key: `pending:{{ $json.pending_id }}`

---

### Workflow 7: Database Operations

**Назначение:** Все операции с Neo4j

**Узлы:**

1. **RabbitMQ Trigger**
   - Queue: db_ops

2. **Switch - Operation Type**
   - Rules:
     - operation === "save"
     - operation === "search"
     - operation === "delete"
     - operation === "link"
     - operation === "update"
     - operation === "stats"

3. **Neo4j - Save** (для save операции)
   - Query:
     ```cypher
     MATCH (u:User {telegram_id: $telegram_id})
     CREATE (n:{{ $json.data.type | capitalize }} {
       id: randomUUID(),
       text: $text,
       improved_text: $improved_text,
       created_at: datetime()
     })
     CREATE (u)-[:CREATED]->(n)
     WITH n
     UNWIND $tags AS tag_name
     MERGE (t:Tag {name: tag_name})
     CREATE (n)-[:TAGGED_WITH]->(t)
     RETURN n
     ```
   - Parameters:
     - telegram_id: `{{ $json.user_id }}`
     - text: `{{ $json.data.text }}`
     - improved_text: `{{ $json.data.improved_text }}`
     - tags: `{{ $json.data.tags }}`

4. **Neo4j - Search** (для search операции)
   - Query:
     ```cypher
     MATCH (u:User {telegram_id: $telegram_id})-[:CREATED]->(n)
     WHERE ($tag IS NULL OR (n)-[:TAGGED_WITH]->(:Tag {name: $tag}))
       AND ($type IS NULL OR $type IN labels(n))
     RETURN n
     ORDER BY n.created_at DESC
     LIMIT 20
     ```

5. **Code - Format Results**
   - JavaScript:
     ```javascript
     const results = items.map(item => {
       const n = item.json.n;
       return `📝 ${n.improved_text || n.text}\n🏷 ${n.tags || 'без тегов'}`;
     }).join('\n\n');
     return { json: { text: results || 'Ничего не найдено' } };
     ```

6. **HTTP Request - Send Results**
   - Method: POST
   - URL: `https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage`
   - Body:
     ```json
     {
       "chat_id": "{{ $node['RabbitMQ Trigger'].json.chat_id }}",
       "text": "{{ $json.text }}"
     }
     ```

7. **RabbitMQ Send - log_events**
   - Queue: log_events
   - Message: Log operation details

---

### Workflow 8: Error Handling

**Назначение:** Централизованная обработка ошибок

**Узлы:**

1. **RabbitMQ Trigger**
   - Queue: http_errors

2. **Code - Log Error**
   - JavaScript:
     ```javascript
     console.error('Error:', items[0].json);
     return items;
     ```

3. **HTTP Request - Notify User** (optional)
   - Method: POST
   - URL: `https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage`
   - Body:
     ```json
     {
       "chat_id": "{{ $json.chat_id }}",
       "text": "⚠️ Произошла ошибка. Попробуйте позже."
     }
     ```

4. **RabbitMQ Send - log_events**
   - Queue: log_events

---

### Workflow 9: Logging

**Назначение:** Сбор и хранение логов

**Узлы:**

1. **RabbitMQ Trigger**
   - Queue: log_events

2. **Code - Format Log**
   - JavaScript:
     ```javascript
     const log = {
       timestamp: new Date().toISOString(),
       ...items[0].json
     };
     console.log(JSON.stringify(log));
     return { json: log };
     ```

3. **Redis - Store Log** (optional, для кратковременного хранения)
   - Operation: Set
   - Key: `log:{{ $now.toUnixInteger() }}`
   - Value: `{{ JSON.stringify($json) }}`
   - TTL: 86400 (24 часа)

---

## Интеграция AI сервисов

### Промпт для Claude API

Создайте файл с системным промптом для анализа сообщений:

```
Ты - ассистент для обработки заметок пользователя. Твоя задача - проанализировать входящий текст и классифицировать его.

Типы объектов:
- note: обычная заметка
- task: задача с возможным сроком
- reminder: напоминание с датой/временем
- command: команда пользователя (найти, удалить, связать, статистика)

Для команд определи:
- search: поиск заметок
- delete: удаление
- link: связывание объектов
- update: обновление
- stats: статистика

Улучши текст, сделай его более структурированным. Извлеки теги (ключевые слова).

Формат ответа (строго JSON):
{
  "type": "note|task|reminder|command",
  "improved_text": "улучшенный текст",
  "tags": ["тег1", "тег2"],
  "command_type": "search|delete|link|update|stats или null",
  "command_params": {"param": "value"}
}
```

### Настройка Whisper

Whisper используется через OpenAI API. Параметры:
- Model: `whisper-1`
- Language: `ru` (для русского языка)
- Response format: `json`

---

## Тестирование

### 1. Тест маршрутизации webhook

```bash
# Тест текстового сообщения
curl -X POST http://localhost:5678/webhook/telegram \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "message_id": 1,
      "from": {"id": 123456, "first_name": "Test"},
      "chat": {"id": 123456},
      "text": "Тестовая заметка",
      "date": 1234567890
    }
  }'
```

### 2. Тест голосового сообщения

Отправьте голосовое сообщение через Telegram и проверьте:
1. Файл получен
2. Транскрипция выполнена
3. Текст отправлен в text_input

### 3. Тест callback-кнопок

```bash
curl -X POST http://localhost:5678/webhook/telegram \
  -H "Content-Type: application/json" \
  -d '{
    "callback_query": {
      "id": "test123",
      "from": {"id": 123456},
      "message": {"message_id": 1, "chat": {"id": 123456}},
      "data": "save:test-pending-id"
    }
  }'
```

### 4. Проверка очередей RabbitMQ

```bash
# Получить статистику очередей
curl -u admin:admin http://localhost:15672/api/queues
```

### 5. Проверка данных в Neo4j

```cypher
// Посмотреть все узлы
MATCH (n) RETURN n LIMIT 25

// Посмотреть связи
MATCH (n)-[r]->(m) RETURN n, r, m LIMIT 25
```

### 6. Проверка Redis

```bash
redis-cli
> KEYS *
> GET pending:test-id
```

---

## Деплой и мониторинг

### 1. Настройка HTTPS (Let's Encrypt)

Для работы Telegram webhook необходим HTTPS. Используйте nginx с Let's Encrypt:

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    location /webhook/ {
        proxy_pass http://localhost:5678/webhook/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 2. Переменные окружения

Создайте `.env` файл:

```bash
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
ANTHROPIC_API_KEY=your_claude_api_key
OPENAI_API_KEY=your_openai_api_key
RABBITMQ_URL=amqp://admin:admin@rabbitmq:5672
REDIS_URL=redis://redis:6379
NEO4J_URL=bolt://neo4j:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=password
```

### 3. Мониторинг

**RabbitMQ:**
- Management UI: http://localhost:15672
- Метрики: количество сообщений, скорость обработки

**n8n:**
- Execution history
- Error tracking

**Neo4j:**
- Browser: http://localhost:7474
- Мониторинг запросов

**Redis:**
- Redis Commander или RedisInsight

### 4. Резервное копирование

```bash
# Neo4j
docker exec neo4j neo4j-admin database dump neo4j --to-path=/backups

# Redis
docker exec redis redis-cli BGSAVE

# RabbitMQ definitions
curl -u admin:admin http://localhost:15672/api/definitions > rabbitmq-backup.json
```

### 5. Логирование

Настройте централизованное логирование (например, ELK Stack):
- Elasticsearch для хранения
- Logstash для обработки
- Kibana для визуализации

---

## Полезные команды

### Просмотр логов

```bash
# n8n
docker logs -f n8n

# RabbitMQ
docker logs -f rabbitmq

# Neo4j
docker logs -f neo4j

# Redis
docker logs -f redis
```

### Перезапуск сервисов

```bash
docker-compose restart n8n
docker-compose restart rabbitmq
```

### Очистка данных

```bash
# Очистка всех очередей RabbitMQ
docker exec rabbitmq rabbitmqctl purge_queue text_input

# Очистка Redis
docker exec redis redis-cli FLUSHALL

# Очистка Neo4j
docker exec neo4j cypher-shell -u neo4j -p password "MATCH (n) DETACH DELETE n"
```

---

## Чеклист для запуска

- [ ] Docker Compose запущен
- [ ] Все сервисы доступны (RabbitMQ, Redis, Neo4j, n8n)
- [ ] Созданы все очереди в RabbitMQ
- [ ] Настроены индексы в Neo4j
- [ ] Получены API ключи (Telegram, Claude, Whisper)
- [ ] Созданы все 9 workflows в n8n
- [ ] Настроены переменные окружения
- [ ] Установлен webhook в Telegram
- [ ] Настроен HTTPS
- [ ] Проведено тестирование основных сценариев
- [ ] Настроен мониторинг
- [ ] Настроено резервное копирование

---

## Следующие шаги

1. Добавить обработку изображений и документов
2. Реализовать планировщик для напоминаний
3. Добавить поддержку групповых чатов
4. Реализовать экспорт данных
5. Добавить аналитику использования
6. Реализовать многоязычность
7. Добавить webhook для уведомлений о событиях

---

## Поддержка и документация

- [n8n Documentation](https://docs.n8n.io/)
- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html)
- [Neo4j Documentation](https://neo4j.com/docs/)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Claude API Documentation](https://docs.anthropic.com/)
- [Whisper API Documentation](https://platform.openai.com/docs/guides/speech-to-text)
