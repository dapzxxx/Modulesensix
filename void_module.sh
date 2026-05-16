#!/system/bin/sh
# ============================================================
#   Sensix Void - Brevent Module
#   GitHub : dapzxxx/Modulesensix
#   Bot    : @himzsensix_bot
#   Version: 1.0
# ============================================================

BOT_TOKEN="8287658272:AAHZl4wHiR2MNjzNC9TfnUHcheETKJbAngg"
ADMIN_ID="8540768271"
GITHUB_USER="dapzxxx"
GITHUB_REPO="Modulesensix"
MODULE_ID="void"
MODULE_NAME="Sensix Void"
CURRENT_VERSION="1.0"
TGAPI="https://api.telegram.org/bot$BOT_TOKEN"

CURL="/data/local/tmp/curl"
STATUS_FILE="/sdcard/Void/.status"
DB_FILE="/data/local/tmp/.sensix_db"
SCRIPT_PATH="/sdcard/Void/void.sh"
TG_RESOLVE="--resolve api.telegram.org:443:149.154.167.220"
GH_RESOLVE="--resolve raw.githubusercontent.com:443:185.199.108.133"

mkdir -p /sdcard/Void
mkdir -p /data/local/tmp
touch "$DB_FILE"

install_curl() {
  if [ ! -f "$CURL" ]; then
    echo "[!] curl tidak ditemukan! Copy curl-armhf ke /data/local/tmp/curl"
    exit 1
  fi
  chmod +x "$CURL"
}

tg_send() {
  $CURL -sk $TG_RESOLVE -X POST "$TGAPI/sendMessage"     -d "chat_id=$1"     --data-urlencode "text=$2"     -d "parse_mode=HTML" > /dev/null 2>&1
}

check_update() {
  echo "[*] Mengecek update..."
  LATEST=$($CURL -sk $GH_RESOLVE     "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/void_version.txt" 2>/dev/null)
  [ -z "$LATEST" ] && echo "[*] Tidak bisa cek update, lanjut..." && return
  if [ "$LATEST" != "$CURRENT_VERSION" ]; then
    echo "[*] Ada update! v$CURRENT_VERSION -> v$LATEST"
    $CURL -sk $GH_RESOLVE       "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/void_module.sh"       -o "$SCRIPT_PATH.new"
    if [ -s "$SCRIPT_PATH.new" ]; then
      cp "$SCRIPT_PATH.new" "$SCRIPT_PATH"
      chmod +x "$SCRIPT_PATH"
      rm "$SCRIPT_PATH.new"
      echo "[✓] Update berhasil! Menjalankan versi baru..."
      exec sh "$SCRIPT_PATH"
      exit 0
    fi
  else
    echo "[✓] Versi terbaru v$CURRENT_VERSION"
  fi
}

get_device_info() {
  SERIAL=$(getprop ro.serialno 2>/dev/null || echo "unknown")
  MODEL=$(getprop ro.product.model 2>/dev/null || echo "unknown")
  BRAND=$(getprop ro.product.brand 2>/dev/null || echo "unknown")
  ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null || echo "unknown")
  IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)
  [ -z "$IP" ] && IP="unknown"
}

read_status_local() {
  [ -f "$STATUS_FILE" ] && cat "$STATUS_FILE" || echo "unknown"
}

save_status_local() {
  echo "$1" > "$STATUS_FILE"
}

check_db() {
  grep "^$1|void|" "$DB_FILE" 2>/dev/null | cut -d"|" -f3
}

notify_new_device() {
  TEXT="🔔 DEVICE BARU!
Module  : Sensix Void
Brand   : $BRAND
Model   : $MODEL
Android : $ANDROID_VER
IP      : $IP
Serial  : $SERIAL

Menunggu persetujuan..."

  KB=$(printf '{"inline_keyboard":[[{"text":"APPROVE","callback_data":"approve_%s_void"},{"text":"BLACKLIST","callback_data":"blacklist_%s_void"}]]}' "$SERIAL" "$SERIAL")

  $CURL -sk $TG_RESOLVE -X POST "$TGAPI/sendMessage"     -d "chat_id=$ADMIN_ID"     --data-urlencode "text=$TEXT"     --data-urlencode "reply_markup=$KB" > /dev/null 2>&1
}

notify_blacklist() {
  tg_send "$ADMIN_ID" "AKSES DITOLAK!
Module: Sensix Void
$BRAND $MODEL
Serial: $SERIAL"
}

wait_approval() {
  echo "Menunggu persetujuan admin..."
  attempts=0
  max=72
  while [ $attempts -lt $max ]; do
    sleep 5
    attempts=$((attempts + 1))
    updates=$($CURL -sk $TG_RESOLVE "$TGAPI/getUpdates?limit=20&allowed_updates=%5B%22callback_query%22%5D")
    approve=$(echo "$updates" | grep -o '"data":"approve_'"$SERIAL"'_void"')
    blacklist=$(echo "$updates" | grep -o '"data":"blacklist_'"$SERIAL"'_void"')
    if [ -n "$approve" ]; then
      save_status_local "approved"
      echo "$SERIAL|void|approved" >> "$DB_FILE"
      tg_send "$ADMIN_ID" "APPROVED! Serial: $SERIAL Module: Sensix Void"
      return 0
    elif [ -n "$blacklist" ]; then
      save_status_local "blacklisted"
      echo "$SERIAL|void|blacklisted" >> "$DB_FILE"
      tg_send "$ADMIN_ID" "BLACKLISTED! Serial: $SERIAL Module: Sensix Void"
      return 1
    fi
  done
  echo "Timeout. Coba lagi nanti."
  return 2
}

run_module() {
  clear
  echo ""
  echo "=============================="
  echo "  Developer By : Himz"
  echo "  Module Name  : Sensix Void"
  echo "  Version      : $CURRENT_VERSION"
  echo "=============================="
  echo ""
  if [ -f "/sdcard/Void/void.sh" ]; then
    sh /sdcard/Void/void.sh "$@"
  else
    echo "void.sh tidak ditemukan di /sdcard/Void/"
  fi
}

main() {
  clear
  echo "=============================="
  echo "  $MODULE_NAME v$CURRENT_VERSION"
  echo "  by @himzsensix_bot"
  echo "=============================="
  echo ""
  install_curl
  check_update
  get_device_info
  echo "Device  : $BRAND $MODEL"
  echo "Android : $ANDROID_VER"
  echo "Serial  : $SERIAL"
  echo ""
  local_status=$(read_status_local)
  if [ "$local_status" = "approved" ]; then
    run_module "$@"
    exit 0
  elif [ "$local_status" = "blacklisted" ]; then
    echo "AKSES DITOLAK! Device ini di-BLACKLIST!"
    notify_blacklist
    exit 1
  fi
  db_status=$(check_db "$SERIAL")
  if [ "$db_status" = "approved" ]; then
    save_status_local "approved"
    run_module "$@"
    exit 0
  elif [ "$db_status" = "blacklisted" ]; then
    save_status_local "blacklisted"
    echo "AKSES DITOLAK!"
    notify_blacklist
    exit 1
  fi
  echo "Device baru, mengirim notifikasi ke admin..."
  notify_new_device
  wait_approval
  result=$?
  if [ $result -eq 0 ]; then
    echo "APPROVED!"
    sleep 1
    run_module "$@"
  elif [ $result -eq 1 ]; then
    echo "Device kamu di-BLACKLIST oleh admin."
  else
    echo "Timeout. Coba lagi nanti."
  fi
}

main "$@"
