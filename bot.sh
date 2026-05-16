#!/system/bin/sh
# ============================================================
#   MODULESENSIX BOT LISTENER
#   Jalankan: sh /sdcard/Bot/bot.sh
# ============================================================

BOT_TOKEN="8287658272:AAHZl4wHiR2MNjzNC9TfnUHcheETKJbAngg"
ADMIN_ID="8540768271"
TGAPI="https://api.telegram.org/bot${BOT_TOKEN}"
CURL="/data/local/tmp/curl"
TG_RESOLVE="--resolve api.telegram.org:443:149.154.167.220"
OFFSET_FILE="/data/local/tmp/.sensix_offset"
DB_FILE="/data/local/tmp/.sensix_db"

mkdir -p /data/local/tmp
touch "$DB_FILE"
chmod +x "$CURL" 2>/dev/null

# ─── KIRIM PESAN ─────────────────────────────────────────────
send_msg() {
  $CURL -sk $TG_RESOLVE -X POST "${TGAPI}/sendMessage" \
    -d "chat_id=${1}" \
    --data-urlencode "text=${2}" \
    -d "parse_mode=HTML"
}

# ─── ANSWER CALLBACK ─────────────────────────────────────────
answer_cb() {
  $CURL -sk $TG_RESOLVE -X POST "${TGAPI}/answerCallbackQuery" \
    -d "callback_query_id=${1}" \
    --data-urlencode "text=${2}"
}

# ─── SIMPAN DB ───────────────────────────────────────────────
save_db() {
  grep -v "^${1}|${2}|" "$DB_FILE" > /tmp/.db_tmp 2>/dev/null
  echo "${1}|${2}|${3}" >> /tmp/.db_tmp
  cp /tmp/.db_tmp "$DB_FILE"
  echo "[DB] ${1} | ${2} => ${3}"
}

check_db() {
  grep "^${1}|${2}|" "$DB_FILE" 2>/dev/null | cut -d'|' -f3
}

# ─── HANDLE COMMAND ──────────────────────────────────────────
handle_cmd() {
  local full_text="$1"
  local chat="$2"

  cmd=$(echo "$full_text" | awk '{print $1}')
  arg1=$(echo "$full_text" | awk '{print $2}')
  arg2=$(echo "$full_text" | awk '{print $3}')

  echo "[CMD] $cmd | $arg1 | $arg2"

  case "$cmd" in
    /start|/help)
      send_msg "$chat" "🤖 <b>MODULESENSIX - Admin Panel</b>

<b>Perintah:</b>
/approve [serial] [module] - Approve device
/blacklist [serial] [module] - Blacklist device
/addmodule [serial] [module] - Tambah akses module
/reset [serial] - Reset device
/status [serial] - Cek status semua module
/listdevice - Lihat semua device
/help - Menu ini

<b>Module ID:</b>
void | cyro | nexa | xron

<b>Contoh:</b>
/approve ABC123 void
/blacklist ABC123 void
/approve ABC123 (approve semua)"
      ;;
    /approve)
      if [ -z "$arg2" ]; then
        for m in void cyro nexa xron; do
          save_db "$arg1" "$m" "approved"
        done
        send_msg "$chat" "✅ Device <code>${arg1}</code> di-APPROVE semua module!"
      else
        save_db "$arg1" "$arg2" "approved"
        send_msg "$chat" "✅ Device <code>${arg1}</code> di-APPROVE untuk <b>${arg2}</b>!"
      fi
      ;;
    /blacklist)
      if [ -z "$arg2" ]; then
        for m in void cyro nexa xron; do
          save_db "$arg1" "$m" "blacklisted"
        done
        send_msg "$chat" "🚫 Device <code>${arg1}</code> di-BLACKLIST semua module!"
      else
        save_db "$arg1" "$arg2" "blacklisted"
        send_msg "$chat" "🚫 Device <code>${arg1}</code> di-BLACKLIST untuk <b>${arg2}</b>!"
      fi
      ;;
    /addmodule)
      save_db "$arg1" "$arg2" "approved"
      send_msg "$chat" "➕ Module <b>${arg2}</b> ditambahkan untuk <code>${arg1}</code>!"
      ;;
    /reset)
      grep -v "^${arg1}|" "$DB_FILE" > /tmp/.db_tmp 2>/dev/null
      cp /tmp/.db_tmp "$DB_FILE"
      send_msg "$chat" "🔄 Device <code>${arg1}</code> di-RESET!"
      ;;
    /status)
      text="📊 <b>Status <code>${arg1}</code>:</b>

"
      for m in void cyro nexa xron; do
        st=$(check_db "$arg1" "$m")
        [ -z "$st" ] && st="belum terdaftar"
        [ "$st" = "approved" ] && icon="✅"
        [ "$st" = "blacklisted" ] && icon="🚫"
        [ "$st" = "belum terdaftar" ] && icon="❌"
        text="${text}${icon} ${m}: ${st}
"
      done
      send_msg "$chat" "$text"
      ;;
    /listdevice)
      if [ ! -s "$DB_FILE" ]; then
        send_msg "$chat" "📭 Belum ada device terdaftar."
      else
        text="📋 <b>DAFTAR DEVICE:</b>

"
        while IFS='|' read -r s m st; do
          [ "$st" = "approved" ] && icon="✅" || icon="🚫"
          text="${text}${icon} <code>${s}</code> | ${m} - ${st}
"
        done < "$DB_FILE"
        send_msg "$chat" "$text"
      fi
      ;;
    *)
      echo "[*] Perintah tidak dikenal: $cmd"
      ;;
  esac
}

# ─── HANDLE CALLBACK ─────────────────────────────────────────
handle_callback() {
  local cb_id="$1"
  local data="$2"
  local chat="$3"

  action=$(echo "$data" | cut -d'_' -f1)
  serial=$(echo "$data" | cut -d'_' -f2)
  module=$(echo "$data" | cut -d'_' -f3)

  case "$action" in
    approve)
      save_db "$serial" "$module" "approved"
      answer_cb "$cb_id" "✅ APPROVED!"
      send_msg "$chat" "✅ <code>${serial}</code> di-APPROVE untuk <b>${module}</b>!"
      ;;
    blacklist)
      save_db "$serial" "$module" "blacklisted"
      answer_cb "$cb_id" "🚫 BLACKLISTED!"
      send_msg "$chat" "🚫 <code>${serial}</code> di-BLACKLIST untuk <b>${module}</b>!"
      ;;
  esac
}

# ════════════════════════════════════════════════════════════
#   MAIN POLLING LOOP
# ════════════════════════════════════════════════════════════
echo "[*] ================================"
echo "[*]  MODULESENSIX BOT AKTIF"
echo "[*] ================================"
echo "[*] Menunggu perintah dari admin..."

offset=0
[ -f "$OFFSET_FILE" ] && offset=$(cat "$OFFSET_FILE")

send_msg "$ADMIN_ID" "🟢 <b>Modulesensix Bot AKTIF!</b>
Ketik /help untuk perintah."

while true; do
  response=$($CURL -sk $TG_RESOLVE --max-time 35 \
    "${TGAPI}/getUpdates?offset=${offset}&limit=10&timeout=30")

  if echo "$response" | grep -q '"update_id"'; then
    update_ids=$(echo "$response" | grep -o '"update_id":[0-9]*' | cut -d: -f2)

    for uid in $update_ids; do
      offset=$((uid + 1))
      echo "$offset" > "$OFFSET_FILE"

      # Cek callback query
      if echo "$response" | grep -q '"callback_query"'; then
        from_id=$(echo "$response" | grep -o '"callback_query":{"id":"[^"]*","from":{"id":[0-9]*' | grep -o '[0-9]*$')
        cb_id=$(echo "$response" | grep -o '"callback_query":{"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        cb_data=$(echo "$response" | grep -o '"data":"[^"]*"' | head -1 | cut -d'"' -f4)

        if [ "$from_id" = "$ADMIN_ID" ] && [ -n "$cb_data" ]; then
          echo "[CB] from=$from_id data=$cb_data"
          handle_callback "$cb_id" "$cb_data" "$ADMIN_ID"
        fi
      else
        # Parse pesan teks
        from_id=$(echo "$response" | grep -o '"from":{"id":[0-9]*' | head -1 | grep -o '[0-9]*$')
        chat_id=$(echo "$response" | grep -o '"chat":{"id":[^,]*' | head -1 | grep -o '\-\?[0-9]*$')
        msg_text=$(echo "$response" | grep -o '"text":"[^"]*"' | head -1 | cut -d'"' -f4)

        echo "[MSG] from=$from_id chat=$chat_id text=$msg_text"

        if [ "$from_id" = "$ADMIN_ID" ] && [ -n "$msg_text" ]; then
          handle_cmd "$msg_text" "$chat_id"
        fi
      fi
    done
  fi

  sleep 2
done
