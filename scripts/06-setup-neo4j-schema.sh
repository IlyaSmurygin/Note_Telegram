#!/bin/bash
# Скрипт настройки схемы Neo4j для микросервиса заметок

echo "📊 Настройка схемы Neo4j..."

NEO4J_PASSWORD="Vtxs3+Lm4rPz"
CONTAINER_NAME="neo4j-notes"

# Создание ограничений (constraints)
echo "Создание ограничений..."

echo "  - User.telegram_id (UNIQUE)"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE CONSTRAINT user_telegram_id_unique IF NOT EXISTS FOR (u:User) REQUIRE u.telegram_id IS UNIQUE;"

echo "  - Note.id (UNIQUE)"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE CONSTRAINT note_id_unique IF NOT EXISTS FOR (n:Note) REQUIRE n.id IS UNIQUE;"

echo "  - Task.id (UNIQUE)"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE CONSTRAINT task_id_unique IF NOT EXISTS FOR (t:Task) REQUIRE t.id IS UNIQUE;"

echo "  - Reminder.id (UNIQUE)"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE CONSTRAINT reminder_id_unique IF NOT EXISTS FOR (r:Reminder) REQUIRE r.id IS UNIQUE;"

echo "  - Tag.name (UNIQUE)"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE CONSTRAINT tag_name_unique IF NOT EXISTS FOR (t:Tag) REQUIRE t.name IS UNIQUE;"

# Создание индексов
echo ""
echo "Создание индексов..."

echo "  - User.username"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE INDEX user_username IF NOT EXISTS FOR (u:User) ON (u.username);"

echo "  - Note.created_at"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE INDEX note_created_at IF NOT EXISTS FOR (n:Note) ON (n.created_at);"

echo "  - Note.text"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE INDEX note_text IF NOT EXISTS FOR (n:Note) ON (n.text);"

echo "  - Task.status"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE INDEX task_status IF NOT EXISTS FOR (t:Task) ON (t.status);"

echo "  - Task.due_date"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE INDEX task_due_date IF NOT EXISTS FOR (t:Task) ON (t.due_date);"

echo "  - Reminder.remind_at"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE INDEX reminder_datetime IF NOT EXISTS FOR (r:Reminder) ON (r.remind_at);"

echo "  - Tag.name"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "CREATE INDEX tag_name IF NOT EXISTS FOR (t:Tag) ON (t.name);"

echo ""
echo "✅ Схема Neo4j настроена!"

# Проверка
echo ""
echo "Список ограничений:"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "SHOW CONSTRAINTS;"

echo ""
echo "Список индексов:"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "SHOW INDEXES;"
