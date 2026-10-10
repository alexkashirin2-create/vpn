#!/usr/bin/env bash
#
# ЕДИНЫЙ УСТАНОВЩИК ДЛЯ НОВОГО СЕРВЕРА (одна команда):
#   • панель 3X-UI (веб-интерфейс)
#   • подключение VLESS + XTLS-Reality с уникальными ключами
#   • бесплатный домен DuckDNS + SSL Let's Encrypt (панель и подписка) + авто-продление
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
# ПЕРЕД ЗАПУСКОМ:
#   Откройте https://www.duckdns.org, войдите, в поле "sub domain" впишите имя
#   (например myvpn) и нажмите "add domain". Это имя подставьте в SUB ниже.
#
# ЗАПУСК на чистом Ubuntu 22.04/24.04 или Debian 12 под root:
#   SUB=myvpn bash install-vpn-all.sh
#
# Повторный запуск на том же сервере безопасен: ключи VPN и ссылка-подписка
# сохраняются (меняется только пароль панели) — так можно, например, дочинить SSL.
#
# Списки можно поменять в панели: Настройки → Подписка →
# «Профиль маршрутизации для JSON-подписки» (после правки увеличьте LastUpdated).
#
set -euo pipefail

# ============================ ЗАПОЛНИТЬ ============================
SUB="${SUB:-}"                                           # имя поддомена DuckDNS (без .duckdns.org)
TOKEN="${TOKEN:-c67abc8d-4f66-41b8-87bb-db7883241572}"   # токен DuckDNS
EMAIL="${EMAIL:-alexkashirin2@gmail.com}"                # почта для Let's Encrypt
# ===================== опционально (можно не трогать) =====================
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
DOMAIN="${SUB}.duckdns.org"
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
[ -n "$SUB" ] || die "Укажите имя поддомена DuckDNS: SUB=myvpn bash install-vpn-all.sh"
[ -n "$TOKEN" ] || die "Не задан токен DuckDNS (TOKEN=...)."
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
api() {        # api МЕТОД /путь [файл-с-JSON]
  local args=(-sk --noproxy '*' --max-time 60 -X "$1" -H "Authorization: Bearer ${API_TOKEN}")
  if [ -n "${3:-}" ]; then args+=(-H 'Content-Type: application/json' --data-binary "@$3"); fi
  curl "${args[@]}" "${API_SCHEME}://127.0.0.1:${PANEL_PORT}/${WEBPATH}/panel/api$2"
}
api_form() {   # api_form /путь поле=значение... (форма, как отправляет сама панель)
  local path="$1" args=(-sk --noproxy '*' --max-time 60 -X POST -H "Authorization: Bearer ${API_TOKEN}") f
  shift
  for f in "$@"; do args+=(--data-urlencode "$f"); done
  curl "${args[@]}" "${API_SCHEME}://127.0.0.1:${PANEL_PORT}/${WEBPATH}/panel/api${path}"
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
apt-get install -y curl openssl qrencode python3 certbot ca-certificates >/dev/null

# ============================================================================
grn "[2/10] Определяю IP сервера и привязываю домен ${DOMAIN}..."
SERVER_IP=""
for u in https://api.ipify.org https://ipv4.icanhazip.com https://4.ident.me https://ifconfig.me/ip; do
  SERVER_IP="$(curl -4 -fsS --max-time 8 "$u" 2>/dev/null | tr -d '[:space:]' || true)"
  [[ "$SERVER_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && break
  SERVER_IP=""
done
[ -n "$SERVER_IP" ] || die "Не удалось определить внешний IPv4 сервера."
DUCK_OK=0
DUCK_RESP="$(curl -fsS --max-time 20 "https://www.duckdns.org/update?domains=${SUB}&token=${TOKEN}&ip=${SERVER_IP}" 2>/dev/null || true)"
if [ "$DUCK_RESP" = "OK" ]; then
  DUCK_OK=1
  grn "    DuckDNS: OK (${DOMAIN} → ${SERVER_IP})"
  # авто-обновление IP домена раз в сутки
  mkdir -p /opt/duckdns
  printf '#!/usr/bin/env bash\ncurl -s "https://www.duckdns.org/update?domains=%s&token=%s&ip=" >/dev/null 2>&1\n' "$SUB" "$TOKEN" > /opt/duckdns/update.sh
  chmod 700 /opt/duckdns/update.sh
  ( crontab -l 2>/dev/null | grep -v '/opt/duckdns/update.sh' || true; echo "17 4 * * * /opt/duckdns/update.sh" ) | crontab - 2>/dev/null || true
else
  ylw "    DuckDNS вернул '${DUCK_RESP:-нет ответа}' (ожидалось OK). Проверьте имя поддомена и токен."
fi

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
grn "[5/10] Готовлю подключение VLESS + Reality..."
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
    SNI="$SNI" VPN_PORT="$VPN_PORT" LABEL="$LABEL" SERVER_IP="$SERVER_IP" CLIENT_EMAIL="user${n}" \
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
                  # в ссылках всегда IP сервера — подключение не зависит от DNS
                  "shareAddrStrategy": "custom", "shareAddr": e["SERVER_IP"],
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

case "${STATE:-error}" in
  reuse)
    [ "$SHORT_ID" = "-" ] && SHORT_ID=""
    [ "$OLD_SNI" != "-" ] && SNI="$OLD_SNI"
    grn "    На порту ${VPN_PORT} уже есть подключение — оставляю его, ключи прежние."
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
  grn "[6/10] Включаю фильтр рекламы и трекеров на сервере..."
else
  grn "[6/10] Фильтр рекламы на сервере выключен (BLOCK_ADS=0)..."
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
grn "[7/10] Настраиваю домен ${DOMAIN} и SSL..."
SSL_OK=0
CERT="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
KEY="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
setup_ssl() {
  [ "$DUCK_OK" = "1" ] || { ylw "    Домен не привязан (DuckDNS) — SSL пропущен."; return 1; }
  local r ok=0 _
  for _ in $(seq 1 30); do
    r="$(python3 -c 'import socket,sys;print(socket.gethostbyname(sys.argv[1]))' "$DOMAIN" 2>/dev/null || true)"
    [ "$r" = "$SERVER_IP" ] && { ok=1; break; }
    sleep 5
  done
  [ "$ok" = "1" ] || { ylw "    Домен пока не указывает на ${SERVER_IP} — SSL отложен."; return 1; }
  if ! certbot certonly --standalone --non-interactive --agree-tos -m "$EMAIL" -d "$DOMAIN" \
       --deploy-hook "systemctl restart x-ui" >"$WORK/certbot.log" 2>&1; then
    ylw "    certbot не выпустил сертификат (порт 80 должен быть открыт снаружи):"
    tail -n 5 "$WORK/certbot.log"
    return 1
  fi
  { [ -s "$CERT" ] && [ -s "$KEY" ]; } || { ylw "    Файлы сертификата не найдены."; return 1; }
  return 0
}
if setup_ssl; then
  SSL_OK=1
  grn "    SSL: OK"
elif [ -s "$CERT" ] && [ -s "$KEY" ]; then
  SSL_OK=1
  ylw "    Использую ранее выпущенный сертификат."
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
fi
systemctl start x-ui
wait_api || die "Панель не запустилась после настройки подписки. Логи: journalctl -u x-ui -e"

# ============================================================================
grn "[9/10] Проверяю подписку и фильтры..."
if [ "$SSL_OK" = "1" ]; then SUB_BASE="https://${DOMAIN}:${SUB_PORT}"; else SUB_BASE="http://${SERVER_IP}:${SUB_PORT}"; fi
SUB_URL="${SUB_BASE}${SUB_PATH}${SUB_ID}"
JSON_URL="${SUB_BASE}${JSON_PATH}${SUB_ID}"
fetch_local() {   # fetch_local USER-AGENT /путь  ->  $WORK/h (заголовки), $WORK/b (тело)
  local _ target=("http://127.0.0.1:${SUB_PORT}$2")
  [ "$SSL_OK" = "1" ] && target=(--resolve "${DOMAIN}:${SUB_PORT}:127.0.0.1" "https://${DOMAIN}:${SUB_PORT}$2")
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
VLESS_URL="vless://${UUID}@${SERVER_IP}:${VPN_PORT}?type=tcp&encryption=none&security=reality&pbk=${PUBLIC_KEY}&fp=chrome&sni=${SNI}&sid=${SHORT_ID}&spx=%2F&flow=xtls-rprx-vision#${LABEL}"
if [ "$API_SCHEME" = "https" ] && [ "$SSL_OK" = "1" ]; then
  PANEL_URL="https://${DOMAIN}:${PANEL_PORT}/${WEBPATH}"
else
  PANEL_URL="${API_SCHEME}://${SERVER_IP}:${PANEL_PORT}/${WEBPATH}"
fi
if [ "$BLOCK_ADS" = "1" ]; then ADS_TEXT="блокируются"; else ADS_TEXT="не блокируются (BLOCK_ADS=0)"; fi

echo
ylw "==================== ВЕБ-ПАНЕЛЬ 3X-UI ===================="
echo "Адрес:  ${PANEL_URL}"
echo "Логин:  ${PANEL_USER}"
echo "Пароль: ${PANEL_PASS}"
if [ "$SSL_OK" = "1" ]; then echo "SSL:    включён (https), заходите по домену ${DOMAIN}"; fi
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
  ylw "SSL не настроился (причина — выше, на шаге 7), поэтому подписка пока работает по http."
  ylw "v2rayNG примет её только с галочкой «Разрешать незащищённые HTTP-адреса» в настройках подписки."
  ylw "Когда домен заработает, запустите скрипт ещё раз — ключи VPN сохранятся, а подписка"
  ylw "переедет на https://${DOMAIN}:${SUB_PORT}/… (её нужно будет добавить в приложение заново):"
  echo  "   SUB=${SUB} bash install-vpn-all.sh"
fi

umask 077
cat > "$PROFILE" <<TXT
=== Веб-панель 3X-UI ===
Адрес:  ${PANEL_URL}
Логин:  ${PANEL_USER}
Пароль: ${PANEL_PASS}
SSL:    $([ "$SSL_OK" = "1" ] && echo "включён (домен ${DOMAIN})" || echo "не настроен")

=== Подписка (добавлять в приложение) ===
Ссылка:      ${SUB_URL}
JSON-версия: ${JSON_URL}
Правила: РФ-сайты и РФ-IP — напрямую; реклама и трекеры — ${ADS_TEXT}; остальное — через VPN.

=== Подключение VLESS + Reality ===
Сервер:    ${SERVER_IP}:${VPN_PORT}
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
