#!/bin/sh

set -e

API_URL="https://api.github.com/repos/shtorm-7/sing-box-extended/releases/latest"
TMP_DIR="/tmp/sing-box-install"
ARCHIVE_NAME="sing-box-latest.tar.gz"
DEST_FILE="/usr/bin/sing-box"

HOST_ARCH=$(uname -m)
echo "[*] Ваша архитектура: $HOST_ARCH"

case $HOST_ARCH in
  aarch64)
    ARCH_SUFFIX="arm64"
    ;;
  armv7*)
    ARCH_SUFFIX="armv7"
    ;;
  x86_64)
    ARCH_SUFFIX="amd64"
    ;;
  mips | mipsle | mipsel)
    ARCH_SUFFIX="mipsle-softfloat"
    ;;
  *)
    echo "[!] ОШИБКА: Архитектура $HOST_ARCH не поддерживается."
    exit 1
    ;;
esac

FILE_PATTERN="linux-$ARCH_SUFFIX.tar.gz"
echo "[*] Целевой файл: $FILE_PATTERN"

echo "[*] Ищу ссылку на GitHub..."
DOWNLOAD_URL=$(wget -qO- "$API_URL" | tr ',' '\n' | grep "browser_download_url" | grep "$FILE_PATTERN" | head -n 1 | awk -F '"' '{print $4}')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "[!] ОШИБКА: Ссылка не найдена."
    exit 1
fi

echo "[+] Ссылка: $DOWNLOAD_URL"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

echo "[*] Качаю..."
wget -O "$ARCHIVE_NAME" "$DOWNLOAD_URL"

if [ ! -s "$ARCHIVE_NAME" ]; then
    echo "[!] ОШИБКА: Файл пустой."
    exit 1
fi

echo "[*] Останавливаю sing-box..."
service sing-box stop >/dev/null 2>&1 || true
killall sing-box >/dev/null 2>&1 || true

echo "[*] Распаковываю..."
tar -xzf "$ARCHIVE_NAME"

echo "[*] Ищу бинарник..."
BINARY_PATH=$(find . -type f -name sing-box | head -n 1)

if [ -z "$BINARY_PATH" ]; then
    echo "[!] ОШИБКА: Бинарник не найден."
    exit 1
fi

echo "[*] Обновляю файл в $DEST_FILE..."
mv -f "$BINARY_PATH" "$DEST_FILE"
chmod +x "$DEST_FILE"

cd /
rm -rf "$TMP_DIR"

echo "[+] Успешно! Перезагружаю роутер..."
reboot
