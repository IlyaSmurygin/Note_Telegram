#!/bin/bash
# Скрипт очистки Neo4j от старых данных

echo "🗑️  Очистка Neo4j..."

# Параметры подключения
NEO4J_PASSWORD="Vtxs3+Lm4rPz"
CONTAINER_NAME="neo4j-notes"

# Удаление всех узлов и связей
echo "Удаление всех узлов и связей..."
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "MATCH (n) DETACH DELETE n;"

# Удаление старых индексов
echo "Удаление старых индексов..."
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "DROP INDEX note_created_at IF EXISTS;"

docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "DROP INDEX note_type IF EXISTS;"

docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "DROP INDEX note_priority IF EXISTS;"

docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "DROP INDEX note_status IF EXISTS;"

docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "DROP INDEX note_fulltext IF EXISTS;"

docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "DROP INDEX tag_name IF EXISTS;"

# Удаление старых ограничений
echo "Удаление старых ограничений..."
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "DROP CONSTRAINT note_id_unique IF EXISTS;"

docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "DROP CONSTRAINT tag_name_unique IF EXISTS;"

docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "DROP CONSTRAINT user_id_unique IF EXISTS;"

echo "✅ Neo4j очищен!"

# Проверка
echo ""
echo "Проверка состояния базы:"
docker exec $CONTAINER_NAME cypher-shell -u neo4j -p "$NEO4J_PASSWORD" \
  "MATCH (n) RETURN count(n) as total_nodes;"
