#!/usr/bin/env bash
#
# ЕДИНЫЙ УСТАНОВЩИК ДЛЯ НОВОГО СЕРВЕРА (одна команда):
#   • панель 3X-UI (веб-интерфейс)
#   • подключение VLESS + XTLS-Reality с уникальными ключами
#   • адрес для подключения на выбор:
#       1) домен, который создаётся автоматически (ИП-сервера.sslip.io) — без регистрации;
#       2) IP сервера;  3) свой домен.
#     SSL-сертификат Let's Encrypt на этот адрес (панель и подписка) + авто-продление
#   • ПОДПИСКА С РАЗДЕЛЬНОЙ МАРШРУТИЗАЦИЕЙ И ФИЛЬТРАЦИЕЙ:
#       российские сайты и российские IP-адреса (.ru .su .рф, Яндекс, VK,
#       Госуслуги, банки, маркетплейсы…) — напрямую, через интернет пользователя;
#       реклама и трекеры — блокируются;
#       всё остальное (зарубежное) — через VPN-канал.
#     Правила хранятся на сервере и приходят в приложение вместе с подпиской
#     (Happ, v2rayNG, v2rayN), обновляются автоматически. На телефонах ничего
#     настраивать не нужно — только один раз добавить ссылку-подписку.
#     Реклама дополнительно режется и на самом сервере — для любых приложений.
#
# ЗАПУСК на чистом Ubuntu 22.04/24.04 или Debian 12 под root — одна команда из GitHub:
#   bash <(curl -fsSL https://raw.githubusercontent.com/alexkashirin2-create/vpn/main/install-vpn-all.sh)
# Скрипт спросит, как подключаться (просто Enter — домен создастся автоматически).
# Без вопросов: DOMAIN=auto | DOMAIN=ip | DOMAIN=vpn.example.ru  bash <(curl -fsSL …)
#
# Повторный запуск на том же сервере безопасен: ключи VPN сохраняются (меняется
# только пароль панели); после смены IP сервера ссылки сами переходят на новый IP.
#
# Списки можно поменять в панели: Настройки → Подписка →
# «Профиль маршрутизации для JSON-подписки» (после правки увеличьте LastUpdated).
#
set -euo pipefail

# ===================== настройки (можно не трогать) =====================
DOMAIN="${DOMAIN:-}"                  # auto — домен создастся сам, ip — по IP, или свой домен; пусто — спросить
SNI="${SNI:-www.microsoft.com}"       # домен-маскировка Reality (TLS 1.3, открыт из РФ)
VPN_PORT="${VPN_PORT:-443}"           # порт VPN-подключения
PANEL_PORT="${PANEL_PORT:-}"          # порт панели (пусто = случайный, при повторном запуске — прежний)
SUB_PORT="${SUB_PORT:-2096}"          # порт, с которого приложения забирают подписку
PANEL_USER="${PANEL_USER:-admin}"     # логин в панель
LABEL="${LABEL:-MyVPN-Reality}"       # имя подключения и подписки в приложении
BLOCK_ADS="${BLOCK_ADS:-1}"           # 1 — блокировать рекламу и трекеры, 0 — не блокировать
XUI_VERSION="${XUI_VERSION:-}"        # версия 3X-UI (пусто = последняя доступная)
# ==========================================================================

XUI_TESTED_VERSION="v3.9.0"           # проверенная версия — запасной вариант
XUI_DIR="/usr/local/x-ui"
XUI_BIN="${XUI_DIR}/x-ui"
DB="/etc/x-ui/x-ui.db"
PROFILE="/root/vpn-profile.txt"
INSTALL_LOG="/root/x-ui-install.log"
INSTALL_SH_URLS=(
  "https://raw.githubusercontent.com/MHSanaei/3x-ui/main/install.sh"
  "https://cdn.jsdelivr.net/gh/MHSanaei/3x-ui@main/install.sh"
)

red() { printf '\033[31m%s\033[0m\n' "$*"; }
grn() { printf '\033[32m%s\033[0m\n' "$*"; }
ylw() { printf '\033[33m%s\033[0m\n' "$*"; }
die() { red "$*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Запустите под root (sudo -i)."
command -v apt-get >/dev/null 2>&1 || die "Нужен Ubuntu/Debian (apt)."
[ "$BLOCK_ADS" = "0" ] || BLOCK_ADS=1
if [[ "$XUI_VERSION" =~ ^[0-9] ]]; then XUI_VERSION="v${XUI_VERSION}"; fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------- обращение к API панели (по токену, локально) ----------
API_TOKEN=""
API_SCHEME="http"
wait_api() {   # ждёт, пока панель ответит; сам определяет http или https
  local _ s code
  for _ in $(seq 1 60); do
    for s in https http; do
      code="$(curl -sk --noproxy '*' --max-time 5 -o /dev/null -w '%{http_code}' \
        -H "Authorization: Bearer ${API_TOKEN}" \
        "${s}://127.0.0.1:${PANEL_PORT}/${WEBPATH}/panel/api/server/status" 2>/dev/null || true)"
      if [ "$code" = "200" ]; then API_SCHEME="$s"; return 0; fi
    done
    sleep 2
  done
  return 1
}
api_curl() {   # запрос к панели; если она как раз перезапускается — подождать и повторить
  local rc _
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    curl "$@" && return 0
    rc=$?
    case "$rc" in 7|28|35|52|56) sleep 3 ;; *) return "$rc" ;; esac
  done
  return 1
}
api() {        # api МЕТОД /путь [файл-с-JSON]
  local args=(-sk --noproxy '*' --max-time 60 -X "$1" -H "Authorization: Bearer ${API_TOKEN}")
  if [ -n "${3:-}" ]; then args+=(-H 'Content-Type: application/json' --data-binary "@$3"); fi
  api_curl "${args[@]}" "${API_SCHEME}://127.0.0.1:${PANEL_PORT}/${WEBPATH}/panel/api$2"
}
api_form() {   # api_form /путь поле=значение... (форма, как отправляет сама панель)
  local path="$1" args=(-sk --noproxy '*' --max-time 60 -X POST -H "Authorization: Bearer ${API_TOKEN}") f
  shift
  for f in "$@"; do args+=(--data-urlencode "$f"); done
  api_curl "${args[@]}" "${API_SCHEME}://127.0.0.1:${PANEL_PORT}/${WEBPATH}/panel/api${path}"
}
api_ok() {     # api_ok файл-ответа — успешен ли ответ панели (иначе печатает причину)
  python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
if d.get("success"): sys.exit(0)
print(" ".join(str(d.get("msg")).split())); sys.exit(1)' "$1" 2>/dev/null
}

# ---------- выбор версии 3X-UI без зависимости от «последней версии» GitHub ----------
xui_arch() {
  case "$(uname -m)" in
    x86_64|x64|amd64) echo amd64 ;;
    aarch64|arm64|armv8*) echo arm64 ;;
    armv7*|arm) echo armv7 ;;
    armv6*) echo armv6 ;;
    armv5*) echo armv5 ;;
    i*86|x86) echo 386 ;;
    s390x) echo s390x ;;
    *) echo "" ;;
  esac
}
good_tag() { [[ "$1" =~ ^v[0-9]+(\.[0-9]+)+$ ]]; }
GH=(-fsSL --retry 1 --connect-timeout 8 --max-time 20)
latest_tag() {   # номер последнего релиза — четырьмя разными способами
  local t
  t="$(curl "${GH[@]}" -o /dev/null -w '%{url_effective}' https://github.com/MHSanaei/3x-ui/releases/latest 2>/dev/null || true)"
  t="${t##*/tag/}"; if good_tag "$t"; then echo "$t"; return; fi
  t="$(curl "${GH[@]}" https://github.com/MHSanaei/3x-ui/releases.atom 2>/dev/null \
        | grep -oE '/releases/tag/v[0-9]+(\.[0-9]+)+"' | head -n 1 | tr -d '"' || true)"
  t="${t##*/}"; if good_tag "$t"; then echo "$t"; return; fi
  t="$(curl "${GH[@]}" https://api.github.com/repos/MHSanaei/3x-ui/releases/latest 2>/dev/null \
        | python3 -c 'import json,sys;print(json.load(sys.stdin).get("tag_name",""))' 2>/dev/null || true)"
  if good_tag "$t"; then echo "$t"; return; fi
  t="$(curl "${GH[@]}" 'https://data.jsdelivr.com/v1/packages/gh/MHSanaei/3x-ui/resolved?specifier=latest' 2>/dev/null \
        | python3 -c 'import json,sys;print("v"+json.load(sys.stdin).get("version",""))' 2>/dev/null || true)"
  if good_tag "$t"; then echo "$t"; return; fi
  echo ""
}
release_ok() {   # есть ли у версии готовый архив и скачивается ли он с GitHub
  local a; a="$(xui_arch)"
  [ -n "$a" ] || return 0
  curl -fsSL --retry 3 --retry-delay 3 --connect-timeout 10 --max-time 40 -o /dev/null \
    "https://github.com/MHSanaei/3x-ui/releases/download/$1/x-ui-linux-${a}.tar.gz.sha256" 2>/dev/null
}
github_code() {  # HTTP-код github.com с этого сервера (000 — нет соединения)
  local _ code="000"
  for _ in 1 2 3; do
    code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 20 https://github.com/MHSanaei/3x-ui/releases 2>/dev/null || true)"
    [ "${code:-000}" != "000" ] && break
    sleep 2
  done
  echo "${code:-000}"
}
github_diag() {  # понятная причина, если GitHub не отдаёт файлы
  case "$1" in
    000) echo "сервер не может соединиться с github.com (нет связи или блокировка у хостера)" ;;
    429) echo "GitHub временно ограничил запросы с IP этого сервера (HTTP 429) — подождите 30–60 минут и запустите снова" ;;
    403) echo "GitHub отклоняет запросы с IP этого сервера (HTTP 403)" ;;
    *) echo "github.com ответил кодом $1" ;;
  esac
}

# ============================================================================
grn "[1/10] Устанавливаю зависимости..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y >/dev/null
apt-get install -y curl openssl qrencode python3 socat cron ca-certificates >/dev/null

# ============================================================================
grn "[2/10] Определяю IP сервера..."
SERVER_IP=""
for u in https://api.ipify.org https://ipv4.icanhazip.com https://4.ident.me https://ifconfig.me/ip; do
  SERVER_IP="$(curl -4 -fsS --max-time 8 "$u" 2>/dev/null | tr -d '[:space:]' || true)"
  [[ "$SERVER_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && break
  SERVER_IP=""
done
[ -n "$SERVER_IP" ] || die "Не удалось определить внешний IPv4 сервера."
grn "    IP сервера: ${SERVER_IP}"
ADDR_FILE="/etc/x-ui/vpn-address"     # запоминаем выбор для повторных запусков
SAVED_MODE="$(cat "$ADDR_FILE" 2>/dev/null || true)"     # auto | ip | свой домен
AUTO_DOMAIN="${SERVER_IP//./-}.sslip.io"                  # «быстрый» домен: сразу указывает на IP
norm_domain() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's#^[a-z]+://##; s#[/:].*$##; s#\.$##; s#[[:space:]]##g'; }
is_ipv4() { [[ "$1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; }
MODE="$DOMAIN"
if [ -z "$MODE" ] && { : </dev/tty; } 2>/dev/null; then
  case "$SAVED_MODE" in ip) DEF=2 ;; ""|auto) DEF=1 ;; *) DEF=3 ;; esac
  {
    echo
    echo "Как телефоны будут подключаться к серверу?"
    echo "  1) Домен создастся автоматически: ${AUTO_DOMAIN} — быстро, без регистрации"
    echo "  2) По IP ${SERVER_IP}"
    echo "  3) Свой домен$([ "$DEF" = "3" ] && echo " (сейчас: ${SAVED_MODE})") — он должен указывать на ${SERVER_IP}"
    printf 'Ваш выбор [%s]: ' "$DEF"
  } > /dev/tty
  IFS= read -r CHOICE < /dev/tty || CHOICE=""
  CHOICE="${CHOICE// /}"
  case "${CHOICE:-$DEF}" in
    1) MODE=auto ;;
    2) MODE=ip ;;
    3) if [ "$DEF" = "3" ]; then printf 'Домен [%s]: ' "$SAVED_MODE" > /dev/tty; else printf 'Домен (например, vpn.example.ru): ' > /dev/tty; fi
       IFS= read -r MODE < /dev/tty || MODE=""
       [ -n "${MODE// /}" ] || { [ "$DEF" = "3" ] && MODE="$SAVED_MODE"; }
       [ -n "${MODE// /}" ] || die "Домен не указан." ;;
    *) die "Нужно ввести 1, 2 или 3." ;;
  esac
fi
[ -n "$MODE" ] || MODE="${SAVED_MODE:-auto}"
case "$MODE" in
  auto) ADDR="$AUTO_DOMAIN" ;;
  ip) ADDR="$SERVER_IP" ;;
  *)
    MODE="$(norm_domain "$MODE")"
    if is_ipv4 "$MODE"; then MODE=ip; ADDR="$SERVER_IP"
    else
      [[ "$MODE" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9-]{2,}$ ]] || die "Домен указан неверно: ${MODE}"
      ADDR="$MODE"
      DNS_IPS="$(python3 -c 'import socket,sys;print(" ".join(sorted({a[4][0] for a in socket.getaddrinfo(sys.argv[1],443,socket.AF_INET)})))' "$ADDR" 2>/dev/null || true)"
      if [ -z "$DNS_IPS" ]; then
        ylw "    Домен ${ADDR} пока не находится в DNS — сертификат может не выпуститься."
      elif [[ " $DNS_IPS " != *" $SERVER_IP "* ]]; then
        ylw "    Домен ${ADDR} указывает на ${DNS_IPS}, а IP сервера ${SERVER_IP} — проверьте A-запись домена."
      fi
    fi ;;
esac
grn "    Адрес для подключения: ${ADDR}"

# ============================================================================
grn "[3/10] Устанавливаю панель 3X-UI..."
PANEL_PASS="$(python3 -c 'import secrets,string;a=string.ascii_letters+string.digits;print("".join(secrets.choice(a) for _ in range(16)))')"
WEBPATH=""
FRESH=1
if [ -x "$XUI_BIN" ] && [ -f "$DB" ]; then
  FRESH=0
  ylw "    3X-UI уже установлена — пропускаю установку (ключи VPN и подписка сохранятся)."
else
  # Версию определяем сами: установщик 3X-UI останавливается, если GitHub
  # не сообщил номер последней версии. Пробуем несколько способов, а если
  # ничего не вышло — ставим проверенную версию.
  GH_CODE="$(github_code)"
  [ "$GH_CODE" != "000" ] || die "Не удалось скачать 3X-UI: $(github_diag 000)."
  VERSION=""
  LATEST="$(latest_tag)"
  for cand in "$XUI_VERSION" "$LATEST" "$XUI_TESTED_VERSION"; do
    [ -n "$cand" ] || continue
    if release_ok "$cand"; then VERSION="$cand"; break; fi
  done
  [ -n "$VERSION" ] || die "Не удалось скачать 3X-UI с GitHub: $(github_diag "$(github_code)")."
  if [ -z "$XUI_VERSION" ] && [ -z "$LATEST" ]; then
    ylw "    GitHub не сообщил номер последней версии — ставлю проверенную ${VERSION}."
  else
    grn "    Версия 3X-UI: ${VERSION}"
  fi

  [ -n "$PANEL_PORT" ] || PANEL_PORT=$(( (RANDOM % 20000) + 40000 ))
  WEBPATH="$(openssl rand -hex 8)"
  GOT_SH=0
  for u in "${INSTALL_SH_URLS[@]}"; do
    if curl -fsSL --retry 3 --connect-timeout 15 --max-time 90 -o "$WORK/install.sh" "$u" 2>/dev/null \
       && head -n 1 "$WORK/install.sh" | grep -q '^#!'; then GOT_SH=1; break; fi
  done
  [ "$GOT_SH" = "1" ] || die "Не удалось скачать установщик 3X-UI: $(github_diag "$(github_code)")."
  if ! XUI_NONINTERACTIVE=1 XUI_SSL_MODE=none XUI_DB_TYPE=sqlite XUI_ENABLE_FAIL2BAN=false \
       XUI_SERVER_IP="$SERVER_IP" XUI_PANEL_PORT="$PANEL_PORT" XUI_WEB_BASE_PATH="$WEBPATH" \
       XUI_USERNAME="$PANEL_USER" XUI_PASSWORD="$PANEL_PASS" \
       bash "$WORK/install.sh" "$VERSION" </dev/null >"$INSTALL_LOG" 2>&1; then
    red "Установка 3X-UI завершилась с ошибкой. Конец журнала ${INSTALL_LOG}:"
    tail -n 20 "$INSTALL_LOG"
    exit 1
  fi
  { [ -x "$XUI_BIN" ] && [ -f "$DB" ]; } || die "3X-UI не установилась. Журнал: ${INSTALL_LOG}"
fi

# ============================================================================
grn "[4/10] Настраиваю доступ к панели..."
if [ "$FRESH" = "0" ]; then   # прежние порт и путь панели, новый пароль
  CUR="$("$XUI_BIN" setting -show 2>/dev/null || true)"
  [ -n "$PANEL_PORT" ] || PANEL_PORT="$(printf '%s\n' "$CUR" | awk -F': ' '$1=="port"{print $2}' | tr -d '[:space:]')"
  WEBPATH="$(printf '%s\n' "$CUR" | awk -F': ' '$1=="webBasePath"{print $2}' | tr -d '[:space:]' | sed 's#^/*##; s#/*$##')"
  [[ "$PANEL_PORT" =~ ^[0-9]+$ ]] || PANEL_PORT=$(( (RANDOM % 20000) + 40000 ))
  [ "${#WEBPATH}" -ge 4 ] || WEBPATH="$(openssl rand -hex 8)"
fi
systemctl stop x-ui >/dev/null 2>&1 || true   # базу панели меняем, пока она остановлена
"$XUI_BIN" setting -username "$PANEL_USER" -password "$PANEL_PASS" -port "$PANEL_PORT" -webBasePath "$WEBPATH" >/dev/null 2>&1 \
  || { systemctl start x-ui || true; die "Не удалось задать логин и пароль панели."; }
API_TOKEN="$("$XUI_BIN" setting -getApiToken -tokenName vpn-installer 2>/dev/null | awk '$1=="apiToken:"{print $2}' | tail -n 1)"
if command -v ufw >/dev/null 2>&1; then
  for p in "$VPN_PORT" "$PANEL_PORT" "$SUB_PORT" 80; do ufw allow "${p}/tcp" >/dev/null 2>&1 || true; done
fi
systemctl enable x-ui >/dev/null 2>&1 || true
systemctl start x-ui
[ -n "$API_TOKEN" ] || die "Не удалось получить API-токен панели."
wait_api || die "Панель не запустилась. Логи: journalctl -u x-ui -e"

# ============================================================================
grn "[5/10] Выпускаю SSL-сертификат на ${ADDR}..."
SSL_OK=0
CERT=""; KEY=""
ACME="/root/.acme.sh/acme.sh"
cert_fresh() {   # есть ли сертификат именно на этот адрес, действующий ещё хотя бы сутки
  local text
  [ -s "$CERT" ] && [ -s "$KEY" ] || return 1
  openssl x509 -in "$CERT" -noout -checkend 86400 >/dev/null 2>&1 || return 1
  text="$(openssl x509 -in "$CERT" -noout -text 2>/dev/null || true)"
  if is_ipv4 "$ADDR"; then
    [[ "$text" =~ IP\ Address:${ADDR//./\\.}(,|[[:space:]]|$) ]]
  else
    [[ "$text" =~ DNS:${ADDR//./\\.}(,|[[:space:]]|$) ]]
  fi
}
setup_ssl() {
  CERT="/root/cert/${ADDR}/fullchain.pem"; KEY="/root/cert/${ADDR}/privkey.pem"
  if cert_fresh; then return 0; fi
  if [ ! -x "$ACME" ]; then
    curl -fsSL https://get.acme.sh | HOME=/root sh >"$WORK/acme-install.log" 2>&1 || true
  fi
  [ -x "$ACME" ] || { ylw "    Не удалось установить acme.sh."; return 1; }
  "$ACME" --set-default-ca --server letsencrypt >/dev/null 2>&1 || true
  # на IP Let's Encrypt даёт сертификат на ~6 дней, на домен — на 90; acme.sh сам продлевает по cron
  local life=(--days 60)
  is_ipv4 "$ADDR" && life=(--certificate-profile shortlived --days 3)
  if ! "$ACME" --issue -d "$ADDR" --standalone --httpport 80 --server letsencrypt \
       "${life[@]}" --force >"$WORK/acme.log" 2>&1; then
    ylw "    Let's Encrypt не выдал сертификат (порт 80 должен быть открыт снаружи):"
    tail -n 4 "$WORK/acme.log"
    return 1
  fi
  mkdir -p "/root/cert/${ADDR}"
  "$ACME" --install-cert -d "$ADDR" --key-file "$KEY" --fullchain-file "$CERT" \
    --reloadcmd "systemctl restart x-ui" >"$WORK/acme-inst.log" 2>&1 || true
  chmod 600 "$KEY" 2>/dev/null || true
  cert_fresh || { ylw "    Файлы сертификата не найдены после выпуска."; return 1; }
  return 0
}
if setup_ssl; then
  SSL_OK=1
elif [ "$MODE" = "auto" ]; then
  # у «быстрого» домена есть запасные варианты: зеркало nip.io, затем сам IP
  for alt in "${SERVER_IP}.nip.io" "$SERVER_IP"; do
    ylw "    Пробую запасной адрес: ${alt}"
    ADDR="$alt"
    if setup_ssl; then SSL_OK=1; break; fi
  done
  [ "$SSL_OK" = "1" ] || ADDR="$SERVER_IP"
fi
if [ "$SSL_OK" = "1" ]; then
  grn "    SSL: OK (сертификат на ${ADDR}, продлевается автоматически)"
fi
# acme.sh после выпуска сам перезапускает панель — дожидаемся, пока она снова ответит
wait_api || die "Панель не запустилась после выпуска сертификата. Логи: journalctl -u x-ui -e"

# ============================================================================
grn "[6/10] Готовлю подключение VLESS + Reality..."
XRAY_BIN=""
for f in "$XUI_DIR"/bin/xray-linux-*; do
  if [ -x "$f" ]; then XRAY_BIN="$f"; break; fi
done
[ -n "$XRAY_BIN" ] || die "Не найден xray внутри 3X-UI."
api GET /inbounds/list > "$WORK/inbounds.json" || die "API панели не отвечает."
VPN_PORT="$VPN_PORT" python3 - "$WORK/inbounds.json" > "$WORK/state" 2>/dev/null <<'PY' || echo "error" > "$WORK/state"
import json, os, sys
data = json.load(open(sys.argv[1]))
if not data.get("success"):
    print("error"); raise SystemExit
def obj(v):
    if isinstance(v, str):
        try:
            return json.loads(v) if v else {}
        except ValueError:
            return {}
    return v or {}
port = int(os.environ["VPN_PORT"])
for ib in data.get("obj") or []:
    if int(ib.get("port") or 0) != port:
        continue
    s, st = obj(ib.get("settings")), obj(ib.get("streamSettings"))
    rs = st.get("realitySettings") or {}
    clients = [c for c in (s.get("clients") or []) if c.get("id") and c.get("subId")]
    pub = (rs.get("settings") or {}).get("publicKey") or ""
    if ib.get("protocol") == "vless" and st.get("security") == "reality" and clients and pub:
        c = clients[0]
        print("reuse", ib["id"], c["id"], c["subId"], pub,
              (rs.get("shortIds") or [""])[0] or "-", (rs.get("serverNames") or ["-"])[0] or "-",
              ib.get("tag") or "-")
    else:
        print("replace", ib["id"])
    break
else:
    print("none")
PY
read -r STATE INB_ID UUID SUB_ID PUBLIC_KEY SHORT_ID OLD_SNI INB_TAG < "$WORK/state" || true

create_inbound() {
  local keys="" n msg
  api GET /server/getNewX25519Cert > "$WORK/keys.json" 2>/dev/null || true
  keys="$(python3 -c 'import json,sys;o=json.load(open(sys.argv[1]))["obj"];print(o["privateKey"],o["publicKey"])' "$WORK/keys.json" 2>/dev/null || true)"
  PRIVATE_KEY="${keys%% *}"; PUBLIC_KEY="${keys##* }"
  if [ -z "$keys" ]; then   # запасной путь: напрямую через xray
    keys="$("$XRAY_BIN" x25519 2>/dev/null || true)"
    PRIVATE_KEY="$(printf '%s\n' "$keys" | awk -F': *' 'tolower($1) ~ /private/ {print $2; exit}')"
    PUBLIC_KEY="$(printf '%s\n' "$keys" | awk -F': *' 'tolower($1) ~ /public|password/ {print $2; exit}')"
  fi
  { [ -n "$PRIVATE_KEY" ] && [ -n "$PUBLIC_KEY" ]; } || die "Не удалось сгенерировать ключи Reality."
  UUID="$(cat /proc/sys/kernel/random/uuid)"
  SHORT_ID="$(openssl rand -hex 8)"
  SUB_ID="$(openssl rand -hex 8)"
  # клиенты в 3X-UI живут отдельно от подключений: если user1 уже занят
  # (например, подключение удаляли), берём следующее свободное имя
  for n in $(seq 1 20); do
    UUID="$UUID" PRIVATE_KEY="$PRIVATE_KEY" PUBLIC_KEY="$PUBLIC_KEY" SHORT_ID="$SHORT_ID" SUB_ID="$SUB_ID" \
    SNI="$SNI" VPN_PORT="$VPN_PORT" LABEL="$LABEL" SHARE_ADDR="$ADDR" CLIENT_EMAIL="user${n}" \
    python3 - > "$WORK/inbound.json" <<'PY'
import json, os
e = os.environ
settings = {"clients": [{"id": e["UUID"], "flow": "xtls-rprx-vision", "email": e["CLIENT_EMAIL"],
                         "limitIp": 0, "totalGB": 0, "expiryTime": 0, "enable": True,
                         "tgId": 0, "subId": e["SUB_ID"], "comment": "", "reset": 0}],
            # "encryption" обязателен: без него JSON-подписка даёт конфиг, который новый Xray не принимает
            "decryption": "none", "encryption": "none", "fallbacks": []}
stream = {"network": "tcp", "security": "reality", "externalProxy": [],
          "realitySettings": {"show": False, "xver": 0, "target": e["SNI"] + ":443",
                              "serverNames": [e["SNI"]], "privateKey": e["PRIVATE_KEY"],
                              "minClientVer": "", "maxClientVer": "", "maxTimediff": 0,
                              "shortIds": [e["SHORT_ID"]], "mldsa65Seed": "",
                              "settings": {"publicKey": e["PUBLIC_KEY"], "fingerprint": "chrome",
                                           "serverName": "", "spiderX": "/", "mldsa65Verify": ""}},
          "tcpSettings": {"acceptProxyProtocol": False, "header": {"type": "none"}}}
sniffing = {"enabled": True, "destOverride": ["http", "tls", "quic", "fakedns"],
            "metadataOnly": False, "routeOnly": False}
print(json.dumps({"remark": e["LABEL"], "enable": True, "listen": "", "port": int(e["VPN_PORT"]),
                  "protocol": "vless", "expiryTime": 0, "total": 0,
                  # адрес в ссылках — выбранный IP или домен
                  "shareAddrStrategy": "custom", "shareAddr": e["SHARE_ADDR"],
                  "settings": json.dumps(settings), "streamSettings": json.dumps(stream),
                  "sniffing": json.dumps(sniffing)}))
PY
    api POST /inbounds/add "$WORK/inbound.json" > "$WORK/add.json" || die "API панели не отвечает."
    if msg="$(api_ok "$WORK/add.json")"; then
      INB_TAG="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["obj"].get("tag") or "-")' "$WORK/add.json" 2>/dev/null || echo "-")"
      return 0
    fi
    case "$msg" in *"Duplicate email"*) continue ;; esac
    die "Панель не приняла подключение: ${msg:-нет ответа}"
  done
  die "Не удалось подобрать свободное имя клиента."
}

sync_share_addr() {   # ссылки в подписке должны вести на выбранный адрес (важно после смены IP или домена)
  local st
  api GET "/inbounds/get/${INB_ID}" > "$WORK/inb-get.json" || return 1
  st="$(SHARE_ADDR="$ADDR" python3 - "$WORK/inb-get.json" "$WORK/inb-upd.json" <<'PY' 2>/dev/null || echo "error"
import json, os, sys
ib = json.load(open(sys.argv[1]))["obj"]
if isinstance(ib, str):
    ib = json.loads(ib)
ip = os.environ["SHARE_ADDR"]
if ib.get("shareAddrStrategy") == "custom" and ib.get("shareAddr") == ip:
    print("same"); raise SystemExit
ib["shareAddrStrategy"], ib["shareAddr"] = "custom", ip
for key in ("settings", "streamSettings", "sniffing"):
    value = ib.get(key)
    if not isinstance(value, str):
        ib[key] = json.dumps(value or {})
ib.pop("clientStats", None)
json.dump(ib, open(sys.argv[2], "w"))
print("changed")
PY
)"
  case "$st" in
    same) return 0 ;;
    changed)
      api POST "/inbounds/update/${INB_ID}" "$WORK/inb-upd.json" > "$WORK/inb-res.json" || return 1
      if api_ok "$WORK/inb-res.json" >/dev/null; then
        grn "    Адрес в ссылках обновлён: ${ADDR}"
        return 0
      fi
      return 1 ;;
    *) return 1 ;;
  esac
}

case "${STATE:-error}" in
  reuse)
    [ "$SHORT_ID" = "-" ] && SHORT_ID=""
    [ "$OLD_SNI" != "-" ] && SNI="$OLD_SNI"
    grn "    На порту ${VPN_PORT} уже есть подключение — оставляю его, ключи прежние."
    sync_share_addr || ylw "    Не удалось обновить адрес сервера в ссылках — проверьте подключение в панели."
    ;;
  replace)
    ylw "    Порт ${VPN_PORT} занят другим подключением — заменяю его."
    api POST "/inbounds/del/${INB_ID}" >/dev/null || true
    create_inbound
    ;;
  none)
    create_inbound
    ;;
  *)
    die "Не удалось прочитать список подключений из панели."
    ;;
esac

# ============================================================================
if [ "$BLOCK_ADS" = "1" ]; then
  grn "[7/10] Включаю фильтр рекламы и трекеров на сервере..."
else
  grn "[7/10] Фильтр рекламы на сервере выключен (BLOCK_ADS=0)..."
fi
# Правило в маршрутизации самого сервера: даже приложение, которое не умеет
# принимать правила из подписки, не получит рекламу через VPN.
SERVER_FILTER=0
if api POST /xray/ > "$WORK/xray-get.json" && api_ok "$WORK/xray-get.json" >/dev/null; then
  FILTER_STATE="$(BLOCK_ADS="$BLOCK_ADS" python3 - "$WORK/xray-get.json" "$WORK/xray-new.json" <<'PY' || echo "error"
import json, os, sys
obj = json.load(open(sys.argv[1]))["obj"]
if isinstance(obj, str):          # панель отдаёт настройки строкой с JSON внутри
    obj = json.loads(obj)
tpl = obj["xraySetting"]
if isinstance(tpl, str):
    tpl = json.loads(tpl)
rules = tpl.setdefault("routing", {}).setdefault("rules", [])
ADS = "geosite:category-ads-all"
ours = lambda r: r.get("domain") == [ADS] and r.get("outboundTag") == "blocked"
want = os.environ["BLOCK_ADS"] == "1"
have = any(ours(r) for r in rules)
if want and not have:
    if "blocked" not in {o.get("tag") for o in tpl.get("outbounds") or []}:
        print("no-blocked-outbound"); raise SystemExit
    pos = next((i + 1 for i, r in enumerate(rules) if r.get("outboundTag") == "api"), 0)
    rules.insert(pos, {"type": "field", "domain": [ADS], "outboundTag": "blocked"})
elif not want and have:
    rules[:] = [r for r in rules if not ours(r)]
else:
    print("same"); raise SystemExit
json.dump(tpl, open(sys.argv[2], "w"), ensure_ascii=False, indent=2)
print("changed")
PY
)"
  case "$FILTER_STATE" in
    changed)
      if api_form /xray/update "xraySetting@$WORK/xray-new.json" > "$WORK/xray-set.json" && api_ok "$WORK/xray-set.json" >/dev/null; then
        SERVER_FILTER=1
      fi ;;
    same) SERVER_FILTER=1 ;;
  esac
fi
if [ "$SERVER_FILTER" = "1" ]; then
  if [ "$BLOCK_ADS" = "1" ]; then grn "    Сервер блокирует рекламу и трекеры для всего VPN-трафика."; fi
else
  ylw "    Не удалось изменить правила сервера — фильтр будет работать только в приложениях."
fi

# ============================================================================
if [ "$BLOCK_ADS" = "1" ]; then
  grn "[8/10] Включаю подписку: РФ — напрямую, реклама — блок, остальное — VPN..."
else
  grn "[8/10] Включаю подписку: РФ — напрямую, остальное — VPN..."
fi
# Профиль в формате Happ. Из него же панель собирает готовые Xray-конфиги
# для v2rayNG / v2rayN. Все категории есть в стандартных geo-файлах
# (v2fly, Loyalsoldier, runetfreedom) — проверено.
ROUTING="$(BLOCK_ADS="$BLOCK_ADS" python3 - <<'PY'
import json, os, time
ads = os.environ["BLOCK_ADS"] == "1"
print(json.dumps({
    "Name": "RU-direct",
    "GlobalProxy": "true",                     # всё, что не попало в списки, — через VPN
    "LastUpdated": str(int(time.time())),      # Happ обновляет профиль, если число выросло
    "RouteOrder": "block-proxy-direct",        # сначала блок рекламы, потом остальное
    "DomainStrategy": "IPIfNonMatch",          # сайт не из списков — проверяется его IP
    "FakeDNS": "false",
    "RemoteDNSType": "DoH", "RemoteDNSDomain": "https://cloudflare-dns.com/dns-query",
    "RemoteDNSIP": "1.1.1.1",
    "DomesticDNSType": "DoU", "DomesticDNSDomain": "", "DomesticDNSIP": "77.88.8.8",
    "DnsHosts": {"cloudflare-dns.com": "1.1.1.1"},
    "DirectSites": ["geosite:private", "geosite:category-ru"],   # .ru .su .рф + российские сервисы
    "DirectIp": ["geoip:private", "geoip:ru"],                   # локальная сеть + все IP в России
    "ProxySites": [], "ProxyIp": [],
    "BlockSites": ["geosite:category-ads-all"] if ads else [],   # реклама и трекеры
    "BlockIp": [],
}, ensure_ascii=False, separators=(",", ":")))
PY
)"
systemctl stop x-ui
DB="$DB" ROUTING="$ROUTING" SUB_PORT="$SUB_PORT" TITLE="$LABEL" python3 - > "$WORK/paths" <<'PY' || { systemctl start x-ui || true; die "Не удалось записать настройки подписки в базу панели."; }
import os, secrets, sqlite3
con = sqlite3.connect(os.environ["DB"], timeout=30)
cur = con.cursor()
def get(key):
    row = cur.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
    return (row[0] or "").strip() if row else ""
def norm(path):
    path = path.strip().strip("/")
    return "/" + path + "/" if path else ""
sub_path = norm(get("subPath")) or "/" + secrets.token_hex(6) + "/"
json_path = norm(get("subJsonPath"))
if not json_path or json_path == sub_path:
    json_path = "/" + secrets.token_hex(6) + "/"
settings = {
    "subEnable": "true",
    "subPort": os.environ["SUB_PORT"],
    "subPath": sub_path,
    "subTitle": os.environ["TITLE"],
    "subJsonEnable": "true",
    "subJsonPath": json_path,
    # v2rayNG / v2rayN по обычной ссылке сразу получают Xray-конфиги с правилами
    "subJsonAutoDetect": "true",
    "subJsonUserAgentRegex": r"(?i)^(v2rayng|v2rayn)/",
    # правила для конфигов JSON-подписки; пустой subRoutingRules => этот же
    # профиль уходит в Happ заголовком "routing" и включается сам
    "subJsonRoutingRules": os.environ["ROUTING"],
    "subRoutingRules": "",
    "subEnableRouting": "true",
}
for key, value in settings.items():
    cur.execute("UPDATE settings SET value=? WHERE key=?", (value, key))
    if cur.rowcount == 0:
        cur.execute("INSERT INTO settings (key, value) VALUES (?, ?)", (key, value))
con.commit()
con.close()
print(sub_path, json_path)
PY
read -r SUB_PATH JSON_PATH < "$WORK/paths"
if [ "$SSL_OK" = "1" ]; then
  # одна команда ставит сертификат и на панель, и на сервер подписки
  "$XUI_BIN" setting -webCert "$CERT" -webCertKey "$KEY" >/dev/null 2>&1 || SSL_OK=0
elif [[ "$("$XUI_BIN" setting -getCert 2>/dev/null || true)" =~ cert:\ *[^[:space:]] ]]; then
  # старый сертификат (например, на прежний домен) не подходит для работы по IP
  "$XUI_BIN" cert -reset >/dev/null 2>&1 || true
fi
systemctl start x-ui
wait_api || die "Панель не запустилась после настройки подписки. Логи: journalctl -u x-ui -e"

# ============================================================================
grn "[9/10] Проверяю подписку и фильтры..."
if [ "$SSL_OK" = "1" ]; then SUB_BASE="https://${ADDR}:${SUB_PORT}"; else SUB_BASE="http://${ADDR}:${SUB_PORT}"; fi
SUB_URL="${SUB_BASE}${SUB_PATH}${SUB_ID}"
JSON_URL="${SUB_BASE}${JSON_PATH}${SUB_ID}"
fetch_local() {   # fetch_local USER-AGENT /путь  ->  $WORK/h (заголовки), $WORK/b (тело)
  local _ target=("http://127.0.0.1:${SUB_PORT}$2")
  [ "$SSL_OK" = "1" ] && target=("https://127.0.0.1:${SUB_PORT}$2")
  for _ in $(seq 1 10); do
    if curl -sk --noproxy '*' --connect-timeout 3 --max-time 10 -A "$1" -D "$WORK/h" -o "$WORK/b" "${target[@]}" 2>/dev/null \
       && head -n 1 "$WORK/h" | grep -q ' 200'; then
      return 0
    fi
    sleep 2
  done
  return 1
}
CHECK_HAPP=0
CHECK_JSON=0
if fetch_local "Happ/3.0" "${SUB_PATH}${SUB_ID}" && grep -qi '^routing: *happ://routing/onadd/' "$WORK/h"; then
  CHECK_HAPP=1
fi
if fetch_local "v2rayNG/1.10.0" "${SUB_PATH}${SUB_ID}" && BLOCK_ADS="$BLOCK_ADS" python3 - "$WORK/b" "$WORK/client.json" <<'PY'
import json, os, sys
data = json.load(open(sys.argv[1]))
conf = data[0] if isinstance(data, list) else data
rules = json.dumps(conf.get("routing", {}))
assert "geosite:category-ru" in rules and "geoip:ru" in rules
if os.environ["BLOCK_ADS"] == "1":
    assert "geosite:category-ads-all" in rules
json.dump(conf, open(sys.argv[2], "w"))
PY
then
  # тот же конфиг, что получит телефон, проверяем самим Xray
  if XRAY_LOCATION_ASSET="${XUI_DIR}/bin" "$XRAY_BIN" run -test -c "$WORK/client.json" >"$WORK/xtest.log" 2>&1; then
    CHECK_JSON=1
  fi
fi
# проверяем маршрут на самом сервере: рекламный домен должен уйти в блок
CHECK_SERVER="skip"
if [ "$BLOCK_ADS" = "1" ] && [ "$SERVER_FILTER" = "1" ] && [ "${INB_TAG:--}" != "-" ]; then
  CHECK_SERVER="fail"
  for _ in $(seq 1 5); do
    if api_form /xray/routeTest "domain=doubleclick.net" "port=443" "network=tcp" "inboundTag=${INB_TAG}" > "$WORK/route.json" \
       && python3 -c 'import json,sys;sys.exit(0 if "blocked" in json.dumps(json.load(open(sys.argv[1])).get("obj")) else 1)' "$WORK/route.json" 2>/dev/null; then
      CHECK_SERVER="ok"; break
    fi
    sleep 2
  done
fi
if [ "$CHECK_HAPP" = "1" ]; then grn "    ✓ Happ: правила приходят вместе с подпиской"
else ylw "    ✗ Happ: правила в ответе подписки не найдены"; fi
if [ "$CHECK_JSON" = "1" ]; then grn "    ✓ v2rayNG / v2rayN: конфиг с правилами прошёл проверку Xray"
else ylw "    ✗ v2rayNG / v2rayN: конфиг не прошёл проверку"; tail -n 3 "$WORK/xtest.log" 2>/dev/null || true; fi
case "$CHECK_SERVER" in
  ok)   grn "    ✓ Сервер: рекламный домен уходит в блок" ;;
  fail) ylw "    ✗ Сервер: проверка фильтра рекламы не прошла" ;;
esac

# ============================================================================
grn "[10/10] Формирую профиль..."
VLESS_URL="vless://${UUID}@${ADDR}:${VPN_PORT}?type=tcp&encryption=none&security=reality&pbk=${PUBLIC_KEY}&fp=chrome&sni=${SNI}&sid=${SHORT_ID}&spx=%2F&flow=xtls-rprx-vision#${LABEL}"
if [ "$API_SCHEME" = "https" ] && [ "$SSL_OK" = "1" ]; then
  PANEL_URL="https://${ADDR}:${PANEL_PORT}/${WEBPATH}"
else
  PANEL_URL="${API_SCHEME}://${ADDR}:${PANEL_PORT}/${WEBPATH}"
fi
if [ "$BLOCK_ADS" = "1" ]; then ADS_TEXT="блокируются"; else ADS_TEXT="не блокируются (BLOCK_ADS=0)"; fi

echo
ylw "==================== ВЕБ-ПАНЕЛЬ 3X-UI ===================="
echo "Адрес:  ${PANEL_URL}"
echo "Логин:  ${PANEL_USER}"
echo "Пароль: ${PANEL_PASS}"
if [ "$SSL_OK" = "1" ]; then echo "SSL:    включён (https, сертификат на ${ADDR})"; fi
echo
ylw "========================== ПОДПИСКА =========================="
echo "Добавьте в приложение ЭТУ ссылку (один раз):"
grn "${SUB_URL}"
echo
qrencode -t ANSIUTF8 "${SUB_URL}" 2>/dev/null || ylw "(qrencode недоступен — используйте ссылку)"
echo "Как добавить:"
echo "  • Happ (Android / iPhone / ПК): «+» → вставить ссылку из буфера или отсканировать QR."
echo "  • v2rayNG (Android): «+» → «Импорт из буфера обмена» → «Обновить подписку»."
echo
echo "Правила для всех устройств (приходят с сервера и обновляются сами):"
echo "  • российские сайты и российские IP-адреса → напрямую, через интернет пользователя;"
echo "  • реклама и трекеры → ${ADS_TEXT};"
echo "  • всё остальное → через VPN."
echo
echo "JSON-вариант той же подписки (для приложений, которым нужен Xray JSON):"
echo "  ${JSON_URL}"
if [ "$SSL_OK" != "1" ]; then
  echo
  ylw "SSL не настроился (причина — выше, на шаге 5), поэтому подписка пока работает по http."
  ylw "v2rayNG примет её только с галочкой «Разрешать незащищённые HTTP-адреса» в настройках подписки."
  ylw "Откройте снаружи порт 80 и запустите установку ещё раз той же командой — ключи VPN"
  ylw "сохранятся, а подписка переедет на https://${ADDR}:${SUB_PORT}/… (её нужно будет"
  ylw "добавить в приложение заново)."
fi

umask 077
printf '%s\n' "$MODE" > "$ADDR_FILE" 2>/dev/null || true
cat > "$PROFILE" <<TXT
=== Веб-панель 3X-UI ===
Адрес:  ${PANEL_URL}
Логин:  ${PANEL_USER}
Пароль: ${PANEL_PASS}
SSL:    $([ "$SSL_OK" = "1" ] && echo "включён (сертификат на ${ADDR})" || echo "не настроен")

=== Подписка (добавлять в приложение) ===
Ссылка:      ${SUB_URL}
JSON-версия: ${JSON_URL}
Правила: РФ-сайты и РФ-IP — напрямую; реклама и трекеры — ${ADS_TEXT}; остальное — через VPN.

=== Подключение VLESS + Reality ===
Сервер:    ${ADDR}:${VPN_PORT} (IP ${SERVER_IP})
SNI:       ${SNI}
UUID:      ${UUID}
PublicKey: ${PUBLIC_KEY}
ShortID:   ${SHORT_ID}
Одиночная ссылка (БЕЗ правил подписки — весь трафик через VPN):
${VLESS_URL}
TXT
chmod 600 "$PROFILE"
echo
ylw "Всё сохранено на сервере: ${PROFILE}"
ylw "========================================================="
