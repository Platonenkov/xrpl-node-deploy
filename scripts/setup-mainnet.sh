#!/usr/bin/env bash
set -e

CONFIG_URL="https://xrpl.node.staticbit.io/configs/rippled-light.cfg"
CONFIG_PATH="/etc/xrpld/xrpld.cfg"
KEYRING_PATH="/etc/apt/keyrings/xrplf.asc"
RIPPLE_LIST="/etc/apt/sources.list.d/xrplf.list"
LOG_DIR="/var/log/xrpld"

echo "========================================"
echo " XRPL Mainnet Node Setup (StaticBit)"
echo " Domain config URL: ${CONFIG_URL}"
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

echo "[*] Скачиваем конфиг из ${CONFIG_URL} в ${CONFIG_PATH}..."
curl -fsSL "${CONFIG_URL}" -o "${CONFIG_PATH}"

if [ $? -ne 0 ]; then
  echo "[!] Не удалось скачать конфиг с ${CONFIG_URL}"
  echo "    Проверь, что файл доступен по HTTPS и домен настроен."
  exit 1
fi

echo "[+] Конфиг успешно сохранён в ${CONFIG_PATH}"

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
