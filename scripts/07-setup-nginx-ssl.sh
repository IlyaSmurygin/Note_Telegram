#!/bin/bash
# Скрипт установки и настройки Nginx + SSL для notes.ilyasmfa.com

set -e

DOMAIN="notes.ilyasmfa.com"
EMAIL="your-email@example.com"  # Укажите ваш email для Let's Encrypt

echo "🔧 Установка Nginx и Certbot..."

# Обновление пакетов
apt update

# Установка nginx
apt install -y nginx

# Установка certbot для Let's Encrypt
apt install -y certbot python3-certbot-nginx

# Создание конфигурации nginx для n8n
echo "📝 Создание конфигурации Nginx..."

cat > /etc/nginx/sites-available/$DOMAIN << 'NGINX_EOF'
server {
    listen 80;
    server_name notes.ilyasmfa.com;

    # Редирект на HTTPS будет добавлен certbot'ом автоматически

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Увеличиваем таймауты для длинных операций
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
    }

    # Специальная настройка для webhook
    location /webhook/ {
        proxy_pass http://localhost:5678/webhook/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Увеличиваем размер тела запроса для голосовых сообщений
        client_max_body_size 20M;
    }
}
NGINX_EOF

# Создание символической ссылки
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# Удаление дефолтного сайта
rm -f /etc/nginx/sites-enabled/default

# Проверка конфигурации nginx
echo "✅ Проверка конфигурации Nginx..."
nginx -t

# Перезапуск nginx
systemctl restart nginx
systemctl enable nginx

echo ""
echo "🔐 Получение SSL сертификата..."
echo "⚠️  ВНИМАНИЕ: Сейчас запустится certbot. Он задаст несколько вопросов:"
echo "   1. Email для уведомлений - введите ваш email"
echo "   2. Согласие с ToS - введите 'Y'"
echo "   3. Рассылка от EFF - можете 'N'"
echo ""
read -p "Нажмите Enter для продолжения..."

# Получение SSL сертификата
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect || {
    echo "❌ Ошибка получения сертификата!"
    echo "Попробуйте вручную: certbot --nginx -d $DOMAIN"
    exit 1
}

# Настройка автоматического обновления
systemctl enable certbot.timer
systemctl start certbot.timer

echo ""
echo "✅ Nginx и SSL настроены успешно!"
echo ""
echo "🌐 Ваш домен: https://$DOMAIN"
echo "📋 Webhook URL для Telegram: https://$DOMAIN/webhook/telegram"
echo ""
echo "Проверьте доступность n8n:"
echo "curl -I https://$DOMAIN"
