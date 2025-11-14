# Доступ к веб-интерфейсам

## Neo4j Browser

### Доступ через IP (рекомендуется)
```
URL: http://109.172.47.195:7474
Username: neo4j
Password: (проверить в .env файле на сервере)
```

### Доступ через домен
```
URL: http://notes.ilyasmfa.com:7474
```

**Проблема:** Браузер может автоматически редиректить на HTTPS из-за HSTS.

**Решение:**
1. Используйте режим инкогнито
2. Или очистите HSTS настройки:
   - Chrome: `chrome://net-internals/#hsts`
   - Введите `notes.ilyasmfa.com` и нажмите "Delete"
   - Перезапустите браузер

---

## RabbitMQ Management UI

### Доступ через IP
```
URL: http://109.172.47.195:15672
Username: admin
Password: admin123
```

### Доступ через домен
```
URL: http://notes.ilyasmfa.com:15672
Username: admin
Password: admin123
```

---

## Проверка паролей на сервере

### Neo4j
```bash
cat /root/notes-app/.env | grep NEO4J
cat /root/notes-app/docker-compose.yml | grep -A 3 NEO4J_AUTH
```

### RabbitMQ
```bash
cat /root/notes-app/.env | grep RABBIT
cat /root/notes-app/docker-compose.yml | grep -A 3 RABBITMQ_DEFAULT
```

---

## Статус сервисов

Проверить что оба сервиса запущены:
```bash
docker ps | grep -E "neo4j|rabbit"
```

Проверить доступность портов:
```bash
curl -I http://localhost:7474   # Neo4j
curl -I http://localhost:15672  # RabbitMQ
```
