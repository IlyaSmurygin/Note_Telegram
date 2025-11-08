#!/bin/bash
# Скрипт очистки и настройки RabbitMQ

echo "🐰 Настройка RabbitMQ..."

CONTAINER_NAME="rabbitmq-notes"
RABBITMQ_USER="admin"
RABBITMQ_PASSWORD="Mq19\$hDqpt4g"

# Получить список всех очередей
echo "Получение списка существующих очередей..."
docker exec $CONTAINER_NAME rabbitmqctl list_queues

echo ""
echo "Удаление старых очередей..."

# Удалить старые очереди
OLD_QUEUES=(
    "notes.create"
    "notes.search"
    "notes.delete"
    "notes.monitor"
    "notes.reminder"
)

for queue in "${OLD_QUEUES[@]}"; do
    echo "Удаление очереди: $queue"
    docker exec $CONTAINER_NAME rabbitmqctl delete_queue "$queue" 2>/dev/null || echo "  Очередь не найдена, пропускаем"
done

echo ""
echo "Создание новых очередей согласно алгоритму..."

# Новые очереди согласно алгоритму
NEW_QUEUES=(
    "text_input"
    "voice_transcribe"
    "ai_analyze"
    "pending_action"
    "callback_input"
    "db_ops"
    "http_errors"
    "log_events"
)

# Создание очередей через rabbitmqadmin
for queue in "${NEW_QUEUES[@]}"; do
    echo "Создание очереди: $queue"
    docker exec $CONTAINER_NAME rabbitmqadmin declare queue \
        name="$queue" \
        durable=true \
        auto_delete=false \
        arguments='{"x-message-ttl":86400000,"x-max-length":100000}'
done

echo ""
echo "✅ RabbitMQ настроен!"

# Проверка созданных очередей
echo ""
echo "Список всех очередей:"
docker exec $CONTAINER_NAME rabbitmqctl list_queues name messages
