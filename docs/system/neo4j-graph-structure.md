# Структура хранения данных в Neo4j

## Введение

Neo4j - это графовая база данных, где данные хранятся в виде **узлов (nodes)** и **связей (relationships)** между ними. В нашем проекте используется специальная логика создания узлов, которая **предотвращает дублирование** определенных типов данных.

## Типы узлов (Nodes)

### 1. User (Пользователь)
```cypher
(:User {
  telegram_id: 123456789,     // уникальный ID из Telegram
  username: "john_doe",        // имя пользователя (опционально)
  created_at: datetime()       // когда создан
})
```

**Как создается:**
```cypher
MERGE (u:User {telegram_id: $user_id})
ON CREATE SET u.created_at = datetime()
RETURN u
```

**Логика:**
- `MERGE` - создает узел **только если его еще нет**
- Если пользователь с таким `telegram_id` уже существует - просто возвращается
- Если нет - создается новый с установкой `created_at`

**Результат:** Один пользователь = один узел, дубликатов не будет

---

### 2. Note (Заметка)
```cypher
(:Note {
  id: "uuid-string",           // уникальный ID
  text: "Купить молоко",       // оригинальный текст
  improved_text: "Купить молоко в магазине", // улучшенный AI
  created_at: datetime()       // когда создана
})
```

**Как создается:**
```cypher
MATCH (u:User {telegram_id: $user_id})
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

**Логика:**
1. **MATCH** - находим существующего пользователя
2. **CREATE** - создаем НОВУЮ заметку (каждый раз новый узел)
3. **CREATE** - создаем связь `(User)-[:CREATED]->(Note)`
4. **UNWIND** - разворачиваем массив тегов в отдельные строки
5. **MERGE** - для каждого тега: находим или создаем (важно!)
6. **CREATE** - создаем связь `(Note)-[:TAGGED_WITH]->(Tag)`

**Результат:** Каждая заметка = новый узел, но теги переиспользуются

---

### 3. Task (Задача)
```cypher
(:Task {
  id: "uuid-string",
  text: "Сделать презентацию",
  status: "pending",           // pending | completed | cancelled
  due_date: date(),            // срок выполнения
  created_at: datetime()
})
```

**Логика создания:** Аналогична Note - каждая задача = новый узел

---

### 4. Reminder (Напоминание)
```cypher
(:Reminder {
  id: "uuid-string",
  text: "Позвонить маме",
  original_text: "Напомни позвонить маме",
  remind_at: datetime("2025-11-15T18:00:00+03:00"), // когда напомнить
  status: "pending",           // pending | sent
  created_at: datetime()
})
```

**Как создается:**
```cypher
MATCH (u:User {telegram_id: $user_id})
CREATE (r:Reminder {
  id: randomUUID(),
  text: $text,
  original_text: $original_text,
  remind_at: datetime($datetime_string),
  status: 'pending',
  created_at: datetime({timezone: 'Europe/Moscow'})
})
CREATE (u)-[:CREATED]->(r)
WITH r
UNWIND $tags AS tag_name
MERGE (t:Tag {name: tag_name})
CREATE (r)-[:TAGGED_WITH]->(t)
RETURN r
```

**Важно:** Используется timezone `Europe/Moscow` для корректной работы планировщика

---

### 5. Tag (Тег) ⭐ **ПЕРЕИСПОЛЬЗУЕТСЯ**

```cypher
(:Tag {
  name: "работа"               // уникальное имя тега
})
```

**Как создается:**
```cypher
MERGE (t:Tag {name: tag_name})
```

**Логика:**
- `MERGE` - **если тег с таким именем уже существует - использует его**
- Если нет - создает новый

**Результат:**
- Тег `#работа` создается один раз
- Все заметки/задачи с тегом `#работа` ссылаются на **ОДИН И ТОТ ЖЕ** узел Tag
- **Не создается дубликатов**

---

### 6. Log (Лог событий)
```cypher
(:Log {
  id: "uuid-string",
  event: "text_received",      // тип события
  timestamp: datetime(),        // когда произошло
  data: "{...}",               // полные данные события (JSON)
  created_at: datetime()       // когда записано
})
```

**Как создается:**
```cypher
MERGE (u:User {telegram_id: $user_id})
CREATE (l:Log {
  id: randomUUID(),
  event: $event,
  timestamp: datetime($timestamp),
  data: $data,
  created_at: datetime()
})
CREATE (u)-[:LOGGED]->(l)
RETURN l
```

**Логика:** Каждое событие = новый узел Log (не переиспользуется)

**Назначение:**
- Аудит действий пользователей
- Мониторинг активности системы
- Анализ поведения пользователей

**Типы событий:**
- `text_received` - получено текстовое сообщение
- `ai_analyzed` - сообщение проанализировано AI
- и другие события системы

---

### 7. Error (Ошибка)
```cypher
(:Error {
  id: "uuid-string",
  error: "Unknown message type",  // описание ошибки
  body: "{...}",                  // тело запроса (JSON)
  timestamp: datetime(),          // когда произошла
  created_at: datetime()          // когда записана
})
```

**Как создается:**
```cypher
CREATE (e:Error {
  id: randomUUID(),
  error: $error,
  body: $body,
  timestamp: datetime($timestamp),
  created_at: datetime()
})
RETURN e
```

**Логика:** Каждая ошибка = новый узел Error

**Назначение:**
- Отладка системы
- Анализ проблем
- Мониторинг стабильности

---

## Типы связей (Relationships)

### 1. CREATED (Создал)
```cypher
(User)-[:CREATED]->(Note|Task|Reminder)
```

**Значение:** Пользователь создал заметку/задачу/напоминание

**Пример запроса:**
```cypher
// Найти все заметки пользователя
MATCH (u:User {telegram_id: 123456789})-[:CREATED]->(n:Note)
RETURN n
ORDER BY n.created_at DESC
```

---

### 2. TAGGED_WITH (Помечено тегом)
```cypher
(Note|Task|Reminder)-[:TAGGED_WITH]->(Tag)
```

**Значение:** Объект помечен тегом

**Пример запроса:**
```cypher
// Найти все заметки с тегом "работа"
MATCH (n:Note)-[:TAGGED_WITH]->(t:Tag {name: "работа"})
RETURN n
```

---

### 3. RELATED_TO (Связано с)
```cypher
(Note)-[:RELATED_TO]->(Note)
```

**Значение:** Две заметки связаны между собой (опционально)

---

### 4. LOGGED (Залогировано)
```cypher
(User)-[:LOGGED]->(Log)
```

**Значение:** Пользователь выполнил действие, которое было залогировано

**Пример запроса:**
```cypher
// Найти все действия пользователя за последние 24 часа
MATCH (u:User {telegram_id: 123456789})-[:LOGGED]->(l:Log)
WHERE l.timestamp > datetime() - duration({hours: 24})
RETURN l.event, l.timestamp, l.data
ORDER BY l.timestamp DESC
```

---

## Как узлы образуются по совпадениям

### Паттерн: CREATE vs MERGE

#### CREATE - всегда создает новый узел
```cypher
CREATE (n:Note {text: "Текст"})
```
**Результат:** Каждый раз новый узел, даже если такой текст уже есть

#### MERGE - находит или создает
```cypher
MERGE (t:Tag {name: "работа"})
```
**Результат:**
- 1-й раз: создает новый узел Tag
- 2-й раз: находит существующий и возвращает его
- 3-й раз: снова находит существующий

### Визуальный пример

**Создаем 3 заметки с тегом "работа":**

```cypher
// Заметка 1
MATCH (u:User {telegram_id: 111})
CREATE (n1:Note {text: "Презентация"})
CREATE (u)-[:CREATED]->(n1)
MERGE (t:Tag {name: "работа"})    // Создается новый Tag
CREATE (n1)-[:TAGGED_WITH]->(t)

// Заметка 2
MATCH (u:User {telegram_id: 111})
CREATE (n2:Note {text: "Отчет"})
CREATE (u)-[:CREATED]->(n2)
MERGE (t:Tag {name: "работа"})    // Находит СУЩЕСТВУЮЩИЙ Tag!
CREATE (n2)-[:TAGGED_WITH]->(t)

// Заметка 3
MATCH (u:User {telegram_id: 111})
CREATE (n3:Note {text: "Встреча"})
CREATE (u)-[:CREATED]->(n3)
MERGE (t:Tag {name: "работа"})    // Снова находит СУЩЕСТВУЮЩИЙ!
CREATE (n3)-[:TAGGED_WITH]->(t)
```

**Структура в базе:**

```
        ┌─────────────┐
        │   User      │
        │ telegram_id │
        └──────┬──────┘
               │
       ┌───────┴───────┬───────────┐
       │               │           │
       ▼               ▼           ▼
  ┌────────┐     ┌────────┐  ┌────────┐
  │ Note 1 │     │ Note 2 │  │ Note 3 │
  │"Презен"│     │"Отчет" │  │"Встреча│
  └───┬────┘     └───┬────┘  └───┬────┘
      │              │            │
      │              │            │
      └──────┬───────┴────────┬───┘
             │                │
             ▼                ▼
        ┌──────────────────────┐
        │    Tag: "работа"     │  ← ОДИН узел для всех!
        └──────────────────────┘
```

**Итого:** 3 узла Note, но только 1 узел Tag!

---

## Преимущества такого подхода

### 1. Экономия памяти
- Тег "работа" хранится один раз, не 100 раз
- Даже если 1000 заметок с тегом "работа" - тег все равно один

### 2. Быстрый поиск
```cypher
// Найти все объекты с тегом "работа"
MATCH (item)-[:TAGGED_WITH]->(t:Tag {name: "работа"})
RETURN item
```
Запрос работает очень быстро, т.к. сначала находит ОДИН узел Tag, потом идет по связям

### 3. Статистика
```cypher
// Сколько раз использован тег "работа"?
MATCH (t:Tag {name: "работа"})<-[:TAGGED_WITH]-(item)
RETURN count(item)
```

### 4. Консистентность
- Изменение тега в одном месте = изменение везде
- Нет проблемы с "работа" vs "Работа" vs "РАБОТА" (если добавить toLower)

---

## Примеры реальных запросов

### Создание заметки с тегами
```cypher
// Входные данные
user_id: 123456789
text: "Купить молоко и хлеб"
tags: ["покупки", "срочно"]

// Запрос
MATCH (u:User {telegram_id: 123456789})
CREATE (n:Note {
  id: randomUUID(),
  text: "Купить молоко и хлеб",
  created_at: datetime()
})
CREATE (u)-[:CREATED]->(n)
WITH n
UNWIND ["покупки", "срочно"] AS tag_name
MERGE (t:Tag {name: tag_name})
CREATE (n)-[:TAGGED_WITH]->(t)
RETURN n

// Что происходит:
// 1. Находим User
// 2. Создаем новый узел Note
// 3. Связываем User -> Note
// 4. Для "покупки": MERGE находит или создает Tag
// 5. Связываем Note -> Tag("покупки")
// 6. Для "срочно": MERGE находит или создает Tag
// 7. Связываем Note -> Tag("срочно")
```

### Поиск по тегу
```cypher
// Найти все заметки пользователя с тегом "работа"
MATCH (u:User {telegram_id: 123456789})-[:CREATED]->(n:Note)-[:TAGGED_WITH]->(t:Tag {name: "работа"})
RETURN n
ORDER BY n.created_at DESC

// Что происходит:
// 1. Находим User
// 2. Идем по связи CREATED -> Note
// 3. Идем по связи TAGGED_WITH -> Tag
// 4. Проверяем что Tag.name = "работа"
// 5. Возвращаем только подходящие Note
```

### Поиск напоминаний к отправке
```cypher
// Найти все напоминания со статусом pending, время которых уже наступило
MATCH (u:User)-[:CREATED]->(r:Reminder)
WHERE r.remind_at <= datetime({timezone: 'Europe/Moscow'})
  AND r.status = 'pending'
RETURN r.id as reminder_id,
       u.telegram_id as user_id,
       r.text as text
ORDER BY r.remind_at ASC
LIMIT 50

// Что происходит:
// 1. Находим все пары User -> Reminder
// 2. Фильтруем: время напоминания <= текущее время
// 3. Фильтруем: статус = 'pending'
// 4. Сортируем по времени
// 5. Берем первые 50
```

### Статистика пользователя
```cypher
MATCH (u:User {telegram_id: 123456789})
OPTIONAL MATCH (u)-[:CREATED]->(n:Note)
OPTIONAL MATCH (u)-[:CREATED]->(t:Task)
OPTIONAL MATCH (u)-[:CREATED]->(r:Reminder)
RETURN count(DISTINCT n) as notes_count,
       count(DISTINCT t) as tasks_count,
       count(DISTINCT r) as reminders_count

// Что происходит:
// 1. Находим User
// 2. OPTIONAL MATCH - ищем Note (может не быть - вернет null)
// 3. OPTIONAL MATCH - ищем Task (может не быть)
// 4. OPTIONAL MATCH - ищем Reminder (может не быть)
// 5. Считаем уникальные узлы каждого типа
```

---

## Правила работы с данными

### ✅ Правило 1: User - всегда MERGE
```cypher
MERGE (u:User {telegram_id: $user_id})
```
**Почему:** Один telegram_id = один пользователь

### ✅ Правило 2: Tag - всегда MERGE
```cypher
MERGE (t:Tag {name: $tag_name})
```
**Почему:** Один tag name = один тег для всех

### ✅ Правило 3: Note/Task/Reminder - всегда CREATE
```cypher
CREATE (n:Note {...})
```
**Почему:** Каждая заметка уникальна, даже с одинаковым текстом

### ✅ Правило 4: Связи - всегда CREATE
```cypher
CREATE (u)-[:CREATED]->(n)
```
**Почему:** Каждый раз новая связь между узлами

---

## Сравнение с реляционными БД

### В PostgreSQL (реляционная БД):
```sql
-- Таблица users
id | telegram_id | username
1  | 123456789   | john

-- Таблица notes
id | user_id | text           | created_at
1  | 1       | "Купить молоко"| 2025-11-14

-- Таблица tags
id | name
1  | "работа"
2  | "покупки"

-- Таблица note_tags (связь many-to-many)
note_id | tag_id
1       | 2
```

### В Neo4j (графовая БД):
```
(User)-[:CREATED]->(Note)-[:TAGGED_WITH]->(Tag)
```

**Разница:**
- **SQL:** Нужно 4 таблицы + JOIN'ы
- **Neo4j:** Просто идем по связям
- **SQL:** Сначала JOIN, потом фильтр
- **Neo4j:** Сначала фильтр, потом идем по связям (быстрее!)

---

## Производительность

### Почему MERGE для тегов быстрее?

**Вариант 1: CREATE (плохо)**
```cypher
CREATE (t:Tag {name: "работа"})  // Каждый раз
```
Результат: 1000 заметок = 1000 дублирующихся тегов "работа"

**Вариант 2: MERGE (хорошо)**
```cypher
MERGE (t:Tag {name: "работа"})
```
Результат: 1000 заметок = 1 тег "работа"

**Поиск по тегу:**
- Вариант 1: Нужно найти все 1000 тегов → медленно
- Вариант 2: Нужно найти 1 тег → быстро

---

## Итог

### Как образуются узлы:

1. **User** - по совпадению `telegram_id` (MERGE)
2. **Tag** - по совпадению `name` (MERGE)
3. **Note/Task/Reminder** - всегда новые (CREATE)
4. **Log** - всегда новые (CREATE)
5. **Error** - всегда новые (CREATE)

### Почему так:

- **Пользователь** один на аккаунт → не дублируем
- **Тег** общий для всех объектов → не дублируем
- **Заметки/задачи/напоминания** уникальны → создаем каждый раз
- **Логи** уникальны для каждого события → создаем каждый раз
- **Ошибки** уникальны для каждого случая → создаем каждый раз

### Визуализация связей:

```
                ┌─────────┐
                │  User   │ ← MERGE (один на telegram_id)
                └────┬────┘
                     │
       ┌─────────────┼─────────────┬──────────┬──────────┐
       │             │             │          │          │
       ▼             ▼             ▼          ▼          ▼
  ┌────────┐   ┌────────┐    ┌──────────┐  ┌───────┐  ┌───────┐
  │  Note  │   │  Task  │    │ Reminder │  │  Log  │  │ Error │
  └───┬────┘   └───┬────┘    └────┬─────┘  └───────┘  └───────┘
      │            │              │             ↑
      └────────┬───┴──────────────┘          CREATE
               │                          (для аудита)
               ▼
          ┌────────┐
          │  Tag   │ ← MERGE (один на уникальное имя)
          └────────┘

Связи:
- User -[:CREATED]-> Note/Task/Reminder
- Note/Task/Reminder -[:TAGGED_WITH]-> Tag
- User -[:LOGGED]-> Log
- Error (независимые узлы, без связей с User)
```

Это делает систему эффективной:
- **Экономим память** на тегах и пользователях (переиспользование)
- **Сохраняем уникальность** каждой заметки, лога и ошибки
- **Обеспечиваем аудит** через логи и ошибки
