# Правила написания валидного кода для n8n нод

## 1. Использование выражений (Expressions)

### 1.1 HTTP Request - Body Parameters
```javascript
// ✅ ПРАВИЛЬНО
"value": "={{ [{'role': 'system', 'content': 'text'}] }}"

// ❌ НЕПРАВИЛЬНО
"value": "{{ [{'role': 'system'}] }}"  // Пропущен =
```

### 1.2 HTTP Request - JSON Body
```json
// ✅ ПРАВИЛЬНО
{
  "jsonBody": "{{ $json }}"
}

// ❌ НЕПРАВИЛЬНО
{
  "jsonBody": "={{ $json }}"  // Лишний =
}
```

### 1.3 Code ноды
```javascript
// ✅ ПРАВИЛЬНО - используйте обычный JavaScript
const data = $json;
return { text: "Hello\nWorld" };  // Обычное экранирование

// ❌ НЕПРАВИЛЬНО
return { text: "Hello\\nWorld" };  // Двойное экранирование не нужно
```

---

## 2. Работа с JSON и массивами

### 2.1 Отправка массивов в Neo4j/API
```json
// ✅ ПРАВИЛЬНО
{
  "parameters": {
    "tags": {{ JSON.stringify($json.tags) }}
  }
}

// ❌ НЕПРАВИЛЬНО
{
  "parameters": {
    "tags": {{ $json.tags }}  // Может вызвать ошибку валидации
  }
}
```

### 2.2 Сложные объекты
```javascript
// ✅ ПРАВИЛЬНО - создайте Code ноду
const data = {
  user_id: $json.user_id,
  tags: $json.tags,
  params: $json.command_params
};
return { request: data };

// Затем в HTTP Request:
"jsonBody": "{{ $json.request }}"
```

---

## 3. RabbitMQ ноды

### 3.1 Отправка сообщений
```javascript
// ✅ ПРАВИЛЬНО
Mode: "Send: Message per item"
Message: "={{ JSON.stringify({
  user_id: $json.user_id,
  text: $json.text
}) }}"

// ❌ НЕПРАВИЛЬНО
Mode: "Message & Options"
messageData: "={{ {...} }}"  // Создаст "={...}" в очереди
```

### 3.2 Парсинг сообщений из очереди
```javascript
// ✅ ПРАВИЛЬНО - всегда проверяйте формат
let contentStr;

if ($input.item.json.content) {
  contentStr = Buffer.isBuffer($input.item.json.content)
    ? $input.item.json.content.toString()
    : $input.item.json.content;
} else {
  contentStr = JSON.stringify($input.item.json);
}

// Удалить ведущий '=' если есть
if (contentStr.startsWith('=')) {
  contentStr = contentStr.substring(1);
}

const message = JSON.parse(contentStr);
```

---

## 4. Доступ к данным

### 4.1 Текущая нода
```javascript
$json.field_name           // Текущие данные
$json.nested.field         // Вложенные данные
```

### 4.2 Другие ноды
```javascript
$node["Node Name"].json.field    // Данные из другой ноды
$input.item.json                 // Входные данные (в триггерах)
$input.first().json              // Первый элемент массива
$input.last().json               // Последний элемент
```

### 4.3 Проверка существования
```javascript
// ✅ ПРАВИЛЬНО
const value = $json.field || "default";
const nested = $json.obj?.nested?.field || null;

// ❌ НЕПРАВИЛЬНО
const value = $json.field;  // Может быть undefined
```

---

## 5. Neo4j HTTP API

### 5.1 Базовый запрос
```json
// ✅ ПРАВИЛЬНО
{
  "statements": [{
    "statement": "MATCH (n:Node {id: $id}) RETURN n",
    "parameters": {
      "id": {{ $json.id }}
    }
  }]
}
```

### 5.2 С массивами
```json
// ✅ ПРАВИЛЬНО
{
  "statements": [{
    "statement": "MATCH (n:Node)-[:TAG]->(t:Tag) WHERE t.name IN $tags RETURN n",
    "parameters": {
      "user_id": {{ $json.user_id }},
      "tags": {{ JSON.stringify($json.tags) }}
    }
  }]
}
```

---

## 6. OpenAI API

### 6.1 С Code нодой (рекомендуется)
```javascript
// Code нода "Prepare OpenAI Request"
const systemPrompt = `Your instructions here`;

return {
  model: "gpt-4o-mini",
  temperature: 0.3,
  max_tokens: 1000,
  messages: [
    { role: "system", content: systemPrompt },
    { role: "user", content: $json.text }
  ]
};

// HTTP Request нода
// JSON Body: {{ $json }}
```

### 6.2 Прямой вызов (если промпт короткий)
```javascript
// Body Parameters
model: gpt-4o-mini
messages: ={{ [{"role": "system", "content": "Short prompt"}, {"role": "user", "content": $json.text}] }}
temperature: 0.3
max_tokens: 1000
```

---

## 7. IF ноды

### 7.1 Проверка значений
```javascript
// ✅ ПРАВИЛЬНО
Value 1: {{ $json.action }}
Operation: Equal
Value 2: save

// Проверка существования
Value 1: {{ $json.field }}
Operation: Is Not Empty
```

### 7.2 Множественные условия
```javascript
// Используйте выражения для сложной логики
Value 1: {{ $json.type === 'command' && $json.command_type === 'list' }}
Operation: Is True
```

---

## 8. Telegram API

### 8.1 Отправка сообщений
```json
// ✅ ПРАВИЛЬНО
{
  "chat_id": {{ $json.chat_id }},
  "text": "{{ $json.text }}"
}

// С клавиатурой
{
  "chat_id": {{ $json.chat_id }},
  "text": "{{ $json.text }}",
  "reply_markup": {{ JSON.stringify({
    inline_keyboard: [[
      { text: "✅ Да", callback_data: "yes" },
      { text: "❌ Нет", callback_data: "no" }
    ]]
  }) }}
}
```

---

## 9. Обработка ошибок

### 9.1 Continue On Fail
```
Settings → Continue On Fail: ✓
```
Используйте для нод, которые могут безопасно падать:
- Remove Keyboard (сообщение может быть удалено)
- Delete operations (объект может не существовать)

### 9.2 Try-Catch в Code нодах
```javascript
// ✅ ПРАВИЛЬНО
try {
  const data = JSON.parse($json.content);
  return data;
} catch (error) {
  return {
    error: error.message,
    fallback: "default_value"
  };
}
```

---

## 10. Частые ошибки

### ❌ "JSON parameter needs to be valid JSON"
**Причина**: Неправильный синтаксис в JSON Body
**Решение**:
- Используйте `{{ }}` БЕЗ `=`
- Используйте `JSON.stringify()` для массивов
- Создайте Code ноду для сложных объектов

### ❌ "Expected parameter(s): field_name"
**Причина**: Параметр не передан в Neo4j запрос
**Решение**:
- Проверьте что данные доступны через `$node["Previous Node"].json`
- Используйте `JSON.stringify()` для массивов

### ❌ "Bad request - please check your parameters"
**Причина**: Неправильный формат body (form-data вместо JSON)
**Решение**:
- Используйте JSON Body вместо Body Parameters для REST API

### ❌ Данные в RabbitMQ начинаются с `=`
**Причина**: Неправильный режим отправки
**Решение**:
- Mode: "Send: Message per item"
- Message: `={{ JSON.stringify({...}) }}`

---

## 11. Best Practices

### 11.1 Используйте Code ноды для:
- Подготовки сложных данных
- Форматирования ответов
- Обработки ошибок
- Парсинга данных из очередей

### 11.2 Используйте HTTP Request для:
- Простых API вызовов
- Когда все параметры известны заранее

### 11.3 Именование нод
- Используйте понятные имена: "Parse Callback Data", "Format List Response"
- Избегайте: "Code", "HTTP Request", "If"

### 11.4 Тестирование
- Всегда тестируйте с реальными данными
- Проверяйте вывод каждой ноды
- Используйте Pin Data для воспроизведения проблем

---

## 12. Шаблоны для копирования

### Code нода: Парсинг RabbitMQ сообщения
```javascript
let contentStr;

if ($input.item.json.content) {
  contentStr = Buffer.isBuffer($input.item.json.content)
    ? $input.item.json.content.toString()
    : $input.item.json.content;
} else {
  contentStr = JSON.stringify($input.item.json);
}

if (contentStr.startsWith('=')) {
  contentStr = contentStr.substring(1);
}

const message = JSON.parse(contentStr);
return message;
```

### HTTP Request: Neo4j с массивом
```json
{
  "statements": [{
    "statement": "YOUR CYPHER QUERY",
    "parameters": {
      "user_id": {{ $json.user_id }},
      "tags": {{ JSON.stringify($json.tags) }}
    }
  }]
}
```

### RabbitMQ: Отправка сообщения
```
Mode: Send: Message per item
Message: ={{ JSON.stringify({
  field1: $json.field1,
  field2: $json.field2
}) }}
```

---

**Последнее обновление**: 2025-11-13
**Версия n8n**: 1.117.3
