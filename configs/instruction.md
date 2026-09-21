# 🟩 XRPL Mainnet Node Deployment Guide

## **Production-Grade Setup (Debian 11–12)**

Эта инструкция описывает полный процесс установки и запуска ноды XRPL Mainnet на сервере Debian 11/12, включая:

* установку зависимостей
* подключение репозиториев Ripple
* установку `rippled`
* настройку Mainnet
* настройку WebSocket (wss)
* настройку SSL через Let’s Encrypt
* настройку прав доступа
* оптимизацию конфигурации
* проверки статуса ноды

---

# 📌 1. System Preparation

## 1.1. Enable & Expand Swap (8 GB recommended)

```bash
sudo swapoff -a
sudo rm -f /swapfile
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

Проверка:

```bash
free -h
```

---

# 📌 2. Update System & Install Tools

```bash
sudo apt update -y
sudo apt install -y apt-transport-https ca-certificates wget gnupg lsb-release
```

---

# 📌 3. Add Ripple GPG Key

```bash
sudo install -m 0755 -d /etc/apt/keyrings
wget -qO- https://packages.xrplf.org/xrplf.asc | \
  sudo gpg --dearmor -o /etc/apt/keyrings/xrplf.asc
```

Проверка ключа:

```bash
gpg --show-keys /etc/apt/keyrings/xrplf.asc
```

Ожидаемый вывод:

```
pub   rsa3072 2019-02-14 [SC] [expires: 2026-02-17]
    C0010EC205B35A3310DC90DE395F97FFCCAFD9A2
uid           TechOps Team at Ripple <techops+rippled@ripple.com>
```

---

# 📌 4. Add Ripple APT Repository

Для Debian 12 (bookworm):

```bash
echo "deb [signed-by=/etc/apt/keyrings/xrplf.asc] https://packages.xrplf.org/repository/deb-stable bookworm stable" | sudo tee /etc/apt/sources.list.d/xrplf.list
```

Для Debian 11 (bullseye):

```bash
echo "deb [signed-by=/etc/apt/keyrings/xrplf.asc] https://packages.xrplf.org/repository/deb-stable bullseye stable" | sudo tee /etc/apt/sources.list.d/xrplf.list
```

---

# 📌 5. Install rippled

```bash
sudo apt update
sudo apt install -y xrpld
```

Проверка сервиса:

```bash
systemctl status xrpld
```

Если не работает:

```bash
sudo systemctl start xrpld
```

---

# 📌 6. Validate Server Sync

После запуска дайте ноде 15–20 минут.

Проверьте состояние:

```bash
rippled server_info
```

Ожидается:

```
"server_state": "full"
```

---

# 📌 7. Install & Configure Nginx + SSL

## 7.1. Install nginx + certbot

```bash
sudo apt install -y nginx python3-certbot-nginx
```

Открой файл:

```
sudo nano /etc/nginx/sites-enabled/default
```

Минимальная структура:

```nginx
server {
    listen 80;
    server_name wsx.yourdomain.org;

    root /var/www/html/;
    index index.html;
}
```

## 7.2. Issue Let's Encrypt Certificate

```bash
sudo certbot --nginx -d wsx.yourdomain.org
```

После успешной выдачи, куча файлов появится в:

```
/etc/letsencrypt/live/wsx.yourdomain.org/
```

---

# 📌 8. Configure rippled for Public WSS

Открыть конфиг:

```
sudo nano /etc/xrpld/xrpld.cfg
```

Найдите секцию:

```ini
[server]
port_rpc_admin_local
port_peer
port_ws_public
```

И заполните:

```ini
[port_ws_public]
port = 6005
ip = 0.0.0.0
protocol = wss
send_queue_limit = 500

ssl_key = /etc/letsencrypt/live/wsx.yourdomain.org/privkey.pem
ssl_chain = /etc/letsencrypt/live/wsx.yourdomain.org/fullchain.pem
```

⚠️ В `ip = X.X.X.X` НЕ обязательно указывать внешний IP — `0.0.0.0` предпочтительнее.

---

# 📌 9. Allow rippled to Read Certificates

Создать группу:

```bash
sudo groupadd crtgroup
```

Добавить:

```bash
sudo usermod -aG crtgroup rippled
sudo usermod -aG crtgroup root
```

Выдать доступ только группе:

```bash
sudo chown -R root:crtgroup /etc/letsencrypt/
sudo chmod -R 770 /etc/letsencrypt/
```

---

# 📌 10. Restart Services

```bash
sudo systemctl restart xrpld
sudo systemctl restart nginx
```

Проверка:

```bash
rippled server_info
```

---

# 📌 11. Verify WSS Connection

Через websocket-клиент:

```js
const ws = new WebSocket("wss://wsx.yourdomain.org:6005");

ws.onopen = () => ws.send('{"command":"ping"}');
ws.onmessage = msg => console.log(msg.data);
```

Должно вернуть:

```
"status":"success"
```

---

# 📌 12. Security Hardening (Recommended)

### Ограничить публичный RPC (крайне рекомендуется)

В `/etc/xrpld/xrpld.cfg`:

```ini
[port_rpc_admin_local]
port = 5005
ip = 127.0.0.1
protocol = http
```

### Ограничить firewall

```bash
sudo ufw allow 6005/tcp
sudo ufw allow 51235/tcp   # peer port
sudo ufw allow OpenSSH
sudo ufw enable
```

---

# 📌 13. Useful Maintenance Commands

## Restart

```bash
sudo systemctl restart xrpld
```

## Watch logs

```bash
journalctl -u xrpld -f
```

## Check ledgers

```bash
rippled ledger current
```

---

# ✔ Готово

Это чистая, оптимизированная, профессиональная инструкция для развёртывания XRPL ноды в Mainnet.

Если хочешь — сделаю:

* версию **для Docker**
* версию **для XRPL Testnet / Devnet**
* версию **для DigitalOcean / AWS / Vultr / Hetzner**
* автоматический **скрипт setup.sh**, который разворачивает ноду за 1 команду
