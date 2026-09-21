#!/usr/bin/env bash
set -e

# Where to fetch the node configuration from. Leave it empty to keep the configuration the
# package ships, which is a working node that simply keeps more history than most deployments
# want. Publish one of the files from configs/ and point this at it:
#   sudo CONFIG_URL=https://files.example.org/xrpl/rippled-light.cfg bash scripts/setup-mainnet.sh
CONFIG_URL="${CONFIG_URL:-}"
CONFIG_PATH="/etc/xrpld/xrpld.cfg"
KEYRING_PATH="/etc/apt/keyrings/xrplf.asc"
RIPPLE_LIST="/etc/apt/sources.list.d/xrplf.list"
LOG_DIR="/var/log/xrpld"

echo "========================================"
echo " XRPL mainnet node setup"
echo " Config source: ${CONFIG_URL:-packaged default}"
echo "========================================"

if [ "$(id -u)" -ne 0 ]; then
  echo "[!] Запусти скрипт от root, пример:"
  echo "    sudo bash setup-mainnet.sh"
  exit 1
fi

echo "[*] Обновляем пакеты..."
apt update -y

echo "[*] Устанавливаем зависимости..."
apt install -y apt-transport-https ca-certificates wget gnupg lsb-release curl

echo "[*] Добавляем GPG-ключ Ripple (если ещё не добавлен)..."
install -m 0755 -d /etc/apt/keyrings
if [ ! -f "${KEYRING_PATH}" ]; then
  wget -qO- https://packages.xrplf.org/xrplf.asc > "${KEYRING_PATH}"
  echo "[+] GPG ключ сохранён в ${KEYRING_PATH}"
else
  echo "[=] GPG ключ уже существует: ${KEYRING_PATH}"
fi

CODENAME=$(lsb_release -sc)
echo "[*] Используем дистрибутив: ${CODENAME}"

echo "[*] Добавляем репозиторий Ripple в ${RIPPLE_LIST}..."
echo "deb [signed-by=${KEYRING_PATH}] https://packages.xrplf.org/repository/deb-stable ${CODENAME} stable" > "${RIPPLE_LIST}"

echo "[*] apt update..."
apt update -y

echo "[*] Устанавливаем rippled..."
apt install -y xrpld

echo "[*] Останавливаем rippled перед конфигурацией..."
systemctl stop xrpld || true

echo "[*] Создаем каталог /etc/xrpld (если нет)..."
mkdir -p /etc/xrpld

if [ -n "${CONFIG_URL}" ]; then
  echo "[*] Fetching the configuration from ${CONFIG_URL}"
  # curl -f already fails the script through set -e; the message says which URL was wrong.
  if ! curl -fsSL "${CONFIG_URL}" -o "${CONFIG_PATH}"; then
    echo "[!] Could not download the configuration from ${CONFIG_URL}"
    echo "    The URL has to serve the file as plain text over HTTPS."
    exit 1
  fi
  echo "[+] Configuration written to ${CONFIG_PATH}"
else
  echo "[*] No CONFIG_URL given, keeping the configuration the package installed"
fi

echo "[*] Создаём каталог логов ${LOG_DIR}..."
mkdir -p "${LOG_DIR}"
chown xrpld:xrpld "${LOG_DIR}"

echo "[*] Включаем сервис rippled в автозагрузку..."
systemctl enable xrpld

echo "[*] Запускаем rippled..."
systemctl start xrpld

echo "[*] Ждем 5 секунд перед проверкой статуса..."
sleep 5

echo "[*] Проверка статуса сервиса:"
systemctl status xrpld --no-pager || true

echo "[*] Проверка server_info:"
rippled server_info || echo "[!] Команда rippled server_info завершилась с ошибкой, смотри логи: journalctl -u xrpld -f"

echo "========================================"
echo " Готово. Нода XRPL Mainnet запущена."
echo " RPC: http://<твой-сервер>:5005"
echo " WS:  ws://<твой-сервер>:6006 (если так настроено в конфиге)"
echo " Логи: journalctl -u xrpld -f"
echo "========================================"
