# Полный алгоритм микросервиса заметок через Telegram, RabbitMQ, n8n, Claude, Whisper, Neo4j

## Общая архитектура

- **Точка входа** — Telegram Webhook через HTTP POST (работа только через HTTP Request)
- **Маршрутизация** — RabbitMQ (очереди событий)
- **Временное хранение** — Redis для сессий, pending, кэшей
- **База данных** — Neo4j (графовая модель)
- **AI агент** — Claude API
- **Транскрипция голоса** — Whisper API
- **Оркестрация** — n8n workflows
- **Логирование** — отдельная очередь log_events

---

## Перечень очередей RabbitMQ

| Очередь         | Назначение                                     |
|-----------------|------------------------------------------------|
| text_input      | Текстовые сообщения Telegram                   |
| voice_transcribe| Голосовые сообщения на транскрипцию            |
| ai_analyze      | Анализ и обработка сообщения с помощью Claude  |
| pending_action  | Ожидание согласования действия пользователя    |
| callback_input  | Входящие callback-запросы от Telegram          |
| db_ops          | Все операции с базой/CRUD, связи, статистика   |
| http_errors     | Ошибки любой логики, retry, dead-letter        |
| log_events      | Все событийные и мониторинговые логи           |

---

## Алгоритм маршрутизации входящих событий

### 1. Webhook Trigger — универсальная точка входа

- Получает POST Telegram (message, voice, callback_query, др.)
- IF Node:
    - Если callback_query ‒ callback_input
    - Если message.text ‒ text_input
    - Если message.voice ‒ voice_transcribe
    - Всё остальное ‒ http_errors

---

### 2. Обработка callback_query

- Set Node: user_id, chat_id, callback_data, callback_id, original_message_id
- RabbitMQ: callback_input

**callback_input workflow:**
- Классификация callback_data (save, delete, link, update, cancel)
- Получение pending данных из Redis
- В зависимости от типа:
    - save — db_ops: save
    - delete — db_ops: delete
    - link — db_ops: link
    - update — db_ops: update
    - cancel — db_ops: cancel
- Отправка answerCallbackQuery для Telegram через HTTP Request
- Отправка результата пользователю через sendMessage

---

### 3. Обработка текстового сообщения

- RabbitMQ: text_input
- text_input workflow:
    - Если команда (найди, удали, свяжи, статистика) — ai_analyze
    - Иначе — ai_analyze

---

### 4. Обработка голосового сообщения

- RabbitMQ: voice_transcribe

**voice_transcribe workflow:**
- Получение файла Telegram (HTTP Request)
- Транскрипция Whisper (HTTP Request)
- Если успех — text_input очереди ({user_id, chat_id, text, type: voice_transcribed})
- Если ошибка — http_errors

---

### 5. Анализ текста/команды (ai_analyze)

- RabbitMQ: ai_analyze

**ai_analyze workflow:**
- HTTP Request к Claude API с текстом и промтом
- Ответ: {type, improved_text, tags, relations, command_params}
- Если тип command (search, delete, update, link, stats) — db_ops
- Если note/task/reminder — pending_action

---

### 6. Согласование действия (pending_action)

- RabbitMQ: pending_action
- Сохранить pending_id и данные в Redis
- Генерировать inline-клавиатуру Telegram (save, delete, cancel с pending_id)
- Отправка сообщения с кнопками через HTTP Request sendMessage
- Callback-согласование происходит через основной webhook → callback_input

---

### 7. Операции с базой данных (db_ops)

- RabbitMQ: db_ops

**db_ops workflow:**
- save — создание и связь объектов
- delete — удаление объекта и связей
- link — связь узлов
- update — обновление объекта
- search — поиск (поиск по тегу, id, типу, дате, вывод списком)
- stats — статистика
- cancel — удаление pending
- Результат — пользователю в Telegram через sendMessage

---

### 8. Обработка ошибок (http_errors)

- RabbitMQ: http_errors
- Логирование события
- Уведомление пользователя через sendMessage

---

### 9. Логирование (log_events)

- RabbitMQ: log_events
- Логи действий для мониторинга и аудита

---

## Итоговая схема работы

1. Любое событие через webhook
2. Определение типа → соответствующая очередь RabbitMQ
3. Полное покрытие сценариев callback-кнопок, обычных сообщений, команд, ошибок, логов
4. Все ответы пользователю — только HTTP Request к Telegram
5. Согласование реализовано через inline-клавиатуру и обработку callback_input
6. Все pending/кэш/связи — через Redis
7. Маршрутизация, анализ и базы — через RabbitMQ, AI-агент и Neo4j

---
