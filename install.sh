#!/bin/sh

set -e

API_URL="https://api.github.com/repos/shtorm-7/sing-box-extended/releases/latest"
ARCHIVE_NAME="sing-box-latest.tar.gz"
DEST_FILE="/usr/bin/sing-box"

if [ -f "/opt/etc/init.d/podkop" ] || [ -f "/etc/init.d/podkop" ]; then
    SERVICE_NAME="podkop"
    echo "[*] Сервис: $SERVICE_NAME"
else
    SERVICE_NAME="sing-box"
    echo "[*] Сервис: $SERVICE_NAME"
fi

HOST_ARCH=$(uname -m)
echo "[*] Архитектура: $HOST_ARCH"

case $HOST_ARCH in
  aarch64) ARCH_SUFFIX="arm64" ;;
  armv7*)  ARCH_SUFFIX="armv7" ;;
  x86_64)  ARCH_SUFFIX="amd64" ;;
  mips | mipsle | mipsel) ARCH_SUFFIX="mipsle-softfloat" ;;
  *)
    echo "[!] ОШИБКА: Архитектура $HOST_ARCH не поддерживается."
    exit 1
    ;;
esac

sync
echo 3 > /proc/sys/vm/drop_caches

FREE_RAM_KB=$(awk '/MemFree/ {print $2}' /proc/meminfo)

if [ "$FREE_RAM_KB" -gt 81920 ]; then
    WORK_DIR="/tmp/sing-box-install"
else
    WORK_DIR="$HOME/sing-box-install_tmp"
fi

FILE_PATTERN="linux-$ARCH_SUFFIX.tar.gz"

echo "[*] Получаю ссылку..."
DOWNLOAD_URL=$(wget -qO- "$API_URL" | tr ',' '\n' | grep "browser_download_url" | grep "$FILE_PATTERN" | head -n 1 | awk -F '"' '{print $4}')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "[!] ОШИБКА: Ссылка не найдена."
    exit 1
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "[*] Скачиваю..."
wget -q --no-check-certificate -O "$ARCHIVE_NAME" "$DOWNLOAD_URL"

if [ ! -s "$ARCHIVE_NAME" ]; then
    echo "[!] ОШИБКА: Файл пустой."
    exit 1
fi

echo "[*] Останавливаю $SERVICE_NAME..."
service "$SERVICE_NAME" stop || true
sleep 2

sync
echo 3 > /proc/sys/vm/drop_caches

echo "[*] Распаковываю..."
tar -xzf "$ARCHIVE_NAME"
rm -f "$ARCHIVE_NAME"

BINARY_PATH=$(find . -type f -name sing-box | head -n 1)

if [ -z "$BINARY_PATH" ]; then
    echo "[!] ОШИБКА: Бинарник не найден."
    service "$SERVICE_NAME" start || true
    rm -rf "$WORK_DIR"
    exit 1
fi

echo "[*] Заменяю файл..."
mv -f "$BINARY_PATH" "$DEST_FILE"
chmod +x "$DEST_FILE"

cd /
rm -rf "$WORK_DIR"

echo "[*] Запускаю $SERVICE_NAME..."
service "$SERVICE_NAME" start

echo "[+] Успешно."
