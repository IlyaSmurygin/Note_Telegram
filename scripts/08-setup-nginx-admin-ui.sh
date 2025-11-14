#!/bin/bash
# Скрипт настройки Nginx для доступа к Neo4j и RabbitMQ

DOMAIN="notes.ilyasmfa.com"
NGINX_CONF="/etc/nginx/sites-available/default"

echo "🔧 Настройка Nginx для Neo4j Browser и RabbitMQ Management UI..."

# Создаем бэкап
echo "📦 Создаем бэкап конфигурации..."
sudo cp $NGINX_CONF ${NGINX_CONF}.backup.$(date +%Y%m%d_%H%M%S)

# Создаем новую конфигурацию
echo "✍️  Создаем новую конфигурацию..."
sudo tee $NGINX_CONF > /dev/null <<'NGINXCONF'
# Default server configuration
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name notes.ilyasmfa.com;

    # Основная страница
    location / {
        try_files $uri $uri/ =404;
    }

    # Neo4j Browser
    location /neo4j/ {
        proxy_pass http://localhost:7474/;
        proxy_http_version 1.1;

        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        # Timeouts для долгих запросов
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        proxy_send_timeout 300s;

        # Буферизация
        proxy_buffering off;
    }

    # RabbitMQ Management UI
    location /rabbitmq/ {
        proxy_pass http://localhost:15672/;
        proxy_http_version 1.1;

        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Отключаем буферизацию для правильной работы WebSocket
        proxy_buffering off;
    }
}
NGINXCONF

echo ""
echo "✅ Конфигурация создана!"
echo ""
echo "🔍 Проверяем синтаксис Nginx..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Синтаксис конфигурации правильный!"
    echo ""
    echo "🔄 Перезагружаем Nginx..."
    sudo systemctl reload nginx

    if [ $? -eq 0 ]; then
        echo ""
        echo "🎉 Готово! Nginx перезагружен!"
        echo ""
        echo "📌 Теперь доступны следующие интерфейсы:"
        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║  Neo4j Browser                                             ║"
        echo "║  URL: http://${DOMAIN}/neo4j/                     ║"
        echo "║  Username: neo4j                                           ║"
        echo "║  Password: Vtxs3+Lm4rPz                                    ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║  RabbitMQ Management UI                                    ║"
        echo "║  URL: http://${DOMAIN}/rabbitmq/                  ║"
        echo "║  Username: admin                                           ║"
        echo "║  Password: Mq19\$hDqpt4g                                    ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "🔍 Проверяем доступность..."
        echo ""

        # Проверка Neo4j
        NEO4J_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/neo4j/)
        if [ "$NEO4J_STATUS" = "200" ] || [ "$NEO4J_STATUS" = "301" ]; then
            echo "✅ Neo4j Browser доступен (HTTP $NEO4J_STATUS)"
        else
            echo "⚠️  Neo4j Browser: HTTP $NEO4J_STATUS"
        fi

        # Проверка RabbitMQ
        RABBIT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/rabbitmq/)
        if [ "$RABBIT_STATUS" = "200" ] || [ "$RABBIT_STATUS" = "301" ]; then
            echo "✅ RabbitMQ Management доступен (HTTP $RABBIT_STATUS)"
        else
            echo "⚠️  RabbitMQ Management: HTTP $RABBIT_STATUS"
        fi

        echo ""
        echo "📝 Бэкап старой конфигурации сохранен в:"
        ls -lh ${NGINX_CONF}.backup.* | tail -1

    else
        echo ""
        echo "❌ Ошибка при перезагрузке Nginx!"
        echo "Восстанавливаем бэкап..."
        sudo cp ${NGINX_CONF}.backup.* $NGINX_CONF
        sudo systemctl reload nginx
    fi
else
    echo ""
    echo "❌ Ошибка в конфигурации Nginx!"
    echo "Бэкап сохранен, изменения не применены."
    echo ""
    echo "Проверьте логи:"
    echo "sudo tail -20 /var/log/nginx/error.log"
fi
