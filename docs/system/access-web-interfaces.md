# Доступ к веб-интерфейсам Neo4j и RabbitMQ

## Проблема

Не можете зайти в Neo4j Browser или RabbitMQ Management UI через браузер.

## Диагностика

### 1. Проверка статуса контейнеров

Первым делом проверьте что контейнеры запущены:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Должны быть видны контейнеры:
- `neo4j-notes` - со статусом `Up`
- `rabbitmq-notes` - со статусом `Up`

Если контейнеры не запущены:

```bash
# Проверить все контейнеры (включая остановленные)
docker ps -a

# Запустить остановленные контейнеры
docker start neo4j-notes
docker start rabbitmq-notes

# Или запустить все через docker-compose
docker-compose up -d
```

---

## Neo4j Browser

### Доступ

**URL:** `http://localhost:7474`

### Credentials (по умолчанию)

```
Username: neo4j
Password: Vtxs3+Lm4rPz
```

(Или пароль который вы установили в переменных окружения)

### Проверка доступности

```bash
# Проверить что порт 7474 доступен
curl http://localhost:7474

# Должны увидеть HTML страницу Neo4j Browser
```

### Проверка портов

```bash
# Посмотреть какие порты открыты для Neo4j
docker port neo4j-notes

# Должно показать:
# 7474/tcp -> 0.0.0.0:7474
# 7687/tcp -> 0.0.0.0:7687
```

### Типичные проблемы

#### Проблема 1: Порт не открыт

**Симптом:** `curl: (7) Failed to connect to localhost port 7474`

**Решение:**

```bash
# Проверить настройки в docker-compose.yml
cat docker-compose.yml | grep -A 10 neo4j

# Должно быть:
# ports:
#   - "7474:7474"
#   - "7687:7687"

# Если портов нет - добавить и перезапустить
docker-compose down
docker-compose up -d
```

#### Проблема 2: Контейнер падает при старте

**Симптом:** Контейнер в статусе `Exited` или `Restarting`

**Диагностика:**

```bash
# Посмотреть логи
docker logs neo4j-notes --tail 50

# Частые ошибки:
# - Нехватка памяти
# - Неправильные права на volumes
# - Конфликт портов
```

**Решение для прав на volumes:**

```bash
# Дать права на volume
sudo chown -R 7474:7474 /path/to/neo4j/data

# Или пересоздать volume
docker-compose down -v
docker-compose up -d
```

#### Проблема 3: Неправильный пароль

**Симптом:** "Invalid username or password"

**Решение:**

```bash
# При первом запуске Neo4j требует смены пароля с "neo4j" на новый
# Если забыли пароль - нужно сбросить:

# 1. Остановить контейнер
docker stop neo4j-notes

# 2. Удалить auth
docker run --rm -v neo4j_data:/data alpine rm -f /data/dbms/auth

# 3. Запустить снова (пароль будет neo4j/neo4j)
docker start neo4j-notes

# 4. Зайти в браузер и сменить пароль
```

#### Проблема 4: Firewall блокирует

**Симптом:** Локально работает (`curl localhost:7474`), но из браузера не открывается

**Решение:**

```bash
# Ubuntu/Debian
sudo ufw allow 7474/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=7474/tcp
sudo firewall-cmd --reload
```

---

## RabbitMQ Management UI

### Доступ

**URL:** `http://localhost:15672`

### Credentials (по умолчанию)

```
Username: admin
Password: Mq19$hDqpt4g
```

(Или credentials которые вы установили)

### Проверка доступности

```bash
# Проверить что порт 15672 доступен
curl http://localhost:15672

# Должны увидеть HTML страницу RabbitMQ Management
```

### Проверка портов

```bash
# Посмотреть какие порты открыты для RabbitMQ
docker port rabbitmq-notes

# Должно показать:
# 5672/tcp -> 0.0.0.0:5672   (AMQP)
# 15672/tcp -> 0.0.0.0:15672 (Management UI)
```

### Типичные проблемы

#### Проблема 1: Management plugin не включен

**Симптом:** Порт 15672 не открыт, только 5672

**Решение:**

```bash
# Зайти в контейнер
docker exec -it rabbitmq-notes bash

# Включить management plugin
rabbitmq-plugins enable rabbitmq_management

# Выйти
exit

# Перезапустить контейнер
docker restart rabbitmq-notes

# Проверить что порт появился
docker port rabbitmq-notes
```

#### Проблема 2: Используется образ без management

**Симптом:** В docker-compose.yml указан образ `rabbitmq:alpine` вместо `rabbitmq:management`

**Решение:**

```yaml
# В docker-compose.yml изменить:
services:
  rabbitmq:
    image: rabbitmq:3.12-management  # Важно: -management
    # или
    image: rabbitmq:3.12-management-alpine
```

```bash
# Применить изменения
docker-compose down
docker-compose up -d
```

#### Проблема 3: Неправильные credentials

**Симптом:** "Login failed"

**Решение:**

```bash
# Посмотреть текущих пользователей
docker exec rabbitmq-notes rabbitmqctl list_users

# Создать нового пользователя
docker exec rabbitmq-notes rabbitmqctl add_user admin Mq19\$hDqpt4g

# Дать права администратора
docker exec rabbitmq-notes rabbitmqctl set_user_tags admin administrator

# Дать права на vhost
docker exec rabbitmq-notes rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
```

#### Проблема 4: Порт занят другим процессом

**Симптом:** Контейнер не стартует, ошибка "address already in use"

**Диагностика:**

```bash
# Посмотреть кто использует порт 15672
sudo lsof -i :15672
# или
sudo netstat -tulpn | grep 15672
```

**Решение:**

```bash
# Вариант 1: Остановить процесс который занял порт
sudo kill <PID>

# Вариант 2: Изменить порт в docker-compose.yml
ports:
  - "15673:15672"  # Используем 15673 вместо 15672
```

---

## Пошаговая диагностика

### Шаг 1: Проверить что контейнеры запущены

```bash
docker ps | grep -E "neo4j|rabbit"
```

Должны видеть оба контейнера со статусом `Up`.

### Шаг 2: Проверить логи

```bash
# Neo4j
docker logs neo4j-notes --tail 30

# RabbitMQ
docker logs rabbitmq-notes --tail 30
```

Ищите ошибки в логах.

### Шаг 3: Проверить порты локально

```bash
# Neo4j
curl -I http://localhost:7474

# RabbitMQ
curl -I http://localhost:15672
```

Должны получить HTTP 200 или 301.

### Шаг 4: Проверить из браузера

Откройте в браузере:
- `http://localhost:7474` - Neo4j
- `http://localhost:15672` - RabbitMQ

### Шаг 5: Если не работает - проверить docker-compose.yml

```bash
cat docker-compose.yml
```

Проверьте что есть:

**Для Neo4j:**
```yaml
neo4j:
  image: neo4j:5-community
  ports:
    - "7474:7474"  # Browser
    - "7687:7687"  # Bolt
  environment:
    NEO4J_AUTH: neo4j/your_password
```

**Для RabbitMQ:**
```yaml
rabbitmq:
  image: rabbitmq:3.12-management  # Важно: -management!
  ports:
    - "5672:5672"   # AMQP
    - "15672:15672" # Management UI
  environment:
    RABBITMQ_DEFAULT_USER: admin
    RABBITMQ_DEFAULT_PASS: your_password
```

---

## Быстрая проверка всего

Выполните этот скрипт для полной диагностики:

```bash
#!/bin/bash

echo "=== Checking Docker containers ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "Names|neo4j|rabbit"

echo ""
echo "=== Checking Neo4j port 7474 ==="
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:7474

echo ""
echo "=== Checking RabbitMQ port 15672 ==="
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:15672

echo ""
echo "=== Neo4j logs (last 5 lines) ==="
docker logs neo4j-notes --tail 5

echo ""
echo "=== RabbitMQ logs (last 5 lines) ==="
docker logs rabbitmq-notes --tail 5

echo ""
echo "=== Port mappings ==="
echo "Neo4j:"
docker port neo4j-notes
echo "RabbitMQ:"
docker port rabbitmq-notes
```

Сохраните как `check-web-access.sh`, дайте права и запустите:

```bash
chmod +x check-web-access.sh
./check-web-access.sh
```

---

## Удаленный доступ (если сервер не localhost)

Если сервис запущен на удаленном сервере:

### Вариант 1: SSH туннель (безопасно)

```bash
# Neo4j
ssh -L 7474:localhost:7474 user@your-server

# RabbitMQ
ssh -L 15672:localhost:15672 user@your-server

# Теперь открывайте в браузере localhost:7474 и localhost:15672
```

### Вариант 2: Изменить bind address (небезопасно без firewall)

В docker-compose.yml:

```yaml
ports:
  - "0.0.0.0:7474:7474"   # Доступ со всех интерфейсов
  - "0.0.0.0:15672:15672"
```

**⚠️ Важно:** Обязательно настройте firewall для ограничения доступа!

```bash
# Разрешить только с вашего IP
sudo ufw allow from YOUR_IP to any port 7474
sudo ufw allow from YOUR_IP to any port 15672
```

---

## После успешного входа

### Neo4j Browser

1. Войдите с credentials: `neo4j` / `Vtxs3+Lm4rPz`
2. Смените пароль если требуется
3. Выполните тестовый запрос:
   ```cypher
   MATCH (n) RETURN count(n) as total_nodes
   ```

### RabbitMQ Management

1. Войдите с credentials: `admin` / `Mq19$hDqpt4g`
2. Проверьте вкладку "Queues" - должны видеть очереди:
   - `text_input`
   - `voice_transcribe`
   - `ai_analyze`
   - `pending_action`
   - `callback_input`
   - `db_ops`
   - `http_errors`
   - `log_events`

3. Проверьте что очереди создаются автоматически при поступлении сообщений

---

## Полезные команды

### Neo4j

```bash
# Перезапустить Neo4j
docker restart neo4j-notes

# Посмотреть использование памяти
docker stats neo4j-notes --no-stream

# Выполнить Cypher запрос из консоли
docker exec neo4j-notes cypher-shell -u neo4j -p "Vtxs3+Lm4rPz" "MATCH (n) RETURN count(n)"

# Экспорт данных
docker exec neo4j-notes neo4j-admin database dump neo4j --to=/backups/neo4j.dump
```

### RabbitMQ

```bash
# Перезапустить RabbitMQ
docker restart rabbitmq-notes

# Посмотреть список очередей
docker exec rabbitmq-notes rabbitmqctl list_queues

# Посмотреть список пользователей
docker exec rabbitmq-notes rabbitmqctl list_users

# Очистить очередь
docker exec rabbitmq-notes rabbitmqctl purge_queue text_input

# Посмотреть статус
docker exec rabbitmq-notes rabbitmqctl status
```

---

## Заключение

Если после всех проверок доступ все равно не работает:

1. Проверьте логи контейнеров более детально
2. Попробуйте пересоздать контейнеры: `docker-compose down && docker-compose up -d`
3. Проверьте что нет конфликтов портов с другими приложениями
4. Убедитесь что firewall не блокирует порты
5. Если используете Docker Desktop - проверьте настройки сети

Сохраните вывод команды `docker-compose logs` для детальной диагностики.
