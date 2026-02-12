#!/bin/sh

set -e

API_URL="https://api.github.com/repos/shtorm-7/sing-box-extended/releases/latest"
ARCHIVE_NAME="sing-box-latest.tar.gz"
DEST_FILE="/usr/bin/sing-box"

R="\033[1;31m"
G="\033[1;32m"
Y="\033[1;33m"
C="\033[1;36m"
N="\033[0m"

if command -v curl >/dev/null 2>&1; then
    FETCH="curl -fsSL --insecure"
    DOWNLOAD="curl -fsSL --insecure -o"
elif command -v wget >/dev/null 2>&1; then
    FETCH="wget -qO- --no-check-certificate"
    DOWNLOAD="wget -q --no-check-certificate -O"
else
    printf "${R}[!] ОШИБКА: Не найден curl или wget.${N}\n"
    exit 1
fi

if [ -f "/opt/etc/init.d/podkop" ] || [ -f "/etc/init.d/podkop" ]; then
    SERVICE_NAME="podkop"
else
    SERVICE_NAME="sing-box"
fi
HOST_ARCH=$(uname -m)

case $HOST_ARCH in
  aarch64)                ARCH_SUFFIX="arm64" ;;
  armv7*)                 ARCH_SUFFIX="armv7" ;;
  armv6*)                 ARCH_SUFFIX="armv6" ;;
  x86_64)                 ARCH_SUFFIX="amd64" ;;
  i386 | i686)            ARCH_SUFFIX="386" ;;
  mips)                   ARCH_SUFFIX="mips-softfloat" ;;
  mipsel | mipsle)        ARCH_SUFFIX="mipsle-softfloat" ;;
  mips64)                 ARCH_SUFFIX="mips64" ;;
  mips64el | mips64le)    ARCH_SUFFIX="mips64le" ;;
  riscv64)                ARCH_SUFFIX="riscv64" ;;
  s390x)                  ARCH_SUFFIX="s390x" ;;
  *)
    printf "${R}[!] ОШИБКА: Архитектура $HOST_ARCH не поддерживается.${N}\n"
    exit 1
    ;;
esac

if [ -f "$DEST_FILE" ]; then
    CURRENT_VERSION=$("$DEST_FILE" version 2>/dev/null | head -n 1 || echo "")
fi

printf "${C}[*] Проверяю обновления...${N}\n"
API_RESPONSE=$($FETCH "$API_URL" 2>/dev/null) || API_RESPONSE=""

if [ -z "$API_RESPONSE" ]; then
    printf "${R}[!] ОШИБКА: Не удалось подключиться к GitHub API. Проверьте соединение.${N}\n"
    exit 1
fi

LATEST_TAG=$(echo "$API_RESPONSE" | tr ',' '\n' | grep '"tag_name"' | head -n 1 | awk -F '"' '{print $4}')
CURRENT_VER=$(echo "$CURRENT_VERSION" | awk '{print $NF}')
LATEST_VER=$(echo "$LATEST_TAG" | sed 's/^v//')

printf "${C}[*] Текущая: ${Y}${CURRENT_VER:-не установлен}${C} | Последняя: ${Y}${LATEST_TAG:-неизвестно}${N}\n"

if [ -n "$CURRENT_VER" ] && [ -n "$LATEST_VER" ] && [ "$CURRENT_VER" = "$LATEST_VER" ]; then
    printf "${G}[+] Уже установлена последняя версия. Обновление не требуется.${N}\n"
    exit 0
fi

FILE_PATTERN="linux-$ARCH_SUFFIX.tar.gz"

DOWNLOAD_URL=$(echo "$API_RESPONSE" \
  | tr ',' '\n' \
  | grep "browser_download_url" \
  | grep "$FILE_PATTERN" \
  | head -n 1 \
  | awk -F '"' '{print $4}')

if [ -z "$DOWNLOAD_URL" ]; then
    printf "${R}[!] ОШИБКА: Файл для архитектуры '$HOST_ARCH' ($ARCH_SUFFIX) не найден.${N}\n"
    exit 1
fi

sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

FREE_RAM_KB=$(awk '/MemFree/ {print $2}' /proc/meminfo)

if [ "$FREE_RAM_KB" -gt 81920 ]; then
    WORK_DIR="/tmp/sing-box-install"
else
    WORK_DIR="$HOME/sing-box-install_tmp"
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

printf "${C}[*] Скачиваю и устанавливаю...${N}\n"
$DOWNLOAD "$ARCHIVE_NAME" "$DOWNLOAD_URL"

if [ ! -s "$ARCHIVE_NAME" ]; then
    printf "${R}[!] ОШИБКА: Файл пустой или не скачался.${N}\n"
    rm -rf "$WORK_DIR"
    exit 1
fi

service "$SERVICE_NAME" stop 2>/dev/null || true
sleep 2

sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

tar -xzf "$ARCHIVE_NAME"
rm -f "$ARCHIVE_NAME"

BINARY_PATH=$(find . -type f -name sing-box | head -n 1)

if [ -z "$BINARY_PATH" ]; then
    printf "${R}[!] ОШИБКА: Бинарник не найден в архиве.${N}\n"
    service "$SERVICE_NAME" start 2>/dev/null || true
    rm -rf "$WORK_DIR"
    exit 1
fi

mv -f "$BINARY_PATH" "$DEST_FILE"
chmod +x "$DEST_FILE"

NEW_VERSION=$("$DEST_FILE" version 2>/dev/null | head -n 1 | awk '{print $NF}')

cd /
rm -rf "$WORK_DIR"

service "$SERVICE_NAME" start

printf "${G}[+] Готово: ${Y}${CURRENT_VER:-н/д}${G} -> ${Y}${NEW_VERSION:-н/д}${N}\n"
