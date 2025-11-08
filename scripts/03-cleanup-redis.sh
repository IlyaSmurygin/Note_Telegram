#!/bin/bash
# Скрипт очистки Redis

echo "🗑️  Очистка Redis..."

CONTAINER_NAME="redis-notes"

# Очистка всех данных в Redis
echo "Удаление всех ключей из Redis..."
docker exec $CONTAINER_NAME redis-cli FLUSHALL

echo "✅ Redis очищен!"

# Проверка
echo ""
echo "Проверка состояния Redis:"
docker exec $CONTAINER_NAME redis-cli DBSIZE
