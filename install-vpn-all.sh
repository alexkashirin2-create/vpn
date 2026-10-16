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
#   • СКОРОСТЬ: BBR и большие буферы TCP, QUIC переводится на TCP, IPv4 без ожидания IPv6.
#     В подписке несколько подключений: XHTTP с переиспользованием соединений (как у
#     коммерческих VPN, сайты открываются быстрее), обычное Reality (запасное),
#     WebSocket + TLS и Hysteria2 (QUIC по UDP — быстрее на мобильном интернете с потерями).
#     В конце скрипт сам меряет скорость и показывает, где узкое место.
#   • АВТОВЫБОР: в подписке профиль «🚀 Автовыбор» — приложение раз в минуту проверяет пинг
#     всех подключений и ведёт трафик через два лучших сразу; подключение с пингом больше
#     1 секунды или с потерями отключается само. Рядом — каждое подключение отдельно,
#     а в режиме моста — и каждый зарубежный сервер отдельно, с названием страны по его IP
#     («🇳🇱 Нидерланды», «🇨🇭 Швейцария»…).
#   • БЕЛЫЕ СПИСКИ ДЛЯ МОБИЛЬНОГО ИНТЕРНЕТА — отдельный пункт меню «3». Когда мобильный оператор
#     пускает только на «разрешённые» сайты, свой сервер недоступен. Выручают готовые подключения
#     из публичных списков для обхода белых списков — 25 источников: igareck/vpn-configs-for-russia
#     (мобильный, CIDR и SNI), zieng2/wl, whoahaow/rjsxrd, V.O.I.D, FLAT447, РосКомПозор (#РКП, с hub.mos.ru —
#     открывается и при белых списках), сборка all_subs и другие
#     (около 2000 разных подключений). Сервер скачивает все списки каждые 5 часов (с GitHub или
#     зеркал), объединяет без повторов и проверяет КАЖДОЕ подключение настоящим запросом через Xray:
#     все — раз в час, рабочие — каждые 15 минут. Нерабочее подключение пропадает из подписки сразу
#     после проверки. В подписку идут 15 самых быстрых рабочих по пингу (самые быстрые — первыми),
#     после своих подключений («🏳️ БС 12 · 🇷🇺 Russia»…); есть и отдельная ссылка — только на них (до 30).
#     АВТОПОДБОР ДЛЯ КОНКРЕТНОГО УСТРОЙСТВА — профиль «🏳️ БС 🚀 Автовыбор» (Happ, v2rayNG, v2rayN):
#     в нём 5 самых быстрых по пингу; при включении телефон сразу пингует их все из СВОЕЙ сети
#     (у каждого оператора и региона пропускают разные) и ведёт трафик через самый быстрый по пингу
#     из работающих у него; каждые 2 минуты пинг повторяется, не отвечает — телефон переходит на другой.
#     ПРОВЕРКА С ТЕЛЕФОНА — страница «…/test/» на порту подписки (адрес — в итоге установки): одна
#     команда в Termux (Android) скачивает с сервера Xray и список серверов, проверяет каждый из
#     мобильной сети телефона и отправляет результат на сервер. Серверы, которые работают у телефона,
#     встают в подписке первыми («🏳️ БС ✅ 01 · …») и попадают в автоподбор (результат действует
#     48 часов); те, что у телефона не заработали, уходят в конец списка.
#     ВХОД И ВЫХОД: у каждого рабочего подключения сервер определяет, где вход (IP сервера подключения —
#     по базе российских IP-сетей RIPE) и где выход (с какого IP подключение выходит в интернет).
#     Первыми в подписке и в автоподборе — вход в России (проходит белые списки по IP), выход за рубежом
#     («… · РФ→🌍»); с выходом в России («… · выход РФ») заблокированные сайты не откроются — они в конце
#     списка и не попадают в автоподбор. WHITE_RU_EXIT=drop — убрать их из подписки совсем.
#   • TUNNEL (Android, github.com/hussaroff/tunnel) И ДРУГИЕ ПРИЛОЖЕНИЯ НА MIHOMO (FlClash, Clash Meta,
#     Clash Verge) получают полный профиль Mihomo: свои подключения и «🚀 Автовыбор», белые списки
#     с автовыбором и «🔀 Автопереключение» — свой VPN, а когда он не отвечает (белые списки), сразу
#     белые списки; российские сайты — напрямую. В итоге установки — ссылка «Открыть в Tunnel».
#     Торренты в Tunnel по умолчанию идут мимо VPN (TUNNEL_TORRENT=0; 1 — через разрешённые серверы,
#     2 — через любой). MIHOMO=0 — без профиля Mihomo.
#   • FREETURN (Android, github.com/hackdiaz-dev/turn-proxy-android) — VPN через звонки VK: трафик идёт
#     через серверы звонков VK, а их не блокируют и при белых списках. Скрипт ставит сервер FreeTurn
#     (официальный установщик free-turn-proxy) с WireGuard и выдаёт ссылку freeturn:// для приложения.
#     В режиме моста FreeTurn ставится на зарубежные серверы — выход в интернет там. FREETURN=0 — убрать;
#     FREETURN_CALL=https://vk.ru/call/join/… — ссылку на звонок VK сразу вписать в ссылку для приложения.
#
# ЗАПУСК на чистом Ubuntu 22.04/24.04 или Debian 12 под root — одна команда из GitHub:
#   bash <(curl -fsSL https://raw.githubusercontent.com/alexkashirin2-create/vpn/main/install-vpn-all.sh)
# Скрипт спросит, как подключаться (просто Enter — домен создастся автоматически).
# Без вопросов: DOMAIN=auto | DOMAIN=ip | DOMAIN=vpn.example.ru  bash <(curl -fsSL …)
# Белые списки без вопросов: WHITE_LISTS=1 — вместе с установкой; WHITE_LISTS=only — только они
# (VPN уже установлен: ключи, подписка и пароль панели не меняются); WHITE_LISTS=0 — убрать.
#   WHITE_LISTS=only bash <(curl -fsSL …)
#
# МОСТ — если зарубежный сервер не открывается из России. Телефоны подключаются
# к российскому серверу; российские сайты он открывает сам, а зарубежные — через
# зарубежный сервер. Запускать на РОССИЙСКОМ сервере и выбрать «2) Мост»: скрипт
# спросит IP, логин и пароль зарубежного сервера и сам настроит его по SSH.
# Всё одной командой, без вопросов — IP, логин и пароль зарубежного сервера прямо в команде:
#   EXIT_HOST=IP EXIT_USER=root EXIT_PASS='пароль' DOMAIN=auto bash <(curl -fsSL …)
# (логин не root — подойдёт пользователь с правами sudo)
# Несколько зарубежных серверов — российский сервер каждые 15 секунд проверяет пинг до них
# и ведёт трафик через два лучших сразу; сервер с пингом больше 1 секунды или с потерями
# отключается, а если один откажет — работают другие:
#   EXIT_HOST='root:пароль1@IP1 root:пароль2@IP2 root:пароль3@IP3' DOMAIN=auto bash <(curl -fsSL …)
# (уже настроенные серверы можно указывать без пароля: «IP1 IP2 root:пароль@IP3»)
# Все зарубежные серверы настраиваются одновременно (5 серверов — те же несколько минут).
# Каждый зарубежный сервер становится «Узлом» российской панели: клиенты, трафик и лимиты
# всех серверов ведутся на российском сервере, а в одной ссылке-подписке у каждого
# зарубежного сервера два подключения — «через РФ» и «напрямую» (телефон → сервер, без России).
# Панели зарубежных серверов из интернета не видны — российская обращается к ним по мосту.
# По умолчанию — только через РФ (EXIT_DIRECT=0); узлы и прямые подключения: EXIT_DIRECT=1.
# Тонкие настройки балансировки (и для моста, и для «Автовыбора» в приложении):
#   BALANCE_EXPECTED=2   — сколько лучших серверов работают одновременно;
#   BALANCE_MAX_RTT=1s   — мост: максимальный пинг до выхода (например, 800ms): кто медленнее — отключается;
#   BALANCE_APP_RTT=3s   — «Автовыбор» в приложении: максимальный пинг с телефона.
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
SNI_USER="${SNI:-}"                   # SNI указан в команде — сменить его и у уже созданных подключений
SNI="${SNI:-www.microsoft.com}"       # домен-маскировка Reality (TLS 1.3, открыт из РФ)
VPN_PORT="${VPN_PORT:-443}"           # порт VPN-подключения
XHTTP_PORT="${XHTTP_PORT:-8443}"      # второе подключение VLESS + XHTTP (сайты открываются быстрее); 0 — не создавать
REALITY_ALT="${REALITY_ALT:-auto}"   # запасной Reality с российской маскировкой: auto — если сервер в РФ, а SNI зарубежный; 1 — всегда; 0 — нет
REALITY_ALT_PORT="${REALITY_ALT_PORT:-9443}"   # его порт
REALITY_ALT_SNI="${REALITY_ALT_SNI:-ya.ru www.ozon.ru www.wildberries.ru vk.com mail.ru www.gosuslugi.ru}"   # кандидаты: берётся первый, что открывается с сервера
WS_PORT="${WS_PORT:-2083}"            # третье подключение VLESS + WebSocket + TLS (как «LTE»-профили, проходит через CDN); 0 — нет
HY2_PORT="${HY2_PORT:-443}"           # четвёртое подключение Hysteria2 — UDP-порт (с Reality на TCP 443 не мешают); 0 — нет
PANEL_PORT="${PANEL_PORT:-}"          # порт панели (пусто = случайный, при повторном запуске — прежний)
SUB_PORT="${SUB_PORT:-2096}"          # порт, с которого приложения забирают подписку
PANEL_USER="${PANEL_USER:-admin}"     # логин в панель
LABEL="${LABEL:-MyVPN-Reality}"       # имя подключения и подписки в приложении
BLOCK_ADS="${BLOCK_ADS:-1}"           # 1 — блокировать рекламу и трекеры, 0 — не блокировать
BLOCK_QUIC="${BLOCK_QUIC:-1}"         # 1 — QUIC (UDP 443) через VPN гасится: приложения сразу берут TCP, так быстрее
BALANCE_EXPECTED="${BALANCE_EXPECTED:-2}"  # «Автовыбор» и мост: сколько лучших серверов работают одновременно
BALANCE_MAX_RTT="${BALANCE_MAX_RTT:-1s}"   # мост (на сервере): максимальный пинг до выхода — медленнее отключается
BALANCE_APP_RTT="${BALANCE_APP_RTT:-3s}"   # «Автовыбор» в приложении: максимальный пинг (телефон → РФ → выход: на мобильном часто больше 1 с)
SUB_FILTER="${SUB_FILTER:-1}"         # 1 — подписку отдаёт фильтр, который дописывает «Автовыбору» эти настройки; 0 — сама панель (с белыми списками фильтр нужен всё равно)
WHITE_LISTS="${WHITE_LISTS:-}"        # белые списки: 1 — включить, only — только они (VPN уже установлен), 0 — убрать; пусто — как в прошлый раз
WHITE_URL="${WHITE_URL:-}"            # белые списки: свои ссылки на txt-списки через пробел; пусто — как в прошлый раз; default — igareck
WHITE_REFRESH_HOURS="${WHITE_REFRESH_HOURS:-5}"   # белые списки: как часто скачивать список заново (часы)
WHITE_CHECK_MIN="${WHITE_CHECK_MIN:-30}"          # белые списки: как часто проверять каждое подключение (минуты)
WHITE_LABEL="${WHITE_LABEL:-🏳️ БС}"              # белые списки: начало названий этих подключений в приложении
WHITE_AUTO_MAX="${WHITE_AUTO_MAX:-5}"             # белые списки: сколько самых быстрых серверов телефон сам пингует в профиле автоподбора (0 — без профиля)
WHITE_SUB_MAX="${WHITE_SUB_MAX:-15}"              # белые списки: сколько самых быстрых по пингу рабочих — в подписке (отдельная ссылка — до 30); короче список — быстрее проверка пинга в приложении
WHITE_RU_EXIT="${WHITE_RU_EXIT:-last}"            # белые списки с выходом в интернет из России: last — в конец списка, drop — убрать
# Сбор белого CIDR-списка пингом (ICMP): какие IP отвечают, их ASN и страна, сборка в подсети → локальные файлы.
# Отдельный режим: WHITE_ICMP=1 собирает списки и выходит, VPN не трогает. Запуск:
#   WHITE_ICMP=1 WHITE_ICMP_ASN=13238,15169 bash <(curl -fsSL …)
WHITE_ICMP="${WHITE_ICMP:-}"              # 1 — собрать CIDR-список пингом и выйти; пусто — не собирать
WHITE_ICMP_ASN="${WHITE_ICMP_ASN:-}"      # ASN через запятую (напр. 13238,15169); префиксы берутся из RIPEstat
WHITE_ICMP_CIDR="${WHITE_ICMP_CIDR:-}"    # свои CIDR через запятую; можно вместе с ASN
WHITE_ICMP_IN="${WHITE_ICMP_IN:-}"        # свой файл с IP или CSV (по строке) — вместо выборки по ASN/CIDR
WHITE_ICMP_OUT="${WHITE_ICMP_OUT:-${WHITE_DATA:-/var/lib/vpn-white-lists}/icmp}"  # куда класть результат
WHITE_ICMP_SUBNET="${WHITE_ICMP_SUBNET:-24}"   # длина префикса для subnets.csv и white-cidr-local.txt
WHITE_ICMP_SAMPLE="${WHITE_ICMP_SAMPLE:-1}"    # сколько адресов на префикс пинговать (1 — только .1)
WHITE_ICMP_FULL="${WHITE_ICMP_FULL:-0}"        # 1 — пинговать все адреса префикса (с защитой WHITE_ICMP_MAX)
WHITE_ICMP_MAXPFX="${WHITE_ICMP_MAXPFX:-22}"   # при FULL пропускать префиксы крупнее /N (защита от огромного скана)
WHITE_ICMP_MAX="${WHITE_ICMP_MAX:-50000}"      # предел числа кандидатов
WHITE_ICMP_CONC="${WHITE_ICMP_CONC:-256}"      # параллельных пингов (фолбэк, если нет fping)
WHITE_ICMP_TMO="${WHITE_ICMP_TMO:-800}"        # таймаут одного пинга, мс
WHITE_ICMP_RETRY="${WHITE_ICMP_RETRY:-1}"      # повторов пинга на адрес
MIHOMO="${MIHOMO:-1}"                 # профиль Mihomo (Clash Meta) для Tunnel, FlClash, Clash Meta и Verge: 1 — включить, 0 — выключить
TUNNEL_TORRENT="${TUNNEL_TORRENT:-0}" # Tunnel: торренты 0 — мимо VPN (на сервер не придут жалобы), 1 — только через разрешённые серверы, 2 — через любой
FREETURN="${FREETURN:-1}"             # FreeTurn — VPN через звонки VK (работает и при белых списках): 1 — поставить, 0 — убрать
FREETURN_PORT="${FREETURN_PORT:-56000}"   # FreeTurn: внешний UDP-порт сервера
FREETURN_CALL="${FREETURN_CALL:-}"    # FreeTurn: ссылка на звонок VK (https://vk.ru/call/join/…) — сразу в ссылку для приложения
XUI_VERSION="${XUI_VERSION:-}"        # версия 3X-UI (пусто = последняя доступная)
EXIT_HOST="${EXIT_HOST:-}"            # мост: IP зарубежного сервера (пусто — спросить; none — без моста)
EXIT_USER="${EXIT_USER:-}"            # мост: логин на зарубежном сервере (пусто — спросить, по умолчанию root)
EXIT_PASS="${EXIT_PASS:-}"            # мост: пароль этого логина (пусто — спросить)
EXIT_SSH_PORT="${EXIT_SSH_PORT:-22}"  # мост: порт SSH зарубежного сервера
EXIT_VPN_PORT="${EXIT_VPN_PORT:-443}" # мост: порт, на котором зарубежный сервер ждёт российский
EXIT_XHTTP_PORT="${EXIT_XHTTP_PORT:-8443}" # мост: порт XHTTP на зарубежном сервере (0 — только TCP)
PEXIT_PROTO="${PEXIT_PROTO:-ws}"       # мост: подключения «через РФ» — ws (WebSocket + TLS на свой домен: проходит, когда провайдер режет Reality) или xhttp (Reality)
EXIT_DIRECT="${EXIT_DIRECT:-0}"       # мост: 0 — только через РФ (прямые подключения к зарубежным IP при белых списках не работают и в приложении висят «таймаутом»); 1 — ещё и узлы с прямым подключением
SCRIPT_URL="${SCRIPT_URL:-https://raw.githubusercontent.com/alexkashirin2-create/vpn/main/install-vpn-all.sh}"
# ==========================================================================
VPN_ROLE="${VPN_ROLE:-}"              # служебное: exit — так скрипт запускается на зарубежном сервере моста
BRIDGE_COMMENT=""                     # пометка клиента моста на зарубежном сервере (его видно и в российской панели)
if [ "$VPN_ROLE" = "exit" ]; then BRIDGE_COMMENT="Мост: российский сервер → этот сервер. Не удалять и не отключать."; fi
TUNNEL_TEST_URLS="${TUNNEL_TEST_URLS:-https://api.ipify.org https://ipv4.icanhazip.com https://4.ident.me}"
SPEED_URLS="${SPEED_URLS:-https://speed.cloudflare.com/__down?bytes=100000000 http://speedtest.tele2.net/100MB.zip}"
# XHTTP: сколько запросов идёт по одному соединению и как долго оно живёт (как у коммерческих VPN)
XMUX_JSON='{"maxConcurrency":"16-32","maxConnections":0,"cMaxReuseTimes":0,"hMaxRequestTimes":"600-900","hMaxReusableSecs":"1800-3000","hKeepAlivePeriod":30}'
SUB_INTERNAL_PORT="${SUB_INTERNAL_PORT:-12096}"   # при фильтре подписки панель отдаёт её только внутри сервера, на этом порту

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
SUB_FILTER_PY="/usr/local/bin/vpn-sub-filter.py"
SUB_FILTER_CONF="/etc/x-ui/vpn-sub-filter.json"
SUB_FILTER_UNIT="/etc/systemd/system/vpn-sub-filter.service"
WHITE_PY="/usr/local/bin/vpn-white-lists.py"        # белые списки: загрузка и проверка подключений
WHITE_CONF="/etc/x-ui/vpn-white-lists.json"
WHITE_DATA="/var/lib/vpn-white-lists"                # скачанный список, рабочие подключения, итог проверки
WHITE_UNIT="/etc/systemd/system/vpn-white-lists.service"
WHITE_TIMER="/etc/systemd/system/vpn-white-lists.timer"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
grn() { printf '\033[32m%s\033[0m\n' "$*"; }
ylw() { printf '\033[33m%s\033[0m\n' "$*"; }
die() { red "$*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Запустите под root (sudo -i)."
command -v apt-get >/dev/null 2>&1 || die "Нужен Ubuntu/Debian (apt)."
[ "$BLOCK_ADS" = "0" ] || BLOCK_ADS=1
[ "$BLOCK_QUIC" = "0" ] || BLOCK_QUIC=1
if ! [[ "$XHTTP_PORT" =~ ^[0-9]+$ ]] || [ "$XHTTP_PORT" -gt 65535 ]; then die "XHTTP_PORT указан неверно: ${XHTTP_PORT}"; fi
XHTTP_LABEL="${XHTTP_LABEL:-${LABEL%-Reality}-XHTTP}"
if ! [[ "$WS_PORT" =~ ^[0-9]+$ ]] || [ "$WS_PORT" -gt 65535 ]; then die "WS_PORT указан неверно: ${WS_PORT}"; fi
WS_LABEL="${WS_LABEL:-${LABEL%-Reality}-WS}"
if ! [[ "$HY2_PORT" =~ ^[0-9]+$ ]] || [ "$HY2_PORT" -gt 65535 ]; then die "HY2_PORT указан неверно: ${HY2_PORT}"; fi
HY2_LABEL="${HY2_LABEL:-${LABEL%-Reality}-Hysteria2}"
AUTO_LABEL="${AUTO_LABEL:-🚀 Автовыбор}"          # профиль, в котором телефон сам выбирает лучшие пути
PEXIT_PREFIX="${LABEL%-Reality}→"                 # так назывались отдельные подключения к выходам в прежних версиях
PEXIT_TAG_PREFIX="vpn-exit-"                      # метка отдельного подключения к выходу: vpn-exit-IP
PEXIT_BASE="${PEXIT_BASE:-8443}"                  # их порты: 8444, 8445, … (выход 1, выход 2, …)
[[ "$BALANCE_EXPECTED" =~ ^[1-9]$ ]] || die "BALANCE_EXPECTED — число от 1 до 9: ${BALANCE_EXPECTED}"
if [[ "$BALANCE_MAX_RTT" =~ ^[0-9]+$ ]]; then BALANCE_MAX_RTT="${BALANCE_MAX_RTT}ms"; fi
[[ "$BALANCE_MAX_RTT" =~ ^[1-9][0-9]*(ms|s)$ ]] || die "BALANCE_MAX_RTT указан неверно (например, 1s или 800ms): ${BALANCE_MAX_RTT}"
case "$BALANCE_MAX_RTT" in *ms) RTT_TEXT="${BALANCE_MAX_RTT%ms} мс" ;; *) RTT_TEXT="${BALANCE_MAX_RTT%s} с" ;; esac
if [[ "$BALANCE_APP_RTT" =~ ^[0-9]+$ ]]; then BALANCE_APP_RTT="${BALANCE_APP_RTT}ms"; fi
[[ "$BALANCE_APP_RTT" =~ ^[1-9][0-9]*(ms|s)$ ]] || die "BALANCE_APP_RTT указан неверно (например, 3s или 2500ms): ${BALANCE_APP_RTT}"
case "$BALANCE_APP_RTT" in *ms) APP_RTT_TEXT="${BALANCE_APP_RTT%ms} мс" ;; *) APP_RTT_TEXT="${BALANCE_APP_RTT%s} с" ;; esac
[ "$SUB_FILTER" = "0" ] || SUB_FILTER=1
{ [[ "$REALITY_ALT_PORT" =~ ^[1-9][0-9]{0,4}$ ]] && [ "$REALITY_ALT_PORT" -le 65535 ]; } || die "REALITY_ALT_PORT указан неверно: ${REALITY_ALT_PORT}"
[ "$EXIT_DIRECT" = "0" ] || EXIT_DIRECT=1
case "$(printf '%s' "$WHITE_LISTS" | tr '[:upper:]' '[:lower:]')" in
  "") WHITE_LISTS="" ;;
  1|on|yes|true) WHITE_LISTS=1 ;;
  only) WHITE_LISTS=only ;;
  0|off|no|false|none) WHITE_LISTS=0 ;;
  *) die "WHITE_LISTS: 1 — включить, only — только белые списки, 0 — убрать (сейчас: ${WHITE_LISTS})" ;;
esac
[[ "$WHITE_REFRESH_HOURS" =~ ^[1-9][0-9]?$ ]] || die "WHITE_REFRESH_HOURS — часы, от 1 до 99: ${WHITE_REFRESH_HOURS}"
{ [[ "$WHITE_CHECK_MIN" =~ ^[1-9][0-9]{0,2}$ ]] && [ "$WHITE_CHECK_MIN" -ge 5 ]; } \
  || die "WHITE_CHECK_MIN — минуты, от 5 до 999: ${WHITE_CHECK_MIN}"
{ [[ "$WHITE_AUTO_MAX" =~ ^[0-9]{1,2}$ ]] && [ "$WHITE_AUTO_MAX" -le 30 ]; } \
  || die "WHITE_AUTO_MAX — сколько серверов в автоподборе, от 0 (без него) до 30: ${WHITE_AUTO_MAX}"
{ [[ "$WHITE_SUB_MAX" =~ ^[1-9][0-9]{0,2}$ ]] && [ "$WHITE_SUB_MAX" -ge 5 ] && [ "$WHITE_SUB_MAX" -le 300 ]; } \
  || die "WHITE_SUB_MAX — сколько белых списков в подписке, от 5 до 300: ${WHITE_SUB_MAX}"
case "$(printf '%s' "$WHITE_RU_EXIT" | tr '[:upper:]' '[:lower:]')" in
  last|"") WHITE_RU_EXIT=last ;;
  drop|0|no|off) WHITE_RU_EXIT=drop ;;
  *) die "WHITE_RU_EXIT: last — выход в РФ в конец списка, drop — убрать (сейчас: ${WHITE_RU_EXIT})" ;;
esac
WHITE_AUTO_NAME="${WHITE_LABEL} 🚀 Автовыбор"     # профиль автоподбора белых списков в приложении
[ "$MIHOMO" = "0" ] || MIHOMO=1
[[ "$TUNNEL_TORRENT" =~ ^[012]$ ]] || die "TUNNEL_TORRENT — 0 (торренты мимо VPN), 1 или 2: ${TUNNEL_TORRENT}"
[ "$FREETURN" = "0" ] || FREETURN=1
{ [[ "$FREETURN_PORT" =~ ^[1-9][0-9]{0,4}$ ]] && [ "$FREETURN_PORT" -le 65535 ]; } || die "FREETURN_PORT указан неверно: ${FREETURN_PORT}"
if [ -n "$FREETURN_CALL" ] && ! [[ "$FREETURN_CALL" =~ ^https://(m\.)?vk\.(ru|com)/call/join/[A-Za-z0-9_-]+$ ]]; then
  die "FREETURN_CALL — ссылка на звонок VK вида https://vk.ru/call/join/…: ${FREETURN_CALL}"
fi
if [[ "$XUI_VERSION" =~ ^[0-9] ]]; then XUI_VERSION="v${XUI_VERSION}"; fi

# ---------- сбор белого CIDR-списка пингом (ICMP) ----------
# Самостоятельный режим WHITE_ICMP=1: собрать IP, которые отвечают на ICMP, с их ASN и страной,
# и свернуть в подсети. Ничего из VPN не трогает. Пишет в $WHITE_ICMP_OUT:
#   prefixes.txt candidates.txt alive-ips.txt alive.csv subnets.csv white-cidr-local.txt
# Шаги с сетью (RIPEstat для ASN→префиксы, Team Cymru для ASN+страны) рассчитаны на сервер.
white_icmp_build() {
  local out="$WHITE_ICMP_OUT"
  command -v python3 >/dev/null 2>&1 || die "Нужен python3."
  mkdir -p "$out" || die "Не создать каталог: $out"
  local pfx="$out/prefixes.txt" cand="$out/candidates.txt" alive="$out/alive-ips.txt"
  local enr="$out/enriched.tsv" acsv="$out/alive.csv" scsv="$out/subnets.csv" clist="$out/white-cidr-local.txt"

  # 1) кандидаты --------------------------------------------------------------
  if [ -n "$WHITE_ICMP_IN" ]; then
    [ -r "$WHITE_ICMP_IN" ] || die "Не прочитать WHITE_ICMP_IN: $WHITE_ICMP_IN"
    grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$WHITE_ICMP_IN" | sort -u > "$cand" || true
    : > "$pfx"
    grn "    Беру IP из файла: $WHITE_ICMP_IN"
  else
    : > "$pfx"
    local c a js
    for c in $(printf '%s' "$WHITE_ICMP_CIDR" | tr ',' ' '); do [ -n "$c" ] && printf '%s\n' "$c" >> "$pfx"; done
    for a in $(printf '%s' "$WHITE_ICMP_ASN" | tr ',' ' '); do
      a="${a#[Aa][Ss]}"; [ -n "$a" ] || continue
      grn "    Префиксы AS${a}…"
      js="$(curl -fsS --max-time 30 "https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS${a}" 2>/dev/null || true)"
      if [ -n "$js" ]; then
        printf '%s' "$js" | python3 - >> "$pfx" <<'PY' || true
import sys, json
try:
    d = json.load(sys.stdin)
    for p in d["data"]["prefixes"]:
        if ":" not in p["prefix"]:
            print(p["prefix"])
except Exception:
    pass
PY
      elif command -v whois >/dev/null 2>&1; then
        whois -h whois.radb.net -- "-i origin AS${a}" 2>/dev/null | awk '/^route:/{print $2}' >> "$pfx" || true
      else
        ylw "    AS${a}: RIPEstat недоступен и нет whois — пропуск (apt-get install -y whois)."
      fi
    done
    sort -u -o "$pfx" "$pfx" 2>/dev/null || true
    local npfx; npfx="$(grep -c . "$pfx" 2>/dev/null || true)"; npfx="${npfx:-0}"
    [ "$npfx" -gt 0 ] || die "Нет префиксов. Задайте WHITE_ICMP_ASN и/или WHITE_ICMP_CIDR (или WHITE_ICMP_IN)."
    grn "    Префиксов: $npfx"
    WIC_FULL="$WHITE_ICMP_FULL" WIC_SAMPLE="$WHITE_ICMP_SAMPLE" WIC_MAX="$WHITE_ICMP_MAX" WIC_MAXPFX="$WHITE_ICMP_MAXPFX" \
    python3 - "$pfx" "$cand" <<'PY' || die "Не удалось развернуть префиксы."
import ipaddress, os, sys
pfx, cand = sys.argv[1], sys.argv[2]
e = os.environ
full = e["WIC_FULL"] == "1"; sample = int(e["WIC_SAMPLE"]); mx = int(e["WIC_MAX"]); maxpfx = int(e["WIC_MAXPFX"])
out, seen = [], set()
def add(ip):
    s = str(ip)
    if s not in seen:
        seen.add(s); out.append(s)
for line in open(pfx):
    line = line.strip()
    if not line:
        continue
    try:
        net = ipaddress.ip_network(line, strict=False)
    except Exception:
        continue
    if net.version != 4:
        continue
    hosts = list(net.hosts()) or [net.network_address]
    if full:
        if net.prefixlen < maxpfx:
            print(f"skip {net} (крупнее /{maxpfx})", file=sys.stderr); continue
        for h in hosts: add(h)
    else:
        for h in hosts[:sample]: add(h)
    if len(out) >= mx:
        print(f"предел WHITE_ICMP_MAX={mx}", file=sys.stderr); break
open(cand, "w").write("\n".join(out[:mx]) + ("\n" if out else ""))
print(f"кандидатов: {min(len(out), mx)}", file=sys.stderr)
PY
  fi
  local ncand; ncand="$(grep -c . "$cand" 2>/dev/null || true)"; ncand="${ncand:-0}"
  [ "$ncand" -gt 0 ] || die "Нет кандидатов для пинга."

  # 2) ICMP-скан --------------------------------------------------------------
  grn "    Пингую $ncand адресов…"
  : > "$alive"
  if command -v fping >/dev/null 2>&1; then
    fping -a -q -r "$WHITE_ICMP_RETRY" -t "$WHITE_ICMP_TMO" < "$cand" > "$alive" 2>/dev/null || true
  else
    local ts=$(( (WHITE_ICMP_TMO + 999) / 1000 )); [ "$ts" -lt 1 ] && ts=1
    TS="$ts" RETRY="$WHITE_ICMP_RETRY" xargs -P "$WHITE_ICMP_CONC" -I{} sh -c '
      n=0; while [ "$n" -le "$RETRY" ]; do
        ping -c1 -W "$TS" "{}" >/dev/null 2>&1 && { echo "{}"; break; }
        n=$((n+1)); done' < "$cand" > "$alive" 2>/dev/null || true
  fi
  sort -u -o "$alive" "$alive" 2>/dev/null || true
  local nup; nup="$(grep -c . "$alive" 2>/dev/null || true)"; nup="${nup:-0}"
  grn "    Ответили на ICMP: $nup из $ncand"

  # 3) обогащение ASN + страна (Team Cymru, один запрос) ----------------------
  python3 - "$alive" "$enr" <<'PY' || true
import socket, sys
alive, enr = sys.argv[1], sys.argv[2]
ips = [l.strip() for l in open(alive) if l.strip()]
raw = ""
if ips:
    try:
        q = "begin\nverbose\n" + "\n".join(ips) + "\nend\n"
        s = socket.create_connection(("whois.cymru.com", 43), timeout=30)
        s.sendall(q.encode()); buf = b""
        while True:
            d = s.recv(65536)
            if not d: break
            buf += d
        s.close(); raw = buf.decode(errors="replace")
    except Exception as ex:
        print(f"Team Cymru недоступен ({ex}); ASN/страна останутся пустыми", file=sys.stderr)
info = {}
for line in raw.splitlines():
    if "|" not in line or line.lower().startswith("bulk"): continue
    parts = [p.strip() for p in line.split("|")]
    if len(parts) < 7: continue
    asn, ip, prefix, cc, reg, alloc, name = parts[:7]
    if not ip or ip == "IP": continue
    info[ip] = (cc, asn, name)
with open(enr, "w") as o:
    for ip in ips:
        cc, asn, name = info.get(ip, ("", "", ""))
        o.write(f"{ip}\t{cc}\t{asn}\t{name}\n")
PY

  # 4) выходные файлы ---------------------------------------------------------
  python3 - "$enr" "$acsv" "$scsv" "$clist" "$WHITE_ICMP_SUBNET" <<'PY' || die "Не удалось записать результат."
import csv, ipaddress, sys
enr, acsv, scsv, clist, sp = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
rows = []
try:
    for l in open(enr):
        parts = (l.rstrip("\n").split("\t") + ["", "", "", ""])[:4]
        if parts[0]: rows.append(tuple(parts))
except OSError:
    pass
w = csv.writer(open(acsv, "w", newline=""))
w.writerow(["ip", "location", "asn", "as_name"])
for ip, cc, asn, name in rows: w.writerow([ip, cc, asn, name])
nets = {}
for ip, cc, asn, name in rows:
    net = str(ipaddress.ip_network(f"{ip}/{sp}", strict=False))
    e = nets.setdefault(net, {"cc": set(), "asn": set(), "n": 0})
    e["n"] += 1
    if cc: e["cc"].add(cc)
    if asn: e["asn"].add(asn)
order = sorted(nets, key=lambda n: ipaddress.ip_network(n))
w = csv.writer(open(scsv, "w", newline=""))
w.writerow(["subnet", "asn", "location", "live_ips"])
for net in order:
    e = nets[net]
    w.writerow([net, "|".join(sorted(e["asn"])), "|".join(sorted(e["cc"])), e["n"]])
with open(clist, "w") as f:
    for net in order: f.write(net + "\n")
print(f"alive.csv: {len(rows)} строк   subnets.csv / white-cidr-local.txt: {len(nets)} подсетей", file=sys.stderr)
PY
  grn "    Готово. Файлы в: $out"
  ylw "      alive.csv — IP, страна, ASN, имя AS"
  ylw "      subnets.csv — подсети /$WHITE_ICMP_SUBNET с ASN и страной"
  ylw "      white-cidr-local.txt — плоский CIDR-список (как WHITE-CIDR-RU-checked.txt)"
  grn "    Подключить к белым спискам: выложите white-cidr-local.txt по ссылке и добавьте её в WHITE_URL."
  return 0
}
if [ -n "$WHITE_ICMP" ] && [ "$WHITE_ICMP" != "0" ]; then
  grn "=== Сбор белого CIDR-списка пингом (ICMP) ==="
  white_icmp_build
  exit 0
fi

WORK="$(mktemp -d)"
TUNNEL_PID=""
cleanup() {
  if [ -n "$TUNNEL_PID" ]; then kill "$TUNNEL_PID" 2>/dev/null || true; fi
  rm -rf "$WORK"
}
trap cleanup EXIT

is_ipv4() { [[ "$1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; }
tcp_ok() {     # tcp_ok хост порт — открывается ли TCP-соединение (ждём до 8 секунд)
  # shellcheck disable=SC2016  # $0 и $1 раскрывает внутренний bash
  timeout 8 bash -c 'exec 3<>"/dev/tcp/$0/$1"' "$1" "$2" 2>/dev/null
}
HAS_TTY=0
if { : </dev/tty; } 2>/dev/null; then HAS_TTY=1; fi
tty_read() {   # tty_read ПЕРЕМЕННАЯ "вопрос" [-s] — ответ с клавиатуры (-s — ввод не показывать)
  local answer=""
  printf '%s' "$2" > /dev/tty
  if [ "${3:-}" = "-s" ]; then
    IFS= read -rs answer < /dev/tty || answer=""
    echo > /dev/tty
  else
    IFS= read -r answer < /dev/tty || answer=""
  fi
  printf -v "$1" '%s' "$answer"
}
apt_retry() {  # apt-get с ожиданием: на новом сервере первые минуты идут автообновления и база apt занята
  local _
  for _ in $(seq 1 30); do
    if apt-get -o DPkg::Lock::Timeout=60 "$@" >/dev/null 2>"$WORK/apt.err"; then return 0; fi
    grep -qiE 'lock|temporarily unavailable' "$WORK/apt.err" || break
    sleep 10
  done
  tail -n 5 "$WORK/apt.err"
  return 1
}

tune_network() {   # ускорение TCP: BBR, большие буферы, без «засыпания» соединений (сразу и после перезагрузки)
  local conf=/etc/sysctl.d/99-vpn-speed.conf
  modprobe tcp_bbr >/dev/null 2>&1 || true
  {
    echo "# install-vpn-all.sh: ускорение TCP для VPN"
    echo "net.core.default_qdisc = fq"
    if grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
      echo "net.ipv4.tcp_congestion_control = bbr"
    fi
    echo "net.core.rmem_max = 33554432"
    echo "net.core.wmem_max = 33554432"
    echo "net.ipv4.tcp_rmem = 4096 131072 33554432"
    echo "net.ipv4.tcp_wmem = 4096 65536 33554432"
    echo "net.core.netdev_max_backlog = 16384"
    echo "net.ipv4.tcp_mtu_probing = 1"
    echo "net.ipv4.tcp_slow_start_after_idle = 0"
    echo "net.ipv4.tcp_notsent_lowat = 131072"
    echo "net.ipv4.tcp_tw_reuse = 1"
    echo "net.ipv4.tcp_fin_timeout = 15"
  } > "$conf"
  echo "tcp_bbr" > /etc/modules-load.d/vpn-bbr.conf 2>/dev/null || true
  sysctl -p "$conf" >/dev/null 2>&1 || true   # в контейнерах (OpenVZ, LXC) часть параметров менять нельзя — это не ошибка
  if [ "$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)" = "bbr" ]; then
    grn "    Сеть ускорена: BBR и увеличенные буферы TCP."
  else
    ylw "    BBR на этом сервере недоступен (ограничение ядра или виртуализации) — оставляю стандартный режим."
  fi
}
speed_mbit() {   # speed_mbit [прокси] — скорость скачивания за ~10 секунд, Мбит/с (пусто — не удалось измерить)
  local u bps mbit urls=() args=()
  read -ra urls <<< "$SPEED_URLS"
  if [ -n "${1:-}" ]; then args=(-x "$1"); fi
  for u in "${urls[@]}"; do
    bps="$(env -u no_proxy -u NO_PROXY curl -s -o /dev/null --connect-timeout 8 --max-time 10 "${args[@]}" \
      -w '%{speed_download}' "$u" 2>/dev/null || true)"
    mbit="$(python3 -c 'import sys
try:
    v = float(sys.argv[1]) * 8 / 1e6
except ValueError:
    v = 0
print(int(v) if v >= 1 else "")' "${bps:-0}" 2>/dev/null || true)"
    if [ -n "$mbit" ]; then echo "$mbit"; return 0; fi
  done
  echo ""
}
ip_country() {   # ip_country IP-или-домен — код страны сервера по его IP (NL, CH, …); пусто — узнать не удалось
  local ip="$1" u out cc
  if ! is_ipv4 "$ip"; then
    ip="$(python3 -c 'import socket,sys;print(socket.gethostbyname(sys.argv[1]))' "$ip" 2>/dev/null || true)"
    is_ipv4 "$ip" || return 0
  fi
  for u in "https://ipinfo.io/${ip}/country" "https://api.country.is/${ip}" \
           "http://ip-api.com/line/${ip}?fields=countryCode" "https://get.geojs.io/v1/ip/country/${ip}"; do
    out="$(curl -fsS --connect-timeout 4 --max-time 6 "$u" 2>/dev/null | head -c 300 || true)"
    if [[ "$out" =~ \"country\"[[:space:]]*:[[:space:]]*\"([A-Za-z]{2})\" ]]; then cc="${BASH_REMATCH[1]}"
    else cc="$(printf '%s' "$out" | tr -d '[:space:]')"; fi
    cc="$(printf '%s' "$cc" | tr '[:lower:]' '[:upper:]')"
    if [[ "$cc" =~ ^[A-Z]{2}$ ]] && [ "$cc" != "XX" ] && [ "$cc" != "ZZ" ]; then echo "$cc"; return 0; fi
  done
  return 0
}
cc_title() {     # cc_title NL — «🇳🇱 Нидерланды» (флаг и название страны по-русски)
  [[ "${1:-}" =~ ^[A-Z]{2}$ ]] || return 0
  python3 - "$1" <<'PY' 2>/dev/null || true
import sys
names = dict(x.split("=") for x in """AD=Андорра AE=ОАЭ AL=Албания AM=Армения AR=Аргентина AT=Австрия AU=Австралия
AZ=Азербайджан BA=Босния_и_Герцеговина BD=Бангладеш BE=Бельгия BG=Болгария BH=Бахрейн BR=Бразилия BY=Беларусь
BZ=Белиз CA=Канада CH=Швейцария CL=Чили CN=Китай CO=Колумбия CR=Коста-Рика CY=Кипр CZ=Чехия DE=Германия
DK=Дания EE=Эстония EG=Египет ES=Испания FI=Финляндия FR=Франция GB=Великобритания GE=Грузия GI=Гибралтар
GR=Греция HK=Гонконг HR=Хорватия HU=Венгрия ID=Индонезия IE=Ирландия IL=Израиль IM=Остров_Мэн IN=Индия
IR=Иран IS=Исландия IT=Италия JP=Япония KG=Киргизия KR=Южная_Корея KZ=Казахстан LI=Лихтенштейн LT=Литва
LU=Люксембург LV=Латвия MA=Марокко MC=Монако MD=Молдова ME=Черногория MK=Северная_Македония MN=Монголия
MT=Мальта MX=Мексика MY=Малайзия NG=Нигерия NL=Нидерланды NO=Норвегия NZ=Новая_Зеландия PA=Панама
PH=Филиппины PK=Пакистан PL=Польша PT=Португалия QA=Катар RO=Румыния RS=Сербия RU=Россия SA=Саудовская_Аравия
SC=Сейшелы SE=Швеция SG=Сингапур SI=Словения SK=Словакия TH=Таиланд TJ=Таджикистан TM=Туркмения TR=Турция
TW=Тайвань UA=Украина US=США UZ=Узбекистан VN=Вьетнам ZA=ЮАР""".split())
cc = sys.argv[1]
flag = "".join(chr(0x1F1E6 + ord(c) - ord("A")) for c in cc)
sys.stdout.buffer.write(("%s %s" % (flag, names.get(cc, cc).replace("_", " "))).encode())
PY
}

# ---------- самопроверка подключений: как у телефона, настоящим запросом ----------
# Берёт из подписки (как её получает Happ) каждое своё подключение — Reality, XHTTP, WS, Hysteria2,
# «через РФ» — запускает с этими настройками Xray и пропускает через него запрос в интернет.
# Запрос идёт с самого сервера, поэтому проверяет сервер и настройки, но не провайдера телефона:
# работает здесь и «н/д» на телефоне — подключение режет сеть телефона (для Reality — смените SNI).
OWN_OK=0; OWN_FAIL=0; OWN_REALITY_FAIL=0; OWN_TLS_OK=0
own_conn_test() {   # own_conn_test URL-подписки [xray] [метка-белых-списков]
  local url="$1" xr="${2:-}" wl="${3:-}" dir n name port proto pid _ ip line
  OWN_OK=0; OWN_FAIL=0; OWN_REALITY_FAIL=0; OWN_TLS_OK=0
  [ -n "$xr" ] || xr="$(compgen -G "/usr/local/x-ui/bin/xray-linux-*" | head -n 1 || true)"
  [ -x "$xr" ] || { ylw "    Самопроверка пропущена: не найден Xray панели."; return 1; }
  dir="$(mktemp -d)"
  if ! curl -sk --noproxy '*' --max-time 20 -A 'Happ/3.0' -o "$dir/sub.json" "$url" 2>/dev/null; then
    ylw "    Самопроверка пропущена: подписка не отвечает (${url})."; rm -rf "$dir"; return 1
  fi
  WL="$wl" python3 - "$dir/sub.json" "$dir" > "$dir/list" 2>/dev/null <<'PY' || { ylw "    Самопроверка пропущена: подписка не в формате Xray JSON."; rm -rf "$dir"; return 1; }
import json, os, sys
data = json.load(open(sys.argv[1]))
wl = os.environ.get("WL") or ""
port = 31800
for i, c in enumerate(data if isinstance(data, list) else [data]):
    name = str(c.get("remarks") or "")
    if not name or (wl and name.startswith(wl)) or (c.get("routing") or {}).get("balancers"):
        continue                                   # белые списки и «Автовыбор» — не свои отдельные подключения
    proxy = next((o for o in c.get("outbounds") or [] if isinstance(o, dict) and o.get("tag") == "proxy"), None)
    if not proxy:
        continue
    st = proxy.get("streamSettings") or {}
    kind = "%s/%s/%s" % (proxy.get("protocol"), st.get("network") or "tcp", st.get("security") or "none")
    port += 1
    conf = {"log": {"loglevel": "warning"},
            "inbounds": [{"listen": "127.0.0.1", "port": port, "protocol": "socks", "settings": {"udp": False}}],
            "outbounds": [dict(proxy, tag="proxy")]}
    json.dump(conf, open("%s/c%d.json" % (sys.argv[2], port), "w"))
    print(port, kind, name.replace("\n", " "))
    if port >= 31830:
        break
PY
  if [ ! -s "$dir/list" ]; then ylw "    Самопроверка: в подписке нет своих подключений."; rm -rf "$dir"; return 1; fi
  while read -r port proto name; do
    XRAY_LOCATION_ASSET="$(dirname "$xr")" "$xr" run -c "$dir/c${port}.json" > "$dir/x${port}.log" 2>&1 &
    pid=$!
    for _ in $(seq 1 20); do tcp_ok 127.0.0.1 "$port" && break; sleep 0.3; done
    ip=""
    for u in https://api.ipify.org https://ipv4.icanhazip.com; do
      ip="$(env -u no_proxy -u NO_PROXY curl -s --max-time 12 -x "socks5h://127.0.0.1:${port}" "$u" 2>/dev/null | tr -d '[:space:]' || true)"
      is_ipv4 "$ip" && break; ip=""
    done
    kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
    if [ -n "$ip" ]; then
      OWN_OK=$((OWN_OK + 1))
      case "$proto" in */tls) OWN_TLS_OK=$((OWN_TLS_OK + 1)) ;; esac
      grn "    ✓ ${name} (${proto}): работает, выход в интернет — ${ip}"
    else
      OWN_FAIL=$((OWN_FAIL + 1))
      case "$proto" in */reality) OWN_REALITY_FAIL=$((OWN_REALITY_FAIL + 1)) ;; esac
      line="$(grep -iE 'error|failed|reality' "$dir/x${port}.log" 2>/dev/null | tail -n 1 | cut -c1-160 || true)"
      ylw "    ✗ ${name} (${proto}): запрос не прошёл${line:+ — ${line}}"
    fi
  done < "$dir/list"
  rm -rf "$dir"
  return 0
}
reality_sni_hint() {   # reality_sni_hint IP-сервера SNI — подсказка: российский сервер с зарубежной маскировкой
  local cc
  case "$2" in *.ru|*.su|*.xn--p1ai|*.рф) return 0 ;; esac
  cc="$(ip_country "$1")"
  if [ "$cc" = "RU" ]; then
    ylw "    ! Сервер в России, а маскировка Reality — зарубежный сайт (${2}). Провайдеры часто режут такие"
    ylw "      подключения: у телефона Reality и XHTTP будут «н/д», хотя здесь работают. Помогает российский"
    ylw "      сайт: запустите скрипт с SNI=ya.ru (или SNI=www.ozon.ru) в начале команды — ключи сохранятся."
  fi
}

if [ "${CHECK:-}" = "1" ]; then   # только самопроверка: ничего не устанавливает и не меняет
  grn "=== Самопроверка подключений из подписки ==="
  C_SUB="$(sed -n 's/^Ссылка: *//p' "$PROFILE" 2>/dev/null | head -n 1 || true)"
  [ -n "$C_SUB" ] || die "Не нашёл ссылку-подписку в ${PROFILE} — сначала установите VPN этим скриптом."
  C_WL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("label") or "")' "$WHITE_CONF" 2>/dev/null || true)"
  own_conn_test "$C_SUB" "" "${C_WL:-$WHITE_LABEL}" || exit 1
  C_IP="$(curl -4 -fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)"
  C_SNI="$(python3 -c 'import json, sqlite3, sys
for (s,) in sqlite3.connect(sys.argv[1], timeout=30).execute("SELECT stream_settings FROM inbounds WHERE port=?", (int(sys.argv[2]),)):
    n = ((json.loads(s or "{}").get("realitySettings") or {}).get("serverNames") or [""])[0]
    if n: print(n); break' "$DB" "$VPN_PORT" 2>/dev/null || true)"
  if [ -n "$C_SNI" ] && [ -n "$C_IP" ]; then reality_sni_hint "$C_IP" "$C_SNI"; fi
  echo "Итог: работают ${OWN_OK}, не работают ${OWN_FAIL}. Проверка идёт с сервера: если здесь ✓, а в приложении «н/д» — подключение режет сеть телефона."
  exit 0
fi

# ---------- фильтр подписки и белые списки: программы, которые ставит этот скрипт ----------
# Фильтр подписки стоит перед панелью на порту подписки: дописывает «Автовыбору» тонкие настройки
# балансировки и добавляет в подписку рабочие подключения белых списков.
write_sub_filter_program() {
  mkdir -p "$(dirname "$SUB_FILTER_PY")"
  cat > "$SUB_FILTER_PY" <<'PY'
#!/usr/bin/env python3
# Фильтр подписки VPN (ставит install-vpn-all.sh). Принимает запросы приложений на порту
# подписки и передаёт их панели 3X-UI, которая отдаёт подписку только внутри сервера.
# В профили с балансировкой leastLoad («Автовыбор») дописывает тонкие настройки: сколько
# лучших подключений работают одновременно, максимальный пинг и допустимые потери.
# Белые списки (если включены): из рабочих подключений (alive.json — его каждые несколько минут
# обновляет vpn-white-lists) добавляет в конец подписки самые быстрые по пингу (sub_max, самые
# быстрые — первыми), отдельной подпиской по своему адресу — до list_max. Для Happ, v2rayNG и v2rayN перед
# ними — профиль автоподбора по пингу: приложение само пингует лучшие белые списки из сети этого
# телефона и ведёт трафик через самый быстрый из тех, что работают именно у него.
# Профиль Mihomo (Clash Meta — Tunnel, FlClash и др.): к профилю панели дописывает автовыбор своих
# подключений, белые списки и «автопереключение» (свой VPN, а при белых списках — белые списки).
# Проверка с телефона (страница …/test/): телефон в Termux скачивает отсюда Xray и список серверов,
# проверяет их из мобильной сети и присылает отчёт; серверы, которые работают у телефона, идут
# в подписке первыми (с ✅) и попадают в автоподбор.
import base64, copy, hashlib, html, json, os, re, secrets, shutil, socket, ssl, sys, threading, time
import urllib.error, urllib.parse, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CONF = json.load(open(sys.argv[1]))
UPSTREAM = "http://127.0.0.1:%d" % int(CONF["upstream"])
CERT, KEY = CONF.get("cert") or "", CONF.get("key") or ""
TUNE = CONF.get("leastLoad") or {}
WHITE = CONF.get("white") or {}
SKIP = {"connection", "keep-alive", "proxy-connection", "transfer-encoding", "te", "trailer", "upgrade",
        "content-length", "content-encoding", "accept-encoding", "host", "date", "server"}
LINK = re.compile(r"^[a-z][a-z0-9+.-]*://\S+$", re.I)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect)


def tune(body):
    if not TUNE:
        return body
    try:
        data = json.loads(body.decode("utf-8"))
    except ValueError:
        return body                       # обычная подписка (ссылки в base64) — как есть
    changed = False
    for conf in data if isinstance(data, list) else [data]:
        routing = conf.get("routing") if isinstance(conf, dict) else None
        for bal in (routing.get("balancers") if isinstance(routing, dict) else None) or []:
            strategy = bal.get("strategy") if isinstance(bal, dict) else None
            if isinstance(strategy, dict) and strategy.get("type") == "leastLoad":
                settings = strategy.setdefault("settings", {})
                for key, value in TUNE.items():
                    settings.setdefault(key, value)
                changed = True
    return json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8") if changed else body


# ---------- белые списки ----------
_white_lock = threading.Lock()
_white = {"stamp": None, "all": [], "sub": [], "list": [], "auto": [], "phone": [], "verified": {}, "failed": set()}
PHONE = WHITE.get("phone") or {}
PHONE_DIR = PHONE.get("dir") or ""
VERIFIED = os.path.join(PHONE_DIR, "verified.json") if PHONE_DIR else ""
REPORTS = os.path.join(PHONE_DIR, "reports") if PHONE_DIR else ""
_phone_lock = threading.Lock()


def file_stamp(path):
    try:
        st = os.stat(path)
        return st.st_mtime_ns, st.st_size
    except (OSError, TypeError, ValueError):
        return None


def read_json(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError, TypeError):
        return default


def item_key(item):
    """постоянный код подключения: одинаков при любом номере и названии"""
    return hashlib.sha1(json.dumps(item["outbound"], sort_keys=True).encode("utf-8")).hexdigest()[:12]


def fresh_verified():
    """проверка с телефона за последние hours часов: (работают — код → пинг у телефона, сеть и время
    самой свежей удачной проверки; не работают ни в одной из проверенных сетей — коды)"""
    out, failed, limit = {}, set(), time.time() - float(PHONE.get("hours") or 48) * 3600
    data = read_json(VERIFIED, {}) if VERIFIED else {}
    for key, nets in (data.items() if isinstance(data, dict) else []):
        for label, r in (nets.items() if isinstance(nets, dict) else []):
            if not isinstance(r, dict) or float(r.get("time") or 0) < limit:
                continue
            if not r.get("ok"):
                failed.add(key)
                continue
            cur = {"ms": int(r.get("ms") or 10 ** 6), "label": label, "time": int(r.get("time") or 0)}
            old = out.get(key)
            if old is None or (cur["time"], -cur["ms"]) > (old["time"], -old["ms"]):
                out[key] = cur
    return out, failed - set(out)


def marked(items, verified):
    """проверенные телефоном — с ✅ в названии (и в ссылке)"""
    label = WHITE.get("label") or ""
    out = []
    for it in items:
        if it.get("_key") in verified:
            name = it["name"]
            name = label + " ✅" + name[len(label):] if label and name.startswith(label) else "✅ " + name
            it = dict(it, name=name, link=rename_link(it["link"], name))
        out.append(it)
    return out


def rename_link(link, name):
    try:
        if link.lower().startswith("vmess://"):
            body = link.split("://", 1)[1].split("#", 1)[0]
            d = json.loads(base64.b64decode(body + "=" * (-len(body) % 4)).decode("utf-8"))
            d["ps"] = name
            return "vmess://" + base64.b64encode(json.dumps(d, ensure_ascii=False).encode("utf-8")).decode("ascii")
        return link.split("#", 1)[0] + "#" + urllib.parse.quote(name, safe="")
    except (ValueError, TypeError):
        return link


def white_items(kind="sub"):
    """белые списки из рабочих подключений (файлы перечитываются, только когда изменились):
    sub — для подписки, list — для отдельной подписки, auto — для профиля автоподбора,
    phone — для проверки с телефона, all — все рабочие, verified — работают у телефона,
    failed — у телефона не работают"""
    empty = {"verified": {}, "failed": set()}.get(kind, [])
    path = WHITE.get("file")
    if not path:
        return empty
    stamp = (file_stamp(path), file_stamp(VERIFIED) if VERIFIED else None, int(time.time() // 600))
    if stamp[0] is None:
        return empty
    with _white_lock:
        if stamp != _white["stamp"]:
            try:
                with open(path, encoding="utf-8") as f:
                    items = json.load(f).get("items") or []
                items = [x for x in items if isinstance(x, dict) and isinstance(x.get("link"), str)
                         and isinstance(x.get("outbound"), dict) and x.get("name")]
                for it in items:
                    it["_key"] = item_key(it)
                ver, bad = fresh_verified()
                # в автоподбор — без выхода в РФ (с ним заблокированные сайты не откроются), если есть другие
                no_ru = [x for x in items if x.get("out_ru") is not True]
                auto_max = int((WHITE.get("auto") or {}).get("max") or 0)
                # везде — сначала работающие у телефона (по пингу у телефона), дальше самые быстрые по
                # пингу с сервера, а не работающие у телефона — в самом конце
                _white.update(stamp=stamp, all=items, verified=ver, failed=bad,
                              sub=marked(pick_best(items, int(WHITE.get("sub_max") or 15), ver, bad), ver),
                              list=marked(pick_best(items, int(WHITE.get("list_max") or 30), ver, bad), ver),
                              auto=pick_best(no_ru if len(no_ru) >= min(2, auto_max) else items, auto_max, ver, bad),
                              phone=pick_best(items, int(PHONE.get("max") or 300), ver, bad))
            except (OSError, ValueError, AttributeError, TypeError):
                pass                      # файл как раз переписывается — отдаём прежний список
        return _white[kind]


def with_level(outbound, level):
    """уровень политики (тайм-ауты соединений) — как у подключений самой панели"""
    out = copy.deepcopy(outbound)
    settings = out.get("settings") or {}
    for server in (settings.get("vnext") or []) + (settings.get("servers") or []):
        if isinstance(server, dict):
            if isinstance(server.get("users"), list):
                for user in server["users"]:
                    if isinstance(user, dict):
                        user["level"] = level
            else:
                server["level"] = level
    return out


def server_host(outbound):
    """адрес сервера подключения"""
    s = outbound.get("settings") or {}
    for key in ("vnext", "servers"):
        for srv in s.get(key) or []:
            if isinstance(srv, dict):
                return str(srv.get("address") or "")
    return str(s.get("address") or "")


def server_port(outbound):
    """порт сервера подключения"""
    s = outbound.get("settings") or {}
    for key in ("vnext", "servers"):
        for srv in s.get(key) or []:
            if isinstance(srv, dict):
                return srv.get("port")
    return s.get("port")


def ping_of(item):
    """пинг подключения — время ответа через него при последней проверке на сервере, мс"""
    return item["ms"] if isinstance(item.get("ms"), (int, float)) else 10 ** 9


def tier(item):
    """вход в РФ и выход за рубежом — лучшие (проходят белые списки по IP и открывают заблокированные
    сайты); дальше выход за рубежом; выход не определился; выход в РФ — в самом конце"""
    out = item.get("out_ru")
    if out is True:
        return 3
    if out is None:
        return 2
    return 0 if item.get("in_ru") is True else 1


def rank(item):
    return tier(item), ping_of(item)


def fastest(items, limit):
    """limit лучших: сначала по входу и выходу (tier), внутри — самые быстрые по пингу. Один и тот же
    сервер (с другим ключом или портом) — только после всех остальных серверов, чтобы не было одинаковых"""
    seen, first, rest = set(), [], []
    for it in sorted(items, key=rank):
        host = server_host(it["outbound"])
        (rest if host in seen else first).append(it)
        seen.add(host)
    return sorted((first + rest)[:max(0, limit)], key=rank)


def pick_best(items, limit, verified=None, failed=()):
    """сначала работающие у телефона (самые быстрые у телефона — первыми), дальше самые быстрые по
    пингу с сервера, а те, что у телефона не заработали, — в конце"""
    verified = verified or {}
    mine = sorted((it for it in items if it.get("_key") in verified), key=lambda it: verified[it["_key"]]["ms"])[:limit]
    other = fastest([it for it in items if it.get("_key") not in verified and it.get("_key") not in failed],
                    limit - len(mine))
    return mine + other + fastest([it for it in items if it.get("_key") in failed], limit - len(mine) - len(other))


def white_auto(template, chosen, level):
    """профиль автоподбора по пингу: лучшие белые списки в одном конфиге; приложение при включении
    пингует их все сразу из сети телефона, потом раз в interval, и ведёт трафик через самый быстрый
    из живых (не отвечает — отключается сам). Правила — как у остальных конфигов."""
    auto = WHITE.get("auto") or {}
    if len(chosen) < 2:
        return None
    conf = copy.deepcopy(template)
    outs = []
    for i, it in enumerate(chosen, 1):
        ob = with_level(it["outbound"], level) if isinstance(level, int) else copy.deepcopy(it["outbound"])
        ob["tag"] = "wl-%d" % i
        outs.append(ob)
    conf["outbounds"] = outs + [o for o in conf["outbounds"] if not (isinstance(o, dict) and o.get("tag") == "proxy")]
    routing = conf.setdefault("routing", {})
    for rule in routing.get("rules") or []:
        if isinstance(rule, dict) and rule.get("outboundTag") == "proxy":
            del rule["outboundTag"]
            rule["balancerTag"] = "wl-auto"
    # leastPing — самый быстрый по пингу из живых; пока пинг не прошёл — лучший по проверке сервера
    routing["balancers"] = [{"tag": "wl-auto", "selector": ["wl-"], "fallbackTag": "wl-1",
                             "strategy": {"type": "leastPing"}}]
    conf.pop("burstObservatory", None)
    # пинг всех сразу при включении (enableConcurrency), дальше — раз в interval
    conf["observatory"] = {"subjectSelector": ["wl-"],
                           "probeUrl": auto.get("url") or "http://www.gstatic.com/generate_204",
                           "probeInterval": auto.get("interval") or "2m", "enableConcurrency": True}
    conf["remarks"] = auto.get("name") or "Автовыбор"
    return conf


def white_json(data, items, chosen):
    """JSON-подписка (Happ, v2rayNG, v2rayN): каждое подключение — копия конфига панели
    с теми же правилами (РФ напрямую, реклама — блок), но со своим выходом proxy"""
    confs = data if isinstance(data, list) else [data]
    template = None
    for conf in confs:
        # шаблон — обычный Xray-конфиг панели (с названием и одним выходом proxy); конфиги других
        # форматов (sing-box и т. п.) и «Автовыбор» с балансировкой шаблоном не служат
        if not isinstance(conf, dict) or "remarks" not in conf or (conf.get("routing") or {}).get("balancers"):
            continue
        outs = conf.get("outbounds")
        proxies = [o for o in outs if isinstance(o, dict) and o.get("tag") == "proxy"] if isinstance(outs, list) else []
        if len(proxies) == 1 and proxies[0].get("protocol"):
            template = conf
            break
    if template is None:
        return None
    proxy = next(o for o in template["outbounds"] if isinstance(o, dict) and o.get("tag") == "proxy")
    settings = proxy.get("settings") or {}
    level = settings.get("level")
    for server in settings.get("vnext") or []:     # старый формат: уровень — у пользователя
        for user in (server.get("users") if isinstance(server, dict) else None) or []:
            if level is None and isinstance(user, dict):
                level = user.get("level")
    result = list(confs)
    auto = white_auto(template, chosen, level)
    if auto is not None:
        result.append(auto)
    for it in items:
        conf = copy.deepcopy(template)
        ob = with_level(it["outbound"], level) if isinstance(level, int) else copy.deepcopy(it["outbound"])
        ob["tag"] = "proxy"
        conf["outbounds"] = [ob if isinstance(o, dict) and o.get("tag") == "proxy" else o for o in conf["outbounds"]]
        conf["remarks"] = it["name"]
        result.append(conf)
    return json.dumps(result, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def add_white(body, items, chosen=()):
    """подписка с белыми списками в конце; None — это не подписка (страница, ошибка) — не трогаем"""
    try:
        text = body.decode("utf-8").strip()
    except UnicodeDecodeError:
        return None
    if text[:1] in ("[", "{"):
        try:
            return white_json(json.loads(text), items, list(chosen))
        except ValueError:
            return None
    encoded = "://" not in text           # обычно ссылки приходят одним куском base64
    if encoded:
        raw = "".join(text.split())
        try:
            text = base64.b64decode(raw + "=" * (-len(raw) % 4), validate=True).decode("utf-8")
        except ValueError:                # сюда же — UnicodeDecodeError и ошибки base64
            return None
    lines = [x.strip() for x in text.splitlines() if x.strip()]
    if not lines or not all(LINK.match(x) for x in lines):
        return None
    out = "\n".join(lines + [it["link"] for it in items])
    if encoded:
        out = base64.b64encode(out.encode("utf-8")).decode("ascii")
    return out.encode("utf-8")


def update_interval(headers):
    """приложение обновляет подписку не реже, чем раз в update_hours часов — нерабочие пропадают быстрее"""
    hours = int(WHITE.get("update_hours") or 0)
    if hours <= 0:
        return headers
    out, found = [], False
    for key, value in headers:
        if key.lower() == "profile-update-interval":
            found = True
            try:
                value = str(min(int(value), hours))
            except ValueError:
                value = str(hours)
        out.append((key, value))
    if not found:
        out.append(("Profile-Update-Interval", str(hours)))
    return out


# ---------- профиль Mihomo (Clash Meta): Tunnel, FlClash, Clash Meta for Android и др. ----------
# Панель отдаёт профиль Mihomo со своими подключениями и группой PROXY. Фильтр дописывает в него:
# автовыбор своих подключений по пингу, белые списки (их автовыбор и полный список) и группу
# «автопереключение»: работает свой VPN — через него, перестал (белые списки) — через белые списки.
try:
    import yaml
    _YAML_LOAD = getattr(yaml, "CSafeLoader", None) or yaml.SafeLoader
    _YAML_DUMP = yaml.SafeDumper          # не C-версия: та пишет эмодзи как \U0001F3F3
except ImportError:                       # нет python3-yaml — профиль Mihomo уходит как есть
    yaml = None
if yaml is not None:
    class _MihomoDumper(_YAML_DUMP):
        """строки, похожие на числа («08», «1e5»), — в кавычках: Mihomo читает YAML 1.2, и без
        кавычек short-id «08» стал бы числом 8"""

    def _str(dumper, value):
        style = "'" if re.match(r"^[-+]?\.?[0-9]|^(true|false|yes|no|on|off|null|y|n|~)$", value, re.I) else None
        return dumper.represent_scalar("tag:yaml.org,2002:str", value, style=style)

    _MihomoDumper.add_representer(str, _str)
    _YAML_DUMP = _MihomoDumper
CLASH = CONF.get("clash") or {}
MH_TEST = "http://www.gstatic.com/generate_204"
MH_FP = {"chrome", "firefox", "safari", "ios", "android", "edge", "360", "qq", "random"}
MH_SS = {"aes-128-gcm", "aes-192-gcm", "aes-256-gcm", "chacha20-ietf-poly1305", "xchacha20-ietf-poly1305",
         "2022-blake3-aes-128-gcm", "2022-blake3-aes-256-gcm", "2022-blake3-chacha20-poly1305"}
MH_VMESS = {"auto", "none", "zero", "aes-128-gcm", "chacha20-poly1305"}
# настройки XHTTP: Xray → Mihomo (те, что у Mihomo называются так же); серверные — пропускаем
MH_XHTTP = {"path": "path", "host": "host", "mode": "mode", "headers": "headers", "noGRPCHeader": "no-grpc-header",
            "xPaddingBytes": "x-padding-bytes", "xPaddingHeader": "x-padding-header", "xPaddingKey": "x-padding-key",
            "xPaddingMethod": "x-padding-method", "xPaddingObfsMode": "x-padding-obfs-mode",
            "xPaddingPlacement": "x-padding-placement", "scMaxEachPostBytes": "sc-max-each-post-bytes",
            "scMinPostsIntervalMs": "sc-min-posts-interval-ms", "uplinkHTTPMethod": "uplink-http-method",
            "uplinkDataPlacement": "uplink-data-placement", "uplinkDataKey": "uplink-data-key",
            "uplinkChunkSize": "uplink-chunk-size", "seqPlacement": "seq-placement", "seqKey": "seq-key",
            "sessionPlacement": "session-placement", "sessionKey": "session-key",
            "sessionIDPlacement": "session-placement", "sessionIDKey": "session-key",
            "sessionIDLength": "session-length", "sessionIDTable": "session-table"}
MH_XHTTP_SERVER = {"noSSEHeader", "scMaxBufferedPosts", "scStreamUpServerSecs", "serverMaxHeaderBytes"}
MH_XMUX = {"maxConcurrency": "max-concurrency", "maxConnections": "max-connections",
           "cMaxReuseTimes": "c-max-reuse-times", "hMaxRequestTimes": "h-max-request-times",
           "hMaxReusableSecs": "h-max-reusable-secs", "hKeepAlivePeriod": "h-keep-alive-period"}


class NoMihomo(Exception):
    """подключение нельзя (или небезопасно) перевести в профиль Mihomo — его там не будет"""


def _host_header(d):
    host = d.get("host") or (d.get("headers") or {}).get("Host") or ""
    if isinstance(host, list):
        host = host[0] if host else ""
    return str(host)


def mihomo_proxy(ob, name):
    """выход Xray (как в alive.json) → прокси Mihomo; NoMihomo — такого Mihomo не умеет"""
    proto = ob.get("protocol")
    st = ob.get("streamSettings") or {}
    s = ob.get("settings") or {}
    net = str(st.get("network") or "tcp").lower()
    sec = str(st.get("security") or "none").lower()
    p = {"name": name}
    if proto in ("vless", "vmess"):
        v = (s.get("vnext") or [{}])[0]
        u = (v.get("users") or [{}])[0]
        p.update(type=proto, server=str(v["address"]), port=int(v["port"]), uuid=str(u["id"]), udp=True)
        if proto == "vless":
            if u.get("flow"):
                if u["flow"] != "xtls-rprx-vision":
                    raise NoMihomo("flow")
                p["flow"] = u["flow"]
            if (u.get("encryption") or "none") != "none":
                raise NoMihomo("vless encryption")   # ключ Mihomo проверяет строже Xray — не рискуем профилем
        else:
            cipher = str(u.get("security") or "auto")
            if cipher not in MH_VMESS:
                raise NoMihomo("vmess cipher")
            p.update(alterId=int(u.get("alterId") or 0), cipher=cipher)
    elif proto == "trojan":
        srv = (s.get("servers") or [{}])[0]
        p.update(type="trojan", server=str(srv["address"]), port=int(srv["port"]), password=str(srv["password"]),
                 udp=True)
    elif proto == "shadowsocks":
        srv = (s.get("servers") or [{}])[0]
        if srv.get("method") not in MH_SS:
            raise NoMihomo("ss cipher")
        p.update(type="ss", server=str(srv["address"]), port=int(srv["port"]), cipher=srv["method"],
                 password=str(srv["password"]), udp=True)
        return p
    elif proto == "hysteria":
        tls = st.get("tlsSettings") or {}
        if tls.get("pinnedPeerCertSha256"):
            raise NoMihomo("pinned")
        p.update(type="hysteria2", server=str(s["address"]), port=int(s["port"]),
                 password=str((st.get("hysteriaSettings") or {}).get("auth") or ""))
        if tls.get("serverName"):
            p["sni"] = str(tls["serverName"])
        if tls.get("alpn"):
            p["alpn"] = [str(a) for a in tls["alpn"]]
        if tls.get("allowInsecure"):
            p["skip-cert-verify"] = True
        return p
    else:
        raise NoMihomo("protocol")
    # шифрование
    if sec == "reality":
        r = st.get("realitySettings") or {}
        if proto != "vless" or not r.get("serverName") \
                or not re.match(r"^[A-Za-z0-9_-]{43}$", str(r.get("publicKey") or "")) \
                or not re.match(r"^[0-9a-fA-F]{0,16}$", str(r.get("shortId") or "")) or len(str(r.get("shortId") or "")) % 2:
            raise NoMihomo("reality")
        fp = str(r.get("fingerprint") or "chrome")
        p.update(tls=True, servername=str(r["serverName"]), **{"client-fingerprint": fp if fp in MH_FP else "chrome"})
        # ML-KEM, как у панели для своих подключений: без этого Mihomo не договорится с новыми серверами Reality
        p["reality-opts"] = {"public-key": str(r["publicKey"]), "short-id": str(r.get("shortId") or ""),
                             "support-x25519mlkem768": True}
    elif sec == "tls":
        t = st.get("tlsSettings") or {}
        if t.get("pinnedPeerCertSha256") or t.get("verifyPeerCertByName"):
            raise NoMihomo("pinned")
        if proto == "trojan":
            if t.get("serverName"):
                p["sni"] = str(t["serverName"])
        else:
            p["tls"] = True
            if t.get("serverName"):
                p["servername"] = str(t["serverName"])
        if t.get("alpn"):
            p["alpn"] = [str(a) for a in t["alpn"]]
        if t.get("fingerprint"):
            fp = str(t["fingerprint"])
            p["client-fingerprint"] = fp if fp in MH_FP else "chrome"
        if t.get("allowInsecure"):
            p["skip-cert-verify"] = True
    elif sec == "none":
        if proto in ("trojan", "vless"):
            raise NoMihomo("plain")
    else:
        raise NoMihomo("security")
    # транспорт
    if net in ("tcp", "raw"):
        if ((st.get("tcpSettings") or st.get("rawSettings") or {}).get("header") or {}).get("type") not in (None, "none"):
            raise NoMihomo("tcp header")
        p["network"] = "tcp"
    elif net in ("ws", "httpupgrade"):
        w = st.get("wsSettings" if net == "ws" else "httpupgradeSettings") or {}
        path = str(w.get("path") or "/")
        opts = {}
        m = re.search(r"[?&]ed=(\d+)", path)
        if m and net == "ws":             # ранние данные: ?ed=2048 в пути (как в Xray)
            path = re.sub(r"[?&]ed=\d+", "", path) or "/"
            opts.update({"max-early-data": int(m.group(1)), "early-data-header-name": "Sec-WebSocket-Protocol"})
        opts["path"] = path
        host = _host_header(w)
        if host:
            opts["headers"] = {"Host": host}
        if net == "httpupgrade":
            opts["v2ray-http-upgrade"] = True
        p.update(network="ws", **{"ws-opts": opts})
    elif net == "grpc":
        g = st.get("grpcSettings") or {}
        p.update(network="grpc", **{"grpc-opts": {"grpc-service-name": str(g.get("serviceName") or "")}})
    elif net in ("xhttp", "splithttp"):
        x = st.get("xhttpSettings") or st.get("splithttpSettings") or {}
        extra = x.get("extra") if isinstance(x.get("extra"), dict) else {}
        merged = dict(x, **extra)
        merged.pop("extra", None)
        opts = {}
        for key, value in merged.items():
            # 0 у Xray — «по умолчанию», а Mihomo такое значение отвергает
            if key in MH_XHTTP_SERVER or value in (None, "", {}, [], 0, "0"):
                continue
            if key == "xmux" and isinstance(value, dict):
                reuse = {MH_XMUX[k]: v for k, v in value.items() if k in MH_XMUX and v not in (None, "", 0, "0")}
                if len(reuse) != len([k for k, v in value.items() if v not in (None, "", 0, "0")]):
                    raise NoMihomo("xmux")
                if reuse:
                    opts["reuse-settings"] = reuse
            elif key in MH_XHTTP:
                opts[MH_XHTTP[key]] = value
            else:                          # downloadSettings и прочее, чего Mihomo не знает
                raise NoMihomo("xhttp " + key)
        if opts.get("mode") == "auto":
            del opts["mode"]
        opts.setdefault("path", "/")
        p.update(network="xhttp", **{"xhttp-opts": opts})
    else:
        raise NoMihomo("network")
    return p


def add_white_yaml(body, items, chosen=()):
    """профиль Mihomo: свои подключения + автовыбор, белые списки, автопереключение; None — не профиль"""
    if yaml is None:
        return None
    try:
        data = yaml.load(body.decode("utf-8"), Loader=_YAML_LOAD)
    except (UnicodeDecodeError, yaml.YAMLError):
        return None
    if not isinstance(data, dict) or not isinstance(data.get("proxies"), list):
        return None
    proxies = [p for p in data["proxies"] if isinstance(p, dict)]
    groups = [g for g in data.get("proxy-groups") or [] if isinstance(g, dict)]
    taken = {str(x.get("name")) for x in proxies + groups} | {"DIRECT", "REJECT", "PASS", "GLOBAL"}
    own = [str(p.get("name")) for p in proxies if p.get("name")]
    wl, names = [], {}
    for it in items:
        name = str(it["name"])
        if name in taken:
            continue
        try:
            wl.append(mihomo_proxy(it["outbound"], name))
        except (NoMihomo, KeyError, TypeError, ValueError, IndexError, AttributeError):
            continue
        taken.add(name)
        names[it.get("_key")] = name
    auto = [names[it.get("_key")] for it in chosen if it.get("_key") in names]
    own_auto = str(CLASH.get("auto_name") or "")
    wl_auto = str((WHITE.get("auto") or {}).get("name") or "")
    wl_list = str(WHITE.get("title") or "")
    switch = str(CLASH.get("fallback_name") or "")
    test = {"url": MH_TEST, "interval": 120, "tolerance": 50, "lazy": False}
    new = []
    if own_auto and own_auto not in taken and len(own) >= 2:
        new.append(dict({"name": own_auto, "type": "url-test", "proxies": own}, **test))
        taken.add(own_auto)
    else:
        own_auto = own[0] if own else ""
    if wl_auto and wl_auto not in taken and len(auto) >= 2:
        new.append(dict({"name": wl_auto, "type": "url-test", "proxies": auto}, **test))
        taken.add(wl_auto)
    else:
        wl_auto = auto[0] if auto else ""
    if wl and wl_list and wl_list not in taken:
        new.append({"name": wl_list, "type": "select", "proxies": [p["name"] for p in wl]})
        taken.add(wl_list)
    else:
        wl_list = ""
    if switch and switch not in taken and own_auto and wl_auto:
        # свой VPN, пока отвечает; перестал (белые списки) — белые списки; заработал снова — опять свой
        new.insert(0, {"name": switch, "type": "fallback", "proxies": [own_auto, wl_auto], "url": MH_TEST,
                       "interval": 60, "lazy": False})
    else:
        switch = ""
    if not new and not wl:
        return None
    main = next((g for g in groups if g.get("type") == "select"), None)
    if main is not None:
        cur = [str(x) for x in main.get("proxies") or []]
        tail = [x for x in cur if x in ("DIRECT", "REJECT")]
        main["proxies"] = ([x for x in (switch, own_auto if own_auto in [g["name"] for g in new] else "") if x]
                           + [x for x in cur if x not in tail]
                           + [x for x in (wl_auto if wl_auto in [g["name"] for g in new] else "", wl_list) if x]
                           + tail)
    data["proxies"] = proxies + wl
    data["proxy-groups"] = ([main] if main is not None else []) + new + [g for g in groups if g is not main]
    return yaml.dump(data, Dumper=_YAML_DUMP, allow_unicode=True, sort_keys=False, default_flow_style=False,
                     width=4096).encode("utf-8")


# ---------- проверка с телефона ----------
# Сервер не видит белые списки оператора, поэтому телефон проверяет серверы сам: страница …/test/
# даёт команду для Termux, скрипт t.sh скачивает отсюда Xray (xray-arm64-v8a.gz) и список серверов
# (bundle), проверяет каждый из мобильной сети и присылает отчёт (POST report). Рабочие у телефона
# (verified.json, за последние hours часов) идут в подписке первыми — с ✅ — и попадают в автоподбор.
PHONE_PORT = 41000                        # входы SOCKS на телефоне: 41000 — служебный, дальше по одному на сервер
PHONE_XRAY = "xray-arm64-v8a.gz"
REPORT_MAX = 256 * 1024
_resolve = {"time": 0, "value": ""}


def phone_base(handler):
    """адрес сервера подписки, как его видит телефон: из настроек, иначе — из запроса"""
    base = str(PHONE.get("base") or "").rstrip("/")
    if not base:
        host = handler.headers.get("Host") or "127.0.0.1:%d" % int(CONF["port"])
        base = ("https://" if CERT else "http://") + host
    return re.sub(r"[^A-Za-z0-9.:/\[\]_-]", "", base)


def phone_resolve(base):
    """«адрес:порт:IP» для curl --resolve — на случай, если DNS телефона не знает адрес сервера"""
    u = urllib.parse.urlsplit(base)
    host, port = u.hostname or "", u.port or (443 if u.scheme == "https" else 80)
    if not host or re.match(r"^[0-9.]+$", host) or ":" in host:
        return ""
    now = time.time()
    if now - _resolve["time"] > 600:
        ip = str(PHONE.get("ip") or "")
        if not ip:
            try:
                ip = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)[0][4][0]
            except (OSError, IndexError, UnicodeError):
                ip = ""
        _resolve.update(time=now, value="%s:%d:%s" % (host, port, ip) if ip else "")
    return _resolve["value"]


def xray_version():
    try:
        with open(os.path.join(PHONE_DIR, "xray-version"), encoding="utf-8") as f:
            v = f.read().strip()
        return v if re.match(r"^[0-9][0-9.]*$", v) else "-"
    except OSError:
        return "-"


def phone_bundle():
    """для телефона: строки «#P порт код tcp|udp адрес порт-сервера IP-с-сервера название» и настройки
    Xray — вход SOCKS на каждый сервер. Каждый вход, выход и правило — отдельной строкой, а первым в
    списке стоит служебный: телефон убирает отвергнутые Xray подключения по коду, не разбирая JSON.
    Служебный выход — freedom: через первый выход Xray отправляет и свои запросы DNS"""
    items = white_items("phone")
    head, inb, outb, rules = [], [], [], []
    for it in items:
        key = it["_key"]
        host = server_host(it["outbound"])
        try:
            sport = int(server_port(it["outbound"]))
        except (TypeError, ValueError):
            continue
        if not re.match(r"^[A-Za-z0-9._:-]+$", host or ""):
            continue
        port = PHONE_PORT + len(head) + 1
        ob = copy.deepcopy(it["outbound"])
        ob["tag"] = "o-" + key
        ss = ob.get("streamSettings")
        if not isinstance(ss, dict):
            ss = ob["streamSettings"] = {}
        sock = ss.get("sockopt") if isinstance(ss.get("sockopt"), dict) else {}
        sock["domainStrategy"] = "UseIPv4"    # адрес сервера — через DNS самого Xray (на Android системный не работает)
        ss["sockopt"] = sock
        udp = ob.get("protocol") == "hysteria" or ss.get("network") in ("kcp", "hysteria")
        ip = str(it.get("ip") or "-")
        if not re.match(r"^[0-9a-fA-F.:]+$", ip):
            ip = "-"
        name = " ".join(str(it.get("name") or key).split())
        head.append("#P %d %s %s %s %d %s %s" % (port, key, "udp" if udp else "tcp", host, sport, ip, name))
        inb.append(json.dumps({"tag": "in-" + key, "listen": "127.0.0.1", "port": port, "protocol": "socks",
                               "settings": {"udp": False}}, separators=(",", ":")))
        outb.append(json.dumps(ob, separators=(",", ":")))
        rules.append(json.dumps({"type": "field", "inboundTag": ["in-" + key], "outboundTag": "o-" + key},
                                separators=(",", ":")))
    lines = ["#B 1 %s %d %d" % (xray_version(), len(head), PHONE_PORT)] + head + [
        "{", '"log":{"loglevel":"none"},',
        '"inbounds":[{"tag":"in-x","listen":"127.0.0.1","port":%d,"protocol":"socks","settings":{"udp":false}}'
        % PHONE_PORT] + ["," + x for x in inb] + [
        "],", '"outbounds":[{"tag":"x","protocol":"freedom"}'] + ["," + x for x in outb] + [
        "],", '"routing":{"rules":[{"type":"field","inboundTag":["in-x"],"outboundTag":"x"}'] + [
        "," + x for x in rules] + ["]}", "}"]
    return ("\n".join(lines) + "\n").encode("utf-8")


def clean_label(text):
    text = " ".join("".join(ch for ch in str(text) if ch.isprintable()).split())
    return text[:40] or "Мобильный интернет"


def phone_report(text, client):
    """отчёт телефона: «ключ: значение» и строки «код мс» (работает) или «код - причина» (нет).
    Возвращает (работают, проверено)"""
    now = int(time.time())
    rep = {"time": now, "label": "Мобильный интернет", "open": False, "xray": "", "script": "",
           "client": client}
    items, seen = [], set()
    for line in text.splitlines()[:6000]:
        line = line.strip()
        m = re.match(r"^([0-9a-f]{12})\s+(\d{1,6}|-)(?:\s+([a-z]{1,10}))?$", line)
        if m:
            if m.group(1) not in seen:
                seen.add(m.group(1))
                items.append([m.group(1), int(m.group(2)) if m.group(2) != "-" else None, m.group(3) or ""])
            continue
        key, _, value = line.partition(":")
        key, value = key.strip().lower(), value.strip()
        if key == "label":
            rep["label"] = clean_label(value)
        elif key == "open":
            rep["open"] = value == "1"
        elif key == "time" and value.isdigit():
            rep["time"] = min(now, max(now - 7 * 86400, int(value)))
        elif key in ("xray", "script"):
            rep[key] = re.sub(r"[^0-9A-Za-z.+-]", "", value)[:20]
    if not items:
        raise ValueError("в отчёте нет ни одного сервера")
    names = {it["_key"]: it["name"] for it in white_items("all")}
    good = sorted((ms, key) for key, ms, _ in items if ms is not None)
    rep.update(tested=len(items), ok=len(good), best=good[0][0] if good else None,
               top=[[names.get(key, key), ms] for ms, key in good[:5]], items=items)
    with _phone_lock:
        os.makedirs(REPORTS, exist_ok=True)
        if not rep["open"]:               # без ограничений (Wi-Fi) — сохраняем, но не учитываем
            data = read_json(VERIFIED, {})
            data = data if isinstance(data, dict) else {}
            for key, ms, _ in items:
                nets = data.get(key) if isinstance(data.get(key), dict) else {}
                old = nets.get(rep["label"])
                if isinstance(old, dict) and int(old.get("time") or 0) > rep["time"]:
                    continue                  # есть результат новее (этот отчёт пришёл с опозданием)
                nets[rep["label"]] = {"ok": ms is not None, "ms": ms, "time": rep["time"]}
                data[key] = nets
            limit = now - 7 * 86400           # неделя без проверки — забываем
            for key in list(data):
                nets = data[key] if isinstance(data[key], dict) else {}
                nets = {k: v for k, v in nets.items() if isinstance(v, dict) and int(v.get("time") or 0) >= limit}
                if nets:
                    data[key] = nets
                else:
                    del data[key]
            write_file(VERIFIED, json.dumps(data, ensure_ascii=False))
        write_file(os.path.join(REPORTS, "%d-%s.json" % (rep["time"], secrets.token_hex(3))),
                   json.dumps(rep, ensure_ascii=False))
        files = sorted(f for f in os.listdir(REPORTS) if f.endswith(".json"))
        for f in files[:-50]:             # храним 50 последних
            try:
                os.unlink(os.path.join(REPORTS, f))
            except OSError:
                pass
    return rep["ok"], rep["tested"]


def write_file(path, text):
    tmp = "%s.%s.tmp" % (path, secrets.token_hex(3))
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def phone_status():
    """для страницы: отчёты телефонов и серверы, которые у них работают"""
    ver = white_items("verified")
    servers = []
    for it in white_items("list"):
        v = ver.get(it.get("_key"))
        if v:
            servers.append({"name": it["name"], "ms": v["ms"], "label": v["label"], "time": v["time"],
                            "server_ms": it.get("ms")})
    reports = []
    try:
        files = sorted((f for f in os.listdir(REPORTS) if f.endswith(".json")), reverse=True)[:20]
    except OSError:
        files = []
    for f in files:
        r = read_json(os.path.join(REPORTS, f), {})
        if isinstance(r, dict):
            reports.append({k: r.get(k) for k in ("time", "label", "open", "tested", "ok", "best", "top")})
    sub_max = int(WHITE.get("sub_max") or 15)
    return {"now": int(time.time()), "alive": len(white_items("all")), "candidates": len(white_items("phone")),
            "verified": len(ver), "failed": len(white_items("failed")), "in_sub": min(len(ver), sub_max),
            "sub_max": sub_max,
            "hours": int(float(PHONE.get("hours") or 48)), "servers": servers[:150], "reports": reports}


def phone_script(base):
    url = base + (WHITE.get("path") or "/").rstrip("/") + "/test"
    auto = str((WHITE.get("auto") or {}).get("name") or "")
    sh = PHONE_SH.replace("__URL__", url).replace("__RESOLVE__", phone_resolve(base))
    return sh.replace("__AUTO__", auto.replace("'", "")).encode("utf-8")


def phone_page(base):
    url = base + (WHITE.get("path") or "/").rstrip("/") + "/test"
    cmd = 'command -v curl >/dev/null || pkg install -y curl; curl -fsSL "%s/t.sh" -o t.sh && bash t.sh' % url
    auto = str((WHITE.get("auto") or {}).get("name") or "Автовыбор")
    page = PHONE_HTML.replace("__CMD__", html.escape(cmd)).replace("__AUTO__", html.escape(auto))
    return page.replace("__HOURS__", str(int(float(PHONE.get("hours") or 48)))).encode("utf-8")


PHONE_SH = r'''#!/usr/bin/env bash
# Проверка белых списков с телефона (Android, Termux): какие серверы белых списков работают
# в ЭТОЙ мобильной сети. Скрипт отдаёт ваш сервер VPN (страница проверки), ставит его install-vpn-all.sh.
#   bash t.sh             — проверить серверы из этой сети и отправить результат на сервер VPN
#   bash t.sh "Билайн"    — то же, с названием сети (запоминается)
#   bash t.sh --force     — проверить, даже если сейчас интернет без ограничений (Wi-Fi)
# Первый запуск — по Wi-Fi: скачает Xray и список серверов. Дальше — в мобильном интернете.
URL='__URL__'
RESOLVE='__RESOLVE__'
AUTO='__AUTO__'
SVER='2026.10.14'
DIR="${WLT_DIR:-${HOME:-.}/.vpn-wl-test}"
TCP_JOBS="${WLT_TCP_JOBS:-16}"; PROBE_JOBS="${WLT_PROBE_JOBS:-8}"
TCP_SEC="${WLT_TCP_SEC:-4}"; PROBE_SEC="${WLT_PROBE_SEC:-10}"
PROBE_URLS=(https://www.gstatic.com/generate_204 https://cp.cloudflare.com/generate_204)
read -r -a OPEN_URLS <<< "${WLT_OPEN_URLS:-https://www.gstatic.com/generate_204 https://1.1.1.1/cdn-cgi/trace https://www.wikipedia.org/}"
RES=(); if [ -n "$RESOLVE" ]; then RES=(--resolve "$RESOLVE"); fi
declare -A BAD=()
X=""; XVER=""; XPID=""; T=""; ONLINE=0; OPEN=0; FORCE=0; LABEL=""; LABEL_ARG=""; SENT=""; VIA=""
TOT=0; OKN=0; N=0

if [ -t 1 ]; then G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; Z=$'\033[0m'; else G=""; Y=""; R=""; Z=""; fi
say()  { printf '%s\n' "$*"; }
good() { printf '%s%s%s\n' "$G" "$*" "$Z"; }
warn() { printf '%s%s%s\n' "$Y" "$*" "$Z"; }
fail() { printf '%s%s%s\n' "$R" "$*" "$Z" >&2; exit 1; }

cleanup() {
  if [ -n "$XPID" ]; then kill "$XPID" 2>/dev/null; fi
  # shellcheck disable=SC2046
  kill $(jobs -p) 2>/dev/null
  return 0
}
trap cleanup EXIT
trap 'echo; warn "Остановлено."; exit 130' INT TERM

direct() {   # direct путь [опции curl] — запрос к серверу VPN напрямую
  local p="$1"; shift
  curl -fsS --noproxy '*' --connect-timeout 10 "${RES[@]}" "$@" "$URL/$p"
}
tunnel() {   # tunnel порт путь [опции curl] — запрос к серверу VPN через рабочий сервер (Xray на телефоне)
  local port="$1" p="$2"; shift 2
  curl -fsS --connect-timeout 15 -x "socks5h://127.0.0.1:$port" "$@" "$URL/$p"
}
fastest() {  # порты 2 самых быстрых рабочих серверов
  [ -n "$T" ] && [ -s "$T/good" ] && [ -n "$XPID" ] || return 0
  sort -n "$T/good" | head -n 2 | cut -d' ' -f2
}
count() { grep -c '^#P ' "$DIR/bundle" 2>/dev/null || true; }
need() {
  local b miss=()
  for b in "$@"; do command -v "$b" >/dev/null 2>&1 || miss+=("$b"); done
  [ ${#miss[@]} -eq 0 ] && return 0
  if command -v pkg >/dev/null 2>&1; then
    say "Ставлю ${miss[*]}..."
    pkg install -y "${miss[@]}" >/dev/null 2>&1
  fi
  for b in "${miss[@]}"; do
    command -v "$b" >/dev/null 2>&1 || fail "Не найден $b — установите: pkg install $b"
  done
}
to_ms() {    # «0.412345» → MS=412
  local t="${1/,/.}" s f
  s=${t%%.*}; f=${t#*.}; [ "$f" = "$t" ] && f=0
  f="${f}000"; f=${f:0:3}
  [[ $s =~ ^[0-9]+$ ]] || s=0
  [[ $f =~ ^[0-9]+$ ]] || f=0
  MS=$(( 10#$s * 1000 + 10#$f ))
}

get_bundle() {   # свежий список серверов с сервера VPN → $DIR/bundle
  if direct bundle -m 120 -o "$DIR/bundle.new" 2>/dev/null && head -n 1 "$DIR/bundle.new" | grep -q '^#B '; then
    mv -f "$DIR/bundle.new" "$DIR/bundle"
    return 0
  fi
  rm -f "$DIR/bundle.new"
  return 1
}

xray_ver() { "$1" version 2>/dev/null | sed -n '1s/^Xray \([0-9][0-9.]*\).*/\1/p'; }
use_xray() {   # use_xray файл — запускается ли этот Xray на телефоне; да — он становится $DIR/xray
  chmod 755 "$1" 2>/dev/null
  if [ -z "$(xray_ver "$1")" ]; then rm -f "$1"; return 1; fi
  mv -f "$1" "$DIR/xray"
}
xray_from_server() {
  case "$(uname -m)" in aarch64|arm64|armv8*) ;; *) return 1 ;; esac
  say "Скачиваю Xray с сервера VPN (около 15 МБ)..."
  local rc=1
  if direct xray-arm64-v8a.gz -m 900 -o "$DIR/xray.gz" 2>/dev/null \
     && gzip -dc "$DIR/xray.gz" > "$DIR/xray.new" 2>/dev/null && use_xray "$DIR/xray.new"; then rc=0; fi
  rm -f "$DIR/xray.gz" "$DIR/xray.new"
  return $rc
}
xray_from_github() {
  local z zips
  case "$(uname -m)" in
    aarch64|arm64) zips="Xray-android-arm64-v8a.zip" ;;
    armv8*|armv7*|arm*) zips="Xray-android-arm64-v8a.zip Xray-linux-arm32-v7a.zip" ;;
    x86_64|amd64) zips="Xray-android-amd64.zip" ;;
    i?86) zips="Xray-linux-32.zip" ;;
    *) zips="Xray-android-arm64-v8a.zip" ;;
  esac
  command -v unzip >/dev/null 2>&1 || pkg install -y unzip >/dev/null 2>&1
  command -v unzip >/dev/null 2>&1 || return 1
  for z in $zips; do
    say "Скачиваю Xray с GitHub ($z)..."
    rm -rf "$DIR/x" "$DIR/x.zip"
    curl -fsSL --connect-timeout 15 -m 900 -o "$DIR/x.zip" "https://github.com/XTLS/Xray-core/releases/latest/download/$z" || continue
    if unzip -q -o "$DIR/x.zip" xray -d "$DIR/x" 2>/dev/null && use_xray "$DIR/x/xray"; then
      rm -rf "$DIR/x" "$DIR/x.zip"
      return 0
    fi
  done
  rm -rf "$DIR/x" "$DIR/x.zip"
  return 1
}
get_xray() {
  local want have
  if [ -n "${WLT_XRAY:-}" ]; then X="$WLT_XRAY"; XVER=$(xray_ver "$X"); [ -n "$XVER" ] && return 0; fi
  X="$DIR/xray"
  want=$(sed -n '1s/^#B [0-9]* \([0-9][0-9.]*\) .*/\1/p' "$DIR/bundle" 2>/dev/null)
  have=$(xray_ver "$X")
  if [ -n "$have" ]; then   # на сервере другая версия — обновляем (не вышло — работаем с этой)
    if [ -n "$want" ] && [ "$want" != "$have" ] && [ "$ONLINE" = 1 ]; then xray_from_server || true; fi
  else
    xray_from_server || xray_from_github || {
      command -v xray >/dev/null 2>&1 || pkg install -y xray >/dev/null 2>&1
      command -v xray >/dev/null 2>&1 && X="$(command -v xray)"
    }
  fi
  XVER=$(xray_ver "$X")
  [ -n "$XVER" ]
}

open_net() {   # 0 — интернет без ограничений: зарубежные сайты открываются напрямую (Wi-Fi, VPN)
  local d="$DIR/open" u i=0
  rm -rf "$d"; mkdir -p "$d"
  for u in "${OPEN_URLS[@]}"; do
    i=$((i + 1))
    curl --noproxy '*' -s -o /dev/null --connect-timeout 5 -m 6 -w '%{http_code}' "$u" > "$d/$i" 2>/dev/null &
  done
  wait
  i=0
  for u in "$d"/*; do
    case "$(cat "$u" 2>/dev/null)" in [1-5][0-9][0-9]) i=$((i + 1)) ;; esac
  done
  rm -rf "$d"
  [ "$i" -ge 2 ]
}

get_label() {
  local def saved=""
  if [ -n "$LABEL_ARG" ]; then LABEL="$LABEL_ARG"
  else
    read -r saved 2>/dev/null < "$DIR/label"
    if [ -n "$saved" ]; then LABEL="$saved"
    else
      def=$(getprop gsm.operator.alpha 2>/dev/null | sed 's/,/ \/ /g; s/^[ \/]*//; s/[ \/]*$//')
      [ -n "$def" ] || def="Мобильный интернет"
      if [ -t 0 ]; then
        printf 'Как назвать эту сеть (оператор, город) [%s]: ' "$def"
        read -r LABEL || LABEL=""
      fi
      LABEL=${LABEL:-$def}
    fi
  fi
  LABEL=$(printf '%s' "$LABEL" | tr -d '\000-\037')
  LABEL=${LABEL:0:40}
  printf '%s\n' "$LABEL" > "$DIR/label"
}

tcp_state() {  # tcp_state код → ST: ok (сервер открывается) | udp | no; TIP — его IP
  local tc="" rip="" ec=""
  ST=no; TIP=""
  IFS='|' read -r tc rip ec 2>/dev/null < "$T/c.$1"
  if [ "$tc" = udp ]; then ST=udp
  elif [ -n "${tc//[0.,]/}" ]; then ST=ok; TIP=$rip
  fi
  EC=$ec
}
stage_tcp() {   # 1) открывается ли сервер из этой сети (без Xray, сразу TCP_JOBS штук)
  local n=0 port key kind host sport sip name u
  while read -r _ port key kind host sport sip name; do
    if [ "$kind" = udp ]; then echo udp > "$T/c.$key"; continue; fi
    case "$host" in *:*) u="[$host]" ;; *) u="$host" ;; esac
    curl --noproxy '*' -s -o /dev/null --connect-timeout "$TCP_SEC" -m $((TCP_SEC + 1)) \
         -w '%{time_connect}|%{remote_ip}|%{exitcode}' "http://$u:$sport/" > "$T/c.$key" 2>/dev/null &
    n=$((n + 1)); if [ "$n" -ge "$TCP_JOBS" ]; then wait -n 2>/dev/null; n=$((n - 1)); fi
  done < "$T/ports"
  wait
  n=0   # адрес сервера не знает DNS телефона — ещё раз по IP, который видит сервер VPN
  while read -r _ port key kind host sport sip name; do
    [ "$kind" = udp ] && continue
    tcp_state "$key"
    [ "$ST" = no ] && [ "$EC" = 6 ] && [[ $sip =~ ^[0-9.]+$ ]] || continue
    curl --noproxy '*' -s -o /dev/null --connect-timeout "$TCP_SEC" -m $((TCP_SEC + 1)) --resolve "$host:$sport:$sip" \
         -w '%{time_connect}|%{remote_ip}|%{exitcode}' "http://$host:$sport/" > "$T/c.$key" 2>/dev/null &
    n=$((n + 1)); if [ "$n" -ge "$TCP_JOBS" ]; then wait -n 2>/dev/null; n=$((n - 1)); fi
  done < "$T/ports"
  wait
}
HOSTS=""
add_host() {   # add_host домен IP — адрес сервера для DNS Xray (только домены и только IPv4)
  [[ $1 =~ ^[A-Za-z0-9._-]+$ ]] && [[ ! $1 =~ ^[0-9.]+$ ]] && [[ $2 =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 0
  case ",$HOSTS," in *",\"$1\":"*) return 0 ;; esac
  HOSTS="${HOSTS:+$HOSTS,}\"$1\":\"$2\""
}
make_conf() {
  {
    head -n 1 "$T/config.json"
    printf '"dns":{"hosts":{%s},"servers":["77.88.8.8","77.88.8.1","1.1.1.1"],"queryStrategy":"UseIPv4"},\n' "$HOSTS"
    tail -n +2 "$T/config.json" | grep -v -F -f "$T/bad"
  } > "$T/run.json"
}
stage_conf() {   # 2) настройки Xray: адреса серверов и только те подключения, которые этот Xray принимает
  local port key kind host sport sip name out k tries=0 open=0 udp=0
  while read -r _ port key kind host sport sip name; do
    tcp_state "$key"
    case "$ST" in
      ok) open=$((open + 1)); add_host "$host" "$TIP" ;;
      udp) udp=$((udp + 1)); add_host "$host" "$sip" ;;
    esac
  done < "$T/ports"
  say "  Открываются из этой сети: $open из $((N - udp))$([ "$udp" -gt 0 ] && echo " (и ещё $udp — Hysteria2 по UDP, их проверит Xray)")."
  : > "$T/bad"
  while :; do
    make_conf
    out=$("$X" run -test -c "$T/run.json" 2>&1) && break
    k=$(printf '%s\n' "$out" | grep -o 'with tag o-[0-9a-f]*' | head -n 1)
    k=${k##*o-}
    tries=$((tries + 1))
    if [ -z "$k" ] || [ -n "${BAD[$k]:-}" ] || [ "$tries" -gt 60 ]; then
      printf '%s\n' "$out" | tail -n 2 >&2
      fail "Xray на телефоне не принимает настройки проверки."
    fi
    BAD[$k]=1
    printf -- '-%s"\n' "$k" >> "$T/bad"
  done
  if [ ${#BAD[@]} -gt 0 ]; then warn "  Пропускаю: ${#BAD[@]} (их настройки не принимает Xray $XVER)."; fi
  PROBE_N=$(( open + udp ))
}
stage_xray() {
  local i r base
  base=$(sed -n '1s/^#B [0-9]* [^ ]* [0-9]* \([0-9]*\).*/\1/p' "$DIR/bundle")
  "$X" run -c "$T/run.json" > "$T/xray.log" 2>&1 &
  XPID=$!
  for i in $(seq 1 60); do
    r=$(curl --noproxy '*' -s -o /dev/null --connect-timeout 1 -m 2 -w '%{time_connect}' "http://127.0.0.1:${base:-41000}/" 2>/dev/null)
    [ -n "${r//[0.,]/}" ] && return 0
    kill -0 "$XPID" 2>/dev/null || break
    sleep 0.5
  done
  tail -n 3 "$T/xray.log" >&2
  fail "Xray на телефоне не запустился."
}
stage_probe() {   # 3) настоящий запрос через каждый открывшийся сервер (через Xray, сразу PROBE_JOBS штук)
  local n=0 i=0 port key kind host sport sip name code tt pids=()
  while read -r _ port key kind host sport sip name; do
    [ -n "${BAD[$key]:-}" ] && continue
    tcp_state "$key"
    [ "$ST" = no ] && continue
    i=$((i + 1))
    curl -s -o /dev/null --connect-timeout "$PROBE_SEC" -m "$PROBE_SEC" -x "socks5h://127.0.0.1:$port" \
         -w '%{http_code}|%{time_total}' "${PROBE_URLS[0]}" > "$T/p.$key" 2>/dev/null &
    pids+=("$!")
    n=$((n + 1)); if [ "$n" -ge "$PROBE_JOBS" ]; then wait -n 2>/dev/null; n=$((n - 1)); fi
    if [ -t 1 ]; then printf '\r  Проверяю через Xray: %d из %d ' "$i" "$PROBE_N"; fi
  done < "$T/ports"
  [ ${#pids[@]} -gt 0 ] && wait "${pids[@]}" 2>/dev/null
  if [ -t 1 ] && [ "$i" -gt 0 ]; then printf '\r'; fi
  pids=(); n=0   # не ответил быстро (ошибка, а не тайм-аут) — ещё раз, другим адресом
  while read -r _ port key kind host sport sip name; do
    [ -f "$T/p.$key" ] || continue
    code=""; tt=""
    IFS='|' read -r code tt 2>/dev/null < "$T/p.$key"
    [[ $code =~ ^[23][0-9][0-9]$ ]] && continue
    to_ms "$tt"
    [ "$MS" -lt $(( PROBE_SEC * 700 )) ] || continue
    curl -s -o /dev/null --connect-timeout "$PROBE_SEC" -m "$PROBE_SEC" -x "socks5h://127.0.0.1:$port" \
         -w '%{http_code}|%{time_total}' "${PROBE_URLS[1]}" > "$T/p.$key" 2>/dev/null &
    pids+=("$!")
    n=$((n + 1)); if [ "$n" -ge "$PROBE_JOBS" ]; then wait -n 2>/dev/null; n=$((n - 1)); fi
  done < "$T/ports"
  [ ${#pids[@]} -gt 0 ] && wait "${pids[@]}" 2>/dev/null
  return 0
}
collect() {
  local port key kind host sport sip name code tt
  : > "$T/items"; : > "$T/good"
  while read -r _ port key kind host sport sip name; do
    TOT=$((TOT + 1))
    if [ -n "${BAD[$key]:-}" ]; then echo "$key - xray" >> "$T/items"; continue; fi
    tcp_state "$key"
    if [ "$ST" = no ]; then echo "$key - tcp" >> "$T/items"; continue; fi
    code=""; tt=""
    IFS='|' read -r code tt 2>/dev/null < "$T/p.$key"
    if [[ $code =~ ^[23][0-9][0-9]$ ]]; then
      to_ms "$tt"
      [ "$MS" -gt 0 ] || MS=1
      echo "$key $MS" >> "$T/items"
      echo "$MS $port $name" >> "$T/good"
      OKN=$((OKN + 1))
    else
      echo "$key - net" >> "$T/items"
    fi
  done < "$T/ports"
}

send_pending() {   # отправить все неотправленные отчёты: напрямую, иначе через рабочие серверы
  local f port ok ans
  for f in "$DIR"/pending/*.txt; do
    [ -e "$f" ] || continue
    ok=0
    if ans=$(direct report -m 60 -H 'Content-Type: text/plain; charset=utf-8' --data-binary @"$f" 2>/dev/null); then
      ok=1
    else
      for port in $(fastest); do
        if ans=$(tunnel "$port" report -m 30 -H 'Content-Type: text/plain; charset=utf-8' --data-binary @"$f" 2>/dev/null); then
          ok=1; VIA=tunnel; break
        fi
      done
    fi
    [ "$ok" = 1 ] || return 1     # этот не ушёл — остальные тоже не уйдут, отправим в следующий раз
    rm -f "$f"
    SENT=$ans
  done
  return 0
}

main() {
  local a now f port p name
  for a in "$@"; do
    case "$a" in
      -f|--force) FORCE=1 ;;
      -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
      *) LABEL_ARG="$a" ;;
    esac
  done
  mkdir -p "$DIR/pending" || fail "Не могу создать папку $DIR"
  need curl gzip
  say "=== Проверка белых списков с телефона ==="
  if get_bundle; then
    ONLINE=1
  elif [ -s "$DIR/bundle" ]; then
    warn "Сервер VPN напрямую не открывается — проверяю по списку, скачанному раньше."
  else
    fail "Нет связи с сервером VPN, а список серверов ещё не скачан. Подключитесь к Wi-Fi, выполните команду ещё раз, затем выключите Wi-Fi."
  fi
  get_xray || fail "Не удалось скачать Xray. Подключитесь к Wi-Fi и запустите ещё раз."
  N=$(count)
  if [ "${N:-0}" -eq 0 ]; then
    fail "На сервере VPN пока нет рабочих серверов белых списков — проверьте позже."
  fi
  if open_net; then
    OPEN=1
    if [ "$FORCE" != 1 ]; then
      good "✓ Всё готово: Xray $XVER и список серверов ($N) на телефоне."
      say "Сейчас интернет без ограничений (Wi-Fi или включён VPN) — так белые списки не проверить."
      say "Дальше: выключите Wi-Fi и VPN, включите мобильный интернет и выполните в Termux:"
      good "  bash t.sh"
      say "(проверить прямо сейчас всё равно: bash t.sh --force)"
      if send_pending && [ -n "$SENT" ]; then good "✓ Отправлены результаты прошлых проверок."; fi
      exit 0
    fi
    warn "Интернет без ограничений: результат сохранится на сервере, но в подписке учитываться не будет."
  fi
  get_label
  T="$DIR/run"
  rm -rf "$T"; mkdir -p "$T" || fail "Не могу создать папку $T"
  grep '^#P ' "$DIR/bundle" > "$T/ports"
  grep -v '^#' "$DIR/bundle" > "$T/config.json"
  say "Сеть: $LABEL. Проверяю серверы: $N (1–3 минуты, не сворачивайте Termux)..."
  stage_tcp
  stage_conf
  if [ "$PROBE_N" -gt 0 ]; then stage_xray; stage_probe; fi
  collect
  now=$(date +%s)
  f="$DIR/pending/$now.txt"
  { echo "v: 1"; echo "time: $now"; echo "label: $LABEL"; echo "open: $OPEN"; echo "xray: $XVER"
    echo "script: $SVER"; echo "tested: $TOT"; echo; cat "$T/items"; } > "$f"
  sort -n "$T/good" > "$DIR/last.txt"
  echo
  say "Проверено: $TOT · работают в этой сети: $OKN (за $((SECONDS / 60)) мин $((SECONDS % 60)) с)"
  if [ "$OKN" -gt 0 ]; then
    say "Самые быстрые:"
    while read -r p port name; do printf '  %5s мс  %s\n' "$p" "$name"; done < <(head -n 10 "$DIR/last.txt")
  else
    warn "В этой сети не работает ни один сервер из списка. Проверьте, что Wi-Fi выключен, а мобильный"
    warn "интернет включён; списки на сервере обновляются каждые несколько часов — попробуйте позже."
  fi
  say "Отправляю результат на сервер VPN..."
  if send_pending; then
    if [ "$OPEN" = 1 ]; then good "✓ Результат отправлен на сервер VPN (как проверка без ограничений — в подписке не учитывается)."
    elif [ "$OKN" -gt 0 ]; then
      good "✓ Результат отправлен на сервер VPN: эти серверы теперь первые в подписке (с ✅)${AUTO:+ и в «$AUTO»}."
      say "Обновите подписку в приложении (Happ, v2rayNG и др.)."
    else good "✓ Результат отправлен на сервер VPN."
    fi
  else
    warn "✗ Отправить результат не удалось: нет связи с сервером VPN ни напрямую, ни через рабочие серверы."
    warn "  Он сохранён и уйдёт при следующем запуске (например, по Wi-Fi): bash t.sh"
  fi
  if [ "$ONLINE" = 0 ] && [ "$VIA" = tunnel ]; then   # список обновим через рабочий сервер — для следующей проверки
    for port in $(fastest); do
      if tunnel "$port" bundle -m 90 -o "$DIR/bundle.new" 2>/dev/null && head -n 1 "$DIR/bundle.new" | grep -q '^#B '; then
        mv -f "$DIR/bundle.new" "$DIR/bundle"
        good "✓ Список серверов обновлён (через рабочий сервер) — для следующей проверки."
        break
      fi
    done
    rm -f "$DIR/bundle.new"
  fi
  rm -rf "$T"
}

main "$@"
'''


PHONE_HTML = r'''<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Проверка белых списков</title>
<style>
:root{--bg:#f5f6f8;--card:#fff;--text:#1a1d21;--muted:#5f6873;--line:#e2e5e9;--accent:#2563eb;--ok:#15803d;--warn:#b45309;--code:#eef1f5}
@media (prefers-color-scheme:dark){:root{--bg:#0f1216;--card:#181c22;--text:#e6e9ed;--muted:#9aa3ae;--line:#29303a;--accent:#6c9cff;--ok:#4ade80;--warn:#f0b354;--code:#222832}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:760px;margin:0 auto;padding:16px}
h1{font-size:22px;line-height:1.25;margin:8px 0 6px}
h2{font-size:17px;margin:0 0 10px}
p{margin:0 0 10px}
a{color:var(--accent)}
.lead{color:var(--muted)}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:16px;margin:14px 0}
ol{margin:0;padding-left:22px}
li{margin:0 0 14px}
li:last-child{margin-bottom:0}
.cmd{display:flex;flex-direction:column;align-items:flex-start;gap:6px;margin-top:6px}
.cmd code{display:block;width:100%;background:var(--code);border-radius:8px;padding:8px 10px;font:13px/1.45 ui-monospace,Menlo,Consolas,monospace;overflow-wrap:anywhere;user-select:all}
button{border:0;border-radius:8px;background:var(--accent);color:#fff;font:600 14px system-ui,sans-serif;padding:0 14px;min-height:36px;cursor:pointer}
.note{color:var(--muted);font-size:14px}
.card>.note{margin:12px 0 0}
li .note{margin:8px 0 0}
.stats{display:flex;flex-wrap:wrap;gap:6px 18px;color:var(--muted);font-size:14px;margin-bottom:10px}
.stats b{color:var(--text)}
table{width:100%;border-collapse:collapse;font-size:14px}
th,td{text-align:left;padding:7px 6px;border-bottom:1px solid var(--line);vertical-align:top}
th{color:var(--muted);font-weight:600}
td.n{text-align:right;white-space:nowrap}
.ok{color:var(--ok)}
.warn{color:var(--warn)}
.muted{color:var(--muted)}
.empty{color:var(--muted);font-size:14px}
.scroll{overflow-x:auto}
</style>
</head>
<body>
<main>
<h1>🏳️ Проверка белых списков с телефона</h1>
<p class="lead">Сервер VPN не видит белые списки вашего оператора: подключение, которое работает у сервера, в мобильной сети может не открываться. Здесь телефон сам проверяет серверы из своей сети — те, что работают у него, встают в подписке первыми (с ✅) и попадают в «__AUTO__».</p>

<section class="card">
<h2>Как проверить (Android)</h2>
<ol>
<li>Установите <b>Termux</b>: <a href="https://f-droid.org/packages/com.termux/" rel="noopener">F-Droid</a> или <a href="https://github.com/termux/termux-app/releases/latest" rel="noopener">GitHub</a> (файл <i>…arm64-v8a.apk</i>).</li>
<li>Один раз — по Wi-Fi или в любой сети, где открывается эта страница: откройте Termux и вставьте команду. Она скачает Xray и список серверов (около 15 МБ).
<div class="cmd"><code id="c1">__CMD__</code><button type="button" data-copy="c1">Копировать</button></div></li>
<li>Выключите Wi-Fi и VPN, включите мобильный интернет и выполните в Termux:
<div class="cmd"><code id="c2">bash t.sh</code><button type="button" data-copy="c2">Копировать</button></div>
<p class="note">Проверка идёт 1–3 минуты — не сворачивайте Termux. Результат сам придёт на сервер (если сервер VPN напрямую не открывается — через один из рабочих серверов).</p></li>
<li>Обновите подписку в приложении (Happ, v2rayNG и др.) — серверы, которые работают у вас, будут первыми.</li>
</ol>
<p class="note">Другая SIM-карта или город — проверьте и там, с названием сети: <code>bash t.sh "Билайн"</code>. Результат действует __HOURS__ ч; проверяйте время от времени — списки операторов меняются.</p>
<p class="note">iPhone так проверить нельзя (Termux есть только на Android). Проверка с Android-телефона того же оператора подойдёт и для iPhone, а «__AUTO__» на iPhone сам пингует серверы из своей сети.</p>
</section>

<section class="card">
<h2>Работают с телефона</h2>
<div class="stats" id="stats"></div>
<div class="scroll"><table id="servers" hidden><thead><tr><th>Сервер</th><th>Сеть</th><th class="n">Пинг</th><th class="n">Когда</th></tr></thead><tbody></tbody></table></div>
<p class="empty" id="servers-empty">Пока нет — проверьте с телефона (шаги выше).</p>
</section>

<section class="card">
<h2>Последние проверки</h2>
<div class="scroll"><table id="reports" hidden><thead><tr><th>Когда</th><th>Сеть</th><th class="n">Работают</th><th class="n">Лучший</th></tr></thead><tbody></tbody></table></div>
<p class="empty" id="reports-empty">Проверок ещё не было.</p>
<p class="note" id="state"></p>
</section>
</main>
<script>
"use strict";
const $ = (id) => document.getElementById(id);
function ago(t, now) {
  const s = Math.max(0, now - t);
  if (s < 90) return "только что";
  if (s < 3600) return Math.round(s / 60) + " мин назад";
  if (s < 172800) return Math.round(s / 3600) + " ч назад";
  return Math.round(s / 86400) + " дн назад";
}
function row(cells) {
  const tr = document.createElement("tr");
  for (const [text, cls] of cells) {
    const td = document.createElement("td");
    td.textContent = text;
    if (cls) td.className = cls;
    tr.appendChild(td);
  }
  return tr;
}
function stat(label, value) {
  const span = document.createElement("span");
  span.append(label + ": ");
  const b = document.createElement("b");
  b.textContent = value;
  span.append(b);
  return span;
}
function fill(id, rows) {
  const table = $(id), body = table.tBodies[0];
  body.replaceChildren(...rows);
  table.hidden = rows.length === 0;
  $(id + "-empty").hidden = rows.length > 0;
}
async function load() {
  try {
    const r = await fetch("status.json", {cache: "no-store"});
    if (!r.ok) throw new Error(r.status);
    const d = await r.json();
    $("stats").replaceChildren(
      stat("работают у сервера", d.alive),
      stat("проверяются с телефона", d.candidates),
      stat("работают с телефона", d.verified),
      stat("не работают с телефона", d.failed),
      stat("из них первыми в подписке", d.in_sub));
    fill("servers", d.servers.map((s) => row([
      [s.name, ""], [s.label, "muted"],
      [s.ms + " мс", "n"], [ago(s.time, d.now), "n muted"]])));
    fill("reports", d.reports.map((x) => row([
      [ago(x.time, d.now), "muted"],
      [x.label + (x.open ? " (без ограничений — не учитывается)" : ""), x.open ? "warn" : ""],
      [x.ok + " из " + x.tested, x.ok > 0 ? "n ok" : "n"],
      [x.best ? x.best + " мс" : "—", "n"]])));
    $("state").textContent = "Обновляется само · " + new Date(d.now * 1000).toLocaleTimeString("ru-RU");
  } catch (e) {
    $("state").textContent = "Нет связи с сервером — повторю через 15 с.";
  }
}
for (const b of document.querySelectorAll("button[data-copy]")) {
  b.addEventListener("click", async () => {
    const text = $(b.dataset.copy).textContent;
    try {
      await navigator.clipboard.writeText(text);
    } catch (e) {
      const ta = document.createElement("textarea");
      ta.value = text;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand("copy");
      ta.remove();
    }
    b.textContent = "Скопировано";
    setTimeout(() => { b.textContent = "Копировать"; }, 1500);
  });
}
load();
setInterval(load, 15000);
</script>
</body>
</html>
'''


class Handler(BaseHTTPRequestHandler):
    def version_string(self):
        return "nginx"

    def do_GET(self):
        self.forward(False)

    def do_HEAD(self):
        self.forward(True)

    def do_POST(self):                    # только отчёт проверки с телефона
        wpath = (WHITE.get("path") or "").rstrip("/")
        if not (PHONE_DIR and wpath and self.path.split("?", 1)[0] == wpath + "/test/report"):
            self.send_error(404)
            return
        try:
            size = int(self.headers.get("Content-Length") or "-1")
        except ValueError:
            size = -1
        if size < 0 or size > REPORT_MAX:
            self.send_error(411 if size < 0 else 413)
            return
        body = self.rfile.read(size)
        client = self.client_address[0]
        client = client[7:] if client.startswith("::ffff:") else client
        try:
            ok, tested = phone_report(body.decode("utf-8", "replace"), client)
        except ValueError as err:
            self.send_body(400, "text/plain; charset=utf-8", ("Ошибка: %s\n" % err).encode("utf-8"), False)
            return
        except OSError:
            self.send_body(500, "text/plain; charset=utf-8", "Не удалось сохранить отчёт\n".encode("utf-8"), False)
            return
        self.send_body(200, "text/plain; charset=utf-8",
                       ("Принято: проверено %d, работают %d\n" % (tested, ok)).encode("utf-8"), False)

    def send_body(self, status, ctype, body, head, extra=()):
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        for key, value in extra:
            self.send_header(key, value)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def send_file(self, path, ctype, head):
        try:
            f = open(path, "rb")
        except OSError:
            self.send_error(404)
            return
        with f:
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(os.fstat(f.fileno()).st_size))
            self.send_header("Connection", "close")
            self.end_headers()
            if not head:
                try:
                    shutil.copyfileobj(f, self.wfile, 64 * 1024)   # медленный мобильный — без тайм-аута на кусок
                except OSError:
                    pass

    def phone(self, sub, head):           # страница проверки с телефона и всё, что берёт t.sh
        wpath = (WHITE.get("path") or "").rstrip("/")
        if sub == "":
            self.send_body(301, "text/plain; charset=utf-8", b"", head, [("Location", wpath + "/test/")])
            return
        try:
            base = phone_base(self)
            if sub == "/":
                self.send_body(200, "text/html; charset=utf-8", phone_page(base), head)
            elif sub == "/t.sh":
                self.send_body(200, "text/plain; charset=utf-8", phone_script(base), head)
            elif sub == "/bundle":
                self.send_body(200, "text/plain; charset=utf-8", phone_bundle(), head)
            elif sub == "/status.json":
                self.send_body(200, "application/json; charset=utf-8",
                               json.dumps(phone_status(), ensure_ascii=False).encode("utf-8"), head)
            elif sub == "/" + PHONE_XRAY:
                self.send_file(os.path.join(PHONE_DIR, PHONE_XRAY), "application/gzip", head)
            else:
                self.send_error(405 if sub == "/report" else 404)
        except (OSError, ValueError, TypeError, KeyError) as err:
            self.send_body(500, "text/plain; charset=utf-8", ("Ошибка: %s\n" % err).encode("utf-8"), head)

    def white_page(self, head):           # отдельная подписка: только белые списки
        links = [it["link"] for it in white_items("list")]
        body = base64.b64encode("\n".join(links).encode("utf-8")) if links else b""
        title = WHITE.get("title") or "Белые списки"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Profile-Title", "base64:" + base64.b64encode(title.encode("utf-8")).decode("ascii"))
        self.send_header("Profile-Update-Interval", str(int(WHITE.get("update_hours") or 1)))
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def forward(self, head):
        wpath = (WHITE.get("path") or "").rstrip("/")
        path = self.path.split("?", 1)[0]
        if wpath and PHONE_DIR and (path == wpath + "/test" or path.startswith(wpath + "/test/")):
            self.phone(path[len(wpath) + 5:], head)
            return
        if wpath and path.rstrip("/") == wpath:
            self.white_page(head)
            return
        req = urllib.request.Request(UPSTREAM + self.path, method="HEAD" if head else "GET")
        for key, value in self.headers.items():
            if key.lower() not in SKIP:
                req.add_header(key, value)
        if self.headers.get("Host"):
            req.add_header("Host", self.headers["Host"])
        req.add_header("X-Forwarded-For", self.client_address[0])
        req.add_header("X-Real-IP", self.client_address[0])
        req.add_header("X-Forwarded-Proto", "https" if CERT else "http")
        try:
            try:
                resp = OPENER.open(req, timeout=30)
            except urllib.error.HTTPError as err:
                resp = err
            try:
                status = getattr(resp, "status", None) or resp.getcode()
                headers = list(resp.headers.items()) if resp.headers else []
                body = b"" if head else (resp.read() or b"")
            finally:
                resp.close()
        except Exception:                 # панель не ответила
            self.send_error(502)
            return
        if status == 200 and body:
            body = tune(body)
            ctype = next((v for k, v in headers if k.lower() == "content-type"), "")
            items = white_items() if WHITE else []
            if "yaml" in ctype.lower() or body.lstrip()[:8] == b"proxies:":
                new = None                # профиль Mihomo (Clash Meta): Tunnel, FlClash и др.
                if items or CLASH:
                    try:
                        new = add_white_yaml(body, items, white_items("auto") if items else [])
                    except Exception:     # что-то пошло не так — профиль уходит как есть
                        new = None
                if new is not None:
                    body = new
                    if items:
                        headers = update_interval(headers)
            elif items and "html" not in ctype.lower():
                try:
                    new = add_white(body, items, white_items("auto"))
                except Exception:         # что-то пошло не так — подписка уходит как есть
                    new = None
                if new is not None:
                    body = new
                    headers = update_interval(headers)
        self.send_response(status)
        for key, value in headers:
            if key.lower() not in SKIP:
                self.send_header(key, value)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass


_lock = threading.Lock()
_tls = {"ctx": None, "stamp": None}


def tls_context():                        # сертификат перечитывается сам, когда его продлили
    with _lock:
        try:
            stamp = (os.stat(CERT).st_mtime_ns, os.stat(KEY).st_mtime_ns)
        except OSError:
            stamp = None
        if _tls["ctx"] is None or (stamp is not None and stamp != _tls["stamp"]):
            try:
                ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                ctx.minimum_version = ssl.TLSVersion.TLSv1_2
                ctx.load_cert_chain(CERT, KEY)
                _tls.update(ctx=ctx, stamp=stamp)
            except (OSError, ssl.SSLError):
                if _tls["ctx"] is None:
                    raise
        return _tls["ctx"]


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True
    request_queue_size = 128

    def server_bind(self):
        if self.address_family == socket.AF_INET6:
            try:
                self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
            except OSError:
                pass
        super().server_bind()

    def finish_request(self, request, client_address):
        request.settimeout(30)
        conn = request
        if CERT:
            try:
                conn = tls_context().wrap_socket(request, server_side=True)
            except (OSError, ValueError):
                return
        try:
            self.RequestHandlerClass(conn, client_address, self)
        finally:
            if conn is not request:
                try:
                    conn.close()
                except OSError:
                    pass


def main():
    port = int(CONF["port"])
    if CERT:
        tls_context()                     # сертификат должен читаться сразу
    try:
        Server.address_family = socket.AF_INET6
        server = Server(("::", port), Handler)
    except OSError:
        Server.address_family = socket.AF_INET
        server = Server(("0.0.0.0", port), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
PY
  chmod 755 "$SUB_FILTER_PY"
}
# Белые списки для мобильного интернета: программа скачивает список готовых подключений и
# проверяет каждое настоящим запросом через Xray; рабочие (alive.json) отдаёт фильтр подписки.
write_white_program() {
  mkdir -p "$(dirname "$WHITE_PY")"
  cat > "$WHITE_PY" <<'PY'
#!/usr/bin/env python3
# Белые списки для мобильного интернета (ставит install-vpn-all.sh, запускает таймер vpn-white-lists).
# Скачивает готовые подключения из многих публичных источников (igareck, zieng2, all_subs и других —
# список в настройках, у каждого источника свои зеркала), объединяет их без повторов и проверяет
# КАЖДОЕ подключение настоящим запросом через Xray панели. Все рабочие записывает в alive.json —
# из них фильтр подписки берёт в подписку самые быстрые с разных серверов. Подключение, которое
# не ответило, пропадает из подписки сразу после проверки.
#   vpn-white-lists.py НАСТРОЙКИ.json auto    — по таймеру: скачать, если пора; полная проверка раз
#                                               в час, между ними — быстрая (только рабочие)
#   vpn-white-lists.py НАСТРОЙКИ.json update  — скачать сейчас и проверить всё
#   vpn-white-lists.py НАСТРОЙКИ.json check   — проверить всё
#   vpn-white-lists.py НАСТРОЙКИ.json quick   — перепроверить только рабочие
#   vpn-white-lists.py НАСТРОЙКИ.json status  — итог последней проверки (JSON)
import base64, binascii, bisect, collections, concurrent.futures, fcntl, glob, ipaddress, json, os, re, socket
import ssl, subprocess, sys, tempfile, time, urllib.error, urllib.parse, urllib.request

SCHEMES = ("vless", "vmess", "trojan", "ss", "hysteria2", "hy2")
MAX_BYTES = 8 * 1024 * 1024
IPV4 = re.compile(rb"\b(\d{1,3}(?:\.\d{1,3}){3})\b")
FLAG = re.compile("[\U0001F1E6-\U0001F1FF]{2}")


class Skip(Exception):
    """подключение, которое здесь не проверить (неизвестный транспорт, нет ключа и т. п.)"""


def log(text):
    print(text, flush=True)


def load_conf(path):
    conf = json.load(open(path, encoding="utf-8"))
    for key, value in (("data", "/var/lib/vpn-white-lists"), ("refresh_hours", 5), ("label", "🏳️ БС"),
                       ("test_urls", ["https://www.gstatic.com/generate_204",
                                      "https://cp.cloudflare.com/generate_204"]),
                       ("timeout", 8),             # ответ через подключение, секунд
                       ("tcp_timeout", 3),         # открывается ли сервер вообще, секунд
                       ("workers", 64), ("tcp_workers", 128), ("batch", 300),
                       ("max_items", 4000),        # сколько разных подключений из всех источников проверять
                       ("full_check_minutes", 60),  # полная проверка; между ними — только рабочие
                       ("sub_max", 15), ("list_max", 30), ("xray_dir", "/usr/local/x-ui/bin"),
                       # российские IP-сети (вход и выход подключения): ipverse — сводка базы RIPE, затем сама RIPE
                       ("ru_ranges", ["https://raw.githubusercontent.com/ipverse/rir-ip/master/country/ru/ipv4-aggregated.txt",
                                      "https://cdn.jsdelivr.net/gh/ipverse/rir-ip@master/country/ru/ipv4-aggregated.txt",
                                      "https://ftp.ripe.net/pub/stats/ripencc/delegated-ripencc-latest"]),
                       # IP выхода: сайты, которые отвечают IP-адресом того, кто к ним пришёл
                       ("exit_urls", ["https://api.ipify.org", "https://ipv4.icanhazip.com", "https://4.ident.me"]),
                       ("ru_exit", "last")):        # выход в России: last — в конец списка, drop — убрать
        conf.setdefault(key, value)
    return conf


def write_atomic(path, text):
    folder = os.path.dirname(path)
    os.makedirs(folder, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=folder, prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def read_json(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def b64text(s):
    s = "".join(str(s).split()).replace("-", "+").replace("_", "/")
    return base64.b64decode(s + "=" * (-len(s) % 4)).decode("utf-8")


def reason(err):
    if isinstance(err, urllib.error.HTTPError):
        return "HTTP %s" % err.code
    if isinstance(err, urllib.error.URLError):
        err = err.reason
    if isinstance(err, socket.timeout) or "timed out" in str(err):
        return "нет ответа"
    return " ".join(str(err).split())[:80] or err.__class__.__name__


# ---------------------------------------------------------------- скачивание списков
def fetch(url, limit=MAX_BYTES):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (vpn-white-lists)",
                                               "Cache-Control": "no-cache"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("файл больше %d МБ" % (limit // (1024 * 1024)))
    return raw


# ---------------------------------------------------------------- российские IP-сети
RU_FILE = "ru-ipv4.txt"


def parse_ru(text):
    """сети России: строки «1.2.3.0/24» (ipverse) или «ripencc|RU|ipv4|начало|сколько|…» (RIPE) →
    отсортированные непересекающиеся диапазоны (начало, конец) числами"""
    nets = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "|" in line:
            p = line.split("|")
            if len(p) > 4 and p[1] == "RU" and p[2] == "ipv4":
                try:
                    start = int(ipaddress.IPv4Address(p[3]))
                    nets.append((start, start + int(p[4]) - 1))
                except ValueError:
                    pass
            continue
        try:
            n = ipaddress.IPv4Network(line, strict=False)
        except ValueError:
            continue
        nets.append((int(n.network_address), int(n.broadcast_address)))
    nets.sort()
    merged = []
    for a, b in nets:
        if merged and a <= merged[-1][1] + 1:
            merged[-1] = (merged[-1][0], max(merged[-1][1], b))
        else:
            merged.append((a, b))
    return merged


def ru_networks(conf, state):
    """российские сети — раз в сутки скачиваем заново; не скачались — берём прежние"""
    path = os.path.join(conf["data"], RU_FILE)
    try:
        age = time.time() - os.path.getmtime(path)
    except OSError:
        age = float("inf")
    if age > 24 * 3600:
        for url in conf["ru_ranges"]:
            try:
                nets = parse_ru(fetch(url, 64 * 1024 * 1024).decode("utf-8", "replace"))
            except (OSError, ValueError):
                continue
            if len(nets) > 1000:                   # у России — тысячи сетей; меньше — файл не тот или битый
                write_atomic(path, "".join("%d %d\n" % n for n in nets))
                break
    try:
        with open(path, encoding="utf-8") as f:
            nets = [tuple(int(x) for x in line.split()) for line in f if line.strip()]
    except (OSError, ValueError):
        nets = []
    state["ru_ranges"] = len(nets)
    return nets


def in_nets(ip, nets):
    """True — IP в российской сети, False — нет, None — не знаем (нет IP, IPv6 или нет базы сетей)"""
    if not ip or not nets:
        return None
    try:
        v = int(ipaddress.IPv4Address(ip))
    except ValueError:
        return None
    i = bisect.bisect_right(nets, (v, float("inf"))) - 1
    return i >= 0 and nets[i][0] <= v <= nets[i][1]


def extract_links(raw):
    text = raw.decode("utf-8", "replace").lstrip("﻿")
    if "://" not in text:                          # весь список в base64
        try:
            text = b64text(text)
        except (binascii.Error, ValueError):
            return []
    links, seen = [], set()
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.split("://", 1)[0].lower() in SCHEMES and line not in seen:
            seen.add(line)
            links.append(line)
    return links


def link_key(link):
    """ссылка без названия: одно и то же подключение в разных списках называется по-разному"""
    return link if link.lower().startswith("vmess://") else link.split("#", 1)[0]


def source_name(mirrors):
    path = urllib.parse.urlsplit(mirrors[0]).path.rstrip("/")
    name = path.rsplit("/", 1)[-1]
    parts = path.strip("/").split("/")
    if 0 < len(name) < 6 and len(parts) > 2:      # «wl» мало о чём говорит — с названием проекта: «roskompozor/wl»
        name = parts[1] + "/" + name
    return name or urllib.parse.urlsplit(mirrors[0]).hostname or mirrors[0]


def fetch_source(mirrors):
    """источник — один файл и его зеркала: берём первое зеркало, которое отдало подключения"""
    errors = []
    for url in mirrors:
        host = urllib.parse.urlsplit(url).hostname or url
        try:
            got = extract_links(fetch(url))
        except (OSError, ValueError) as err:       # сюда же — ошибки HTTP и таймауты
            errors.append("%s: %s" % (host, reason(err)))
            continue
        if got:
            return got, host, ""
        errors.append("%s: в файле нет подключений" % host)
    return [], "", "; ".join(errors[-2:])


def download(conf, state):
    sources = [s if isinstance(s, list) else [s] for s in conf["sources"] if s]
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        results = list(pool.map(fetch_source, sources))
    links, seen, used, errors, failed, ok = [], set(), [], [], [], 0
    for mirrors, (got, host, err) in zip(sources, results):   # по порядку источников — номера стабильны
        if not got:
            failed.append(source_name(mirrors))
            if err:
                errors.append(err)
            continue
        ok += 1
        if host not in used:
            used.append(host)
        for link in got:
            key = link_key(link)
            if key not in seen:
                seen.add(key)
                links.append(link)
    if not links:
        raise RuntimeError("; ".join(errors[-3:]) or "источник не указан")
    links = links[:20000]                          # защита от переполнения; разные подключения — max_items
    write_atomic(os.path.join(conf["data"], "source.txt"), "\n".join(links) + "\n")
    state.update(downloaded=int(time.time()), download_from=used, download_error="", total=len(links),
                 sources_ok=ok, sources_total=len(sources), sources_failed=failed)
    log("Списки скачаны: источников %d из %d, подключений — %d" % (ok, len(sources), len(links)))
    if failed:
        log("Не скачались (или пустые): %s" % ", ".join(failed))
    return links


# ---------------------------------------------------------------- ссылка → выход Xray
def public_host(host):
    """служебные адреса (0.0.0.0, 127.0.0.1, локальные сети) — не серверы: так в списках бывают заглушки"""
    try:
        ip = ipaddress.ip_address(host.strip("[]"))
    except ValueError:
        return True                                # доменное имя
    return not (ip.is_private or ip.is_loopback or ip.is_unspecified or ip.is_link_local
                or ip.is_multicast or ip.is_reserved)


def parse_query(query):
    """параметры ссылки; «+» остаётся «+» (в ключах base64 это не пробел)"""
    out = {}
    for pair in query.split("&"):
        if pair:
            key, _, value = pair.partition("=")
            out.setdefault(urllib.parse.unquote(key), urllib.parse.unquote(value))
    return out


def parts(link):
    u = urllib.parse.urlsplit(link)
    query = parse_query(u.query)
    try:
        port = u.port
    except ValueError:
        raise Skip("неверный порт")
    if not u.hostname or not port:
        raise Skip("нет адреса или порта")
    if not public_host(u.hostname):
        raise Skip("служебный адрес")
    user = urllib.parse.unquote(u.netloc.rpartition("@")[0]) if "@" in u.netloc else ""
    return u.hostname, port, user, query, urllib.parse.unquote(u.fragment)


def stream(q, host):
    net = (q.get("type") or "tcp").lower()
    sec = (q.get("security") or "none").lower()
    path, hosts = q.get("path") or "/", q.get("host") or ""
    s = {"network": net}
    if net in ("tcp", "raw"):
        s["network"] = "tcp"
        if (q.get("headerType") or "").lower() == "http":
            req = {"path": [path]}
            if hosts:
                req["headers"] = {"Host": [h for h in hosts.split(",") if h]}
            s["tcpSettings"] = {"header": {"type": "http", "request": req}}
    elif net == "ws":
        s["wsSettings"] = {"path": path}
        if hosts:
            s["wsSettings"]["host"] = hosts
    elif net == "grpc":
        g = {"serviceName": q.get("serviceName") or ""}
        if q.get("authority"):
            g["authority"] = q["authority"]
        if (q.get("mode") or "").lower() == "multi":
            g["multiMode"] = True
        s["grpcSettings"] = g
    elif net in ("xhttp", "splithttp"):
        s["network"] = "xhttp"
        x = {"path": path, "mode": q.get("mode") or "auto"}
        if hosts:
            x["host"] = hosts
        if q.get("extra"):
            try:
                extra = json.loads(q["extra"])
            except ValueError:
                extra = None
            if isinstance(extra, dict):
                x["extra"] = extra
        s["xhttpSettings"] = x
    elif net == "httpupgrade":
        s["httpupgradeSettings"] = {"path": path}
        if hosts:
            s["httpupgradeSettings"]["host"] = hosts
    else:
        raise Skip("транспорт %s" % net)
    if sec == "reality":
        if not q.get("pbk"):
            raise Skip("Reality без ключа")
        pbk = q["pbk"].strip().replace("+", "-").replace("/", "_").rstrip("=")   # Xray ждёт base64url
        r = {"serverName": q.get("sni") or "", "fingerprint": q.get("fp") or "chrome",
             "publicKey": pbk, "shortId": q.get("sid") or ""}
        spx = q.get("spx") or ""
        for _ in range(10):                        # бывает закодировано по нескольку раз: %25252F → /
            if "%" not in spx:
                break
            spx = urllib.parse.unquote(spx)
        if spx.startswith("/"):
            r["spiderX"] = spx
        if q.get("pqv"):
            r["mldsa65Verify"] = q["pqv"]
        s.update(security="reality", realitySettings=r)
    elif sec in ("tls", "xtls"):
        t = {"serverName": q.get("sni") or q.get("peer") or hosts.split(",")[0] or host}
        if q.get("fp"):
            t["fingerprint"] = q["fp"]
        alpn = [a for a in (q.get("alpn") or "").split(",") if a]
        if alpn:
            t["alpn"] = alpn
        if q.get("pcs"):
            t["pinnedPeerCertSha256"] = q["pcs"]
        if q.get("vcn"):
            t["verifyPeerCertByName"] = q["vcn"]
        s.update(security="tls", tlsSettings=t)
    elif sec in ("none", ""):
        s["security"] = "none"
    else:
        raise Skip("шифрование %s" % sec)
    return s


def to_outbound(link):
    scheme = link.split("://", 1)[0].lower()
    if scheme == "vless":
        host, port, uid, q, name = parts(link)
        if not uid:
            raise Skip("нет ключа")
        enc = (q.get("encryption") or "none").strip()
        if enc.lower().startswith("none"):         # в некоторых списках к «none» приклеена реклама
            enc = "none"
        user = {"id": uid, "encryption": enc}
        if q.get("flow"):
            user["flow"] = q["flow"]
        st = stream(q, host)
        if st["security"] == "none" and user["encryption"] == "none":
            raise Skip("VLESS без шифрования")    # такие Xray не принимает, а трафик в них открыт
        return {"protocol": "vless", "settings": {"vnext": [{"address": host, "port": port, "users": [user]}]},
                "streamSettings": st}, name
    if scheme == "trojan":
        host, port, password, q, name = parts(link)
        if not password:
            raise Skip("нет пароля")
        q.setdefault("security", "tls")
        return {"protocol": "trojan", "settings": {"servers": [{"address": host, "port": port, "password": password}]},
                "streamSettings": stream(q, host)}, name
    if scheme == "vmess":
        body = link.split("://", 1)[1].split("#", 1)[0]
        d = json.loads(b64text(body))
        host, port = str(d.get("add") or "").strip(), int(d.get("port") or 0)
        if not host or not port or not d.get("id"):
            raise Skip("нет адреса или ключа")
        if not public_host(host):
            raise Skip("служебный адрес")
        net = str(d.get("net") or "tcp").lower()
        q = {"type": net, "security": str(d.get("tls") or "none"), "sni": d.get("sni") or "",
             "host": d.get("host") or "", "fp": d.get("fp") or "", "alpn": d.get("alpn") or ""}
        if net == "grpc":
            q.update(serviceName=d.get("path") or "", mode=d.get("type") or "")
        else:
            q.update(path=d.get("path") or "/", headerType=d.get("type") or "")
        user = {"id": d["id"], "alterId": int(d.get("aid") or 0), "security": d.get("scy") or "auto"}
        return {"protocol": "vmess", "settings": {"vnext": [{"address": host, "port": port, "users": [user]}]},
                "streamSettings": stream(q, host)}, str(d.get("ps") or "")
    if scheme == "ss":
        rest = link.split("://", 1)[1]
        rest, _, frag = rest.partition("#")
        rest = rest.split("?", 1)[0].rstrip("/")
        if "@" not in rest:                        # старый формат: всё в base64
            rest = b64text(rest)
        userinfo, _, hostport = rest.rpartition("@")
        userinfo = urllib.parse.unquote(userinfo)
        if ":" not in userinfo:
            userinfo = b64text(userinfo)
        method, _, password = userinfo.partition(":")
        u = urllib.parse.urlsplit("ss://x@" + hostport)
        if not u.hostname or not u.port or not method:
            raise Skip("нет адреса или пароля")
        if not public_host(u.hostname):
            raise Skip("служебный адрес")
        if "plugin=" in link:
            raise Skip("плагин Shadowsocks")
        return {"protocol": "shadowsocks", "settings": {"servers": [{"address": u.hostname, "port": u.port,
                                                                     "method": method, "password": password}]}}, \
            urllib.parse.unquote(frag)
    if scheme in ("hysteria2", "hy2"):
        host, port, auth, q, name = parts(link)
        if q.get("obfs") or q.get("mport"):
            raise Skip("Hysteria2 с маскировкой")
        tls = {"serverName": q.get("sni") or host, "alpn": ["h3"]}
        if q.get("pinSHA256"):
            tls["pinnedPeerCertSha256"] = q["pinSHA256"].replace(":", "").lower()
        return {"protocol": "hysteria", "settings": {"version": 2, "address": host, "port": port},
                "streamSettings": {"network": "hysteria", "security": "tls", "tlsSettings": tls,
                                   "hysteriaSettings": {"version": 2, "auth": auth}}}, name
    raise Skip("протокол %s" % scheme)


def nice_name(label, n, original):
    country = ""
    m = FLAG.search(original or "")
    if m:                                          # «🇩🇪 Germany, Frankfurt | [BL]» → «🇩🇪 Germany»
        tail = re.split(r"[|,(\[]", original[m.end():])[0]
        tail = " ".join(re.sub(r"[^\w\s.-]", " ", tail).split())
        if len(tail) > 24:
            tail = tail[:24].rsplit(" ", 1)[0]
        country = (m.group(0) + " " + tail).strip()
    return "%s %02d%s" % (label, n, " · " + country if country else "")


def rename(link, name):
    if link.lower().startswith("vmess://"):
        d = json.loads(b64text(link.split("://", 1)[1].split("#", 1)[0]))
        d["ps"] = name
        return "vmess://" + base64.b64encode(json.dumps(d, ensure_ascii=False).encode("utf-8")).decode("ascii")
    return link.split("#", 1)[0] + "#" + urllib.parse.quote(name, safe="")


def build_items(conf, links):
    """ссылки → подключения для проверки; одинаковые (тот же сервер и ключ из разных источников) — один раз"""
    items, seen, skipped = [], set(), collections.Counter()
    for n, link in enumerate(links, 1):
        try:
            outbound, original = to_outbound(link)
        except Skip as err:
            skipped[str(err)] += 1
            continue
        except (ValueError, KeyError, TypeError, UnicodeError, binascii.Error):
            skipped["ошибка в ссылке"] += 1
            continue
        key = json.dumps(outbound, sort_keys=True)
        if key in seen:
            continue
        seen.add(key)
        name = nice_name(conf["label"], n, original)
        items.append({"n": n, "name": name, "link": rename(link, name), "outbound": outbound,
                      "cidr": "cidr" in (original or "").lower()})
        if len(items) >= int(conf["max_items"]):
            break
    return items, skipped


# ---------------------------------------------------------------- проверка через Xray
def find_xray(conf):
    for path in sorted(glob.glob(os.path.join(conf["xray_dir"], "xray-linux-*"))):
        if os.access(path, os.X_OK):
            return path
    raise RuntimeError("не найден Xray панели в %s" % conf["xray_dir"])


def free_ports(count):
    socks, ports = [], []
    try:
        for _ in range(count):
            s = socket.socket()
            s.bind(("127.0.0.1", 0))
            socks.append(s)
            ports.append(s.getsockname()[1])
    finally:
        for s in socks:
            s.close()
    return ports


def xray_config(items, ports):
    inbounds, outbounds, rules = [], [], []
    for it, port in zip(items, ports):
        tag = "w%d" % it["n"]
        inbounds.append({"tag": "in-" + tag, "listen": "127.0.0.1", "port": port, "protocol": "socks",
                         "settings": {"udp": False}})
        outbounds.append(dict(it["outbound"], tag=tag))
        rules.append({"type": "field", "inboundTag": ["in-" + tag], "outboundTag": tag})
    return {"log": {"loglevel": "none"}, "inbounds": inbounds, "outbounds": outbounds,
            "routing": {"rules": rules}}


def xray_error(text):
    """главное из ошибки Xray: «Failed to start: … > причина» → «причина»"""
    text = text.strip()
    m = re.search(r"Failed to start: (.*)", text)
    line = m.group(1) if m else (text.splitlines()[-1] if text else "")
    return " ".join(line.split(" > ")[-1].split())[:200]


def xray_test(xray, conf, items, workdir):
    """(принимает ли Xray эти настройки, причина отказа)"""
    fd, path = tempfile.mkstemp(dir=workdir, suffix=".json")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(xray_config(items, range(20000, 20000 + len(items))), f)
    env = dict(os.environ, XRAY_LOCATION_ASSET=conf["xray_dir"])
    try:
        r = subprocess.run([xray, "run", "-test", "-c", path], stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, env=env, timeout=120)
    except (OSError, subprocess.TimeoutExpired) as err:
        return False, str(err)
    finally:
        os.unlink(path)
    if r.returncode == 0:
        return True, ""
    return False, xray_error(r.stdout.decode("utf-8", "replace")) or "код %d" % r.returncode


def xray_valid(xray, conf, items, workdir):
    """подключения, настройки которых принимает Xray этого сервера: проверяем пачками,
    пачку с ошибкой делим пополам, пока не найдём неподходящие"""
    good, bad = [], []

    def split(group):
        ok, why = xray_test(xray, conf, group, workdir)
        if ok:
            return list(group), []
        if len(group) == 1:
            return [], [why]
        mid = len(group) // 2
        g1, b1 = split(group[:mid])
        g2, b2 = split(group[mid:])
        return g1 + g2, b1 + b2

    chunks = [items[i:i + 100] for i in range(0, len(items), 100)]
    with concurrent.futures.ThreadPoolExecutor(4) as pool:
        for g, b in pool.map(split, chunks):
            good.extend(g)
            bad.extend(b)
    good.sort(key=lambda it: it["n"])
    return good, bad


def server_of(outbound):
    """адрес и порт сервера подключения"""
    s = outbound.get("settings") or {}
    for key in ("vnext", "servers"):
        for srv in s.get(key) or []:
            if isinstance(srv, dict):
                return srv.get("address"), srv.get("port")
    return s.get("address"), s.get("port")


def reachable(item, timeout):
    """открывается ли сервер подключения напрямую с этого сервера (None — UDP, так не проверить)
    и его IP-адрес (для итога проверки)"""
    host, port = server_of(item["outbound"])
    if item["outbound"].get("protocol") == "hysteria":
        try:
            return None, socket.getaddrinfo(host, int(port), proto=socket.IPPROTO_UDP)[0][4][0]
        except (OSError, TypeError, ValueError, UnicodeError, IndexError):
            return None, ""
    try:
        conn = socket.create_connection((host, int(port)), timeout=timeout)
        try:
            ip = conn.getpeername()[0]
        finally:
            conn.close()
        return True, ip
    except (OSError, TypeError, ValueError, UnicodeError):
        return False, ""


def recv_exact(sock, size):
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise OSError("соединение закрыто")
        data += chunk
    return data


CTX = ssl.create_default_context()


def probe(port, url, timeout, body=False):
    """запрос url через SOCKS-вход 127.0.0.1:port; время ответа в мс или None.
    body=True — (время, тело ответа) или None"""
    u = urllib.parse.urlsplit(url)
    secure = u.scheme == "https"
    host, dport = u.hostname, u.port or (443 if secure else 80)
    path = (u.path or "/") + ("?" + u.query if u.query else "")
    start = time.monotonic()
    conn = None
    try:
        conn = socket.create_connection(("127.0.0.1", port), timeout=timeout)
        conn.sendall(b"\x05\x01\x00")
        if recv_exact(conn, 2) != b"\x05\x00":
            return None
        name = host.encode("idna")
        conn.sendall(b"\x05\x01\x00\x03" + bytes([len(name)]) + name + dport.to_bytes(2, "big"))
        head = recv_exact(conn, 4)
        if head[1] != 0:
            return None
        size = {1: 4, 4: 16}.get(head[3])
        if size is None:
            size = recv_exact(conn, 1)[0]
        recv_exact(conn, size + 2)
        if secure:
            conn = CTX.wrap_socket(conn, server_hostname=host)
        conn.sendall(("GET %s HTTP/1.1\r\nHost: %s\r\nUser-Agent: Mozilla/5.0\r\nAccept: */*\r\n"
                      "Connection: close\r\n\r\n" % (path, host)).encode("ascii"))
        reply = b""
        while b"\r\n" not in reply and len(reply) < 4096:
            chunk = conn.recv(1024)
            if not chunk:
                break
            reply += chunk
        ms = int((time.monotonic() - start) * 1000)
        status = reply.split(b"\r\n", 1)[0].split()
        if not (len(status) >= 2 and status[0].startswith(b"HTTP/") and status[1].isdigit()
                and 200 <= int(status[1]) < 400):
            return None
        if not body:
            return ms
        while len(reply) < 8192:                   # тело ответа: сайты с IP отвечают коротко и закрывают соединение
            chunk = conn.recv(2048)
            if not chunk:
                break
            reply += chunk
        return ms, reply.partition(b"\r\n\r\n")[2]
    except (OSError, ValueError, UnicodeError):
        return None
    finally:
        if conn is not None:
            try:
                conn.close()
            except OSError:
                pass


def exit_ip(port, urls, timeout, first=0):
    """IP, с которого подключение выходит в интернет (через SOCKS-вход port); "" — не узнали.
    Сайты с IP чередуем по подключениям, чтобы не упереться в ограничения одного из них"""
    for k in range(min(2, len(urls))):
        r = probe(port, urls[(first + k) % len(urls)], timeout, body=True)
        if not r:
            continue
        for m in IPV4.finditer(r[1][:512]):
            ip = m.group(1).decode("ascii")
            try:
                if ipaddress.IPv4Address(ip).is_global:
                    return ip
            except ValueError:
                continue
    return ""


def internet_ok(conf):
    # есть ли у самого сервера интернет (без него все подключения выглядели бы нерабочими)
    for url in list(conf["test_urls"]) + ["https://ya.ru/"]:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=conf["timeout"]) as resp:
                if 200 <= resp.status < 400:
                    return True
        except (OSError, ValueError):
            continue
    return False


def probe_batch(xray, conf, items, work):
    """одна пачка: временный Xray со входом на каждое подключение, запрос через каждое;
    у ответивших, чей выход ещё не известен, — и IP выхода. Итог: [(мс или None, IP выхода или "")]"""
    ports = free_ports(len(items))
    need_exit = {p: not it.get("exit_ip") for p, it in zip(ports, items)}
    exit_urls = list(conf.get("exit_urls") or [])
    path = os.path.join(work, "check.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(xray_config(items, ports), f)
    xlog = open(os.path.join(work, "xray.log"), "wb")
    proc = subprocess.Popen([xray, "run", "-c", path], stdout=xlog, stderr=subprocess.STDOUT,
                            env=dict(os.environ, XRAY_LOCATION_ASSET=conf["xray_dir"]))
    xlog.close()
    timeout = float(conf["timeout"])
    try:
        pending, deadline = set(ports), time.monotonic() + 20
        while pending and time.monotonic() < deadline and proc.poll() is None:
            for port in list(pending):
                try:
                    socket.create_connection(("127.0.0.1", port), timeout=1).close()
                    pending.discard(port)
                except OSError:
                    pass
            if pending:
                time.sleep(0.3)
        if pending:
            try:
                with open(os.path.join(work, "xray.log"), encoding="utf-8", errors="replace") as f:
                    err = xray_error(f.read())
            except OSError:
                err = ""
            raise RuntimeError("Xray для проверки не запустился%s" % (": " + err if err else ""))

        def ping(port):
            for url in conf["test_urls"][:2]:
                t0 = time.monotonic()
                ms = probe(port, url, timeout)
                if ms is not None:
                    return ms
                if time.monotonic() - t0 >= timeout * 0.8:   # не ответил вовсе — второй раз не ждём
                    return None
            return None

        def one(port):
            ms = ping(port)
            if ms is None or not need_exit[port] or not exit_urls:
                return ms, ""
            return ms, exit_ip(port, exit_urls, timeout, port % len(exit_urls))

        with concurrent.futures.ThreadPoolExecutor(int(conf["workers"])) as pool:
            return list(pool.map(one, ports))
    finally:
        proc.terminate()
        try:
            proc.wait(5)
        except subprocess.TimeoutExpired:
            proc.kill()


def check(conf, state, items, quick=False):
    """проверить подключения; все рабочие — в alive.json (с временем ответа)"""
    xray = find_xray(conf)
    total = len(items)
    work = tempfile.mkdtemp(prefix="vpn-white-")
    try:
        # настройки, которые этот Xray не принимает (устаревшие и т. п.), отсеиваем сразу
        items, bad = xray_valid(xray, conf, items, work)
        why = collections.Counter(bad).most_common(1)[0][0] if bad else ""
        if bad:
            log("Xray этого сервера не принял настройки %d подключений: %s" % (len(bad), why))
        state.update(unsupported=len(bad), unsupported_reason=why)
        if not items:
            raise RuntimeError("Xray не принял ни одно подключение из списка: %s" % (why or "формат не поддерживается"))
        if not internet_ok(conf):
            raise RuntimeError("у сервера сейчас нет связи с интернетом — проверку пропускаю")
        nets = ru_networks(conf, state)            # где вход и выход подключения: в России или нет
        if not nets:
            log("Базу российских IP-сетей скачать не удалось — вход и выход подключений не определяю.")
        # 1) открывается ли сервер подключения вообще — быстро, без Xray
        with concurrent.futures.ThreadPoolExecutor(int(conf["tcp_workers"])) as pool:
            checked = list(pool.map(lambda it: reachable(it, float(conf["tcp_timeout"])), items))
        reach = [r for r, _ in checked]
        for it, (_, ip) in zip(items, checked):
            if ip:
                it["ip"] = ip
        # 2) настоящий запрос через каждое подключение, сервер которого открылся (и через UDP)
        todo = [it for it, r in zip(items, reach) if r is not False]
        results = {}
        size = max(1, int(conf["batch"]))
        for i in range(0, len(todo), size):
            batch = todo[i:i + size]
            for it, (ms, ex) in zip(batch, probe_batch(xray, conf, batch, work)):
                results[it["n"]] = ms
                if ex:
                    it["exit_ip"] = ex
            if len(todo) > size:
                log("  проверено %d из %d…" % (min(i + size, len(todo)), len(todo)))
    finally:
        for name in os.listdir(work):
            os.unlink(os.path.join(work, name))
        os.rmdir(work)
    alive = [dict(it, ms=results[it["n"]]) for it in items if results.get(it["n"]) is not None]
    # вход (IP сервера подключения) и выход (IP, с которого оно выходит в интернет): в России или нет.
    # Вход в России — подключение проходит белые списки по IP; выход за рубежом — открываются и
    # заблокированные сайты. Отметка — в названии: «… · РФ→🌍» лучшие, «… · выход РФ» — только российский интернет
    for it in alive:
        it["in_ru"] = in_nets(it.get("ip") or "", nets)
        it["out_ru"] = in_nets(it.get("exit_ip") or "", nets)
        base = it.get("base_name") or it["name"]
        tag = ""
        if it["out_ru"] is True:
            tag = " · выход РФ"
        elif it["out_ru"] is False and it["in_ru"] is True:
            tag = " · РФ→🌍"
        it["base_name"] = base
        if it["name"] != base + tag:
            it["name"] = base + tag
            it["link"] = rename(it["link"], it["name"])
    ru_good = sum(1 for it in alive if it["in_ru"] is True and it["out_ru"] is False)
    abroad = sum(1 for it in alive if it["in_ru"] is not True and it["out_ru"] is False)
    ru_exit = sum(1 for it in alive if it["out_ru"] is True)
    no_exit = sum(1 for it in alive if it["out_ru"] is None)
    answered = len(alive)
    if conf.get("ru_exit") == "drop":
        alive = [it for it in alive if it["out_ru"] is not True]
    state.update(ru_good=ru_good, exit_abroad=abroad, ru_exit=ru_exit, exit_unknown=no_exit)
    closed = sum(1 for r in reach if r is False)
    opened = sum(1 for it, r in zip(items, reach) if r is True and results.get(it["n"]) is None)
    udp = sum(1 for it, r in zip(items, reach) if r is None and results.get(it["n"]) is None)
    failed = closed + opened + udp
    detail = []
    if closed:
        detail.append("сервер не открывается отсюда — %d" % closed)
    if opened:
        detail.append("открывается, но запрос через него не проходит — %d" % opened)
    if udp:
        detail.append("Hysteria2 (UDP) — %d" % udp)
    detail = " (%s)" % "; ".join(detail) if detail else ""
    now = int(time.time())
    state.update(checked=now, tested=len(items), alive=len(alive), check_error="", fail_closed=closed,
                 fail_open=opened)
    if not quick:
        state["full_checked"] = now
    path = os.path.join(conf["data"], "alive.json")
    kind = "Перепроверено рабочих" if quick else "Проверено"
    if failed and not alive and closed == failed:
        log("Этот сервер не может подключиться ни к одному серверу из списка — похоже, исходящие "
            "соединения ограничивает хостер или сеть сервера.")
    if not answered:
        # не ответило ни одно — скорее всего, сбой связи у самого сервера, а не у всех подключений
        # сразу: оставляем прежние рабочие (те, что ещё есть в списке) до следующей проверки
        keys = {json.dumps(it["outbound"], sort_keys=True) for it in items}
        prev = read_json(path, {}).get("items") or []
        kept = [it for it in prev if isinstance(it, dict) and json.dumps(it.get("outbound"), sort_keys=True) in keys]
        if kept:
            state["check_error"] = "не ответило ни одно подключение — оставлены прежние рабочие (%d)" % len(kept)
            log("%s %d: не ответило ни одно%s — похоже на сбой связи у сервера; в подписке остаются "
                "прежние рабочие (%d) до следующей проверки." % (kind, len(items), detail, len(kept)))
            if len(kept) != len(prev):
                write_atomic(path, json.dumps({"updated": now, "total": total, "alive": len(kept),
                                               "items": kept}, ensure_ascii=False))
            return
    write_atomic(path, json.dumps({"updated": now, "total": total, "alive": len(alive), "items": alive},
                                  ensure_ascii=False))
    log("%s %d: работают %d, не отвечают %d%s." % (kind, len(items), answered, failed, detail))
    if answered and nets:
        log("  вход в РФ, выход за рубежом — %d; выход за рубежом — %d; выход в РФ — %d%s; выход не определился — %d."
            % (ru_good, abroad, ru_exit, " (убраны из подписки)" if conf.get("ru_exit") == "drop" else
               " (в конце списка)", no_exit))
    if not quick and bad:
        log("Не проверялись: %d (Xray этого сервера не принимает их настройки)." % len(bad))


# ---------------------------------------------------------------- запуск
def main():
    if len(sys.argv) < 2:
        print("vpn-white-lists.py НАСТРОЙКИ.json [auto|update|check|quick|status]")
        return 2
    conf = load_conf(sys.argv[1])
    cmd = sys.argv[2] if len(sys.argv) > 2 else "auto"
    data = conf["data"]
    state_path = os.path.join(data, "state.json")
    alive_path = os.path.join(data, "alive.json")
    if cmd == "status":
        state = read_json(state_path, {})
        alive = len(read_json(alive_path, {}).get("items") or [])
        state["alive_now"] = alive                   # рабочих сейчас (из всех источников)
        state["in_subscription"] = min(alive, int(conf["sub_max"]))   # из них в подписке — лучшие
        print(json.dumps(state, ensure_ascii=False))
        return 0
    if cmd not in ("auto", "update", "check", "quick"):
        print("неизвестная команда: %s" % cmd)
        return 2
    os.makedirs(data, exist_ok=True)
    with open(os.path.join(data, ".lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)          # проверка по таймеру и ручной запуск — по очереди
        state = read_json(state_path, {})
        try:
            with open(os.path.join(data, "source.txt"), encoding="utf-8") as f:
                links = [x.strip() for x in f if x.strip()]
        except OSError:
            links = []
        now = time.time()
        due = now - float(state.get("downloaded") or 0) >= float(conf["refresh_hours"]) * 3600 - 60
        rc, fresh = 0, False
        if cmd == "update" or (cmd == "auto" and (due or not links)):
            try:
                links = download(conf, state)
                fresh = True
            except RuntimeError as err:
                state["download_error"] = str(err)
                log("Скачать списки не удалось (%s)%s" % (err, " — проверяю прежние." if links else "."))
                rc = 1
        prev = read_json(alive_path, {}).get("items") or []
        full_due = now - float(state.get("full_checked") or 0) >= float(conf["full_check_minutes"]) * 60 - 60
        quick = cmd == "quick" or (cmd == "auto" and not fresh and not full_due)
        try:
            if quick and not prev:
                pass                               # рабочих нет — ждём полной проверки (раз в час)
            elif quick:
                items = [it for it in prev if isinstance(it, dict) and isinstance(it.get("outbound"), dict)]
                if items:
                    check(conf, state, items, quick=True)
            elif links:
                items, skipped = build_items(conf, links)
                if skipped:
                    log("Пропущены: %d (%s)." % (sum(skipped.values()),
                                                 ", ".join("%s — %d" % kv for kv in skipped.most_common(3))))
                if items:
                    check(conf, state, items)
                else:
                    raise RuntimeError("в списках нет подключений, которые можно проверить")
        except RuntimeError as err:
            state["check_error"] = str(err)
            log("Проверка не прошла: %s" % err)
            rc = 1
        write_atomic(state_path, json.dumps(state, ensure_ascii=False, indent=1))
    return rc if (links or prev) else 1


if __name__ == "__main__":
    sys.exit(main())
PY
  chmod 755 "$WHITE_PY"
}
white_setup() {   # программа, настройки и таймер белых списков (сам список скачивает white_run_now)
  local py
  py="$(command -v python3)"
  write_white_program
  mkdir -p "$(dirname "$WHITE_CONF")" "$WHITE_DATA"
  WHITE_URL="$WHITE_URL" REFRESH="$WHITE_REFRESH_HOURS" LABEL="$WHITE_LABEL" DATA="$WHITE_DATA" \
  AUTO_MAX="$WHITE_AUTO_MAX" AUTO_NAME="$WHITE_AUTO_NAME" SUB_MAX="$WHITE_SUB_MAX" XDIR="${XUI_DIR}/bin" RU_EXIT="$WHITE_RU_EXIT" \
  python3 - "$WHITE_CONF" <<'PY' || return 1
import json, os, secrets, sys
e = os.environ
try:
    old = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError):
    old = {}
# Публичные списки подключений для обхода белых списков (проверены в октябре 2026: все обновляются
# каждый день или чаще). Источник — файл и его зеркала: берётся первое, которое ответило.
def gh(owner, repo, path, extra=()):             # GitHub, свои зеркала автора, затем jsDelivr
    return (["https://raw.githubusercontent.com/%s/%s/main/%s" % (owner, repo, path)] + list(extra)
            + ["https://cdn.jsdelivr.net/gh/%s/%s@main/%s" % (owner, repo, path)])
def igareck(name):
    repo = "igareck/vpn-configs-for-russia"
    return gh("igareck", "vpn-configs-for-russia", name, ["https://raw.githack.com/%s/main/%s" % (repo, name),
                                                         "https://gitlab.com/%s/-/raw/main/%s" % (repo, name),
                                                         "https://codeberg.org/%s/raw/branch/main/%s" % (repo, name)])
def zieng2(name):
    return gh("zieng2", "wl", name, ["https://codeberg.org/zieng2/wl/raw/branch/main/%s" % name,
                                     "https://gitlab.com/zieng2/wl/raw/main/%s" % name])
default = [
    igareck("Vless-Reality-White-Lists-Rus-Mobile.txt"),     # мобильные белые списки, ТОП-150
    igareck("WHITE-CIDR-RU-checked.txt"),                    # белые IP-сети, проверенные
    igareck("WHITE-CIDR-RU-all.txt"),                        # белые IP-сети, все
    igareck("WHITE-SNI-RU-all.txt"),                         # маскировка под разрешённые сайты (SNI)
    zieng2("vless_universal.txt"), zieng2("vless_lite.txt"), # zieng2: обновляется каждый час
    gh("whoahaow", "rjsxrd", "githubmirror/bypass/bypass-all.txt"),   # обход SNI/CIDR, только безопасные
    gh("VOID-Anonymity", "V.O.I.D-VPN_Bypass", "url_work.txt"),     # проверенные по IP и SNI
    gh("FLAT447", "v2ray-lists", "WHITE_FULL.txt"),
    gh("AirLinkVPN1", "AirLinkVPN", "rkn_white_list"),
    gh("Diversan313", "apex-parser", "subs/main/alive_bs.txt"),
    gh("LimeHi", "LimeVPN", "whitelist.txt"),
    gh("Maskkost93", "kizyak-vpn-4.0", "kizyakbeta6.txt"),
    gh("OceaniaVPN", "StekloVPN", "configs/whitelist.txt"),
    gh("VansFenix", "vpnparser", "white.txt"),
    gh("VansFenix", "vpnparser", "configs.txt"),
    gh("dequar", "deqwl", "deray.txt"),
    gh("flaafix", "AetrisVPN-white-list-lite", "AetrisVPN.txt"),
    gh("flaafix", "AetrisVPN", "AetrisVPN.txt"),
    gh("gooseteam-hackers", "GooseVPN", "configs/balanced.txt"),
    gh("gooseteam-hackers", "GooseVPN", "configs/plus.txt"),
    gh("vladvarp", "Prometheus", "WhiteList/vless.txt"),
    gh("MrEndi777709", "Endi-VPN", "mrendi-vpn-white-list.txt"),
    # РосКомПозор (#РКП, t.me/RKP_channel): живой список — на hub.mos.ru (сайт открывается и при белых
    # списках); точное имя группы там не проверено — пробуем оба, последней — копия с GitHub
    ["https://hub.mos.ru/rkpchannel/roskompozor/raw/main/wl", "https://hub.mos.ru/rkp_channel/roskompozor/raw/main/wl"]
    + gh("RKPchannel", "RKP_bypass_configs", "whitelist.txt"),
    # сборка all_subs: всё вышеперечисленное и ещё ~10 источников вне GitHub, обновляется каждую минуту
    gh("solovyov-jenya2004", "all_subs", "final_sorted", ["https://final-sorted.solovyov-jenya2004.workers.dev/"]),
]
urls = e["WHITE_URL"].replace(",", " ").split()
if urls and urls != ["default"]:
    sources, custom = [[u] for u in urls], True        # свои списки: каждый — отдельный источник
elif not urls and old.get("custom") and old.get("sources"):
    sources, custom = old["sources"], True             # свои списки, указанные при прошлом запуске
else:
    sources, custom = default, False
conf = {"sources": sources, "custom": custom, "refresh_hours": int(e["REFRESH"]), "label": e["LABEL"],
        "data": e["DATA"], "xray_dir": e["XDIR"],
        "test_urls": ["https://www.gstatic.com/generate_204", "https://cp.cloudflare.com/generate_204"],
        # проверка: сначала открывается ли сервер (3 с), затем настоящий запрос через подключение (8 с);
        # все — раз в час (full_check_minutes), между ними — только рабочие
        "timeout": 8, "tcp_timeout": 3, "workers": 24, "tcp_workers": 64, "batch": 150,
        "max_items": 800, "full_check_minutes": 180,
        # у каждого рабочего — вход и выход (в России или нет); выход в России: last — в конец, drop — убрать
        "ru_exit": e["RU_EXIT"],
        # в подписке — sub_max самых быстрых по пингу рабочих, в отдельной подписке — до list_max
        "sub_max": int(e["SUB_MAX"]), "list_max": max(30, int(e["SUB_MAX"])),
        # для фильтра подписки: адрес отдельной подписки (прежний), её название в приложении
        # и как часто приложению обновлять подписку (часы) — тогда нерабочие пропадают и с телефона
        "path": old.get("path") or "/" + secrets.token_hex(8) + "/",
        "title": "🏳️ Белые списки", "update_hours": 1,
        # автоподбор на устройстве по пингу: max самых быстрых серверов в одном профиле —
        # телефон пингует их все сразу при включении и каждые interval и ведёт трафик через самый
        # быстрый из живых (observatory + leastPing)
        "auto": {"max": int(e["AUTO_MAX"]), "name": e["AUTO_NAME"], "interval": "2m",
                 "url": "http://www.gstatic.com/generate_204"}}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(conf, f, indent=1)
PY
  chmod 600 "$WHITE_CONF"
  cat > "$WHITE_UNIT" <<UNIT
[Unit]
Description=VPN white lists: new lists every ${WHITE_REFRESH_HOURS}h, every connection checked, only working ones in the subscription
After=network-online.target x-ui.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${py} ${WHITE_PY} ${WHITE_CONF} auto
Nice=19
CPUQuota=40%
IOSchedulingClass=idle
TimeoutStartSec=40min
UNIT
  cat > "$WHITE_TIMER" <<UNIT
[Unit]
Description=VPN white lists: check every ${WHITE_CHECK_MIN} minutes

[Timer]
OnActiveSec=${WHITE_CHECK_MIN}min
OnUnitActiveSec=${WHITE_CHECK_MIN}min
AccuracySec=30s

[Install]
WantedBy=timers.target
UNIT
  systemctl daemon-reload >/dev/null 2>&1 || true
  if white_phone_setup; then
    grn "    Проверка с телефона: Xray для Android готов — страница проверки отдаёт его в Termux."
  else
    ylw "    Xray для Android не скачался — телефон при проверке скачает его сам с GitHub."
  fi
  return 0
}
white_phone_setup() {   # проверка с телефона: папка для отчётов и Xray для Android (arm64) той же версии, что у панели
  local dir="${WHITE_DATA}/phone" xr ver="" url tmp
  mkdir -p "$dir/reports" || return 1
  xr="$(compgen -G "${XUI_DIR}/bin/xray-linux-*" | head -n 1 || true)"
  if [ -n "$xr" ]; then ver="$("$xr" version 2>/dev/null | sed -n '1s/^Xray \([0-9][0-9.]*\).*/\1/p' || true)"; fi
  if [ -s "$dir/xray-arm64-v8a.gz" ] && { [ -z "$ver" ] || [ "$(cat "$dir/xray-version" 2>/dev/null)" = "$ver" ]; }; then
    return 0
  fi
  tmp="$(mktemp -d)" || return 1
  for url in ${ver:+"https://github.com/XTLS/Xray-core/releases/download/v${ver}/Xray-android-arm64-v8a.zip"} \
             "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-android-arm64-v8a.zip"; do
    if curl -fsSL --connect-timeout 15 --max-time 300 -o "$tmp/x.zip" "$url" 2>/dev/null \
       && python3 -c 'import gzip, os, shutil, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z, z.open("xray") as f, gzip.open(sys.argv[2] + ".tmp", "wb", 6) as g:
    shutil.copyfileobj(f, g, 1 << 20)
os.replace(sys.argv[2] + ".tmp", sys.argv[2])' "$tmp/x.zip" "$dir/xray-arm64-v8a.gz" 2>/dev/null; then
      case "$url" in */latest/*) echo "-" ;; *) echo "$ver" ;; esac > "$dir/xray-version"
      rm -rf "$tmp"
      return 0
    fi
  done
  rm -rf "$tmp"
  return 1
}
white_phone_check() {   # white_phone_check https://127.0.0.1:порт/путь/test/ — «N X»: серверов для проверки с телефона, есть ли Xray для Android (1/0)
  local base="$1" n x=0 code
  code="$(curl -sk --noproxy '*' --max-time 15 -o /dev/null -w '%{http_code}' "$base" 2>/dev/null || true)"
  [ "$code" = 200 ] || { echo "- 0"; return 0; }
  n="$(curl -sk --noproxy '*' --max-time 30 "${base}bundle" 2>/dev/null | sed -n '1s/^#B [0-9]* [^ ]* \([0-9]*\) .*/\1/p' || true)"
  if [ "$(curl -sk --noproxy '*' --max-time 15 -I -o /dev/null -w '%{http_code}' "${base}xray-arm64-v8a.gz" 2>/dev/null || true)" = 200 ]; then x=1; fi
  echo "${n:--} $x"
}
white_timer_on() {   # проверка по таймеру — каждые WHITE_CHECK_MIN минут (и после перезагрузки сервера)
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable vpn-white-lists.timer >/dev/null 2>&1 || true
  systemctl restart vpn-white-lists.timer >/dev/null 2>&1
}
WHITE_TOTAL=0; WHITE_ALIVE=0; WHITE_ERR=""
WHITE_WORKING=0; WHITE_SRC_OK=0; WHITE_SRC_ALL=0
WHITE_RU_GOOD=0; WHITE_EXIT_ABROAD=0; WHITE_RU_EXIT_N=0; WHITE_RU_NETS=0
white_state() {   # итог последней проверки → WHITE_TOTAL (подключений во всех списках), WHITE_WORKING (рабочих),
                  # WHITE_ALIVE (из них в подписке), WHITE_SRC_OK/WHITE_SRC_ALL (источников скачано/всего), WHITE_ERR,
                  # WHITE_RU_GOOD (вход в РФ, выход за рубежом), WHITE_EXIT_ABROAD (выход за рубежом, вход не в РФ),
                  # WHITE_RU_EXIT_N (выход в РФ), WHITE_RU_NETS (российских сетей в базе; 0 — вход и выход не определялись)
  local st
  st="$(python3 "$WHITE_PY" "$WHITE_CONF" status 2>/dev/null | python3 -c 'import json, sys
d = json.load(sys.stdin)
err = " ".join(str(d.get("check_error") or d.get("download_error") or "").split())
print(int(d.get("total") or 0), int(d.get("alive_now") or 0), int(d.get("in_subscription") or 0),
      int(d.get("sources_ok") or 0), int(d.get("sources_total") or 0), int(d.get("ru_good") or 0),
      int(d.get("exit_abroad") or 0), int(d.get("ru_exit") or 0), int(d.get("ru_ranges") or 0), err or "-")' 2>/dev/null \
    || echo "0 0 0 0 0 0 0 0 0 -")"
  read -r WHITE_TOTAL WHITE_WORKING WHITE_ALIVE WHITE_SRC_OK WHITE_SRC_ALL WHITE_RU_GOOD WHITE_EXIT_ABROAD \
    WHITE_RU_EXIT_N WHITE_RU_NETS WHITE_ERR <<< "$st" || true
  local v
  for v in WHITE_TOTAL WHITE_WORKING WHITE_ALIVE WHITE_SRC_OK WHITE_SRC_ALL WHITE_RU_GOOD WHITE_EXIT_ABROAD \
           WHITE_RU_EXIT_N WHITE_RU_NETS; do
    [[ "${!v}" =~ ^[0-9]+$ ]] || printf -v "$v" '%s' 0
  done
  if [ "${WHITE_ERR:--}" = "-" ]; then WHITE_ERR=""; fi
}
white_run_now() {   # скачать список сейчас и проверить каждое подключение (ход — на экран)
  local line
  while IFS= read -r line; do printf '    %s\n' "$line"; done < <(python3 "$WHITE_PY" "$WHITE_CONF" update 2>&1 || true)
  white_state
}
white_remove() {   # убрать белые списки: таймер, программу, настройки и скачанные списки
  systemctl disable --now vpn-white-lists.timer >/dev/null 2>&1 || true
  systemctl stop vpn-white-lists.service >/dev/null 2>&1 || true
  rm -f "$WHITE_TIMER" "$WHITE_UNIT" "$WHITE_PY" "$WHITE_CONF"
  rm -rf "$WHITE_DATA"
  systemctl daemon-reload >/dev/null 2>&1 || true
}
sub_filter_conf_white() {   # sub_filter_conf_white 1|0 — в настройки фильтра подписки: белые списки или без них
  WHITE="$1" WHITE_CONF="$WHITE_CONF" SUB_BASE="${SUB_BASE:-}" python3 - "$SUB_FILTER_CONF" <<'PY'
import json, os, sys
conf = json.load(open(sys.argv[1]))
conf.pop("white", None)
if os.environ["WHITE"] == "1":
    w = json.load(open(os.environ["WHITE_CONF"], encoding="utf-8"))
    conf["white"] = {"file": os.path.join(w["data"], "alive.json"), "path": w["path"],
                     "title": w.get("title") or "Белые списки", "update_hours": int(w.get("update_hours") or 1),
                     "sub_max": int(w.get("sub_max") or 15), "list_max": int(w.get("list_max") or 30),
                     "label": w.get("label") or "", "auto": w.get("auto") or {},
                     # проверка с телефона (страница …/test/): отчёты, Xray для Android; работающие у телефона
                     # за последние hours часов — первыми в подписке; max — сколько серверов проверяет телефон
                     "phone": {"dir": os.path.join(w["data"], "phone"), "hours": 48, "max": 300,
                               "base": os.environ.get("SUB_BASE", "")}}
with open(sys.argv[1], "w") as f:
    json.dump(conf, f, indent=1)
PY
}
white_path() {   # адрес отдельной подписки белых списков (путь на порту подписки)
  python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("path") or "")' "$WHITE_CONF" 2>/dev/null || true
}
white_in_sub() {   # white_in_sub https://127.0.0.1:порт/путь — «N M A»: белых списков в JSON-подписке (Happ), в обычной и серверов в автоподборе
  local url="$1" nj nb
  nj="$(curl -sk --noproxy '*' --max-time 20 -A 'Happ/3.0' "$url" 2>/dev/null | LABEL="$WHITE_LABEL" AUTO="$WHITE_AUTO_NAME" python3 -c 'import json, os, sys
d = json.load(sys.stdin)
confs = d if isinstance(d, list) else [d]
one = sum(1 for c in confs if str(c.get("remarks") or "").startswith(os.environ["LABEL"]) and c.get("remarks") != os.environ["AUTO"])
auto = next((c for c in confs if c.get("remarks") == os.environ["AUTO"]), {})
print(one, sum(1 for o in auto.get("outbounds") or [] if str(o.get("tag") or "").startswith("wl-")))' 2>/dev/null || true)"
  nb="$(curl -sk --noproxy '*' --max-time 20 -A 'Streisand/1.6' "$url" 2>/dev/null | python3 -c 'import base64, json, sys
def key(link):   # ссылка без названия: проверенные с телефона приходят с «✅» в названии
    if link.lower().startswith("vmess://"):
        body = link.split("://", 1)[1].split("#", 1)[0]
        try:
            d = json.loads(base64.b64decode(body + "=" * (-len(body) % 4)).decode("utf-8"))
            d.pop("ps", None)
            return "vmess:" + json.dumps(d, sort_keys=True)
        except ValueError:
            return link
    return link.split("#", 1)[0]
raw = "".join(sys.stdin.read().split())
text = base64.b64decode(raw + "=" * (-len(raw) % 4)).decode("utf-8", "replace")
alive = {key(x["link"]) for x in json.load(open(sys.argv[1], encoding="utf-8")).get("items") or []}
print(sum(1 for line in text.splitlines() if line.strip() and key(line.strip()) in alive))' "${WHITE_DATA}/alive.json" 2>/dev/null || true)"
  read -r nj na <<< "${nj:-0 0}" || true
  echo "${nj:-0} ${nb:-0} ${na:-0}"
}
white_summary() {   # итог для экрана и для файла с доступами
  local src="публичные списки для обхода белых списков: igareck (мобильный, CIDR, SNI), zieng2, rjsxrd, V.O.I.D, FLAT447, РосКомПозор, all_subs и другие"
  if python3 -c 'import json, sys; sys.exit(0 if json.load(open(sys.argv[1], encoding="utf-8")).get("custom") else 1)' "$WHITE_CONF" 2>/dev/null; then
    src="свои списки (WHITE_URL)"
  fi
  if [ "$WHITE_SRC_ALL" -gt 0 ]; then src="${src} — скачано ${WHITE_SRC_OK} из ${WHITE_SRC_ALL}"; fi
  echo "Источники: ${src}."
  echo "Новые списки — каждые ${WHITE_REFRESH_HOURS} ч; каждое подключение проверяется настоящим запросом: все — раз в час,"
  echo "рабочие — каждые ${WHITE_CHECK_MIN} мин. Нерабочее пропадает из подписки сразу после проверки (приложение обновляет её раз в час)."
  echo "Сейчас: подключений во всех списках — ${WHITE_TOTAL}, рабочих — ${WHITE_WORKING}; в подписке — ${WHITE_ALIVE} лучших${WHITE_ERR:+ (последняя проверка: ${WHITE_ERR})}."
  if [ "$WHITE_RU_NETS" -gt 0 ]; then
    echo "Вход и выход рабочих: вход в РФ, выход за рубежом («… · РФ→🌍», в подписке первыми) — ${WHITE_RU_GOOD};"
    echo "выход за рубежом — ${WHITE_EXIT_ABROAD}; выход в РФ («… · выход РФ», заблокированные сайты через них не откроются) — ${WHITE_RU_EXIT_N}$([ "$WHITE_RU_EXIT" = "drop" ] && echo ", убраны из подписки (WHITE_RU_EXIT=drop)" || echo ", в конце списка, не в автоподборе")."
  fi
  if [ "$WHITE_AUTO_MAX" -gt 1 ]; then
    echo "Автоподбор для каждого устройства — профиль «${WHITE_AUTO_NAME}» (Happ, v2rayNG, v2rayN): в нём ${WHITE_AUTO_MAX} самых"
    echo "быстрых по пингу; при включении телефон сразу пингует их все из своей сети, потом каждые 2 минуты, и ведёт"
    echo "трафик через самый быстрый из работающих у него; перестал отвечать — переходит на другой."
  fi
  if [ -n "${WHITE_URL_SUB:-}" ]; then
    echo "Отдельная подписка — только белые списки: ${WHITE_URL_SUB}"
    echo "Проверка с телефона (Android) — какие из них работают именно в вашей мобильной сети:"
    echo "  ${WHITE_URL_SUB}test/"
    echo "  Откройте на телефоне и выполните команду оттуда в Termux; работающие у вас серверы встанут"
    echo "  в подписке первыми (с ✅) и попадут в автоподбор."
  fi
  echo "Проверить сейчас: systemctl start vpn-white-lists   Журнал: journalctl -u vpn-white-lists -e"
}

# ---------- профиль Mihomo (Clash Meta): Tunnel, FlClash, Clash Meta и Verge ----------
# Профиль отдаёт сама панель (подписка Clash/Mihomo), фильтр подписки дописывает в него автовыбор,
# белые списки и автопереключение. Правила — без geo-баз: телефон при белых списках не скачал бы их,
# и Mihomo отверг бы весь профиль. Российские сайты узнаются по домену.
CLASH_DIRECT_DOMAINS="ru su xn--p1ai xn--p1acf xn--80adxhks xn--d1acj3b yandex.net yandex.com yastatic.net
yandexcloud.net yandex.cloud vk.com vk.me vk.cc userapi.com vkuser.net vkuseraudio.net vkuservideo.net vk-cdn.net
vk-portal.net mycdn.me mradx.net wbstatic.net ozonusercontent.com avito.st 2gis.com sberbank.com"
clash_rules_yaml() {   # правила профиля Mihomo: локальные сети и российские сайты — напрямую, остальное — VPN
  local c
  echo "rules:"
  for c in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8 100.64.0.0/10 169.254.0.0/16; do
    echo "  - IP-CIDR,${c},DIRECT,no-resolve"
  done
  echo "  - IP-CIDR6,fc00::/7,DIRECT,no-resolve"
  echo "  - IP-CIDR6,fe80::/10,DIRECT,no-resolve"
  for c in $CLASH_DIRECT_DOMAINS; do echo "  - DOMAIN-SUFFIX,${c},DIRECT"; done
  echo "  - MATCH,PROXY"
}
clash_db_update() {   # clash_db_update 1|0 (фильтр подписки) — профиль Mihomo в настройках панели → «изменилось(0|1) путь»
  DB="$DB" MIHOMO="$MIHOMO" FILTER="$1" SUB_BASE="${SUB_BASE:-}" RULES="$(clash_rules_yaml)" python3 - <<'PY'
import os, secrets, sqlite3
e = os.environ
con = sqlite3.connect(e["DB"], timeout=30)
cur = con.cursor()
def get(key):
    row = cur.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
    return (row[0] or "").strip() if row else ""
def norm(path):
    path = path.strip().strip("/")
    return "/" + path + "/" if path else ""
path = norm(get("subClashPath"))
if not path or path in (norm(get("subPath")), norm(get("subJsonPath"))):
    path = "/" + secrets.token_hex(6) + "/"
want = {"subClashEnable": "true" if e["MIHOMO"] == "1" else "false"}
if e["MIHOMO"] == "1":
    want.update({"subClashPath": path,
                 # приложения на Mihomo получают профиль и по обычной ссылке подписки
                 "subClashAutoDetect": "true", "subClashUserAgentRegex": r"(?i)(clash|mihomo|tunnel)",
                 "subClashEnableRouting": "true", "subClashRules": e["RULES"].strip()})
    if e["FILTER"] == "1" and e["SUB_BASE"]:
        want["subClashURI"] = e["SUB_BASE"] + path      # ссылки в панели — на внешний адрес фильтра
    elif get("subClashURI").rstrip("/").endswith(path.rstrip("/")):
        want["subClashURI"] = ""
changed = 0
for key, value in want.items():
    if get(key) == value.strip():
        continue
    changed = 1
    cur.execute("UPDATE settings SET value=? WHERE key=?", (value, key))
    if cur.rowcount == 0:
        cur.execute("INSERT INTO settings (key, value) VALUES (?, ?)", (key, value))
con.commit()
con.close()
print(changed, path)
PY
}
sub_filter_conf_clash() {   # sub_filter_conf_clash 1|0 — фильтр дописывает в профиль Mihomo автовыбор, белые списки и автопереключение
  CLASH="$1" AUTO_NAME="$AUTO_LABEL" python3 - "$SUB_FILTER_CONF" <<'PY'
import json, os, sys
conf = json.load(open(sys.argv[1], encoding="utf-8"))
conf.pop("clash", None)
if os.environ["CLASH"] == "1":
    conf["clash"] = {"auto_name": os.environ["AUTO_NAME"], "fallback_name": "🔀 Автопереключение"}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(conf, f, indent=1)
PY
}
mihomo_check() {   # mihomo_check URL — «подключений белых-списков автопереключение(1|0)» в профиле Mihomo; «- - -» — профиля нет
  curl -sk --noproxy '*' --max-time 20 -A 'clash.meta' "$1" 2>/dev/null | LABEL="$WHITE_LABEL" python3 -c 'import os, sys
try:
    import yaml
    d = yaml.safe_load(sys.stdin.read())
    names = [str(p.get("name") or "") for p in d.get("proxies") or []]
    fb = any(g.get("type") == "fallback" for g in d.get("proxy-groups") or [])
    print(len(names), sum(1 for n in names if n.startswith(os.environ["LABEL"])), int(fb))
except Exception:
    print("- - -")' 2>/dev/null || echo "- - -"
}
urlencode() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }
tunnel_link() {   # tunnel_link URL-профиля — «Открыть в Tunnel» (Tunnel убирает x-tunnel-torrent, на сервер он не уходит)
  printf 'tunnel://install-config?url=%s' "$(urlencode "${1}?x-tunnel-torrent=${TUNNEL_TORRENT}")"
}
ensure_yaml() {   # python3-yaml — фильтру для профиля Mihomo (без него профиль уходит без белых списков)
  python3 -c 'import yaml' >/dev/null 2>&1 && return 0
  DEBIAN_FRONTEND=noninteractive apt_retry install -y python3-yaml >/dev/null 2>&1 || true
  python3 -c 'import yaml' >/dev/null 2>&1
}
mihomo_text() {   # для экрана и файла с доступами
  echo "Tunnel (Android) — одна ссылка, откройте её на телефоне («Открыть в Tunnel»):"
  echo "  ${TUNNEL_URL}"
  echo "  Придёт полный профиль Mihomo: «🔀 Автопереключение» (свой VPN, а когда он не отвечает — белые"
  echo "  списки), «${AUTO_LABEL}», каждое подключение и белые списки; российские сайты — напрямую."
  case "$TUNNEL_TORRENT" in
    0) echo "  Торренты идут мимо VPN (TUNNEL_TORRENT=1 — через разрешённые серверы, 2 — через любой)." ;;
    1) echo "  Торренты — только через серверы с пометкой torrent/p2p в названии (TUNNEL_TORRENT=1)." ;;
    2) echo "  Торренты разрешены через любой сервер (TUNNEL_TORRENT=2)." ;;
  esac
  echo "Профиль Mihomo (Clash Meta) — для Tunnel, FlClash, Clash Meta и Clash Verge:"
  echo "  ${CLASH_URL}"
}

# ---------- FreeTurn: VPN через звонки VK (github.com/hackdiaz-dev/turn-proxy-android) ----------
# Сервер ставит официальный установщик free-turn-proxy в режиме без вопросов (тот же, которым
# пользуется приложение): FreeTurn (systemd) + WireGuard ft-wg0, клиент owner и ссылка freeturn://.
FT_SCRIPT_URL="${FT_SCRIPT_URL:-https://raw.githubusercontent.com/hackdiaz-dev/free-turn-proxy/master/scripts/install.sh}"
FT_DIR="/opt/free-turn-proxy"
FT_APK="https://github.com/hackdiaz-dev/turn-proxy-android/releases/latest"
FT_LINK=""; FT_ERR=""
freeturn_fetch() {   # установщик FreeTurn → $WORK/ft-install.sh
  curl -fsSL --retry 3 --connect-timeout 15 --max-time 120 -o "$WORK/ft-install.sh" "$FT_SCRIPT_URL" 2>/dev/null \
    && grep -q 'PROTO_VERSION' "$WORK/ft-install.sh"
}
freeturn_rpc() {   # freeturn_rpc команда [--ключ=значение…] — ответ установщика FreeTurn (JSON, последняя строка)
  bash "$WORK/ft-install.sh" "$@" 2>>"$WORK/ft.log" </dev/null | grep '^{' | tail -n 1 || true
}
freeturn_setup() {   # freeturn_setup [IP] — поставить или обновить FreeTurn с WireGuard → FT_LINK (не вышло — FT_ERR)
  local js host=()
  FT_LINK=""; FT_ERR=""
  if [ -n "${1:-}" ]; then host=(--host="$1"); fi   # без IP установщик узнает его сам
  if ! freeturn_fetch; then FT_ERR="не удалось скачать установщик FreeTurn (${FT_SCRIPT_URL})"; return 1; fi
  js="$(freeturn_rpc apply --method=systemd --backend=new --listen-port="$FREETURN_PORT" --mode=udp \
        --obf-profile=rtpopus3 "${host[@]}")"
  read -r FT_LINK FT_ERR < <(CALL="$FREETURN_CALL" python3 -c 'import base64, json, os, sys
try:
    d = json.loads(sys.argv[1] or "{}")
except ValueError:
    print("- установщик FreeTurn ответил непонятно"); raise SystemExit
if d.get("result") != "ok":
    print("-", " ".join(str(d.get("msg") or d.get("code") or "ошибка установки").split())[:200]); raise SystemExit
link = str(((d.get("data") or {}).get("owner") or {}).get("link") or "")
if not link.startswith("freeturn://"):
    print("- в ответе установщика нет ссылки"); raise SystemExit
call = os.environ.get("CALL") or ""
if call:   # ссылка на звонок — прямо в ссылку для приложения (поле vk, как у самого приложения)
    raw = link[len("freeturn://"):]
    j = json.loads(base64.urlsafe_b64decode(raw + "=" * (-len(raw) % 4)))
    j["vk"] = call
    link = "freeturn://" + base64.urlsafe_b64encode(json.dumps(j, ensure_ascii=False, separators=(",", ":"))
                                                    .encode("utf-8")).decode("ascii").rstrip("=")
print(link, "-")' "$js" 2>/dev/null || echo "- не удалось разобрать ответ установщика FreeTurn")
  if [ "${FT_LINK:--}" = "-" ]; then FT_LINK=""; fi
  if [ "${FT_ERR:--}" = "-" ]; then FT_ERR=""; fi
  [ -n "$FT_LINK" ]
}
freeturn_remove() {   # FREETURN=0: снести FreeTurn и его WireGuard (чужой WireGuard установщик не трогает)
  [ -f "$FT_DIR/install.conf" ] || return 1
  freeturn_fetch || return 1
  freeturn_rpc uninstall --target=all --purge >/dev/null
  return 0
}
freeturn_exit_links() {   # freeturn_exit_links файл — «название|ссылка» FreeTurn выходов моста; «!название|причина» — где не встал
  python3 -c 'import json, sys
text = open(sys.argv[1], encoding="utf-8").read()
try:
    d = json.loads(text)
    rows = d.get("exits", []) if isinstance(d, dict) else []
except ValueError:                        # exits.jsonl — по подключению в строке
    rows = []
    for line in text.splitlines():
        try:
            rows.append(json.loads(line))
        except ValueError:
            pass
for p in rows:
    if not isinstance(p, dict):
        continue
    if str(p.get("freeturn") or "").startswith("freeturn://"):
        print("%s|%s|%s" % (p.get("cc") or "-", p.get("host") or "", p["freeturn"]))
    elif p.get("freeturn_err"):
        print("!%s|%s|%s" % (p.get("cc") or "-", p.get("host") or "", " ".join(str(p["freeturn_err"]).split())))' "$1" 2>/dev/null \
  | while IFS='|' read -r cc host rest; do
      mark=""; case "$cc" in !*) mark="!"; cc="${cc#!}" ;; esac
      if [ "$cc" != "-" ]; then printf '%s%s %s|%s\n' "$mark" "$(cc_title "$cc")" "$host" "$rest"
      else printf '%s%s|%s\n' "$mark" "$host" "$rest"; fi
    done
}
freeturn_text() {   # freeturn_text «название|ссылка» … — как подключиться (для экрана и файла с доступами)
  local l t
  echo "1) Установите приложение FreeTurn (Android 7+): ${FT_APK}"
  if [ "$#" -gt 1 ]; then
    echo "2) В приложении «+» → вставьте ссылку; у каждого сервера своя (в них ключи — никому не пересылайте):"
  else
    echo "2) В приложении «+» → вставьте ссылку (в ней ключи — никому не пересылайте):"
  fi
  for l in "$@"; do t="${l%%|*}"; echo "   ${t:+${t}: }${l#*|}"; done
  if [ -z "$FREETURN_CALL" ]; then
    echo "3) Создайте звонок в VK (Звонки → «Создать звонок»), скопируйте ссылку https://vk.ru/call/join/…"
    echo "   и вставьте её в приложение. Звонок не завершайте: через него идёт трафик."
  else
    echo "3) Ссылка на звонок VK уже в ней (FREETURN_CALL). Звонок не завершайте: через него идёт трафик."
  fi
  echo "4) Подключитесь: трафик идёт через серверы звонков VK — их не блокируют и при белых списках."
}

# ---------- режим: один сервер или мост (этот сервер в России → зарубежные серверы) ----------
BRIDGE=0
BRIDGE_FILE="/etc/x-ui/vpn-bridge.json"   # параметры зарубежных выходов — для повторных запусков
SAVED_EXITS="$(sed -n 's/.*"host": *"\([^"]*\)".*/\1/p' "$BRIDGE_FILE" 2>/dev/null | tr '\n' ' ' | sed 's/ *$//' || true)"
EXIT_USER_ALL="$EXIT_USER"; EXIT_PASS_ALL="$EXIT_PASS"   # общие логин и пароль — для выходов, где они не указаны
if [ "$VPN_ROLE" = "exit" ]; then
  EXIT_HOST=""
else
  case "$(printf '%s' "$EXIT_HOST" | tr '[:upper:]' '[:lower:]')" in
    none|off|no|0) EXIT_HOST="" ;;
    "")
      if [ "$WHITE_LISTS" = "only" ]; then
        EXIT_HOST="$SAVED_EXITS"   # только белые списки: мост (если он есть) остаётся как был
      elif [ "$HAS_TTY" = "1" ]; then
        DEF=1; [ -n "$SAVED_EXITS" ] && DEF=2
        {
          echo
          echo "Как будет работать этот сервер?"
          echo "  1) Один сервер — телефоны подключаются к нему, и он сам выпускает в интернет"
          echo "  2) Мост — этот сервер в России принимает телефоны, а зарубежные сайты открывает"
          echo "     через зарубежные серверы: один или несколько, сам выбирает лучший по пингу"
          echo "     (настроит их сам по SSH)"
          echo "  3) Белые списки для мобильного интернета — добавить в подписку готовые подключения,"
          echo "     которые работают, когда оператор пускает только на «разрешённые» сайты."
          echo "     Список обновляется каждые ${WHITE_REFRESH_HOURS} ч, каждое подключение проверяется, нерабочие"
          if [ -x "$XUI_BIN" ] && [ -f "$DB" ]; then
            echo "     сразу убираются. VPN, ключи и пароль панели не меняются$([ -f "$WHITE_CONF" ] && echo " (сейчас включены — обновятся)")"
          else
            echo "     сразу убираются. VPN здесь ещё не установлен — сначала установится, как в пункте 1"
          fi
        } > /dev/tty
        tty_read CHOICE "Ваш выбор [${DEF}]: "
        CHOICE="${CHOICE// /}"
        case "${CHOICE:-$DEF}" in
          1) ;;
          2) tty_read EXIT_HOST "IP зарубежных серверов через пробел${SAVED_EXITS:+ [${SAVED_EXITS}]}: "
             [ -n "${EXIT_HOST// /}" ] || EXIT_HOST="$SAVED_EXITS"
             [ -n "${EXIT_HOST// /}" ] || die "IP зарубежного сервера не указан." ;;
          3) WHITE_LISTS=only; EXIT_HOST="$SAVED_EXITS" ;;
          *) die "Нужно ввести 1, 2 или 3." ;;
        esac
      else
        EXIT_HOST="$SAVED_EXITS"   # без клавиатуры — как при прошлой установке
      fi ;;
  esac
fi
# Выходы: «IP», «логин@IP» или «логин:пароль@IP», через пробел или запятую.
EXIT_HOSTS=(); EXIT_USERS=(); EXIT_PASSES=()
if [ -n "${EXIT_HOST// /}" ]; then
  BRIDGE=1
  read -ra EXIT_ENTRIES <<< "${EXIT_HOST//,/ }"
  for entry in "${EXIT_ENTRIES[@]}"; do
    creds=""; host="$entry"; u=""; pw=""
    if [[ "$entry" == *@* ]]; then creds="${entry%@*}"; host="${entry##*@}"; fi
    if [ -n "$creds" ]; then
      if [[ "$creds" == *:* ]]; then u="${creds%%:*}"; pw="${creds#*:}"; else u="$creds"; fi
    fi
    is_ipv4 "$host" || [[ "$host" =~ ^([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,}$ ]] \
      || die "IP зарубежного сервера указан неверно: ${host}"
    if [ -n "$u" ] && ! [[ "$u" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]; then die "Логин указан неверно: ${u}"; fi
    if [[ " ${EXIT_HOSTS[*]} " == *" ${host} "* ]]; then continue; fi   # повтор — пропускаем
    EXIT_HOSTS+=("$host"); EXIT_USERS+=("$u"); EXIT_PASSES+=("$pw")
  done
  [ "${#EXIT_HOSTS[@]}" -gt 0 ] || BRIDGE=0
fi
EXIT_TEXT="${EXIT_HOSTS[*]:-}"
if [ "${#EXIT_HOSTS[@]}" -gt 1 ]; then EXIT_TEXT="зарубежные серверы (${#EXIT_HOSTS[@]} шт.)"; fi

# Белые списки: only — только они (VPN уже установлен), 1 — вместе с установкой, 0 — убрать,
# пусто — как при прошлом запуске.
WHITE_ONLY=0
if [ "$VPN_ROLE" = "exit" ]; then
  WHITE_LISTS=0                       # выход моста подписку не отдаёт
elif [ "$WHITE_LISTS" = "only" ]; then
  if [ -x "$XUI_BIN" ] && [ -f "$DB" ]; then
    # у выхода моста панель слушает только 127.0.0.1 — телефоны к нему не подключаются
    if [ "$(DB="$DB" python3 -c 'import os, sqlite3
row = sqlite3.connect(os.environ["DB"], timeout=30).execute("SELECT value FROM settings WHERE key=?", ("webListen",)).fetchone()
print((row[0] or "").strip() if row else "")' 2>/dev/null || true)" = "127.0.0.1" ]; then
      die "Это зарубежный сервер моста (выход). Белые списки ставятся на российский сервер, к которому подключаются телефоны: запустите скрипт там и выберите пункт 3."
    fi
    WHITE_ONLY=1
  else
    ylw "VPN на этом сервере ещё не установлен — сначала установлю его (как в пункте 1), затем белые списки."
  fi
  WHITE_LISTS=1
fi
WHITE_ON=0; WHITE_READY=0            # WHITE_READY — программа и настройки белых списков на месте
if [ "$WHITE_LISTS" = "1" ] || { [ -z "$WHITE_LISTS" ] && [ -f "$WHITE_CONF" ]; }; then WHITE_ON=1; fi

if [ "$VPN_ROLE" = "exit" ]; then TOTAL=7; elif [ "$BRIDGE" = "1" ]; then TOTAL=$((11 + EXIT_DIRECT)); else TOTAL=10; fi
TOTAL=$((TOTAL + WHITE_ON))
if [ "$FREETURN" = "1" ] && [ "$BRIDGE" != "1" ]; then TOTAL=$((TOTAL + 1)); fi   # FreeTurn (при мосте — на выходах)
STEP=0
step() { STEP=$((STEP + 1)); grn "[${STEP}/${TOTAL}] $*"; }

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
# ТОЛЬКО БЕЛЫЕ СПИСКИ (пункт 3 меню или WHITE_LISTS=only): VPN уже установлен — ставим загрузку
# и проверку списка и добавляем рабочие подключения в подписку. Панель, ключи VPN, ссылку-подписку
# и пароль панели не трогаем.
if [ "$WHITE_ONLY" = "1" ] && ! { [ -f "$SUB_FILTER_UNIT" ] && [ -s "$SUB_FILTER_CONF" ]; }; then
  ylw "Подписку на этом сервере отдаёт сама панель, без фильтра подписки — белые списки добавлю"
  ylw "полной настройкой: ключи VPN и ссылка-подписка сохранятся, у панели будет новый пароль."
  WHITE_ONLY=0
fi
if [ "$WHITE_ONLY" = "1" ]; then
  TOTAL=3
  if [ "$FREETURN" = "1" ] && [ -z "$SAVED_EXITS" ]; then TOTAL=4; fi   # FreeTurn (при мосте он на зарубежных серверах)
  step "Ставлю загрузку и проверку белых списков..."
  for b in python3 curl; do
    command -v "$b" >/dev/null 2>&1 || die "Не найден ${b}: запустите скрипт и выберите пункт 1 или 2 (полная настройка)."
  done
  compgen -G "${XUI_DIR}/bin/xray-linux-*" >/dev/null || die "Не найден Xray панели в ${XUI_DIR}/bin — проверять подключения нечем."
  white_setup || die "Не удалось записать настройки белых списков."
  grn "    Новые списки — каждые ${WHITE_REFRESH_HOURS} ч; проверка: все подключения — раз в час, рабочие — каждые ${WHITE_CHECK_MIN} мин."
  step "Скачиваю списки и проверяю каждое подключение (несколько минут)..."
  white_run_now
  white_timer_on || ylw "    Таймер проверки не запустился: systemctl status vpn-white-lists.timer"
  step "Добавляю белые списки в подписку..."
  write_sub_filter_program
  # ссылка-подписка — из файла с доступами, адрес сервера подписки — из настроек панели
  SUB_URL="$(sed -n 's/^Ссылка: *//p' "$PROFILE" 2>/dev/null | head -n 1 || true)"
  SUB_BASE="$(DB="$DB" python3 -c 'import os, re, sqlite3
row = sqlite3.connect(os.environ["DB"], timeout=30).execute("SELECT value FROM settings WHERE key=?", ("subURI",)).fetchone()
m = re.match(r"(https?://[^/]+)", (row[0] or "") if row else "")
print(m.group(1) if m else "")' 2>/dev/null || true)"
  if [ -z "$SUB_BASE" ]; then SUB_BASE="$(printf '%s' "$SUB_URL" | sed -nE 's#^(https?://[^/]+).*#\1#p')"; fi
  # профиль Mihomo (Tunnel, FlClash): подписку Clash/Mihomo отдаёт панель, фильтр дописывает белые списки
  if [ "$MIHOMO" = "1" ] && ! ensure_yaml; then ylw "    Нет python3-yaml — профиль Mihomo будет без белых списков."; fi
  read -r CLASH_CHANGED CLASH_PATH < <(clash_db_update 1 2>/dev/null || echo "0 -")
  sub_filter_conf_white 1 || die "Не удалось записать настройки фильтра подписки."
  sub_filter_conf_clash "$MIHOMO" || die "Не удалось записать настройки фильтра подписки."
  systemctl restart vpn-sub-filter >/dev/null 2>&1 || die "Фильтр подписки не перезапустился. Логи: journalctl -u vpn-sub-filter -e"
  if [ "${CLASH_CHANGED:-0}" = "1" ]; then   # новые настройки подписки панель берёт при запуске
    if [ "$MIHOMO" = "1" ]; then grn "    Профиль Mihomo для Tunnel включён в панели (панель перезапускается — пара секунд)."; fi
    systemctl restart x-ui >/dev/null 2>&1 || ylw "    Панель не перезапустилась: systemctl status x-ui"
  fi
  read -r F_PORT F_SCHEME < <(python3 -c 'import json, sys
c = json.load(open(sys.argv[1]))
print(int(c["port"]), "https" if c.get("cert") else "http")' "$SUB_FILTER_CONF" 2>/dev/null || echo "$SUB_PORT http")
  for _ in $(seq 1 20); do
    code="$(curl -sk --noproxy '*' --max-time 5 -o /dev/null -w '%{http_code}' "${F_SCHEME}://127.0.0.1:${F_PORT}/" 2>/dev/null || true)"
    case "$code" in ""|000|502) sleep 1 ;; *) break ;; esac
  done
  WHITE_URL_SUB=""; WP="$(white_path)"
  if [ -n "$SUB_BASE" ] && [ -n "$WP" ]; then WHITE_URL_SUB="${SUB_BASE}${WP}"; fi
  NJ=0; NB=0; NA=0
  if [ -n "$SUB_URL" ]; then
    read -r NJ NB NA <<< "$(white_in_sub "${F_SCHEME}://127.0.0.1:${F_PORT}/${SUB_URL#*://*/}")" || true
  fi
  if [ "${NJ:-0}" -gt 0 ] || [ "${NB:-0}" -gt 0 ]; then
    grn "    ✓ В подписке рабочих подключений: ${NJ} — для Happ / v2rayNG / v2rayN, ${NB} — для остальных приложений."
    if [ "${NA:-0}" -gt 0 ]; then grn "    ✓ Автоподбор: профиль «${WHITE_AUTO_NAME}» — телефон сам выбирает лучший (серверов в профиле: ${NA})."; fi
  elif [ "$WHITE_ALIVE" -gt 0 ] && [ -n "$SUB_URL" ]; then
    ylw "    ✗ Рабочие подключения есть (${WHITE_ALIVE}), но в ответе подписки их не видно. Логи: journalctl -u vpn-sub-filter -e"
  elif [ "$WHITE_ALIVE" -eq 0 ]; then
    ylw "    Рабочих подключений пока нет — появятся в подписке после следующей полной проверки (раз в час)."
  fi
  if [ -n "$WP" ]; then
    read -r PN PX <<< "$(white_phone_check "${F_SCHEME}://127.0.0.1:${F_PORT}${WP}test/")" || true
    if [ "${PN:--}" != "-" ]; then
      grn "    ✓ Проверка с телефона: страница работает (серверов для проверки: ${PN}$([ "${PX:-0}" = 1 ] && echo ", Xray для Android — на сервере"))."
    else
      ylw "    ✗ Страница проверки с телефона не отвечает. Логи: journalctl -u vpn-sub-filter -e"
    fi
  fi
  SUB_ID="${SUB_URL##*/}"; CLASH_URL=""; TUNNEL_URL=""
  if [ "$MIHOMO" = "1" ] && [ "${CLASH_PATH:--}" != "-" ] && [ -n "$SUB_BASE" ] && [ -n "$SUB_ID" ]; then
    read -r MP MW MF <<< "$(mihomo_check "${F_SCHEME}://127.0.0.1:${F_PORT}${CLASH_PATH}${SUB_ID}")" || true
    if [ "${MP:--}" != "-" ] && [ "${MP:-0}" -gt 0 ]; then
      CLASH_URL="${SUB_BASE}${CLASH_PATH}${SUB_ID}"; TUNNEL_URL="$(tunnel_link "$CLASH_URL")"
      grn "    ✓ Tunnel / Mihomo: профиль (подключений: ${MP}$([ "${MW:-0}" -gt 0 ] && echo ", из них белых списков: ${MW}")$([ "${MF:-0}" = 1 ] && echo ", автопереключение VPN → белые списки"))."
    else
      ylw "    ✗ Профиль Mihomo не отвечает. Логи: journalctl -u x-ui -e"
    fi
  fi
  # FreeTurn — VPN через звонки VK: на одиночном сервере — здесь; при мосте — на зарубежных серверах
  FT_LINKS=()
  if [ -n "$SAVED_EXITS" ]; then
    if [ "$FREETURN" = "1" ] && [ -f "$BRIDGE_FILE" ]; then
      while IFS= read -r ft_line; do
        case "$ft_line" in !*) ;; *) FT_LINKS+=("$ft_line") ;; esac
      done < <(freeturn_exit_links "$BRIDGE_FILE")
    fi
  elif [ "$FREETURN" = "1" ]; then
    step "FreeTurn — VPN через звонки VK (работает и при белых списках): ставлю сервер..."
    if freeturn_setup ""; then
      FT_LINKS+=("|${FT_LINK}")
      grn "    FreeTurn работает: UDP-порт ${FREETURN_PORT}, WireGuard внутри сервера. Ссылка для приложения — ниже."
    else
      ylw "    FreeTurn не установился: ${FT_ERR:-причина неизвестна}."
      tail -n 3 "$WORK/ft.log" 2>/dev/null | sed 's/^/    │ /' || true
    fi
  elif freeturn_remove; then
    grn "    FreeTurn убран (FREETURN=0)."
  fi
  echo
  ylw "============ БЕЛЫЕ СПИСКИ ДЛЯ МОБИЛЬНОГО ИНТЕРНЕТА ============"
  white_summary
  echo
  echo "Они уже в вашей подписке — в приложении достаточно обновить её${SUB_URL:+:}"
  if [ -n "$SUB_URL" ]; then grn "${SUB_URL}"; fi
  echo "В приложении они в конце списка: «${WHITE_LABEL} …». Включайте их, когда мобильный интернет"
  echo "пускает только на «разрешённые» сайты и свой VPN не подключается."
  if [ "${NA:-0}" -gt 0 ]; then
    echo "Проще всего выбрать «${WHITE_AUTO_NAME}» (Happ, v2rayNG, v2rayN): телефон сам пингует самые быстрые"
    echo "серверы (в профиле: ${NA}) и ведёт трафик через самый быстрый из тех, что работают именно у него."
  fi
  if [ -n "$WHITE_URL_SUB" ]; then
    echo "Отдельной подпиской (только белые списки — если удобнее держать их отдельной группой):"
    echo "  ${WHITE_URL_SUB}"
  fi
  if [ -n "$TUNNEL_URL" ]; then
    echo
    ylw "================ TUNNEL И ДРУГИЕ ПРИЛОЖЕНИЯ НА MIHOMO ================"
    mihomo_text
  fi
  if [ "${#FT_LINKS[@]}" -gt 0 ]; then
    if [ -n "$SAVED_EXITS" ]; then FT_WHERE="на зарубежных серверах моста"; else FT_WHERE="на этом сервере"; fi
    echo
    ylw "======== FREETURN — VPN ЧЕРЕЗ ЗВОНКИ VK (работает и при белых списках) ========"
    freeturn_text "${FT_LINKS[@]}"
    echo "Сервер FreeTurn — ${FT_WHERE}; там же управление: freeturn (ещё клиент: freeturn client add имя)."
  elif [ "$FREETURN" = "1" ] && [ -n "$SAVED_EXITS" ]; then
    echo
    ylw "FreeTurn (VPN через звонки VK) при мосте ставится на зарубежные серверы — запустите полную"
    ylw "настройку моста (команда с EXIT_HOST=…), и ссылки для приложения FreeTurn появятся в итоге."
  fi
  if [ -f "$PROFILE" ]; then   # в файле с доступами разделы про белые списки, Tunnel и FreeTurn — заново
    python3 - "$PROFILE" <<'PY' || true
import sys
text = open(sys.argv[1], encoding="utf-8").read()
for head in ("=== Белые списки", "=== Tunnel", "=== FreeTurn"):
    start = text.find(head)
    if start >= 0:
        end = text.find("\n=== ", start)
        text = text[:start] + (text[end + 1:] if end >= 0 else "")
open(sys.argv[1], "w", encoding="utf-8").write(text.rstrip("\n") + "\n")
PY
    { echo; echo "=== Белые списки для мобильного интернета ==="; white_summary
      if [ -n "$TUNNEL_URL" ]; then echo; echo "=== Tunnel и приложения на Mihomo (Clash Meta) ==="; mihomo_text; fi
      if [ "${#FT_LINKS[@]}" -gt 0 ]; then
        echo; echo "=== FreeTurn — VPN через звонки VK ==="; freeturn_text "${FT_LINKS[@]}"
        echo "Сервер FreeTurn — ${FT_WHERE}; там же управление: freeturn (ещё клиент: freeturn client add имя)."
      fi; } >> "$PROFILE"
    chmod 600 "$PROFILE"
    echo
    ylw "Всё сохранено на сервере: ${PROFILE}"
  fi
  exit 0
fi

# ============================================================================
step "Устанавливаю зависимости и ускоряю сеть..."
export DEBIAN_FRONTEND=noninteractive
PKGS=(curl openssl qrencode python3 python3-yaml socat cron ca-certificates kmod)
if [ "$BRIDGE" = "1" ]; then PKGS+=(openssh-client sshpass); fi
apt_retry update -y || die "Не удалось обновить список пакетов (apt-get update)."
apt_retry install -y "${PKGS[@]}" || die "Не удалось установить пакеты: ${PKGS[*]}"
tune_network

# ============================================================================
step "Определяю IP сервера..."
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
MODE="$DOMAIN"
if [ "$VPN_ROLE" = "exit" ]; then MODE=ip; fi   # зарубежному выходу моста домен не нужен
if [ -z "$MODE" ] && [ "$HAS_TTY" = "1" ]; then
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
sni_check() {   # sni_check домен — открывается ли он с этого сервера по TLS 1.3 (иначе Reality не работает)
  curl -s -o /dev/null --tlsv1.3 --connect-timeout 5 --max-time 8 "https://$1/" 2>/dev/null
}
SNI_NOW="${SNI_USER:-$(python3 -c 'import json, sqlite3, sys
for (s,) in sqlite3.connect(sys.argv[1], timeout=30).execute("SELECT stream_settings FROM inbounds WHERE port=?", (int(sys.argv[2]),)):
    n = ((json.loads(s or "{}").get("realitySettings") or {}).get("serverNames") or [""])[0]
    if n: print(n); break' "$DB" "$VPN_PORT" 2>/dev/null || true)}"
SNI_NOW="${SNI_NOW:-$SNI}"
if sni_check "$SNI_NOW"; then
  grn "    Маскировка Reality ${SNI_NOW}: открывается с сервера."
else
  ylw "    ✗ Маскировка Reality ${SNI_NOW} не открывается с этого сервера по TLS 1.3 — подключения Reality"
  ylw "      (XHTTP, Reality, «через РФ») работать не будут. Подходящие отсюда домены:"
  for d in www.apple.com dl.google.com www.samsung.com www.nvidia.com ya.ru www.ozon.ru www.wildberries.ru; do
    if [ "$d" != "$SNI_NOW" ] && sni_check "$d"; then ylw "        $d"; fi
  done
  ylw "      Запустите скрипт ещё раз с SNI=домен в начале команды (ключи и подписка сохранятся)."
fi

# ============================================================================
# МОСТ: зарубежный сервер настраивается отсюда по SSH этим же скриптом (роль exit)
exit_ssh() {   # exit_ssh команда — выполнить на зарубежном сервере
  local opts=(-p "$EXIT_SSH_PORT" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15
              -o ServerAliveInterval=20 -o ServerAliveCountMax=9 -o LogLevel=ERROR)
  if [ -n "$EXIT_PASS" ]; then
    SSHPASS="$EXIT_PASS" sshpass -e ssh "${opts[@]}" -o PubkeyAuthentication=no \
      -o NumberOfPasswordPrompts=1 "${EXIT_USER}@${EXIT_HOST}" "$@"
  else
    ssh "${opts[@]}" -o BatchMode=yes "${EXIT_USER}@${EXIT_HOST}" "$@"
  fi
}
exit_input() {   # что подать на вход удалённой команде: пароль для sudo (логин не root) или ничего
  if [ "$EXIT_USER" != "root" ] && [ -n "$EXIT_PASS" ]; then printf '%s\n' "$EXIT_PASS"; fi
}
EXIT_OUT="$WORK/exit.json"
exit_filter() {   # вывод зарубежного сервера — на экран с отступом, параметры подключения — в файл
  local line
  while IFS= read -r line; do
    case "$line" in
      VPN_EXIT_PARAMS=*) printf '%s\n' "${line#VPN_EXIT_PARAMS=}" > "$EXIT_OUT" ;;
      *) printf '    │ %s\n' "$line" ;;
    esac
  done
}
prepare_self() {   # копия этого скрипта для зарубежных серверов — одна на всех
  local self="$WORK/self.sh"
  if [ -f "$0" ] && grep -q 'VPN_ROLE' "$0" 2>/dev/null; then
    cp "$0" "$self"
  else
    curl -fsSL --retry 3 --connect-timeout 15 --max-time 90 -o "$self" "$SCRIPT_URL" 2>/dev/null || rm -f "$self"
  fi
}
setup_exit() {
  local out rc try cmd sudo="" self="$WORK/self.sh"
  tcp_ok "$EXIT_HOST" "$EXIT_SSH_PORT" || die "Этот сервер не может подключиться к ${EXIT_HOST} (SSH, порт ${EXIT_SSH_PORT}).
Если IP верный — связь между серверами закрыта, и мост через этот зарубежный сервер не заработает."
  for try in 1 2 3; do
    rc=0
    out="$(exit_ssh true 2>&1 </dev/null)" || rc=$?
    [ "$rc" = "0" ] && break
    case "$out" in
      *"IDENTIFICATION HAS CHANGED"*|*"Host key verification failed"*)
        die "SSH-ключ сервера ${EXIT_HOST} сменился (его переустанавливали?). Выполните: ssh-keygen -R ${EXIT_HOST} — и запустите скрипт снова." ;;
    esac
    if [ "$rc" = "5" ] || [[ "$out" == *"Permission denied"* ]]; then
      { [ "$HAS_TTY" = "1" ] && [ "$try" -lt 3 ]; } || die "Не удалось войти на ${EXIT_HOST}: неверный логин или пароль (логин ${EXIT_USER})."
      tty_read EXIT_PASS "Пароль не подошёл. Пароль ${EXIT_USER} на ${EXIT_HOST}: " -s
      continue
    fi
    die "Не удалось подключиться к ${EXIT_HOST} по SSH: $(printf '%s' "$out" | tail -n 2)"
  done
  if [ "$EXIT_USER" != "root" ]; then   # не root — настраиваем через sudo
    if [ -n "$EXIT_PASS" ]; then sudo="sudo -S -p '' env"; else sudo="sudo -n env"; fi
    exit_input | exit_ssh "${sudo} true" >/dev/null 2>&1 \
      || die "У пользователя ${EXIT_USER} на ${EXIT_HOST} нет прав sudo. Нужен root или пользователь с правами sudo."
  fi
  # на зарубежный сервер уходит этот же скрипт (копию готовит prepare_self)
  [ -s "$self" ] || die "Не удалось подготовить скрипт для зарубежного сервера (${SCRIPT_URL})."
  grep -q 'VPN_ROLE' "$self" || die "По адресу ${SCRIPT_URL} лежит старая версия скрипта — загрузите новую в репозиторий."
  exit_ssh "cat > install-vpn-all.sh && chmod 700 install-vpn-all.sh" < "$self" \
    || die "Не удалось передать скрипт на ${EXIT_HOST}."
  printf -v cmd '%sVPN_ROLE=exit VPN_PORT=%q XHTTP_PORT=%q SNI=%q LABEL=%q XUI_VERSION=%q EXIT_LOGIN=%q FREETURN=%q FREETURN_PORT=%q FREETURN_CALL=%q bash install-vpn-all.sh' \
    "${sudo:+$sudo }" "$EXIT_VPN_PORT" "$EXIT_XHTTP_PORT" "$SNI" "bridge-exit" "$XUI_VERSION" "$EXIT_USER" \
    "$FREETURN" "$FREETURN_PORT" "$FREETURN_CALL"
  rm -f "$EXIT_OUT"
  if ! exit_input | exit_ssh "$cmd" 2>&1 | exit_filter; then
    die "Настройка зарубежного сервера не удалась (подробности — выше)."
  fi
  [ -s "$EXIT_OUT" ] || die "Зарубежный сервер не вернул параметры подключения (подробности — выше)."
}

EXIT_OK_N=()                              # номера выходов, до которых этот сервер достаёт
declare -A EX_HOST=() EX_RTT=() EX_NET=() EX_NAME=()
exit_title() {   # exit_title N — «🇳🇱 Нидерланды (IP)», а если страна неизвестна — просто IP
  if [ -n "${EX_NAME[$1]:-}" ]; then printf '%s (%s)' "${EX_NAME[$1]}" "${EX_HOST[$1]}"; else printf '%s' "${EX_HOST[$1]}"; fi
}
exit_base() {    # exit_base N — название для подписки: «🇳🇱 Нидерланды»; страны совпали — с IP; неизвестна — «🌐 IP»
  local m
  if [ -z "${EX_NAME[$1]:-}" ]; then printf '🌐 %s' "${EX_HOST[$1]}"; return 0; fi
  for m in "${EXIT_OK_N[@]}"; do
    if [ "$m" != "$1" ] && [ "${EX_NAME[$m]:-}" = "${EX_NAME[$1]}" ]; then printf '%s %s' "${EX_NAME[$1]}" "${EX_HOST[$1]}"; return 0; fi
  done
  printf '%s' "${EX_NAME[$1]}"
}
if [ "$BRIDGE" = "1" ]; then
  if [ "${#EXIT_HOSTS[@]}" -gt 1 ]; then
    step "Настраиваю зарубежные серверы — выходы моста (${#EXIT_HOSTS[@]} шт.)..."
  else
    step "Настраиваю зарубежный сервер ${EXIT_HOSTS[0]} — выход моста..."
  fi
  # параметры прошлых запусков — по адресу сервера (в файле старого формата — один выход)
  mkdir -p "$WORK/saved"
  python3 - "$BRIDGE_FILE" "$WORK/saved" <<'PY' 2>/dev/null || true
import json, os, sys
try:
    d = json.load(open(sys.argv[1]))
except (OSError, ValueError):
    raise SystemExit
exits = d.get("exits") if isinstance(d, dict) and "exits" in d else [d]
for p in exits:
    if isinstance(p, dict) and p.get("host"):
        json.dump(p, open(os.path.join(sys.argv[2], p["host"] + ".json"), "w"))
PY
  : > "$WORK/exits.jsonl"
  # 1) логины и пароли — по очереди (если их нет в команде, спросит с клавиатуры)
  declare -A X_USER=() X_PASS=() X_ACT=() X_RC=() X_PID=()
  SETUP_N=()
  for i in "${!EXIT_HOSTS[@]}"; do
    n=$((i + 1)); EXIT_HOST="${EXIT_HOSTS[$i]}"; saved="$WORK/saved/${EXIT_HOST}.json"
    if [ "$EXIT_HOST" = "$SERVER_IP" ]; then ylw "    ${EXIT_HOST} — это IP самого сервера, пропускаю."; continue; fi
    EXIT_USER="${EXIT_USERS[$i]:-$EXIT_USER_ALL}"
    EXIT_PASS="${EXIT_PASSES[$i]:-$EXIT_PASS_ALL}"
    if [ -z "$EXIT_USER" ] && [ -s "$saved" ]; then
      EXIT_USER="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("user") or "")' "$saved" 2>/dev/null || true)"
    fi
    if [ -z "$EXIT_PASS" ] && [ "$HAS_TTY" = "1" ]; then
      if [ -s "$saved" ]; then
        tty_read EXIT_PASS "    Пароль ${EXIT_USER:-root} на ${EXIT_HOST} (просто Enter — не трогать, он уже настроен): " -s
      else
        if [ -z "$EXIT_USER" ]; then
          tty_read EXIT_USER "    Логин на ${EXIT_HOST} [root]: "
          EXIT_USER="${EXIT_USER// /}"
        fi
        tty_read EXIT_PASS "    Пароль ${EXIT_USER:-root} на ${EXIT_HOST} (при вводе не отображается): " -s
      fi
    fi
    EXIT_USER="${EXIT_USER:-root}"
    if ! [[ "$EXIT_USER" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]; then
      ylw "    Логин ${EXIT_USER} указан неверно — ${EXIT_HOST} пропускаю."; continue
    fi
    X_USER[$n]="$EXIT_USER"; X_PASS[$n]="$EXIT_PASS"
    if [ -z "$EXIT_PASS" ] && [ -s "$saved" ]; then X_ACT[$n]="saved"; else X_ACT[$n]="setup"; SETUP_N+=("$n"); fi
  done
  # 2) настройка: несколько серверов — одновременно, у каждого свой журнал
  run_setup() {   # run_setup N — настроить выход N (в подоболочке: ошибка одного не мешает остальным)
    EXIT_HOST="${EXIT_HOSTS[$(($1 - 1))]}"; EXIT_USER="${X_USER[$1]}"; EXIT_PASS="${X_PASS[$1]}"
    EXIT_OUT="$WORK/exit-$1.json"; rm -f "$EXIT_OUT"
    setup_exit
  }
  if [ "${#SETUP_N[@]}" -gt 0 ]; then prepare_self; fi
  if [ "${#SETUP_N[@]}" -eq 1 ]; then
    n="${SETUP_N[0]}"
    grn "    Выход ${n}: настраиваю ${EXIT_HOSTS[$((n - 1))]}..."
    if ( run_setup "$n" ); then X_RC[$n]=0; else X_RC[$n]=1; fi
  elif [ "${#SETUP_N[@]}" -gt 1 ]; then
    list=""
    for n in "${SETUP_N[@]}"; do list="${list:+${list}, }${EXIT_HOSTS[$((n - 1))]}"; done
    grn "    Настраиваю одновременно (${#SETUP_N[@]} шт.): ${list} — обычно 3–6 минут..."
    for n in "${SETUP_N[@]}"; do
      ( HAS_TTY=0; run_setup "$n" ) > "$WORK/exit-${n}.log" 2>&1 &
      X_PID[$n]=$!
    done
    for n in "${SETUP_N[@]}"; do
      if wait "${X_PID[$n]}"; then X_RC[$n]=0; else X_RC[$n]=1; fi
      grn "    Выход ${n}: ${EXIT_HOSTS[$((n - 1))]}"
      cat "$WORK/exit-${n}.log"
    done
  fi
  # 3) параметры каждого выхода
  for i in "${!EXIT_HOSTS[@]}"; do
    n=$((i + 1)); EXIT_HOST="${EXIT_HOSTS[$i]}"; saved="$WORK/saved/${EXIT_HOST}.json"; fresh=0
    [ -n "${X_ACT[$n]:-}" ] || continue
    EXIT_OUT="$WORK/exit-${n}.json"
    if [ "${X_ACT[$n]}" = "saved" ]; then
      grn "    Выход ${n}: ${EXIT_HOST} уже настроен — беру прежние параметры."
      cp "$saved" "$EXIT_OUT"
    elif [ "${X_RC[$n]:-1}" = "0" ] && [ -s "$EXIT_OUT" ]; then
      fresh=1
    elif [ -s "$saved" ]; then
      ylw "    Выход ${n}: ${EXIT_HOST} не перенастроился — беру прежние параметры."
      cp "$saved" "$EXIT_OUT"
    else
      ylw "    Выход ${n}: ${EXIT_HOST} пропускаю (причина — выше)."
      continue
    fi
    # страна сервера по IP — для названий («🇳🇱 Нидерланды»); узнаём один раз и запоминаем
    cc="$(sed -n 's/.*"cc": *"\([A-Z][A-Z]\)".*/\1/p' "$EXIT_OUT" 2>/dev/null | head -n 1 || true)"
    if [ -z "$cc" ]; then cc="$(ip_country "$EXIT_HOST")"; fi
    N="$n" HOST="$EXIT_HOST" LOGIN="${X_USER[$n]}" FRESH="$fresh" CC="$cc" python3 - "$EXIT_OUT" >> "$WORK/exits.jsonl" <<'PY' || ylw "    Выход ${n}: не удалось разобрать параметры ${EXIT_HOST}."
import json, os, sys
p = json.load(open(sys.argv[1]))
if not all(p.get(k) for k in ("port", "id", "pbk", "sni")):
    raise SystemExit(1)
p.update({"host": os.environ["HOST"],        # адрес — тот, по которому этот сервер до него достаёт
          "user": os.environ["LOGIN"],       # логин — чтобы при повторном запуске предложить его же
          "n": int(os.environ["N"]), "fresh": os.environ["FRESH"] == "1"})
if os.environ.get("CC"):
    p["cc"] = os.environ["CC"]
print(json.dumps(p))
PY
  done
  # выходы для Xray: у каждого сервера TCP и, если есть, XHTTP (переиспользует соединения)
  XMUX="$XMUX_JSON" python3 - "$WORK/exits.jsonl" "$WORK" > "$WORK/exits.tsv" <<'PY' || die "Не удалось разобрать параметры зарубежных серверов."
import json, os, sys
work = sys.argv[2]
exits = [json.loads(line) for line in open(sys.argv[1]) if line.strip()]
for p in exits:
    n = p["n"]
    p.setdefault("flow", "xtls-rprx-vision")
    p.setdefault("sid", "")
    p.setdefault("fp", "chrome")
    user = {"id": p["id"], "encryption": "none"}
    if p["flow"]:
        user["flow"] = p["flow"]
    out = {"tag": "bridge-exit-%d-t" % n, "protocol": "vless",
           "settings": {"vnext": [{"address": p["host"], "port": int(p["port"]), "users": [user]}]},
           "streamSettings": {"network": "tcp", "security": "reality",
                              "realitySettings": {"serverName": p["sni"], "publicKey": p["pbk"],
                                                  "shortId": p["sid"], "fingerprint": p["fp"] or "chrome",
                                                  "spiderX": "/"}}}
    json.dump(out, open("%s/out-%d.json" % (work, n), "w"))
    x = p.get("xhttp") or {}
    xport = "-"
    if all(x.get(k) for k in ("port", "pbk", "sni", "path")):
        xo = {"tag": "bridge-exit-%d-x" % n, "protocol": "vless",
              "settings": {"vnext": [{"address": p["host"], "port": int(x["port"]),
                                      "users": [{"id": p["id"], "encryption": "none"}]}]},
              "streamSettings": {"network": "xhttp", "security": "reality",
                                 "xhttpSettings": {"path": x["path"], "mode": "auto",
                                                   "extra": {"xPaddingBytes": "100-1000",
                                                             "xmux": json.loads(os.environ["XMUX"])}},
                                 "realitySettings": {"serverName": x["sni"], "publicKey": x["pbk"],
                                                     "shortId": x.get("sid") or "", "fingerprint": "chrome",
                                                     "spiderX": "/"}}}
        json.dump(xo, open("%s/out-%d-x.json" % (work, n), "w"))
        xport = int(x["port"])
    panel = p.get("panel")
    if isinstance(panel, dict) and panel.get("token") and panel.get("port"):
        json.dump(panel, open("%s/panel-%d.json" % (work, n), "w"))   # для узла: панель выхода по мосту
    speed = p.get("speed") if p.get("fresh") else ""   # скорость показываем, только если её только что измерили
    print(n, p["host"], int(p["port"]), xport, speed or "-", p.get("cc") or "-")
saved = [{k: v for k, v in p.items() if k not in ("n", "fresh")} for p in exits]
json.dump({"exits": saved}, open("%s/bridge.json" % work, "w"), indent=1)
PY
  while read -r n host port xport speed cc; do
    if [ "${cc:--}" = "-" ]; then cc=""; fi
    EX_NAME[$n]="$(cc_title "$cc")"
    if ! tcp_ok "$host" "$port"; then
      ylw "    Выход ${n}: ${host}:${port} не открывается с этого сервера — пропускаю."
      rm -f "$WORK/out-${n}.json" "$WORK/out-${n}-x.json"
      continue
    fi
    rtt="$(python3 - "$host" "$port" <<'PY' 2>/dev/null || true
import socket, sys, time
best = None
for _ in range(3):                      # задержка до выхода — лучшая из трёх попыток
    t = time.time()
    try:
        socket.create_connection((sys.argv[1], int(sys.argv[2])), 5).close()
    except OSError:
        continue
    ms = (time.time() - t) * 1000
    best = ms if best is None else min(best, ms)
print(int(best) if best is not None else "")
PY
)"
    if [ -s "$WORK/out-${n}-x.json" ] && ! tcp_ok "$host" "$xport"; then
      ylw "    Выход ${n}: XHTTP-порт ${xport} недоступен — только TCP."
      rm -f "$WORK/out-${n}-x.json"
    fi
    if [ "$speed" = "-" ]; then speed=""; fi
    EXIT_OK_N+=("$n"); EX_HOST[$n]="$host"; EX_RTT[$n]="$rtt"; EX_NET[$n]="$speed"
    grn "    Выход ${n} готов: ${EX_NAME[$n]:+${EX_NAME[$n]} — }${host}:${port}$([ -s "$WORK/out-${n}-x.json" ] && echo " и XHTTP :${xport}")${rtt:+, задержка ${rtt} мс}"
  done < "$WORK/exits.tsv"
  [ "${#EXIT_OK_N[@]}" -gt 0 ] || die "Ни один зарубежный сервер не готов — мост не заработает (причины — выше)."
  if [ "${#EXIT_OK_N[@]}" -gt 1 ]; then
    EXIT_TEXT=""
    for n in "${EXIT_OK_N[@]}"; do EXIT_TEXT="${EXIT_TEXT:+${EXIT_TEXT}, }${EX_NAME[$n]:-${EX_HOST[$n]}}"; done
    EXIT_TEXT="зарубежные серверы: ${EXIT_TEXT}"
  else
    EXIT_TEXT="$(exit_title "${EXIT_OK_N[0]}")"
  fi
fi

# ============================================================================
step "Устанавливаю панель 3X-UI..."
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
step "Настраиваю доступ к панели..."
if [ "$FRESH" = "0" ]; then   # прежние порт и путь панели, новый пароль
  CUR="$("$XUI_BIN" setting -show 2>/dev/null || true)"
  [ -n "$PANEL_PORT" ] || PANEL_PORT="$(printf '%s\n' "$CUR" | awk -F': ' '$1=="port"{print $2}' | tr -d '[:space:]')"
  WEBPATH="$(printf '%s\n' "$CUR" | awk -F': ' '$1=="webBasePath"{print $2}' | tr -d '[:space:]' | sed 's#^/*##; s#/*$##')"
  [[ "$PANEL_PORT" =~ ^[0-9]+$ ]] || PANEL_PORT=$(( (RANDOM % 20000) + 40000 ))
  [ "${#WEBPATH}" -ge 4 ] || WEBPATH="$(openssl rand -hex 8)"
fi
LISTEN_ARGS=()
OPEN_PORTS=("$VPN_PORT" "$PANEL_PORT" "$SUB_PORT" 80)
if [ "$VPN_ROLE" = "exit" ]; then   # у выхода моста панель не видна из интернета, открыты только порты VPN
  LISTEN_ARGS=(-listenIP 127.0.0.1)
  OPEN_PORTS=("$VPN_PORT")
fi
if [ "$XHTTP_PORT" != "0" ]; then OPEN_PORTS+=("$XHTTP_PORT"); fi
if [ "$WS_PORT" != "0" ] && [ "$VPN_ROLE" != "exit" ]; then OPEN_PORTS+=("$WS_PORT"); fi
systemctl stop x-ui >/dev/null 2>&1 || true   # базу панели меняем, пока она остановлена
"$XUI_BIN" setting -username "$PANEL_USER" -password "$PANEL_PASS" -port "$PANEL_PORT" -webBasePath "$WEBPATH" \
  "${LISTEN_ARGS[@]}" >/dev/null 2>&1 \
  || { systemctl start x-ui || true; die "Не удалось задать логин и пароль панели."; }
API_TOKEN="$("$XUI_BIN" setting -getApiToken -tokenName vpn-installer 2>/dev/null | awk '$1=="apiToken:"{print $2}' | tail -n 1)"
NODE_TOKEN=""
if [ "$VPN_ROLE" = "exit" ]; then   # ключ, которым российская панель управляет этим сервером как своим узлом
  NODE_TOKEN="$("$XUI_BIN" setting -getApiToken -tokenName central -tokenScope node-sync 2>/dev/null | awk '$1=="apiToken:"{print $2}' | tail -n 1)"
  if [ -z "$NODE_TOKEN" ]; then   # старая версия панели — без областей доступа
    NODE_TOKEN="$("$XUI_BIN" setting -getApiToken -tokenName central 2>/dev/null | awk '$1=="apiToken:"{print $2}' | tail -n 1)"
  fi
fi
if command -v ufw >/dev/null 2>&1; then
  for p in "${OPEN_PORTS[@]}"; do ufw allow "${p}/tcp" >/dev/null 2>&1 || true; done
fi
systemctl enable x-ui >/dev/null 2>&1 || true
systemctl start x-ui
[ -n "$API_TOKEN" ] || die "Не удалось получить API-токен панели."
wait_api || die "Панель не запустилась. Логи: journalctl -u x-ui -e"

# ============================================================================
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
if [ "$VPN_ROLE" != "exit" ]; then   # выходу моста сертификат не нужен: к нему подключается только российский сервер
  step "Выпускаю SSL-сертификат на ${ADDR}..."
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
fi

# ============================================================================
step "Готовлю подключение VLESS + Reality..."
XRAY_BIN=""
for f in "$XUI_DIR"/bin/xray-linux-*; do
  if [ -x "$f" ]; then XRAY_BIN="$f"; break; fi
done
[ -n "$XRAY_BIN" ] || die "Не найден xray внутри 3X-UI."
api GET /inbounds/list > "$WORK/inbounds.json" || die "API панели не отвечает."
VPN_PORT="$VPN_PORT" ROLE="$VPN_ROLE" python3 - "$WORK/inbounds.json" > "$WORK/state" 2>/dev/null <<'PY' || echo "error" > "$WORK/state"
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
    if ib.get("protocol") in ("hysteria", "wireguard", "amneziawg", "tuic") or st.get("network") in ("kcp", "quic"):
        continue        # UDP-подключение (например, Hysteria2 на том же номере порта) TCP не мешает
    rs = st.get("realitySettings") or {}
    clients = [c for c in (s.get("clients") or []) if c.get("id") and c.get("subId")]
    pub = (rs.get("settings") or {}).get("publicKey") or ""
    if ib.get("protocol") == "vless" and st.get("security") == "reality" and clients and pub:
        c = clients[0]
        if os.environ["ROLE"] == "exit":   # на выходе моста: клиент моста, а не пользователи российской панели
            c = next((x for x in clients if str(x.get("email") or "").startswith("bridge-")), c)
        print("reuse", ib["id"], c["id"], c["subId"], pub,
              (rs.get("shortIds") or [""])[0] or "-", (rs.get("serverNames") or ["-"])[0] or "-",
              ib.get("tag") or "-", c.get("flow") or "-", c.get("email") or "-")
    else:
        print("replace", ib["id"])
    break
else:
    print("none")
PY
read -r STATE INB_ID UUID SUB_ID PUBLIC_KEY SHORT_ID OLD_SNI INB_TAG CLIENT_FLOW CLIENT_EMAIL < "$WORK/state" || true

create_inbound() {
  local keys="" n msg email
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
    email="user${n}"
    if [ "$VPN_ROLE" = "exit" ]; then   # клиент моста: у каждого зарубежного сервера своё имя
      email="bridge-${SERVER_IP}"
      if [ "$n" -gt 1 ]; then email="bridge-${SERVER_IP}-${n}"; fi
    fi
    UUID="$UUID" PRIVATE_KEY="$PRIVATE_KEY" PUBLIC_KEY="$PUBLIC_KEY" SHORT_ID="$SHORT_ID" SUB_ID="$SUB_ID" \
    SNI="$SNI" VPN_PORT="$VPN_PORT" LABEL="$LABEL" SHARE_ADDR="$ADDR" CLIENT_EMAIL="$email" COMMENT="$BRIDGE_COMMENT" \
    python3 - > "$WORK/inbound.json" <<'PY'
import json, os
e = os.environ
settings = {"clients": [{"id": e["UUID"], "flow": "xtls-rprx-vision", "email": e["CLIENT_EMAIL"],
                         "limitIp": 0, "totalGB": 0, "expiryTime": 0, "enable": True,
                         "tgId": 0, "subId": e["SUB_ID"], "comment": e["COMMENT"], "reset": 0}],
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
      CLIENT_FLOW="xtls-rprx-vision"
      CLIENT_EMAIL="$email"
      INB_ID="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["obj"]["id"])' "$WORK/add.json" 2>/dev/null || echo "$INB_ID")"
      return 0
    fi
    case "$msg" in *"Duplicate email"*) continue ;; esac
    die "Панель не приняла подключение: ${msg:-нет ответа}"
  done
  die "Не удалось подобрать свободное имя клиента."
}

sync_share_addr() {   # sync_share_addr [id] [название] [метка] [адрес|keep] — ссылки ведут на выбранный адрес (после смены IP или домена)
  local st id="${1:-$INB_ID}"
  api GET "/inbounds/get/${id}" > "$WORK/inb-get.json" || return 1
  st="$(SHARE_ADDR="${4:-$ADDR}" NEW_REMARK="${2:-}" NEW_TAG="${3:-}" NEW_SNI="$([ -z "${4:-}" ] && printf '%s' "$SNI_USER")" python3 - "$WORK/inb-get.json" "$WORK/inb-upd.json" <<'PY' 2>/dev/null || echo "error"
import json, os, sys
ib = json.load(open(sys.argv[1]))["obj"]
if isinstance(ib, str):
    ib = json.loads(ib)
e = os.environ
ip = e["SHARE_ADDR"]
state = "same"
if ip != "keep" and not (ib.get("shareAddrStrategy") == "custom" and ib.get("shareAddr") == ip):
    ib["shareAddrStrategy"], ib["shareAddr"] = "custom", ip
    state = "addr"
for key, new in (("remark", e.get("NEW_REMARK")), ("tag", e.get("NEW_TAG"))):
    if new and ib.get(key) != new:      # заодно — новое название и метка подключения
        ib[key] = new
        if state == "same":
            state = "changed"
sni = e.get("NEW_SNI") or ""
if sni:                                 # SNI из команды: новая маскировка Reality (ключи прежние)
    st = ib.get("streamSettings")
    st = json.loads(st) if isinstance(st, str) and st else (st or {})
    rs = st.get("realitySettings") if st.get("security") == "reality" else None
    if isinstance(rs, dict) and (rs.get("serverNames") != [sni] or (rs.get("target") or rs.get("dest")) != sni + ":443"):
        rs["serverNames"] = [sni]
        rs.pop("dest", None)
        rs["target"] = sni + ":443"
        ib["streamSettings"] = st
        if state == "same":
            state = "changed"
if state == "same":
    print("same"); raise SystemExit
for key in ("settings", "streamSettings", "sniffing"):
    value = ib.get(key)
    if not isinstance(value, str):
        ib[key] = json.dumps(value or {})
ib.pop("clientStats", None)
json.dump(ib, open(sys.argv[2], "w"))
print(state)
PY
)"
  case "$st" in
    same) return 0 ;;
    addr|changed)
      api POST "/inbounds/update/${id}" "$WORK/inb-upd.json" > "$WORK/inb-res.json" || return 1
      if api_ok "$WORK/inb-res.json" >/dev/null; then
        if [ "$st" = "addr" ] && [ -z "${4:-}" ]; then grn "    Адрес в ссылках обновлён: ${ADDR}"; fi
        return 0
      fi
      return 1 ;;
    *) return 1 ;;
  esac
}

case "${STATE:-error}" in
  reuse)
    [ "$SHORT_ID" = "-" ] && SHORT_ID=""
    if [ "$OLD_SNI" != "-" ] && [ -z "$SNI_USER" ]; then SNI="$OLD_SNI"; fi
    if [ -n "$SNI_USER" ] && [ "$OLD_SNI" != "$SNI_USER" ]; then grn "    Маскировка Reality меняется: ${OLD_SNI} → ${SNI_USER} (ключи прежние)."; fi
    [ "${CLIENT_FLOW:--}" = "-" ] && CLIENT_FLOW=""
    grn "    На порту ${VPN_PORT} уже есть подключение — оставляю его, ключи прежние."
    sync_share_addr "$INB_ID" "$LABEL" || ylw "    Не удалось обновить адрес сервера в ссылках — проверьте подключение в панели."
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
# Выход моста: клиент моста называется bridge-IP (в прежних версиях — user1). У каждого сервера
# своё имя: российская панель ведёт все серверы как свои узлы, а имена клиентов в ней общие.
rename_bridge_client() {
  local new="bridge-${SERVER_IP}"
  api GET "/clients/get/${CLIENT_EMAIL}" > "$WORK/cl.json" || return 1
  NEW_EMAIL="$new" COMMENT="$BRIDGE_COMMENT" python3 - "$WORK/cl.json" > "$WORK/cl-upd.json" 2>/dev/null <<'PY' || return 1
import json, os, sys
c = json.load(open(sys.argv[1]))["obj"]["client"]
print(json.dumps({"id": c["uuid"], "email": os.environ["NEW_EMAIL"], "subId": c["subId"], "flow": c.get("flow") or "",
                  "limitIp": c.get("limitIp") or 0, "totalGB": c.get("totalGB") or 0, "expiryTime": c.get("expiryTime") or 0,
                  "enable": True, "tgId": c.get("tgId") or 0, "comment": os.environ["COMMENT"], "reset": c.get("reset") or 0}))
PY
  api POST "/clients/update/${CLIENT_EMAIL}" "$WORK/cl-upd.json" > "$WORK/cl-res.json" || return 1
  api_ok "$WORK/cl-res.json" >/dev/null || return 1
  CLIENT_EMAIL="$new"
}
if [ "$VPN_ROLE" = "exit" ] && [ "${CLIENT_EMAIL:--}" != "-" ] && [[ "$CLIENT_EMAIL" != bridge-* ]]; then
  rename_bridge_client || ylw "    Не удалось переименовать клиента моста — прямое подключение к этому серверу может не настроиться."
fi

# Общие помощники для дополнительных подключений.
new_reality_keys() {   # новые ключи Reality → NK_PRIV, NK_PUB
  local keys
  NK_PRIV=""; NK_PUB=""
  api GET /server/getNewX25519Cert > "$WORK/nkeys.json" 2>/dev/null || true
  keys="$(python3 -c 'import json,sys;o=json.load(open(sys.argv[1]))["obj"];print(o["privateKey"],o["publicKey"])' "$WORK/nkeys.json" 2>/dev/null || true)"
  NK_PRIV="${keys%% *}"; NK_PUB="${keys##* }"
  if [ -z "$keys" ]; then
    keys="$("$XRAY_BIN" x25519 2>/dev/null || true)"
    NK_PRIV="$(printf '%s\n' "$keys" | awk -F': *' 'tolower($1) ~ /private/ {print $2; exit}')"
    NK_PUB="$(printf '%s\n' "$keys" | awk -F': *' 'tolower($1) ~ /public|password/ {print $2; exit}')"
  fi
  [ -n "$NK_PRIV" ] && [ -n "$NK_PUB" ]
}
create_xhttp_inbound() {   # create_xhttp_inbound порт название порядок [метка] → MK_ID MK_PBK MK_SID MK_PATH
  local msg
  new_reality_keys || { ylw "    Не удалось сгенерировать ключи Reality."; return 1; }
  MK_PBK="$NK_PUB"; MK_SID="$(openssl rand -hex 8)"; MK_PATH="/assets/$(openssl rand -hex 4)/media"
  PRIV="$NK_PRIV" PUB="$MK_PBK" SID="$MK_SID" XSNI="$SNI" XPATH="$MK_PATH" XPORT="$1" XLABEL="$2" SORT="$3" \
  XTAG="${4:-}" SHARE_ADDR="$ADDR" XMUX="$XMUX_JSON" python3 - > "$WORK/mk.json" <<'PY'
import json, os
e = os.environ
stream = {"network": "xhttp", "security": "reality", "externalProxy": [],
          "xhttpSettings": {"path": e["XPATH"], "host": "", "headers": {}, "mode": "auto",
                            "xPaddingBytes": "100-1000", "scStreamUpServerSecs": "20-80",
                            "noSSEHeader": False, "xmux": json.loads(e["XMUX"])},
          "realitySettings": {"show": False, "xver": 0, "target": e["XSNI"] + ":443",
                              "serverNames": [e["XSNI"]], "privateKey": e["PRIV"],
                              "minClientVer": "", "maxClientVer": "", "maxTimediff": 0,
                              "shortIds": [e["SID"]], "mldsa65Seed": "",
                              "settings": {"publicKey": e["PUB"], "fingerprint": "chrome",
                                           "serverName": "", "spiderX": "/", "mldsa65Verify": ""}}}
settings = {"clients": [], "decryption": "none", "encryption": "none", "fallbacks": []}
sniffing = {"enabled": True, "destOverride": ["http", "tls", "quic", "fakedns"],
            "metadataOnly": False, "routeOnly": False}
inbound = {"remark": e["XLABEL"], "enable": True, "listen": "", "port": int(e["XPORT"]),
           "protocol": "vless", "expiryTime": 0, "total": 0,
           "shareAddrStrategy": "custom", "shareAddr": e["SHARE_ADDR"],
           "disableFlow": True,      # у XHTTP без шифрования VLESS поток vision не используется
           "subSortIndex": int(e["SORT"]),
           "settings": json.dumps(settings), "streamSettings": json.dumps(stream),
           "sniffing": json.dumps(sniffing)}
if e.get("XTAG"):
    inbound["tag"] = e["XTAG"]
print(json.dumps(inbound))
PY
  api POST /inbounds/add "$WORK/mk.json" > "$WORK/mk-res.json" || return 1
  if ! msg="$(api_ok "$WORK/mk-res.json")"; then ylw "    Панель не приняла подключение «$2»: ${msg:-нет ответа}"; return 1; fi
  MK_ID="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["obj"]["id"])' "$WORK/mk-res.json" 2>/dev/null || true)"
  [ -n "$MK_ID" ]
}
attach_client() {   # attach_client id — наш клиент (тот же ключ и та же подписка) и на этом подключении
  local msg
  printf '{"inboundIds":[%s]}' "$1" > "$WORK/attach.json"
  api POST "/clients/${CLIENT_EMAIL}/attach" "$WORK/attach.json" > "$WORK/attach-res.json" || return 1
  if ! msg="$(api_ok "$WORK/attach-res.json")"; then ylw "    Не удалось подключить клиента: ${msg:-нет ответа}"; return 1; fi
}
set_sort() {   # set_sort id место — порядок подключения в подписке (меньше — выше)
  if [ -n "${1:-}" ] && [ "${1:-}" != "-" ]; then
    api_form "/inbounds/${1}/subSortIndex" "subSortIndex=${2}" > /dev/null 2>&1 || true
  fi
}

# Второе подключение — VLESS + XHTTP + Reality, как у коммерческих VPN: соединения
# переиспользуются (xmux), поэтому новые сайты открываются без лишних рукопожатий.
XHTTP_OK=0; XHTTP_ID=""; XHTTP_PBK=""; XHTTP_SID=""; XHTTP_SNI=""; XHTTP_PATH=""
ensure_xhttp() {
  local st has
  if [ "$XHTTP_PORT" = "0" ]; then return 0; fi
  if [ "$XHTTP_PORT" = "$VPN_PORT" ]; then ylw "    XHTTP_PORT совпадает с VPN_PORT — XHTTP пропускаю."; return 0; fi
  if [ "${CLIENT_EMAIL:--}" = "-" ]; then ylw "    Не нашёл имя клиента — XHTTP пропускаю."; return 0; fi
  api GET /inbounds/list > "$WORK/inbounds-x.json" || return 1
  st="$(XHTTP_PORT="$XHTTP_PORT" UUID="$UUID" python3 - "$WORK/inbounds-x.json" <<'PY' 2>/dev/null || echo "error"
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
port = int(os.environ["XHTTP_PORT"])
for ib in data.get("obj") or []:
    if int(ib.get("port") or 0) != port:
        continue
    s, st = obj(ib.get("settings")), obj(ib.get("streamSettings"))
    if ib.get("protocol") in ("hysteria", "wireguard", "amneziawg", "tuic") or st.get("network") in ("kcp", "quic"):
        continue        # UDP-подключение TCP-порту не мешает
    rs, xs = st.get("realitySettings") or {}, st.get("xhttpSettings") or {}
    pub = (rs.get("settings") or {}).get("publicKey") or ""
    if ib.get("protocol") == "vless" and st.get("network") == "xhttp" and st.get("security") == "reality" and pub:
        has = any(c.get("id") == os.environ["UUID"] for c in (s.get("clients") or []))
        print("reuse", ib["id"], pub, (rs.get("shortIds") or [""])[0] or "-",
              (rs.get("serverNames") or ["-"])[0] or "-", xs.get("path") or "/", "yes" if has else "no")
    else:
        print("replace", ib["id"])
    break
else:
    print("none")
PY
)"
  read -r st XHTTP_ID XHTTP_PBK XHTTP_SID XHTTP_SNI XHTTP_PATH has <<< "$st" || true
  case "$st" in
    reuse)
      [ "$XHTTP_SID" = "-" ] && XHTTP_SID=""
      if [ "$XHTTP_SNI" = "-" ] || [ -n "$SNI_USER" ]; then XHTTP_SNI="$SNI"; fi
      sync_share_addr "$XHTTP_ID" "$XHTTP_LABEL" || true ;;
    replace|none)
      if [ "$st" = "replace" ]; then
        ylw "    Порт ${XHTTP_PORT} занят другим подключением — заменяю его на XHTTP."
        api POST "/inbounds/del/${XHTTP_ID}" >/dev/null || true
      fi
      create_xhttp_inbound "$XHTTP_PORT" "$XHTTP_LABEL" 2 || return 1
      XHTTP_ID="$MK_ID"; XHTTP_PBK="$MK_PBK"; XHTTP_SID="$MK_SID"; XHTTP_SNI="$SNI"; XHTTP_PATH="$MK_PATH"
      has="no" ;;
    *) return 1 ;;
  esac
  if [ "$has" != "yes" ]; then attach_client "$XHTTP_ID" || return 1; fi
  XHTTP_OK=1
}
if ensure_xhttp && [ "$XHTTP_OK" = "1" ]; then
  grn "    Второе подключение XHTTP на порту ${XHTTP_PORT}: соединения переиспользуются — сайты открываются быстрее."
elif [ "$XHTTP_PORT" != "0" ]; then
  ylw "    XHTTP не настроился — остаётся обычное подключение."
fi

# Третье подключение — VLESS + WebSocket + настоящий TLS, как «LTE»-профили коммерческих VPN:
# обычный HTTPS с WebSocket, который можно пустить и через CDN. Нужен SSL-сертификат.
WS_OK=0; WS_ID=""; WS_PATH=""
ensure_ws() {
  local st has msg p
  if [ "$WS_PORT" = "0" ] || [ "$VPN_ROLE" = "exit" ]; then return 0; fi
  if [ "$SSL_OK" != "1" ]; then ylw "    WebSocket пропускаю: для него нужен SSL-сертификат (шаг с SSL не прошёл)."; return 0; fi
  for p in "$VPN_PORT" "$XHTTP_PORT" "$SUB_PORT" "$PANEL_PORT" 80; do
    if [ "$WS_PORT" = "$p" ]; then ylw "    WS_PORT совпадает с другим портом — WebSocket пропускаю."; return 0; fi
  done
  if [ "${CLIENT_EMAIL:--}" = "-" ]; then return 0; fi
  api GET /inbounds/list > "$WORK/inbounds-ws.json" || return 1
  st="$(WS_PORT="$WS_PORT" UUID="$UUID" ADDR="$ADDR" CERT="$CERT" python3 - "$WORK/inbounds-ws.json" <<'PY' 2>/dev/null || echo "error"
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
port = int(os.environ["WS_PORT"])
for ib in data.get("obj") or []:
    if int(ib.get("port") or 0) != port:
        continue
    s, st = obj(ib.get("settings")), obj(ib.get("streamSettings"))
    if ib.get("protocol") in ("hysteria", "wireguard", "amneziawg", "tuic") or st.get("network") in ("kcp", "quic"):
        continue        # UDP-подключение TCP-порту не мешает
    ts, ws = st.get("tlsSettings") or {}, st.get("wsSettings") or {}
    cert = ((ts.get("certificates") or [{}])[0]).get("certificateFile")
    if (ib.get("protocol") == "vless" and st.get("network") == "ws" and st.get("security") == "tls"
            and ts.get("serverName") == os.environ["ADDR"] and cert == os.environ["CERT"]):
        has = any(c.get("id") == os.environ["UUID"] for c in (s.get("clients") or []))
        print("reuse", ib["id"], ws.get("path") or "/", "yes" if has else "no")
    else:
        print("replace", ib["id"])      # чужое подключение или сертификат на другой адрес — создаём заново
    break
else:
    print("none")
PY
)"
  read -r st WS_ID WS_PATH has <<< "$st" || true
  case "$st" in
    reuse) sync_share_addr "$WS_ID" "$WS_LABEL" || true ;;
    replace|none)
      if [ "$st" = "replace" ]; then api POST "/inbounds/del/${WS_ID}" >/dev/null || true; fi
      WS_PATH="/gateway/v1/ws/$(openssl rand -hex 16)"
      WPORT="$WS_PORT" WPATH="$WS_PATH" WLABEL="$WS_LABEL" ADDR="$ADDR" CERT="$CERT" KEY="$KEY" \
      python3 - > "$WORK/wsinb.json" <<'PY'
import json, os
e = os.environ
stream = {"network": "ws", "security": "tls", "externalProxy": [],
          "wsSettings": {"acceptProxyProtocol": False, "path": e["WPATH"], "host": e["ADDR"],
                         "headers": {}, "heartbeatPeriod": 30},
          "tlsSettings": {"serverName": e["ADDR"], "minVersion": "1.2", "maxVersion": "1.3",
                          "cipherSuites": "", "rejectUnknownSni": False, "disableSystemRoot": False,
                          "enableSessionResumption": False,
                          "certificates": [{"certificateFile": e["CERT"], "keyFile": e["KEY"],
                                            "ocspStapling": 3600, "oneTimeLoading": False,
                                            "usage": "encipherment", "buildChain": False}],
                          "alpn": ["http/1.1"],
                          "settings": {"allowInsecure": False, "fingerprint": "firefox", "echConfigList": ""}}}
settings = {"clients": [], "decryption": "none", "encryption": "none", "fallbacks": []}
sniffing = {"enabled": True, "destOverride": ["http", "tls", "quic", "fakedns"],
            "metadataOnly": False, "routeOnly": False}
print(json.dumps({"remark": e["WLABEL"], "enable": True, "listen": "", "port": int(e["WPORT"]),
                  "protocol": "vless", "expiryTime": 0, "total": 0,
                  "shareAddrStrategy": "custom", "shareAddr": e["ADDR"],
                  "disableFlow": True, "subSortIndex": 4,
                  "settings": json.dumps(settings), "streamSettings": json.dumps(stream),
                  "sniffing": json.dumps(sniffing)}))
PY
      api POST /inbounds/add "$WORK/wsinb.json" > "$WORK/wsadd.json" || return 1
      if ! msg="$(api_ok "$WORK/wsadd.json")"; then ylw "    Панель не приняла WebSocket: ${msg:-нет ответа}"; return 1; fi
      WS_ID="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["obj"]["id"])' "$WORK/wsadd.json" 2>/dev/null || true)"
      [ -n "$WS_ID" ] || return 1
      has="no" ;;
    *) return 1 ;;
  esac
  if [ "$has" != "yes" ]; then   # тот же клиент, та же подписка
    printf '{"inboundIds":[%s]}' "$WS_ID" > "$WORK/attach-ws.json"
    api POST "/clients/${CLIENT_EMAIL}/attach" "$WORK/attach-ws.json" > "$WORK/attach-ws-res.json" || return 1
    if ! msg="$(api_ok "$WORK/attach-ws-res.json")"; then ylw "    Не удалось подключить клиента к WebSocket: ${msg:-нет ответа}"; return 1; fi
  fi
  WS_OK=1
}
if ensure_ws && [ "$WS_OK" = "1" ]; then
  grn "    Третье подключение WebSocket + TLS на порту ${WS_PORT} — как «LTE»-профили, можно пустить через CDN."
elif [ "$WS_PORT" != "0" ] && [ "$VPN_ROLE" != "exit" ] && [ "$SSL_OK" = "1" ]; then
  ylw "    WebSocket не настроился — остаются другие подключения."
fi

# Четвёртое подключение — Hysteria2: QUIC по UDP. На мобильном интернете с потерями
# обычно быстрее TCP. С Reality на том же номере порта не мешает: там TCP, здесь UDP.
HY2_OK=0; HY2_ID=""
ensure_hy2() {
  local st has msg
  if [ "$HY2_PORT" = "0" ] || [ "$VPN_ROLE" = "exit" ]; then return 0; fi
  if [ "$SSL_OK" != "1" ]; then ylw "    Hysteria2 пропускаю: для него нужен SSL-сертификат (шаг с SSL не прошёл)."; return 0; fi
  if [ "${CLIENT_EMAIL:--}" = "-" ]; then return 0; fi
  api GET /inbounds/list > "$WORK/inbounds-hy.json" || return 1
  st="$(HY2_PORT="$HY2_PORT" EMAIL="$CLIENT_EMAIL" ADDR="$ADDR" CERT="$CERT" python3 - "$WORK/inbounds-hy.json" <<'PY' 2>/dev/null || echo "error"
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
port = int(os.environ["HY2_PORT"])
for ib in data.get("obj") or []:
    if int(ib.get("port") or 0) != port or ib.get("protocol") != "hysteria":
        continue
    s, st = obj(ib.get("settings")), obj(ib.get("streamSettings"))
    ts = st.get("tlsSettings") or {}
    cert = ((ts.get("certificates") or [{}])[0]).get("certificateFile")
    if ts.get("serverName") == os.environ["ADDR"] and cert == os.environ["CERT"]:
        has = any(c.get("email") == os.environ["EMAIL"] for c in (s.get("clients") or []))
        print("reuse", ib["id"], "yes" if has else "no")
    else:
        print("replace", ib["id"])      # сертификат на другой адрес — создаём заново
    break
else:
    print("none")
PY
)"
  read -r st HY2_ID has <<< "$st" || true
  case "$st" in
    reuse) sync_share_addr "$HY2_ID" "$HY2_LABEL" || true ;;
    replace|none)
      if [ "$st" = "replace" ]; then api POST "/inbounds/del/${HY2_ID}" >/dev/null || true; fi
      HPORT="$HY2_PORT" HLABEL="$HY2_LABEL" ADDR="$ADDR" CERT="$CERT" KEY="$KEY" python3 - > "$WORK/hyinb.json" <<'PY'
import json, os
e = os.environ
stream = {"network": "hysteria", "security": "tls", "externalProxy": [],
          "hysteriaSettings": {"version": 2, "auth": "", "udpIdleTimeout": 60},
          "tlsSettings": {"serverName": e["ADDR"], "minVersion": "1.3", "maxVersion": "1.3",
                          "cipherSuites": "", "rejectUnknownSni": False, "disableSystemRoot": False,
                          "enableSessionResumption": False,
                          "certificates": [{"certificateFile": e["CERT"], "keyFile": e["KEY"],
                                            "ocspStapling": 3600, "oneTimeLoading": False,
                                            "usage": "encipherment", "buildChain": False}],
                          "alpn": ["h3"],
                          "settings": {"allowInsecure": False, "fingerprint": "", "echConfigList": ""}}}
sniffing = {"enabled": True, "destOverride": ["http", "tls", "quic", "fakedns"],
            "metadataOnly": False, "routeOnly": False}
print(json.dumps({"remark": e["HLABEL"], "enable": True, "listen": "", "port": int(e["HPORT"]),
                  "protocol": "hysteria", "expiryTime": 0, "total": 0,
                  "shareAddrStrategy": "custom", "shareAddr": e["ADDR"], "subSortIndex": 5,
                  "settings": json.dumps({"version": 2, "clients": []}),
                  "streamSettings": json.dumps(stream), "sniffing": json.dumps(sniffing)}))
PY
      api POST /inbounds/add "$WORK/hyinb.json" > "$WORK/hyadd.json" || return 1
      if ! msg="$(api_ok "$WORK/hyadd.json")"; then ylw "    Панель не приняла Hysteria2: ${msg:-нет ответа}"; return 1; fi
      HY2_ID="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["obj"]["id"])' "$WORK/hyadd.json" 2>/dev/null || true)"
      [ -n "$HY2_ID" ] || return 1
      has="no" ;;
    *) return 1 ;;
  esac
  if [ "$has" != "yes" ]; then attach_client "$HY2_ID" || return 1; fi   # у клиента появится свой пароль Hysteria2
  if command -v ufw >/dev/null 2>&1; then ufw allow "${HY2_PORT}/udp" >/dev/null 2>&1 || true; fi
  HY2_OK=1
}
if ensure_hy2 && [ "$HY2_OK" = "1" ]; then
  grn "    Четвёртое подключение Hysteria2 на UDP-порту ${HY2_PORT} — быстрее на мобильном интернете с потерями."
elif [ "$HY2_PORT" != "0" ] && [ "$VPN_ROLE" != "exit" ] && [ "$SSL_OK" = "1" ]; then
  ylw "    Hysteria2 не настроился — остаются другие подключения."
fi

# Запасной вариант Reality — с российской маскировкой. Провайдеры часто режут Reality к российскому
# серверу, если маскировка — зарубежный сайт (apple.com и т. п.), а с российским сайтом пропускают.
# Скрипт сам выбирает сайт, который открывается с сервера, и добавляет второе подключение: в подписке
# и в «Автовыборе» есть оба, телефон пользуется тем, что работает у него.
ALT_OK=0; ALT_ID=""; ALT_SNI=""; ALT_LABEL="${ALT_LABEL:-${LABEL%-Reality}-XHTTP-RU}"
ensure_reality_alt() {
  local want=0 cc d st id port sni has msg
  if [ "$VPN_ROLE" = "exit" ] || [ "${CLIENT_EMAIL:--}" = "-" ]; then return 0; fi
  case "$REALITY_ALT" in
    1|on|yes) want=1 ;;
    0|off|no) want=0 ;;
    *) case "$SNI" in *.ru|*.su|*.xn--p1ai) want=0 ;;
         *) cc="$(ip_country "$SERVER_IP")"; if [ "$cc" = "RU" ]; then want=1; fi ;; esac ;;
  esac
  for p in "$VPN_PORT" "$XHTTP_PORT" "$WS_PORT" "$SUB_PORT" "$PANEL_PORT" 80; do
    if [ "$REALITY_ALT_PORT" = "$p" ]; then ylw "    REALITY_ALT_PORT совпадает с другим портом — запасной Reality пропускаю."; want=0; fi
  done
  api GET /inbounds/list > "$WORK/inbounds-alt.json" || return 1
  read -r st id sni has < <(PORT="$REALITY_ALT_PORT" UUID="$UUID" python3 - "$WORK/inbounds-alt.json" <<'PY' 2>/dev/null || echo "error - - -"
import json, os, sys
def obj(v):
    if isinstance(v, str):
        try:
            return json.loads(v) if v else {}
        except ValueError:
            return {}
    return v or {}
for ib in json.load(open(sys.argv[1])).get("obj") or []:
    if int(ib.get("port") or 0) != int(os.environ["PORT"]):
        continue
    s, st = obj(ib.get("settings")), obj(ib.get("streamSettings"))
    if ib.get("protocol") in ("hysteria", "wireguard", "amneziawg", "tuic") or st.get("network") in ("kcp", "quic"):
        continue
    rs = st.get("realitySettings") or {}
    if ib.get("protocol") == "vless" and st.get("security") == "reality" and st.get("network") == "xhttp":
        has = any(c.get("id") == os.environ["UUID"] for c in (s.get("clients") or []))
        print("reuse", ib["id"], (rs.get("serverNames") or ["-"])[0] or "-", "yes" if has else "no")
    elif ib.get("tag") == "vpn-reality-alt":
        print("old", ib["id"], "-", "-")        # прежний запасной (обычный Reality) — заменяем на XHTTP
    else:
        print("busy", ib["id"], "-", "-")
    break
else:
    print("none - - -")
PY
)
  if [ "$st" = "old" ]; then api POST "/inbounds/del/${id}" >/dev/null 2>&1 || true; st="none"; fi
  if [ "$want" != "1" ]; then   # не нужен — прежний запасной (если был) убираем
    if [ "$st" = "reuse" ]; then api POST "/inbounds/del/${id}" >/dev/null 2>&1 || true; fi
    return 0
  fi
  if [ "$st" = "busy" ]; then ylw "    Порт ${REALITY_ALT_PORT} занят другим подключением — запасной Reality пропускаю (REALITY_ALT_PORT=…)."; return 0; fi
  # сайт для маскировки: прежний, если ещё открывается, иначе первый подходящий из списка
  ALT_SNI=""
  if [ "$st" = "reuse" ] && [ "$sni" != "-" ] && [ "$sni" != "$SNI" ] && sni_check "$sni"; then ALT_SNI="$sni"; fi
  if [ -z "$ALT_SNI" ]; then
    for d in $REALITY_ALT_SNI; do
      if [ "$d" != "$SNI" ] && sni_check "$d"; then ALT_SNI="$d"; break; fi
    done
  fi
  if [ -z "$ALT_SNI" ]; then ylw "    Запасной Reality: ни один сайт из списка (${REALITY_ALT_SNI}) не открывается с сервера — пропускаю."; return 0; fi
  if [ "$st" = "reuse" ] && [ "$sni" = "$ALT_SNI" ]; then
    ALT_ID="$id"
    sync_share_addr "$ALT_ID" "$ALT_LABEL" "" "$ADDR" || true   # адрес — явно: SNI из команды запасного не касается
    if [ "$has" != "yes" ]; then attach_client "$ALT_ID" || return 1; fi
  else
    if [ "$st" = "reuse" ]; then api POST "/inbounds/del/${id}" >/dev/null 2>&1 || true; fi
    local main_sni="$SNI" rc=0
    SNI="$ALT_SNI"   # create_xhttp_inbound берёт маскировку из SNI
    create_xhttp_inbound "$REALITY_ALT_PORT" "$ALT_LABEL" 3 "vpn-reality-alt" || rc=1
    SNI="$main_sni"
    [ "$rc" = "0" ] || return 1
    ALT_ID="$MK_ID"
    attach_client "$ALT_ID" || return 1   # тот же клиент, та же подписка
  fi
  if command -v ufw >/dev/null 2>&1; then ufw allow "${REALITY_ALT_PORT}/tcp" >/dev/null 2>&1 || true; fi
  ALT_OK=1
}
if ensure_reality_alt && [ "$ALT_OK" = "1" ]; then
  grn "    Запасной XHTTP «${ALT_LABEL}» на порту ${REALITY_ALT_PORT}: маскировка под ${ALT_SNI} — если провайдер режет Reality с ${SNI}."
fi

# Отдельное подключение к каждому зарубежному выходу: в приложении можно выбрать конкретный
# сервер — он подписан страной по IP, «🇳🇱 Нидерланды (IP)» (порт 8444 — выход 1, 8445 — выход 2…).
declare -A PEXIT_ID=() PEXIT_TAG=()
PEXIT_LIST=""
create_ws_inbound() {   # create_ws_inbound порт название порядок [метка] → MK_ID (VLESS + WebSocket + TLS на сертификат этого сервера)
  local msg
  WPORT="$1" WLABEL="$2" SORT="$3" XTAG="${4:-}" WPATH="/api/v2/ws/$(openssl rand -hex 12)" ADDR="$ADDR" CERT="$CERT" KEY="$KEY" \
  python3 - > "$WORK/mkws.json" <<'PY'
import json, os
e = os.environ
stream = {"network": "ws", "security": "tls", "externalProxy": [],
          "wsSettings": {"acceptProxyProtocol": False, "path": e["WPATH"], "host": e["ADDR"],
                         "headers": {}, "heartbeatPeriod": 30},
          "tlsSettings": {"serverName": e["ADDR"], "minVersion": "1.2", "maxVersion": "1.3",
                          "cipherSuites": "", "rejectUnknownSni": False, "disableSystemRoot": False,
                          "enableSessionResumption": False,
                          "certificates": [{"certificateFile": e["CERT"], "keyFile": e["KEY"],
                                            "ocspStapling": 3600, "oneTimeLoading": False,
                                            "usage": "encipherment", "buildChain": False}],
                          "alpn": ["http/1.1"],
                          "settings": {"allowInsecure": False, "fingerprint": "chrome", "echConfigList": ""}}}
settings = {"clients": [], "decryption": "none", "encryption": "none", "fallbacks": []}
sniffing = {"enabled": True, "destOverride": ["http", "tls", "quic", "fakedns"],
            "metadataOnly": False, "routeOnly": False}
inbound = {"remark": e["WLABEL"], "enable": True, "listen": "", "port": int(e["WPORT"]),
           "protocol": "vless", "expiryTime": 0, "total": 0,
           "shareAddrStrategy": "custom", "shareAddr": e["ADDR"],
           "disableFlow": True, "subSortIndex": int(e["SORT"]),
           "settings": json.dumps(settings), "streamSettings": json.dumps(stream),
           "sniffing": json.dumps(sniffing)}
if e.get("XTAG"):
    inbound["tag"] = e["XTAG"]
print(json.dumps(inbound))
PY
  api POST /inbounds/add "$WORK/mkws.json" > "$WORK/mkws-res.json" || return 1
  if ! msg="$(api_ok "$WORK/mkws-res.json")"; then ylw "    Панель не приняла подключение «$2»: ${msg:-нет ответа}"; return 1; fi
  MK_ID="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["obj"]["id"])' "$WORK/mkws-res.json" 2>/dev/null || true)"
  [ -n "$MK_ID" ]
}
ensure_exit_inbounds() {
  local n port host id rport rhost rtag has kind remark tag keep p
  if [ "$VPN_ROLE" = "exit" ] || [ "${CLIENT_EMAIL:--}" = "-" ]; then return 0; fi   # без моста — только уборка
  api GET /inbounds/list > "$WORK/inbounds-pe.json" || return 1
  PREFIX="$PEXIT_PREFIX" TPREFIX="$PEXIT_TAG_PREFIX" UUID="$UUID" python3 - "$WORK/inbounds-pe.json" > "$WORK/pe.tsv" <<'PY' || return 1
import json, os, sys
data = json.load(open(sys.argv[1]))
def obj(v):
    if isinstance(v, str):
        try:
            return json.loads(v) if v else {}
        except ValueError:
            return {}
    return v or {}
prefix, tprefix = os.environ["PREFIX"], os.environ["TPREFIX"]
for ib in data.get("obj") or []:
    remark, tag = ib.get("remark") or "", ib.get("tag") or ""
    s, st = obj(ib.get("settings")), obj(ib.get("streamSettings"))
    host = ""
    if tag.startswith(tprefix):
        host = tag[len(tprefix):]
    elif remark.startswith(prefix):          # так назывались подключения в прежних версиях: «MyVPN→IP»
        host = remark[len(prefix):]
    if host:
        has = any(c.get("id") == os.environ["UUID"] for c in (s.get("clients") or []))
        net = st.get("network") or "tcp"
        if net == "ws":
            cert = (((st.get("tlsSettings") or {}).get("certificates") or [{}])[0]).get("certificateFile") or ""
            net = "ws|" + cert
        print("our", ib["id"], ib["port"], host, tag or "-", "yes" if has else "no", net)
    elif ib.get("protocol") in ("hysteria", "wireguard", "amneziawg", "tuic") or st.get("network") in ("kcp", "quic"):
        continue                             # UDP-подключения TCP-порты не занимают
    else:
        print("busy", ib["id"], ib["port"], "-", "-", "-", "-")
PY
  # прежние подключения к выходам, которых больше нет (или порт достался другому выходу), — удаляем
  local want="xhttp" net
  if [ "$PEXIT_PROTO" = "ws" ] && [ "$SSL_OK" = "1" ]; then want="ws|${CERT}"; fi
  while read -r kind id rport rhost rtag has net; do
    [ "$kind" = "our" ] || continue
    keep=0
    for n in "${EXIT_OK_N[@]}"; do
      if [ "$rport" = "$((PEXIT_BASE + n))" ] && [ "$rhost" = "${EX_HOST[$n]}" ]; then keep=1; fi
    done
    if [ "$keep" = "0" ]; then api POST "/inbounds/del/${id}" >/dev/null 2>&1 || true; fi
  done < "$WORK/pe.tsv"
  if [ "$BRIDGE" != "1" ]; then return 0; fi
  for n in "${EXIT_OK_N[@]}"; do
    port=$((PEXIT_BASE + n)); host="${EX_HOST[$n]}"; id=""
    remark="$(exit_base "$n") (через РФ)"; tag="${PEXIT_TAG_PREFIX}${host}"
    for p in "$VPN_PORT" "$XHTTP_PORT" "$WS_PORT" "$SUB_PORT" "$PANEL_PORT" 80 "$REALITY_ALT_PORT"; do
      if [ "$port" = "$p" ]; then port=""; fi
    done
    if [ -z "$port" ]; then ylw "    Выход ${n}: порт $((PEXIT_BASE + n)) занят другой настройкой — отдельного подключения не будет."; continue; fi
    while read -r kind rid rport rhost rtag has net; do
      if [ "$rport" != "$port" ]; then continue; fi
      if [ "$kind" = "our" ] && [ "$rhost" = "$host" ] && [ "$net" != "$want" ]; then
        api POST "/inbounds/del/${rid}" >/dev/null 2>&1 || true   # другой вид подключения — пересоздаём
        continue
      fi
      if [ "$kind" = "our" ] && [ "$rhost" = "$host" ]; then id="$rid"
        if [ "$has" != "yes" ]; then attach_client "$id" || id=""; fi
        if [ -n "$id" ]; then sync_share_addr "$id" "$remark" "$tag" || true; fi   # и название со страной
      elif [ "$kind" = "busy" ]; then id="busy"
      fi
    done < "$WORK/pe.tsv"
    if [ "$id" = "busy" ]; then ylw "    Выход ${n}: порт ${port} занят другим подключением — отдельного подключения не будет."; continue; fi
    if [ -z "$id" ]; then
      if [ "$want" != "xhttp" ]; then
        create_ws_inbound "$port" "$remark" "$((10 + 2 * n))" "$tag" || continue
      else
        create_xhttp_inbound "$port" "$remark" "$((10 + 2 * n))" "$tag" || continue
      fi
      if attach_client "$MK_ID"; then
        id="$MK_ID"
      else
        continue
      fi
    fi
    set_sort "$id" "$((10 + 2 * n))"     # рядом с прямым подключением к тому же серверу
    PEXIT_ID[$n]="$id"
    PEXIT_LIST="${PEXIT_LIST:+${PEXIT_LIST}, }«${remark}» — порт ${port}"
    if command -v ufw >/dev/null 2>&1; then ufw allow "${port}/tcp" >/dev/null 2>&1 || true; fi
  done
  # настоящие метки этих подключений — на них опираются маршруты «подключение → свой выход»
  api GET /inbounds/list > "$WORK/inbounds-pe2.json" || return 0
  while read -r id rtag; do
    for n in "${!PEXIT_ID[@]}"; do
      if [ "${PEXIT_ID[$n]}" = "$id" ]; then PEXIT_TAG[$n]="$rtag"; fi
    done
  done < <(python3 -c 'import json,sys
for ib in json.load(open(sys.argv[1])).get("obj") or []:
    print(ib["id"], ib.get("tag") or "-")' "$WORK/inbounds-pe2.json" 2>/dev/null || true)
}
if ensure_exit_inbounds && [ -n "$PEXIT_LIST" ]; then
  grn "    Отдельные подключения к каждому выходу: ${PEXIT_LIST}."
fi

# Порядок в подписке: «Автовыбор», XHTTP, Reality, WebSocket, Hysteria2, затем выходы по отдельности.
set_sort "$INB_ID" 3
if [ "$XHTTP_OK" = "1" ]; then set_sort "$XHTTP_ID" 2; fi
if [ "$WS_OK" = "1" ]; then set_sort "$WS_ID" 4; fi
if [ "$HY2_OK" = "1" ]; then set_sort "$HY2_ID" 5; fi

# «Автовыбор» — профиль со всеми подключениями сразу: приложение само проверяет пинг каждого
# раз в минуту и ведёт трафик через лучшие (как в коммерческих VPN). Сколько лучших работают
# одновременно и какой пинг — предел, дописывает фильтр подписки (шаг с подпиской).
AUTO_OK=0
ensure_autoselect() {
  local ids=() id bid args=() n
  if [ "$VPN_ROLE" = "exit" ]; then return 0; fi
  if [ "$XHTTP_OK" = "1" ]; then ids+=("$XHTTP_ID"); fi
  if [ -n "${INB_ID:-}" ] && [ "$INB_ID" != "-" ]; then ids+=("$INB_ID"); fi
  if [ "$WS_OK" = "1" ]; then ids+=("$WS_ID"); fi
  if [ "$HY2_OK" = "1" ]; then ids+=("$HY2_ID"); fi
  if [ "$ALT_OK" = "1" ]; then ids+=("$ALT_ID"); fi
  for n in "${EXIT_OK_N[@]}"; do
    if [ -n "${PEXIT_ID[$n]:-}" ]; then ids+=("${PEXIT_ID[$n]}"); fi
    if [ -n "${DIRECT_ID[$n]:-}" ]; then ids+=("${DIRECT_ID[$n]}"); fi
  done
  if [ "${#ids[@]}" -lt 2 ]; then return 0; fi
  api GET /sub-balancers > "$WORK/sb.json" || return 1
  bid="$(NAME="$AUTO_LABEL" python3 -c 'import json,os,sys
d = json.load(open(sys.argv[1]))
print(next((str(b["id"]) for b in (d.get("obj") or []) if b.get("remark") == os.environ["NAME"]), ""))' "$WORK/sb.json" 2>/dev/null || true)"
  args=("remark=${AUTO_LABEL}" "strategy=leastLoad" "sortOrder=1" "enabled=true")
  for id in "${ids[@]}"; do args+=("inboundIds=${id}"); done
  if [ -n "$bid" ]; then
    api_form "/sub-balancers/${bid}" "${args[@]}" > "$WORK/sb-res.json" || return 1
  else
    api_form "/sub-balancers" "${args[@]}" > "$WORK/sb-res.json" || return 1
  fi
  if api_ok "$WORK/sb-res.json" >/dev/null; then AUTO_OK=1; AUTO_COUNT="${#ids[@]}"; fi
}
AUTO_COUNT=0

# ============================================================================
route_of() {   # route_of домен — куда сервер отправит этот сайт (метка выхода в Xray)
  local _
  for _ in 1 2 3 4 5; do
    if api_form /xray/routeTest "domain=$1" "port=443" "network=tcp" "inboundTag=${INB_TAG}" > "$WORK/route.json" \
       && python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
if not d.get("success"): sys.exit(1)
print((d.get("obj") or {}).get("outboundTag") or "-")' "$WORK/route.json" 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "?"
}
tunnel_test() {   # tunnel_test файл-выхода — настоящий запрос через этот выход (временный Xray); итог в T_IP и T_SPEED
  local port u ip="" _ urls=()
  T_IP=""; T_SPEED=""
  read -ra urls <<< "$TUNNEL_TEST_URLS"
  port=$(( (RANDOM % 20000) + 20000 ))
  python3 - "$1" "$port" > "$WORK/tunnel.json" <<'PY' || return 0
import json, sys
print(json.dumps({"log": {"loglevel": "warning"},
                  "inbounds": [{"listen": "127.0.0.1", "port": int(sys.argv[2]), "protocol": "socks",
                                "settings": {"udp": False}}],
                  "outbounds": [json.load(open(sys.argv[1]))]}))
PY
  "$XRAY_BIN" run -c "$WORK/tunnel.json" > "$WORK/tunnel.log" 2>&1 &
  TUNNEL_PID=$!
  for _ in $(seq 1 20); do
    if tcp_ok 127.0.0.1 "$port"; then break; fi
    sleep 0.5
  done
  for u in "${urls[@]}"; do
    ip="$(env -u no_proxy -u NO_PROXY curl -s --max-time 15 -x "socks5h://127.0.0.1:${port}" "$u" 2>/dev/null \
      | tr -d '[:space:]' || true)"
    if is_ipv4 "$ip"; then T_IP="$ip"; break; fi
  done
  if [ -n "$T_IP" ]; then T_SPEED="$(speed_mbit "socks5h://127.0.0.1:${port}")"; fi
  kill "$TUNNEL_PID" 2>/dev/null || true
  wait "$TUNNEL_PID" 2>/dev/null || true
  TUNNEL_PID=""
}

if [ "$VPN_ROLE" = "exit" ]; then
  step "Настраиваю Xray на скорость..."
elif [ "$BRIDGE" = "1" ]; then
  step "Настраиваю маршруты сервера: РФ — напрямую, остальное — через ${EXIT_TEXT}..."
elif [ "$BLOCK_ADS" = "1" ]; then
  step "Включаю фильтр рекламы и трекеров на сервере..."
else
  step "Фильтр рекламы на сервере выключен (BLOCK_ADS=0)..."
fi
# Мост: каждый выход (TCP и XHTTP) проверяем настоящими запросами. У каждого сервера основной
# канал — тот, что быстрее на деле, второй — запасной (если основной заблокируют). Сервер сам
# ведёт трафик через лучшие выходы (BALANCE_EXPECTED сразу) и отключает медленные и с потерями.
BRIDGE_OUTS=(); BRIDGE_FALLBACK=""; BRIDGE_PREF=""; BRIDGE_ALT=""; POOL_SERVERS=0; TUNNEL_IP=""; TUNNEL_SPEED=""
declare -A LEG_IP=() LEG_SPEED=()
if [ "$BRIDGE" = "1" ]; then
  grn "    Проверяю выходы моста настоящими запросами..."
  best_sp=-1
  for n in "${EXIT_OK_N[@]}"; do
    tunnel_test "$WORK/out-${n}.json"; LEG_IP[$n]="$T_IP"; LEG_SPEED[$n]="$T_SPEED"
    if [ -s "$WORK/out-${n}-x.json" ]; then
      tunnel_test "$WORK/out-${n}-x.json"; LEG_IP[$n-x]="$T_IP"; LEG_SPEED[$n-x]="$T_SPEED"
    fi
    # XHTTP вдвое медленнее TCP того же сервера — его не берём
    if [ -n "${LEG_IP[$n]:-}" ] && [ -n "${LEG_IP[$n-x]:-}" ] && [ -n "${LEG_SPEED[$n]:-}" ] \
       && [ -n "${LEG_SPEED[$n-x]:-}" ] && [ $(( ${LEG_SPEED[$n-x]} * 2 )) -lt "${LEG_SPEED[$n]}" ]; then
      LEG_IP[$n-x]="slow"
    fi
    t_ok=0; x_ok=0; pref=""; alt=""
    if [ -n "${LEG_IP[$n]:-}" ]; then t_ok=1; fi
    if [ -n "${LEG_IP[$n-x]:-}" ] && [ "${LEG_IP[$n-x]}" != "slow" ]; then x_ok=1; fi
    if [ "$t_ok" = "1" ] && [ "$x_ok" = "1" ]; then
      if [ "${LEG_SPEED[$n-x]:-0}" -gt "${LEG_SPEED[$n]:-0}" ]; then pref="x"; alt="t"; else pref="t"; alt="x"; fi
    elif [ "$t_ok" = "1" ]; then pref="t"
    elif [ "$x_ok" = "1" ]; then pref="x"
    fi
    if [ -n "$pref" ]; then
      POOL_SERVERS=$((POOL_SERVERS + 1))
      for leg in $pref $alt; do
        if [ "$leg" = "t" ]; then BRIDGE_OUTS+=("$WORK/out-${n}.json"); else BRIDGE_OUTS+=("$WORK/out-${n}-x.json"); fi
      done
      BRIDGE_PREF+="${n}:bridge-exit-${n}-${pref} "
      if [ -n "$alt" ]; then BRIDGE_ALT+="bridge-exit-${n}-${alt} "; fi
      if [ "$pref" = "t" ]; then k="$n"; else k="$n-x"; fi
      sp="${LEG_SPEED[$k]:-0}"
      if [ -z "$BRIDGE_FALLBACK" ] || [ "$sp" -gt "$best_sp" ]; then BRIDGE_FALLBACK="bridge-exit-${n}-${pref}"; best_sp="$sp"; fi
    fi
    for k in "$n" "$n-x"; do
      if [ -z "${LEG_IP[$k]:-}" ] || [ "${LEG_IP[$k]:-}" = "slow" ]; then continue; fi
      if [ -z "$TUNNEL_IP" ]; then TUNNEL_IP="${LEG_IP[$k]}"; fi
      if [ -n "${LEG_SPEED[$k]:-}" ]; then
        if [ -z "$TUNNEL_SPEED" ] || [ "${LEG_SPEED[$k]}" -gt "$TUNNEL_SPEED" ]; then TUNNEL_SPEED="${LEG_SPEED[$k]}"; fi
      fi
    done
  done
  if [ "${#BRIDGE_OUTS[@]}" -eq 0 ]; then   # ни один выход не ответил — оставляем TCP-выходы, проверка в конце покажет
    for n in "${EXIT_OK_N[@]}"; do
      BRIDGE_OUTS+=("$WORK/out-${n}.json"); BRIDGE_PREF+="${n}:bridge-exit-${n}-t "; POOL_SERVERS=$((POOL_SERVERS + 1))
    done
    BRIDGE_FALLBACK="bridge-exit-${EXIT_OK_N[0]}-t"
  fi
fi
# сколько выходов работают одновременно: не больше BALANCE_EXPECTED и не больше, чем их есть
POOL_EXPECTED="$BALANCE_EXPECTED"
if [ "$POOL_SERVERS" -gt 0 ] && [ "$POOL_EXPECTED" -gt "$POOL_SERVERS" ]; then POOL_EXPECTED="$POOL_SERVERS"; fi
PEXIT_MAP=""
for n in "${EXIT_OK_N[@]}"; do
  if [ -n "${PEXIT_TAG[$n]:-}" ] && [ "${PEXIT_TAG[$n]}" != "-" ]; then PEXIT_MAP+="${PEXIT_TAG[$n]}:${n} "; fi
done
# Выход моста: российская панель будет управлять этим сервером как своим узлом — её запросы
# приходят по мосту (только через подключения моста) и попадают в панель этого сервера.
PANEL_LOCAL_PORT=""; PANEL_LOCAL_TAGS=""
if [ "$VPN_ROLE" = "exit" ] && [ -n "$NODE_TOKEN" ] && api GET /inbounds/list > "$WORK/inb-tags.json"; then
  PANEL_LOCAL_TAGS="$(IDS="${INB_ID:-} ${XHTTP_ID:-}" python3 -c 'import json, os, sys
ids = set(os.environ["IDS"].split())
print(" ".join(ib["tag"] for ib in json.load(open(sys.argv[1])).get("obj") or [] if str(ib.get("id")) in ids and ib.get("tag")))' \
    "$WORK/inb-tags.json" 2>/dev/null || true)"
  if [ -n "$PANEL_LOCAL_TAGS" ]; then PANEL_LOCAL_PORT="$PANEL_PORT"; fi
fi
# Правила в маршрутизации самого сервера: даже приложение, которое не умеет
# принимать правила из подписки, не получит рекламу через VPN. В режиме моста
# российские сайты сервер открывает сам, а всё остальное отправляет за рубеж.
SERVER_FILTER=0
FILTER_STATE=""
if api POST /xray/ > "$WORK/xray-get.json" && api_ok "$WORK/xray-get.json" >/dev/null; then
  FILTER_STATE="$(BLOCK_ADS="$BLOCK_ADS" BLOCK_QUIC="$BLOCK_QUIC" BRIDGE="$BRIDGE" \
    BRIDGE_OUTS="${BRIDGE_OUTS[*]:-}" BRIDGE_FALLBACK="$BRIDGE_FALLBACK" PEXIT_MAP="$PEXIT_MAP" \
    BRIDGE_PREF="$BRIDGE_PREF" BRIDGE_ALT="$BRIDGE_ALT" POOL_EXPECTED="$POOL_EXPECTED" MAX_RTT="$BALANCE_MAX_RTT" \
    PANEL_LOCAL_PORT="$PANEL_LOCAL_PORT" PANEL_LOCAL_TAGS="$PANEL_LOCAL_TAGS" \
    python3 - "$WORK/xray-get.json" "$WORK/xray-new.json" <<'PY' || echo "error"
import json, os, sys
obj = json.load(open(sys.argv[1]))["obj"]
if isinstance(obj, str):          # панель отдаёт настройки строкой с JSON внутри
    obj = json.loads(obj)
tpl = obj["xraySetting"]
if isinstance(tpl, str):
    tpl = json.loads(tpl)
before = json.dumps(tpl, sort_keys=True)
rules = tpl.setdefault("routing", {}).setdefault("rules", [])
outs = tpl.setdefault("outbounds", [])
tags = {o.get("tag") for o in outs}
ADS, EXIT = "geosite:category-ads-all", "bridge-exit"
POOL = EXIT + "-"
is_ads = lambda r: r.get("domain") == [ADS] and r.get("outboundTag") == "blocked"
is_ru = lambda r: r.get("outboundTag") == "direct" and (
    r.get("domain") == ["geosite:category-ru"] or r.get("ip") == ["geoip:ru"])
is_quic = lambda r: r.get("network") == "udp" and str(r.get("port")) == "443" and r.get("outboundTag") == "blocked"
# свои прежние правила убираем и ставим заново — повторный запуск ничего не дублирует
ours_exit = lambda r: (str(r.get("outboundTag") or "").startswith(EXIT)
                       or str(r.get("balancerTag") or "").startswith("bridge"))
PANEL = "vpn-panel"            # выход моста: путь российской панели к панели этого сервера
rules[:] = [r for r in rules if not is_ads(r) and not is_ru(r) and not is_quic(r) and not ours_exit(r)
            and r.get("outboundTag") != PANEL]
outs[:] = [o for o in outs if not str(o.get("tag") or "").startswith(EXIT) and o.get("tag") != PANEL]
routing = tpl["routing"]
balancers = [b for b in routing.get("balancers") or [] if not str(b.get("tag") or "").startswith("bridge")]
if balancers:
    routing["balancers"] = balancers
else:
    routing.pop("balancers", None)
for key in ("observatory", "burstObservatory"):
    if (tpl.get(key) or {}).get("subjectSelector") in ([EXIT], [POOL]):
        tpl.pop(key)
pos = next((i + 1 for i, r in enumerate(rules) if r.get("outboundTag") == "api"), 0)
add = []
if os.environ.get("PANEL_LOCAL_PORT") and os.environ.get("PANEL_LOCAL_TAGS"):
    # российская панель управляет этим сервером как своим узлом: её запросы идут по мосту и попадают
    # в панель этого сервера, которая из интернета не видна (слушает только 127.0.0.1)
    outs.append({"tag": PANEL, "protocol": "freedom", "settings": {"finalRules": [{"action": "allow"}]}})
    add.append({"type": "field", "inboundTag": os.environ["PANEL_LOCAL_TAGS"].split(), "ip": ["127.0.0.1"],
                "port": os.environ["PANEL_LOCAL_PORT"], "outboundTag": PANEL})
if os.environ["BLOCK_ADS"] == "1":
    if "blocked" not in tags:
        print("no-blocked-outbound"); raise SystemExit
    add.append({"type": "field", "domain": [ADS], "outboundTag": "blocked"})
if os.environ["BLOCK_QUIC"] == "1":
    # QUIC (UDP 443) внутри TCP-туннеля работает медленно; без него браузеры и YouTube сразу берут TCP
    if "blocked" not in tags:
        print("no-blocked-outbound"); raise SystemExit
    add.append({"type": "field", "network": "udp", "port": "443", "outboundTag": "blocked"})
# прямой выход: сайты по IPv4, без задержек на неработающий IPv6
for o in outs:
    if o.get("tag") == "direct" and o.get("protocol") == "freedom":
        (o.get("settings") or {}).pop("domainStrategy", None)      # устаревшее место настройки
        o.setdefault("streamSettings", {}).setdefault("sockopt", {})["domainStrategy"] = "UseIPv4"
if os.environ["BRIDGE"] == "1":
    if "direct" not in tags:
        print("no-direct-outbound"); raise SystemExit
    add.append({"type": "field", "domain": ["geosite:category-ru"], "outboundTag": "direct"})
    add.append({"type": "field", "ip": ["geoip:ru"], "outboundTag": "direct"})
    files = os.environ["BRIDGE_OUTS"].split()
    if not files:
        print("no-exits"); raise SystemExit
    loaded = [json.load(open(f)) for f in files]
    outs.extend(loaded)
    pref = dict(x.split(":", 1) for x in os.environ.get("BRIDGE_PREF", "").split())
    alt = os.environ.get("BRIDGE_ALT", "").split()
    def least_load(expected):
        # leastLoad: из живых каналов с пингом меньше maxRTT и почти без потерь берёт expected самых
        # стабильных и делит между ними соединения; запасной канал сервера — только если основной плох
        s = {"expected": expected, "maxRTT": os.environ["MAX_RTT"], "tolerance": 0.25}
        if alt:
            s["costs"] = [{"regexp": True, "match": "^(%s)$" % "|".join(alt), "value": 10000}]
        return {"type": "leastLoad", "settings": s}
    # у каждого выхода с двумя каналами — свой балансировщик bridge-N: по нему идут его отдельное
    # подключение и управление этим сервером из панели (узел)
    per_exit = {}
    for n in pref:
        legs = [o["tag"] for o in loaded if o["tag"].startswith("%s-%s-" % (EXIT, n))]
        if len(legs) > 1:
            routing.setdefault("balancers", []).append({"tag": "bridge-%s" % n, "selector": ["%s-%s-" % (EXIT, n)],
                                                        "strategy": least_load(1), "fallbackTag": pref[n]})
            per_exit[n] = {"balancerTag": "bridge-%s" % n}
        elif legs:
            per_exit[n] = {"outboundTag": legs[0]}
    # отдельное подключение к выходу N ведёт только через этот выход (его TCP- и XHTTP-каналы)
    for pair in os.environ.get("PEXIT_MAP", "").split():
        itag, n = pair.rsplit(":", 1)
        if n in per_exit:
            rules.append(dict({"type": "field", "inboundTag": [itag]}, **per_exit[n]))
    if len(files) > 1:
        # сервер ведёт трафик через лучшие выходы сразу (проверка каждые 15 секунд); отказал один — работают другие
        routing.setdefault("balancers", []).append({"tag": "bridge", "selector": [POOL],
                                                    "strategy": least_load(int(os.environ["POOL_EXPECTED"])),
                                                    "fallbackTag": os.environ["BRIDGE_FALLBACK"]})
        tpl["burstObservatory"] = {"subjectSelector": [POOL],
                                   "pingConfig": {"destination": "http://www.gstatic.com/generate_204",
                                                  "interval": "15s", "sampling": 4, "timeout": "5s"}}
        rules.append({"type": "field", "network": "tcp,udp", "balancerTag": "bridge"})   # всё остальное — за рубеж
    else:
        rules.append({"type": "field", "network": "tcp,udp",
                      "outboundTag": outs[-1]["tag"]})   # всё остальное — за рубеж
rules[pos:pos] = add
if json.dumps(tpl, sort_keys=True) == before:
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
  if [ "$BLOCK_ADS" = "1" ] && [ "$VPN_ROLE" != "exit" ]; then grn "    Сервер блокирует рекламу и трекеры для всего VPN-трафика."; fi
  if [ "$BRIDGE" = "1" ]; then grn "    Российские сайты сервер открывает сам, остальное — через ${EXIT_TEXT}."; fi
  if [ "$BLOCK_QUIC" = "1" ]; then grn "    Для скорости: QUIC переведён на TCP, сайты открываются по IPv4 без ожидания IPv6."
  else grn "    Для скорости: сайты открываются по IPv4 без ожидания IPv6."; fi
elif [ "$BRIDGE" = "1" ]; then
  die "Не удалось записать маршруты моста в настройки сервера (${FILTER_STATE:-панель не ответила})."
else
  ylw "    Не удалось изменить правила сервера — фильтр будет работать только в приложениях."
fi

# ============================================================================
if [ "$VPN_ROLE" = "exit" ]; then   # зарубежный сервер моста готов: отдаём параметры российскому
  if [ -f "$WHITE_CONF" ] || [ -f "$WHITE_TIMER" ]; then white_remove; fi   # подписку выход не отдаёт — белые списки ему не нужны
  step "Проверяю скорость интернета этого сервера..."
  EXIT_NET_SPEED="$(speed_mbit)"
  if [ -n "$EXIT_NET_SPEED" ]; then grn "    Скорость интернета этого сервера ≈ ${EXIT_NET_SPEED} Мбит/с"
  else ylw "    Скорость измерить не удалось."; fi
  EXIT_CC="$(ip_country "$SERVER_IP")"   # страна по IP — российский сервер подпишет ей подключение
  if [ -n "$EXIT_CC" ]; then grn "    Страна сервера по IP: $(cc_title "$EXIT_CC")"; fi
  # FreeTurn (VPN через звонки VK): при мосте он здесь — выход в интернет у этого сервера
  EXIT_FT=""; EXIT_FT_ERR=""
  if [ "$FREETURN" = "1" ]; then
    step "FreeTurn — VPN через звонки VK: ставлю сервер..."
    if freeturn_setup "$SERVER_IP"; then
      EXIT_FT="$FT_LINK"
      grn "    FreeTurn работает: UDP-порт ${FREETURN_PORT}, WireGuard внутри сервера."
    else
      EXIT_FT_ERR="${FT_ERR:-причина неизвестна}"
      ylw "    FreeTurn не установился: ${EXIT_FT_ERR}"
    fi
  elif freeturn_remove; then
    grn "    FreeTurn убран (FREETURN=0)."
  fi
  umask 077
  cat > "$PROFILE" <<TXT
=== Этот сервер — выход моста ===
Принимает подключения российского сервера на порту ${VPN_PORT} (VLESS + Reality, SNI ${SNI})$([ "$XHTTP_OK" = "1" ] && echo " и ${XHTTP_PORT} (XHTTP)").
Настраивается с российского сервера тем же скриптом (режим «Мост»).
Российская панель управляет этим сервером как своим узлом: клиенты, трафик и лимиты — там.

=== Веб-панель 3X-UI (открыта только изнутри сервера) ===
Открыть с компьютера: ssh -L 8080:127.0.0.1:${PANEL_PORT} ${EXIT_LOGIN:-root}@${SERVER_IP}
и затем в браузере:   ${API_SCHEME}://127.0.0.1:8080/${WEBPATH}
Логин:  ${PANEL_USER}
Пароль: ${PANEL_PASS}
TXT
  chmod 600 "$PROFILE"
  grn "    Панель закрыта от интернета, доступы к ней — в ${PROFILE} на этом сервере."
  SERVER_IP="$SERVER_IP" VPN_PORT="$VPN_PORT" UUID="$UUID" CLIENT_FLOW="$CLIENT_FLOW" SNI="$SNI" \
  PUBLIC_KEY="$PUBLIC_KEY" SHORT_ID="$SHORT_ID" NET_SPEED="$EXIT_NET_SPEED" XHTTP_OK="$XHTTP_OK" \
  XHTTP_PORT="$XHTTP_PORT" XHTTP_PBK="$XHTTP_PBK" XHTTP_SID="$XHTTP_SID" XHTTP_SNI="$XHTTP_SNI" \
  XHTTP_PATH="$XHTTP_PATH" EXIT_CC="$EXIT_CC" PANEL_LOCAL_PORT="$([ "$SERVER_FILTER" = "1" ] && echo "$PANEL_LOCAL_PORT")" \
  PANEL_PATH="/${WEBPATH}/" NODE_TOKEN="$NODE_TOKEN" INB_TAG="$INB_TAG" BRIDGE_EMAIL="$CLIENT_EMAIL" \
  FT="$EXIT_FT" FT_ERR="$EXIT_FT_ERR" python3 -c 'import json, os
e = os.environ
p = {"host": e["SERVER_IP"], "port": int(e["VPN_PORT"]), "id": e["UUID"],
     "flow": e["CLIENT_FLOW"], "sni": e["SNI"], "pbk": e["PUBLIC_KEY"], "sid": e["SHORT_ID"], "fp": "chrome",
     "speed": e["NET_SPEED"]}
if e["FT"]:
    p["freeturn"] = e["FT"]          # ссылка для приложения FreeTurn (VPN через звонки VK) на этот сервер
elif e["FT_ERR"]:
    p["freeturn_err"] = e["FT_ERR"]
if e["EXIT_CC"]:
    p["cc"] = e["EXIT_CC"]
if e["PANEL_LOCAL_PORT"] and e["NODE_TOKEN"]:
    # панель этого сервера (видна только по мосту): российская панель подключит его как свой узел
    p["panel"] = {"port": int(e["PANEL_LOCAL_PORT"]), "path": e["PANEL_PATH"], "token": e["NODE_TOKEN"],
                  "tag": e["INB_TAG"], "bridge": e["BRIDGE_EMAIL"]}
if e["XHTTP_OK"] == "1":
    p["xhttp"] = {"port": int(e["XHTTP_PORT"]), "pbk": e["XHTTP_PBK"], "sid": e["XHTTP_SID"],
                  "sni": e["XHTTP_SNI"], "path": e["XHTTP_PATH"]}
print("VPN_EXIT_PARAMS=" + json.dumps(p))'
  exit 0
fi

# ============================================================================
# УЗЛЫ. Каждый зарубежный сервер становится узлом этой панели: клиенты, их трафик и лимиты
# ведутся здесь, а у каждого сервера в подписке появляется прямое подключение (телефон → сервер,
# без России) — к его основному подключению на порту 443, которым пользуется и мост. Панели
# зарубежных серверов из интернета не видны: эта панель обращается к ним по мосту.
declare -A DIRECT_ID=() NODE_ID=() NODE_OUT=()
DIRECT_LIST=""; NODE_OK_COUNT=0
nodes_json() { api GET /nodes/list > "$WORK/nodes.json" 2>/dev/null && api_ok "$WORK/nodes.json" >/dev/null; }
wait_node_synced() {   # wait_node_synced ID — ждём (до 30 с), пока узел на связи получит изменения этой панели
  local _ st
  for _ in $(seq 1 15); do
    api GET "/nodes/get/$1" > "$WORK/node-st.json" 2>/dev/null || return 0
    st="$(python3 -c 'import json,sys
n = json.load(open(sys.argv[1])).get("obj") or {}
print("wait" if n.get("status") == "online" and n.get("configDirty") else "ok")' "$WORK/node-st.json" 2>/dev/null || echo "ok")"
    [ "$st" = "wait" ] || return 0
    sleep 2
  done
}
remove_node() {   # remove_node ID — узел больше не нужен: отцепляем его, сам сервер не трогаем
  local id="$1" ib email bridges
  api GET /inbounds/list > "$WORK/inb-node.json" || return 1
  # клиенты мостов (bridge-…) этой панели после отключения узла не нужны
  bridges="$(NODE="$id" python3 -c 'import json, os, sys
for ib in json.load(open(sys.argv[1])).get("obj") or []:
    if str(ib.get("nodeId") or "") == os.environ["NODE"]:
        s = ib.get("settings")
        s = json.loads(s) if isinstance(s, str) and s else (s or {})
        for c in s.get("clients") or []:
            if str(c.get("email") or "").startswith("bridge-"):
                print(c["email"])' "$WORK/inb-node.json" 2>/dev/null | sort -u || true)"
  for ib in $(NODE="$id" python3 -c 'import json, os, sys
for ib in json.load(open(sys.argv[1])).get("obj") or []:
    if str(ib.get("nodeId") or "") == os.environ["NODE"]:
        print(ib["id"])' "$WORK/inb-node.json" 2>/dev/null || true); do
    # клиент этой панели больше не подключается к серверу напрямую (мост сервера не трогаем)
    printf '{"inboundIds":[%s]}' "$ib" > "$WORK/detach.json"
    api POST "/clients/${CLIENT_EMAIL}/detach" "$WORK/detach.json" >/dev/null 2>&1 || true
  done
  wait_node_synced "$id"
  # выключенный узел изменения больше не получает: записи о его подключениях удаляются только здесь
  printf '{"enable":false}' > "$WORK/node-off.json"
  api POST "/nodes/setEnable/${id}" "$WORK/node-off.json" >/dev/null 2>&1 || true
  for ib in $(NODE="$id" python3 -c 'import json, os, sys
for ib in json.load(open(sys.argv[1])).get("obj") or []:
    if str(ib.get("nodeId") or "") == os.environ["NODE"]:
        print(ib["id"])' "$WORK/inb-node.json" 2>/dev/null || true); do
    api POST "/inbounds/del/${ib}" >/dev/null 2>&1 || true
  done
  api POST "/nodes/del/${id}" > "$WORK/node-del.json" 2>/dev/null && api_ok "$WORK/node-del.json" >/dev/null || return 1
  for email in $bridges; do api POST "/clients/del/${email}" >/dev/null 2>&1 || true; done
}
cleanup_nodes() {   # наши узлы (exit-ХОСТ), чьих серверов больше нет в списке выходов (или узлы выключены)
  local id name host keep h
  nodes_json || return 0
  while read -r id name; do
    host="${name#exit-}"; keep=0
    if [ "$BRIDGE" = "1" ] && [ "$EXIT_DIRECT" = "1" ]; then
      for h in "${EXIT_HOSTS[@]}"; do if [ "$h" = "$host" ]; then keep=1; fi; done
    fi
    if [ "$keep" = "0" ]; then
      if remove_node "$id"; then ylw "    Узел ${host} отключён от этой панели (сам сервер не тронут)."; fi
    fi
  done < <(python3 -c 'import json, sys
for x in json.load(open(sys.argv[1])).get("obj") or []:
    if str(x.get("name") or "").startswith("exit-"):
        print(x["id"], x["name"])' "$WORK/nodes.json" 2>/dev/null || true)
}
ensure_nodes() {
  local n pf id res _ pending legs f pair
  # управление узлом идёт по мосту: через балансировщик выхода (два канала) или его единственный канал
  for pair in $BRIDGE_PREF; do
    n="${pair%%:*}"; legs=0
    for f in "${BRIDGE_OUTS[@]}"; do
      case "$f" in "$WORK/out-${n}.json"|"$WORK/out-${n}-x.json") legs=$((legs + 1)) ;; esac
    done
    if [ "$legs" -gt 1 ]; then NODE_OUT[$n]="bridge-${n}"; else NODE_OUT[$n]="${pair#*:}"; fi
  done
  for n in "${EXIT_OK_N[@]}"; do
    pf="$WORK/panel-${n}.json"
    if [ ! -s "$pf" ] || [ -z "${NODE_OUT[$n]:-}" ]; then
      if [ "${X_ACT[$n]:-}" = "setup" ] && [ "${X_RC[$n]:-1}" = "0" ]; then
        ylw "    $(exit_base "$n"): сервер не открыл свою панель для этой — прямое подключение не настроено (подробности — выше, на шаге 3)."
      else
        ylw "    $(exit_base "$n"): прямое подключение появится после настройки этой версией скрипта — укажите в EXIT_HOST его пароль (root:пароль@${EX_HOST[$n]})."
      fi
      continue
    fi
    nodes_json || return 1
    id="$(NAME="exit-${EX_HOST[$n]}" REMARK="$(exit_title "$n")" OUT="${NODE_OUT[$n]}" \
      python3 - "$pf" "$WORK/nodes.json" "$WORK/node-req.json" <<'PY' 2>/dev/null || echo "error"
import json, os, sys
panel = json.load(open(sys.argv[1]))
cur = next((x for x in json.load(open(sys.argv[2])).get("obj") or [] if x.get("name") == os.environ["NAME"]), None) or {}
tags = list(cur.get("inboundTags") or [])          # уже выбранные подключения узла сохраняем
if panel.get("tag") and panel["tag"] not in tags:
    tags.append(panel["tag"])                     # основное подключение сервера (порт 443) ведёт эта панель
json.dump({"name": os.environ["NAME"], "remark": os.environ["REMARK"], "scheme": "http", "address": "127.0.0.1",
           "port": int(panel["port"]), "basePath": panel.get("path") or "/", "apiToken": panel["token"],
           "enable": True, "allowPrivateAddress": True, "tlsVerifyMode": "skip",
           "inboundSyncMode": "selected", "inboundTags": tags, "outboundTag": os.environ["OUT"]},
          open(sys.argv[3], "w"), ensure_ascii=False)
print(cur.get("id") or 0)
PY
)"
    case "$id" in
      error) ylw "    $(exit_base "$n"): не удалось подготовить узел."; continue ;;
      0) api POST /nodes/add "$WORK/node-req.json" > "$WORK/node-res.json" || true ;;
      *) api POST "/nodes/update/${id}" "$WORK/node-req.json" > "$WORK/node-res.json" || true ;;
    esac
    # при добавлении панель сразу проверяет связь; если не вышло — узел всё равно создан
    nodes_json || return 1
    id="$(NAME="exit-${EX_HOST[$n]}" python3 -c 'import json, os, sys
print(next((x["id"] for x in json.load(open(sys.argv[1])).get("obj") or [] if x.get("name") == os.environ["NAME"]), ""))' \
      "$WORK/nodes.json" 2>/dev/null || true)"
    if [ -z "$id" ]; then
      ylw "    $(exit_base "$n"): панель не приняла узел: $(api_ok "$WORK/node-res.json" || true)"
      continue
    fi
    NODE_ID[$n]="$id"
  done
  [ "${#NODE_ID[@]}" -gt 0 ] || return 0
  # ждём, пока узлы выйдут на связь и панель примет их основные подключения (обычно 10–30 секунд)
  for _ in $(seq 1 40); do
    nodes_json || true
    api GET /inbounds/list > "$WORK/inb-all.json" 2>/dev/null || true
    pending=0
    for n in "${!NODE_ID[@]}"; do
      res="$(NODE="${NODE_ID[$n]}" PORT="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("port") or "")' "$WORK/exit-${n}.json" 2>/dev/null || true)" \
        TAG="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("tag") or "")' "$WORK/panel-${n}.json" 2>/dev/null || true)" \
        python3 - "$WORK/nodes.json" "$WORK/inb-all.json" <<'PY' 2>/dev/null || echo "wait"
import json, os, sys
e = os.environ
node = next((x for x in json.load(open(sys.argv[1])).get("obj") or [] if str(x.get("id")) == e["NODE"]), {})
if node.get("status") != "online":
    print("wait"); raise SystemExit
for ib in json.load(open(sys.argv[2])).get("obj") or []:
    if str(ib.get("nodeId") or "") != e["NODE"] or ib.get("protocol") != "vless":
        continue
    if ib.get("tag") in (e["TAG"], "n%s-%s" % (e["NODE"], e["TAG"])) or str(ib.get("port")) == e["PORT"]:
        print(ib["id"]); break
else:
    print("wait")
PY
)"
      if [ "$res" = "wait" ]; then pending=1; else DIRECT_ID[$n]="$res"; fi
    done
    [ "$pending" = "1" ] || break
    sleep 3
  done
  for n in "${!NODE_ID[@]}"; do
    if [ -z "${DIRECT_ID[$n]:-}" ]; then
      ylw "    $(exit_base "$n"): узел пока не на связи — прямое подключение появится, когда он ответит (запустите скрипт ещё раз)."
      continue
    fi
    # название в подписке, клиент этой панели на подключении сервера, место в списке
    # адрес в ссылке — сам зарубежный сервер (панель узла видна этой панели только по мосту, на 127.0.0.1)
    sync_share_addr "${DIRECT_ID[$n]}" "$(exit_base "$n") (напрямую)" "" "${EX_HOST[$n]}" || true
    attach_client "${DIRECT_ID[$n]}" >/dev/null 2>&1 || true
    set_sort "${DIRECT_ID[$n]}" "$((11 + 2 * n))"
    NODE_OK_COUNT=$((NODE_OK_COUNT + 1))
    DIRECT_LIST="${DIRECT_LIST:+${DIRECT_LIST}, }«$(exit_base "$n") (напрямую)»"
  done
}
if [ "$BRIDGE" = "1" ] && [ "$EXIT_DIRECT" = "1" ]; then
  step "Подключаю зарубежные серверы к этой панели: узлы и прямые подключения..."
  cleanup_nodes
  if ensure_nodes && [ "$NODE_OK_COUNT" -gt 0 ]; then
    grn "    Узлы этой панели: ${NODE_OK_COUNT} шт. — клиенты, трафик и лимиты всех серверов ведутся здесь."
    grn "    Прямые подключения: ${DIRECT_LIST}."
  fi
else
  cleanup_nodes
fi
AUTO_COUNT=0
if ensure_autoselect && [ "$AUTO_OK" = "1" ]; then
  grn "    «${AUTO_LABEL}»: в подписке профиль со всеми подключениями (${AUTO_COUNT} шт.) — приложение само выбирает лучшие."
fi

# ============================================================================
if [ "$BLOCK_ADS" = "1" ]; then
  step "Включаю подписку: РФ — напрямую, реклама — блок, остальное — VPN..."
else
  step "Включаю подписку: РФ — напрямую, остальное — VPN..."
fi
# Белые списки: программа, настройки и таймер (сам список скачивается и проверяется после подписки)
if [ "$WHITE_ON" = "1" ]; then
  if white_setup; then WHITE_READY=1; else ylw "    Не удалось настроить белые списки — подписка будет без них."; fi
elif [ -f "$WHITE_CONF" ] || [ -f "$WHITE_TIMER" ]; then
  white_remove
  grn "    Белые списки убраны (WHITE_LISTS=0): в подписке их больше не будет."
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
# Фильтр подписки: панель 3X-UI не умеет задавать «Автовыбору» максимальный пинг и число
# одновременно работающих подключений. Фильтр стоит перед панелью на порту подписки и дописывает
# эти настройки в каждый ответ (остальное отдаёт как есть); панель отдаёт подписку только ему.
# Он же добавляет в подписку рабочие подключения белых списков (программа — write_sub_filter_program).
setup_sub_filter() {   # ставит и запускает фильтр; ждёт, пока через него ответит панель
  local _ code scheme=http certf="" keyf="" py
  py="$(command -v python3)"
  write_sub_filter_program
  if [ "$SSL_OK" = "1" ]; then certf="$CERT"; keyf="$KEY"; scheme=https; fi
  PORT="$SUB_PORT" UP="$SUB_INTERNAL_PORT" CERTF="$certf" KEYF="$keyf" EXPECTED="$BALANCE_EXPECTED" \
  MAX_RTT="$BALANCE_APP_RTT" TUNE="$SUB_FILTER" python3 - > "$SUB_FILTER_CONF" <<'PY' || return 1
import json, os
e = os.environ
print(json.dumps({"port": int(e["PORT"]), "upstream": int(e["UP"]), "cert": e["CERTF"], "key": e["KEYF"],
                  # expected — сколько лучших подключений работают сразу; maxRTT — предельный пинг;
                  # tolerance — допустимая доля неудачных проверок (как в профилях коммерческих VPN).
                  # SUB_FILTER=0, а фильтр нужен только для белых списков — «Автовыбор» не трогаем
                  "leastLoad": {"expected": int(e["EXPECTED"]), "maxRTT": e["MAX_RTT"], "tolerance": 0.3}
                  if e["TUNE"] == "1" else {}},
                 indent=1))
PY
  sub_filter_conf_white "$WHITE_READY" || return 1   # белые списки: файл с рабочими и отдельный адрес
  sub_filter_conf_clash "$MIHOMO" || return 1         # профиль Mihomo: автовыбор, белые списки, автопереключение
  chmod 600 "$SUB_FILTER_CONF"
  cat > "$SUB_FILTER_UNIT" <<UNIT
[Unit]
Description=VPN subscription filter: auto-select tuning and white lists
After=network-online.target x-ui.service
Wants=network-online.target

[Service]
ExecStart=${py} ${SUB_FILTER_PY} ${SUB_FILTER_CONF}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable vpn-sub-filter >/dev/null 2>&1 || true
  systemctl restart vpn-sub-filter >/dev/null 2>&1 || return 1
  for _ in $(seq 1 20); do
    code="$(curl -sk --noproxy '*' --max-time 5 -o /dev/null -w '%{http_code}' "${scheme}://127.0.0.1:${SUB_PORT}/" 2>/dev/null || true)"
    case "$code" in ""|000|502) sleep 1 ;; *) return 0 ;; esac
  done
  return 1
}
FILTER=0
if { [ "$SUB_FILTER" = "1" ] && [ "$AUTO_OK" = "1" ]; } || [ "$WHITE_READY" = "1" ]; then
  FILTER=1
  for p in "$VPN_PORT" "$XHTTP_PORT" "$WS_PORT" "$SUB_PORT" "$PANEL_PORT" 80; do
    if [ "$SUB_INTERNAL_PORT" = "$p" ]; then FILTER=0; fi
  done
fi
systemctl stop x-ui
if [ -f "$SUB_FILTER_UNIT" ]; then systemctl stop vpn-sub-filter >/dev/null 2>&1 || true; fi   # прежний фильтр держит порт подписки
if [ "$SSL_OK" = "1" ]; then
  # одна команда ставит сертификат и на панель, и на сервер подписки
  "$XUI_BIN" setting -webCert "$CERT" -webCertKey "$KEY" >/dev/null 2>&1 || SSL_OK=0
elif [[ "$("$XUI_BIN" setting -getCert 2>/dev/null || true)" =~ cert:\ *[^[:space:]] ]]; then
  # старый сертификат (например, на прежний домен) не подходит для работы по IP
  "$XUI_BIN" cert -reset >/dev/null 2>&1 || true
fi
if [ "$SSL_OK" = "1" ]; then SUB_BASE="https://${ADDR}:${SUB_PORT}"; else SUB_BASE="http://${ADDR}:${SUB_PORT}"; fi
write_sub_settings() {   # write_sub_settings 1|0 — подписку отдаёт фильтр (а панель — только ему) или сама панель
  DB="$DB" ROUTING="$ROUTING" SUB_PORT="$SUB_PORT" TITLE="$LABEL" FILTER="$1" INTERNAL="$SUB_INTERNAL_PORT" \
  SUB_BASE="$SUB_BASE" python3 - > "$WORK/paths" <<'PY' || return 1
import json, os, secrets, sqlite3
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
    "subPath": sub_path,
    "subTitle": os.environ["TITLE"],
    "subJsonEnable": "true",
    "subJsonPath": json_path,
    # v2rayNG / v2rayN по обычной ссылке сразу получают Xray-конфиги с правилами
    "subJsonAutoDetect": "true",
    # Happ, v2rayNG и v2rayN получают полные Xray-конфиги: в них «Автовыбор» и правила маршрутизации
    "subJsonUserAgentRegex": r"(?i)^(v2rayng|v2rayn|happ)/",
    # «Автовыбор»: пинг каждого подключения раз в минуту (как в профилях коммерческих VPN)
    "subJsonObservatory": json.dumps({"destination": "http://www.gstatic.com/generate_204",
                                      "interval": "1m", "sampling": 3, "timeout": "6s"}),
    "remarkTemplate": "{{INBOUND}}",     # в приложении — просто название подключения
    # правила для конфигов JSON-подписки; пустой subRoutingRules => этот же
    # профиль уходит в Happ заголовком "routing" и включается сам
    "subJsonRoutingRules": os.environ["ROUTING"],
    "subRoutingRules": "",
    "subEnableRouting": "true",
}
base = os.environ["SUB_BASE"]
if os.environ["FILTER"] == "1":
    settings.update({
        "subListen": "127.0.0.1",                 # панель отдаёт подписку только фильтру,
        "subPort": os.environ["INTERNAL"],        # на внутреннем порту и без шифрования
        "subCertFile": "", "subKeyFile": "",
        "subURI": base + sub_path,                # а в панели ссылки — на внешний адрес фильтра
        "subJsonURI": base + json_path,
    })
else:
    settings["subPort"] = os.environ["SUB_PORT"]
    if get("subListen") == "127.0.0.1":           # раньше подписку отдавал фильтр
        settings["subListen"] = ""
    for key, path in (("subURI", sub_path), ("subJsonURI", json_path)):
        if get(key).rstrip("/").endswith(path.rstrip("/")):
            settings[key] = ""
if get("webListen") in ("127.0.0.1", "::1", "localhost"):   # сервер раньше был выходом моста
    settings["webListen"] = ""
for key, value in settings.items():
    cur.execute("UPDATE settings SET value=? WHERE key=?", (value, key))
    if cur.rowcount == 0:
        cur.execute("INSERT INTO settings (key, value) VALUES (?, ?)", (key, value))
con.commit()
con.close()
print(sub_path, json_path)
PY
  # профиль Mihomo (Tunnel, FlClash, Clash Meta): включить или выключить в панели
  clash_db_update "$1" > "$WORK/clash" 2>/dev/null || printf '0 -\n' > "$WORK/clash"
}
write_sub_settings "$FILTER" || { systemctl start x-ui || true; die "Не удалось записать настройки подписки в базу панели."; }
read -r SUB_PATH JSON_PATH < "$WORK/paths"
read -r _ CLASH_PATH < "$WORK/clash" || CLASH_PATH="-"
systemctl start x-ui
wait_api || die "Панель не запустилась после настройки подписки. Логи: journalctl -u x-ui -e"
FILTER_TUNE=0   # 1 — фильтр дописывает «Автовыбору» тонкие настройки
if [ "$FILTER" = "1" ]; then
  if setup_sub_filter; then
    if [ "$SUB_FILTER" = "1" ] && [ "$AUTO_OK" = "1" ]; then
      FILTER_TUNE=1
      grn "    Фильтр подписки: «${AUTO_LABEL}» ведёт трафик через лучшие подключения (одновременно — ${BALANCE_EXPECTED}), пинг больше ${APP_RTT_TEXT} или потери — подключение отключается."
    fi
    if [ "$WHITE_READY" = "1" ]; then grn "    Фильтр подписки добавляет в неё рабочие подключения белых списков."; fi
  else
    ylw "    Фильтр подписки не запустился — подписку отдаёт сама панель$([ "$AUTO_OK" = "1" ] && echo ", «${AUTO_LABEL}» без тонких настроек")$([ "$WHITE_READY" = "1" ] && echo ", белых списков в ней не будет")."
    systemctl stop vpn-sub-filter >/dev/null 2>&1 || true
    systemctl disable vpn-sub-filter >/dev/null 2>&1 || true
    rm -f "$SUB_FILTER_UNIT"
    systemctl stop x-ui
    if [ "$SSL_OK" = "1" ]; then "$XUI_BIN" setting -webCert "$CERT" -webCertKey "$KEY" >/dev/null 2>&1 || true; fi
    FILTER=0
    write_sub_settings 0 || true
    systemctl start x-ui
    wait_api || die "Панель не запустилась после настройки подписки. Логи: journalctl -u x-ui -e"
  fi
elif [ -f "$SUB_FILTER_UNIT" ]; then   # фильтр больше не нужен
  systemctl disable vpn-sub-filter >/dev/null 2>&1 || true
  rm -f "$SUB_FILTER_UNIT"
  systemctl daemon-reload >/dev/null 2>&1 || true
fi

# ============================================================================
# Белые списки для мобильного интернета: скачать список и проверить каждое подключение сейчас,
# дальше — по таймеру (новый список каждые WHITE_REFRESH_HOURS ч, проверка каждые WHITE_CHECK_MIN мин).
WHITE_URL_SUB=""
if [ "$WHITE_ON" = "1" ]; then
  step "Белые списки для мобильного интернета: скачиваю списки и проверяю каждое подключение (несколько минут)..."
  if [ "$WHITE_READY" = "1" ] && [ "$FILTER" = "1" ]; then
    white_run_now
    white_timer_on || ylw "    Таймер проверки не запустился: systemctl status vpn-white-lists.timer"
    WHITE_URL_SUB="${SUB_BASE}$(white_path)"
    grn "    Новые списки — каждые ${WHITE_REFRESH_HOURS} ч; проверка: все — раз в час, рабочие — каждые ${WHITE_CHECK_MIN} мин; в подписке только рабочие."
  elif [ "$WHITE_READY" = "1" ]; then
    ylw "    Фильтр подписки не работает (причина — выше) — белые списки в подписку не попадут."
    systemctl disable --now vpn-white-lists.timer >/dev/null 2>&1 || true
  else
    ylw "    Белые списки не настроены (причина — выше)."
  fi
fi

# ============================================================================
# FreeTurn — VPN через звонки VK (приложение FreeTurn для Android). При мосте он стоит на зарубежных
# серверах (там выход в интернет), здесь — только на одиночном сервере.
FT_LINKS=()        # «название|ссылка freeturn://»
if [ "$FREETURN" = "1" ] && [ "$BRIDGE" != "1" ]; then
  step "FreeTurn — VPN через звонки VK (работает и при белых списках): ставлю сервер..."
  if freeturn_setup "$SERVER_IP"; then
    FT_LINKS+=("|${FT_LINK}")
    grn "    FreeTurn работает: UDP-порт ${FREETURN_PORT}, WireGuard внутри сервера. Ссылка для приложения — в итоге."
  else
    ylw "    FreeTurn не установился: ${FT_ERR:-причина неизвестна}."
    tail -n 3 "$WORK/ft.log" 2>/dev/null | sed 's/^/    │ /' || true
  fi
elif [ "$FREETURN" = "0" ] && freeturn_remove; then
  grn "    FreeTurn убран (FREETURN=0)."
elif [ "$FREETURN" = "1" ] && [ -s "$WORK/exits.jsonl" ]; then   # мост: FreeTurn — на зарубежных серверах
  while IFS= read -r ft_line; do
    case "$ft_line" in
      !*) ft_line="${ft_line#!}"; ylw "    FreeTurn на ${ft_line%%|*} не установился: ${ft_line#*|}" ;;
      *) FT_LINKS+=("$ft_line") ;;
    esac
  done < <(freeturn_exit_links "$WORK/exits.jsonl")
fi

# ============================================================================
if [ "$BRIDGE" = "1" ]; then step "Проверяю подписку, фильтры и мост..."; else step "Проверяю подписку и фильтры..."; fi
SUB_URL="${SUB_BASE}${SUB_PATH}${SUB_ID}"
JSON_URL="${SUB_BASE}${JSON_PATH}${SUB_ID}"
CLASH_URL=""; TUNNEL_URL=""
if [ "$MIHOMO" = "1" ] && [ "${CLASH_PATH:--}" != "-" ]; then
  CLASH_URL="${SUB_BASE}${CLASH_PATH}${SUB_ID}"
  TUNNEL_URL="$(tunnel_link "$CLASH_URL")"
fi
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
if fetch_local "Happ/3.0" "${SUB_PATH}${SUB_ID}" && AUTO_OK="$AUTO_OK" FILTER="$FILTER_TUNE" \
   MAX_RTT="$BALANCE_APP_RTT" python3 - "$WORK/b" <<'PY' 2>/dev/null
import json, os, sys
data = json.load(open(sys.argv[1]))
assert isinstance(data, list) and data
for conf in data:
    rules = json.dumps(conf.get("routing", {}))
    assert "geosite:category-ru" in rules and "geoip:ru" in rules
if os.environ["AUTO_OK"] == "1":
    auto = [c for c in data if (c.get("routing") or {}).get("balancers") and c.get("burstObservatory")]
    assert auto
    if os.environ["FILTER"] == "1":      # тонкие настройки «Автовыбора» дописаны фильтром
        st = auto[0]["routing"]["balancers"][0]["strategy"]
        assert st["type"] == "leastLoad" and st["settings"]["maxRTT"] == os.environ["MAX_RTT"]
PY
then
  CHECK_HAPP=1
fi
JSON_COUNT=0
if fetch_local "v2rayNG/1.10.0" "${SUB_PATH}${SUB_ID}" && BLOCK_ADS="$BLOCK_ADS" \
   WLABEL="$([ "$WHITE_READY" = "1" ] && printf '%s' "$WHITE_LABEL")" python3 - "$WORK/b" "$WORK/client" > "$WORK/client-count" <<'PY'
import json, os, sys
data = json.load(open(sys.argv[1]))
confs = data if isinstance(data, list) else [data]
own = white = 0
for i, conf in enumerate(confs):
    rules = json.dumps(conf.get("routing", {}))
    assert "geosite:category-ru" in rules and "geoip:ru" in rules
    if os.environ["BLOCK_ADS"] == "1":
        assert "geosite:category-ads-all" in rules
    if os.environ["WLABEL"] and str(conf.get("remarks") or "").startswith(os.environ["WLABEL"]):
        white += 1
        if white > 2:        # белые списки собраны из того же шаблона — Xray проверяет пару из них
            continue
    else:
        own += 1
    json.dump(conf, open("%s-%d.json" % (sys.argv[2], i), "w"))
print(own)
PY
then
  # те же конфиги, что получит телефон (обычный и XHTTP), проверяем самим Xray
  CHECK_JSON=1
  read -r JSON_COUNT < "$WORK/client-count" || JSON_COUNT=0
  for f in "$WORK"/client-*.json; do
    if ! XRAY_LOCATION_ASSET="${XUI_DIR}/bin" "$XRAY_BIN" run -test -c "$f" >"$WORK/xtest.log" 2>&1; then
      CHECK_JSON=0; break
    fi
  done
fi
# проверяем маршруты на самом сервере (без реального трафика)
CHECK_SERVER="skip"
if [ "$BLOCK_ADS" = "1" ] && [ "$SERVER_FILTER" = "1" ] && [ "${INB_TAG:--}" != "-" ]; then
  if [ "$(route_of doubleclick.net)" = "blocked" ]; then CHECK_SERVER="ok"; else CHECK_SERVER="fail"; fi
fi
CHECK_ROUTES="skip"; SERVER_SPEED=""
if [ "$BRIDGE" = "1" ]; then
  CHECK_ROUTES="fail"
  if [ "${INB_TAG:--}" != "-" ] && [[ "$(route_of www.google.com)" == bridge-exit* ]] \
     && [ "$(route_of ya.ru)" = "direct" ]; then
    CHECK_ROUTES="ok"
  fi
else
  SERVER_SPEED="$(speed_mbit)"   # один сервер: сколько даёт его интернет
fi
if [ "$CHECK_HAPP" = "1" ]; then
  if [ "$FILTER_TUNE" = "1" ]; then
    grn "    ✓ Happ: в подписке «${AUTO_LABEL}» (лучших сразу — ${BALANCE_EXPECTED}, пинг до ${APP_RTT_TEXT}) и каждое подключение отдельно, правила внутри каждого"
  elif [ "$AUTO_OK" = "1" ]; then grn "    ✓ Happ: в подписке «${AUTO_LABEL}» и каждое подключение отдельно, правила внутри каждого"
  else grn "    ✓ Happ: правила приходят вместе с подпиской"; fi
else ylw "    ✗ Happ: правила в ответе подписки не найдены"; fi
if [ "$CHECK_JSON" = "1" ]; then grn "    ✓ v2rayNG / v2rayN: конфиги с правилами (${JSON_COUNT} шт.) прошли проверку Xray"
else ylw "    ✗ v2rayNG / v2rayN: конфиг не прошёл проверку"; tail -n 3 "$WORK/xtest.log" 2>/dev/null || true; fi
if [ "$WHITE_READY" = "1" ] && [ "$FILTER" = "1" ]; then
  if [ "$SSL_OK" = "1" ]; then LOCAL_SUB="https://127.0.0.1:${SUB_PORT}${SUB_PATH}${SUB_ID}"; else LOCAL_SUB="http://127.0.0.1:${SUB_PORT}${SUB_PATH}${SUB_ID}"; fi
  WA=0
  read -r WJ WB WA <<< "$(white_in_sub "$LOCAL_SUB")" || true
  if [ "${WJ:-0}" -gt 0 ] || [ "${WB:-0}" -gt 0 ]; then
    grn "    ✓ Белые списки: в подписке рабочих подключений: ${WJ} — для Happ / v2rayNG / v2rayN, ${WB} — для остальных приложений"
    if [ "${WA:-0}" -gt 0 ]; then grn "    ✓ Автоподбор: «${WHITE_AUTO_NAME}» — телефон сам выбирает лучший из своей сети (серверов в профиле: ${WA})"; fi
  elif [ "$WHITE_ALIVE" -eq 0 ]; then
    ylw "    ✗ Белые списки: рабочих подключений пока нет — появятся после следующей полной проверки (раз в час)"
  else
    ylw "    ✗ Белые списки: рабочие подключения есть (${WHITE_ALIVE}), но в подписке их не видно (journalctl -u vpn-sub-filter -e)"
  fi
  read -r PN PX <<< "$(white_phone_check "${LOCAL_SUB%%"${SUB_PATH}${SUB_ID}"}$(white_path)test/")" || true
  if [ "${PN:--}" != "-" ]; then
    grn "    ✓ Проверка с телефона: страница работает (серверов для проверки: ${PN}$([ "${PX:-0}" = 1 ] && echo ", Xray для Android — на сервере"))"
  else
    ylw "    ✗ Проверка с телефона: страница не отвечает (journalctl -u vpn-sub-filter -e)"
  fi
fi
if [ -n "$CLASH_URL" ]; then
  if [ "$SSL_OK" = "1" ]; then LOCAL_CLASH="https://127.0.0.1:${SUB_PORT}${CLASH_PATH}${SUB_ID}"; else LOCAL_CLASH="http://127.0.0.1:${SUB_PORT}${CLASH_PATH}${SUB_ID}"; fi
  read -r MP MW MF <<< "$(mihomo_check "$LOCAL_CLASH")" || true
  if [ "${MP:--}" != "-" ] && [ "${MP:-0}" -gt 0 ]; then
    grn "    ✓ Tunnel / Mihomo: профиль (подключений: ${MP}$([ "${MW:-0}" -gt 0 ] && echo ", из них белых списков: ${MW}")$([ "${MF:-0}" = 1 ] && echo ", автопереключение VPN → белые списки"))"
  else
    ylw "    ✗ Tunnel / Mihomo: профиль не отвечает (journalctl -u x-ui -e)"; CLASH_URL=""; TUNNEL_URL=""
  fi
fi
grn "    Проверяю каждое подключение настоящим запросом (как у телефона)..."
if [ "$SSL_OK" = "1" ]; then OWN_URL="https://127.0.0.1:${SUB_PORT}${SUB_PATH}${SUB_ID}"; else OWN_URL="http://127.0.0.1:${SUB_PORT}${SUB_PATH}${SUB_ID}"; fi
if own_conn_test "$OWN_URL" "$XRAY_BIN" "$([ "$WHITE_READY" = "1" ] && printf '%s' "$WHITE_LABEL")"; then
  if [ "$OWN_REALITY_FAIL" -gt 0 ] && [ "$OWN_TLS_OK" -gt 0 ]; then
    ylw "    ! Reality не работает даже с сервера, а TLS-подключения работают — проверьте, что ${SNI} открывается с сервера."
  fi
fi
reality_sni_hint "$SERVER_IP" "$SNI"
case "$CHECK_SERVER" in
  ok)   grn "    ✓ Сервер: рекламный домен уходит в блок" ;;
  fail) ylw "    ✗ Сервер: проверка фильтра рекламы не прошла" ;;
esac
if [ "$BRIDGE" = "1" ]; then
  if [ "$CHECK_ROUTES" = "ok" ]; then grn "    ✓ Сервер: российские сайты — напрямую, зарубежные — через ${EXIT_TEXT}"
  else ylw "    ✗ Сервер: маршруты моста не прошли проверку"; fi
  leg_text() {   # leg_text ключ название — «TCP ≈ 120 Мбит/с», «XHTTP работает» или пусто
    local ip="${LEG_IP[$1]:-}" sp="${LEG_SPEED[$1]:-}"
    if [ -z "$ip" ]; then return 0; fi
    if [ "$ip" = "slow" ]; then echo "$2 ≈ ${sp} Мбит/с (медленнее TCP, не используется)"; return 0; fi
    if [ -n "$sp" ]; then echo "$2 ≈ ${sp} Мбит/с"; else echo "$2 работает"; fi
  }
  for n in "${EXIT_OK_N[@]}"; do
    line="$(leg_text "$n" TCP)"; lx="$(leg_text "$n-x" XHTTP)"
    if [ -n "$lx" ]; then line="${line:+${line}, }${lx}"; fi
    if [ -n "$line" ]; then grn "    ✓ Выход ${n} — $(exit_title "$n"): ${line}${EX_RTT[$n]:+, задержка ${EX_RTT[$n]} мс}"
    else ylw "    ✗ Выход ${n} — $(exit_title "$n"): не отвечает"; fi
  done
  for n in "${EXIT_OK_N[@]}"; do
    if [ -z "${DIRECT_ID[$n]:-}" ] || [ ! -s "$WORK/out-${n}.json" ]; then continue; fi
    UUID="$UUID" FLOW="$CLIENT_FLOW" python3 - "$WORK/out-${n}.json" "$WORK/direct-${n}.json" <<'PY' 2>/dev/null || continue
import json, os, sys
o = json.load(open(sys.argv[1]))                     # тот же сервер и порт, но ключ клиента, а не моста
user = o["settings"]["vnext"][0]["users"][0]
user["id"] = os.environ["UUID"]
if os.environ["FLOW"]:
    user["flow"] = os.environ["FLOW"]
else:
    user.pop("flow", None)
o["tag"] = "direct-test"
json.dump(o, open(sys.argv[2], "w"))
PY
    tunnel_test "$WORK/direct-${n}.json"
    if [ -n "$T_IP" ]; then grn "    ✓ $(exit_base "$n") (напрямую): узел принял клиента этой панели, подключение работает"
    else ylw "    ✗ $(exit_base "$n") (напрямую): с этого сервера проверить не удалось — проверьте с телефона"; fi
  done
  if [ -n "$TUNNEL_IP" ]; then
    grn "    ✓ Мост работает: зарубежные сайты видят IP ${TUNNEL_IP}"
    if [ "$POOL_SERVERS" -gt 1 ]; then
      grn "    ✓ Сервер ведёт трафик через лучшие выходы (одновременно — ${POOL_EXPECTED}), проверка каждые 15 секунд; пинг больше ${RTT_TEXT} или потери — выход отключается, работают другие"
    elif [ "${#BRIDGE_OUTS[@]}" -gt 1 ]; then
      grn "    ✓ Сервер сам переключит канал до выхода (TCP ↔ XHTTP), если основной перестанет работать (проверка каждые 15 секунд)"
    fi
  else
    ylw "    ✗ Мост: ни один выход не ответил"; tail -n 3 "$WORK/tunnel.log" 2>/dev/null || true
  fi
elif [ -n "$SERVER_SPEED" ]; then
  grn "    ✓ Скорость интернета сервера ≈ ${SERVER_SPEED} Мбит/с"
fi
# где узкое место, если мост медленный
SPEED_HINT=""
if [ "$BRIDGE" = "1" ] && [ -n "$TUNNEL_SPEED" ]; then
  MAX_NET=""
  for n in "${EXIT_OK_N[@]}"; do
    v="${EX_NET[$n]:-}"
    if [ -n "$v" ] && { [ -z "$MAX_NET" ] || [ "$v" -gt "$MAX_NET" ]; }; then MAX_NET="$v"; fi
  done
  if [ -n "$MAX_NET" ] && [ "$MAX_NET" -lt 50 ]; then
    SPEED_HINT="Узкое место — интернет зарубежных серверов (до ${MAX_NET} Мбит/с): нужен сервер у более быстрого хостера."
  elif [ -n "$MAX_NET" ] && [ "$TUNNEL_SPEED" -lt 100 ] && [ $((TUNNEL_SPEED * 3)) -lt "$MAX_NET" ]; then
    SPEED_HINT="Узкое место — канал из Москвы до зарубежных серверов: сами они быстрые, но через мост скорость падает."
  elif [ "$TUNNEL_SPEED" -ge 50 ]; then
    SPEED_HINT="Серверы работают быстро. Если на телефоне медленно — дело в интернете телефона."
  fi
fi

# ============================================================================
# ============================================================================
# НАБЛЮДЕНИЕ В РЕАЛЬНОМ ВРЕМЕНИ (служба vpn-watch, каждые 2 минуты): сервер сам проверяет свои
# подключения настоящим запросом, смотрит, через какие идёт трафик клиентов, при необходимости меняет
# маскировку запасного XHTTP и выстраивает подписку: первыми — рабочие Reality, затем остальные.
WATCH_PY="/usr/local/bin/vpn-watch.py"
WATCH_CONF="/etc/x-ui/vpn-watch.json"
WATCH_DATA="/var/lib/vpn-watch"
WATCH_MIN="${WATCH_MIN:-2}"
write_watch_program() {
  cat > "$WATCH_PY" <<'PY'
#!/usr/bin/env python3
# Наблюдение за подключениями VPN (ставит install-vpn-all.sh, запускает таймер vpn-watch).
# 1) каждое своё подключение из подписки проверяется настоящим запросом через Xray — как у телефона;
# 2) трафик клиентов по каждому подключению: где он идёт — то подключение у людей работает;
# 3) маскировка запасного XHTTP перестала открываться с сервера — берётся следующий сайт из списка;
# 4) порядок в подписке: рабочие Reality первыми (с трафиком и меньшим пингом — выше), затем остальные.
import json, os, socket, ssl, subprocess, sys, tempfile, time, urllib.parse, urllib.request

CONF = json.load(open(sys.argv[1], encoding="utf-8"))
DATA = CONF.get("data") or "/var/lib/vpn-watch"
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE


def log(text):
    print(text, flush=True)


def api(method, path, body=None, form=None):
    url = CONF["api"].rstrip("/") + path
    headers = {"Authorization": "Bearer " + CONF["token"]}
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"
    elif form is not None:
        data = urllib.parse.urlencode(form).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=30, context=CTX) as r:
        return json.loads(r.read().decode("utf-8"))


def obj(v):
    if isinstance(v, str):
        try:
            return json.loads(v) if v else {}
        except ValueError:
            return {}
    return v or {}


def sni_ok(host):
    """открывается ли сайт-маскировка с сервера по TLS 1.3 (без этого Reality не работает)"""
    try:
        c = ssl.create_default_context()
        c.minimum_version = ssl.TLSVersion.TLSv1_3
        with socket.create_connection((host, 443), timeout=6) as raw:
            with c.wrap_socket(raw, server_hostname=host):
                return True
    except (OSError, ssl.SSLError, ValueError):
        return False


def recv_exact(sock, size):
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise OSError("closed")
        data += chunk
    return data


def probe(port, timeout=10):
    """запрос http://www.gstatic.com/generate_204 через SOCKS 127.0.0.1:port — мс или None"""
    host, start = b"www.gstatic.com", time.monotonic()
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=timeout) as s:
            s.sendall(b"\x05\x01\x00")
            if recv_exact(s, 2) != b"\x05\x00":
                return None
            s.sendall(b"\x05\x01\x00\x03" + bytes([len(host)]) + host + (80).to_bytes(2, "big"))
            head = recv_exact(s, 4)
            if head[1] != 0:
                return None
            size = {1: 4, 4: 16}.get(head[3])
            if size is None:
                size = recv_exact(s, 1)[0]
            recv_exact(s, size + 2)
            s.sendall(b"GET /generate_204 HTTP/1.1\r\nHost: www.gstatic.com\r\nConnection: close\r\n\r\n")
            reply = s.recv(64)
            if not reply.startswith(b"HTTP/") or reply.split()[1][:1] not in (b"2", b"3"):
                return None
            return int((time.monotonic() - start) * 1000)
    except (OSError, IndexError, ValueError):
        return None


def self_test():
    """{название подключения: мс или None} — по подписке, как её получает Happ"""
    req = urllib.request.Request(CONF["sub"], headers={"User-Agent": "Happ/3.0"})
    with urllib.request.urlopen(req, timeout=30, context=CTX) as r:
        data = json.loads(r.read().decode("utf-8"))
    wl, items = CONF.get("wl_label") or "", []
    for c in data if isinstance(data, list) else [data]:
        name = str(c.get("remarks") or "")
        if not name or (wl and name.startswith(wl)) or (c.get("routing") or {}).get("balancers"):
            continue
        proxy = next((o for o in c.get("outbounds") or [] if isinstance(o, dict) and o.get("tag") == "proxy"), None)
        if proxy:
            items.append((name, proxy))
    if not items:
        return {}
    socks, ports = [], []
    for _ in items:
        s = socket.socket()
        s.bind(("127.0.0.1", 0))
        socks.append(s)
        ports.append(s.getsockname()[1])
    for s in socks:
        s.close()
    conf = {"log": {"loglevel": "none"}, "inbounds": [], "outbounds": [], "routing": {"rules": []}}
    for i, ((name, proxy), port) in enumerate(zip(items, ports)):
        conf["inbounds"].append({"tag": "i%d" % i, "listen": "127.0.0.1", "port": port, "protocol": "socks",
                                 "settings": {"udp": False}})
        conf["outbounds"].append(dict(proxy, tag="o%d" % i))
        conf["routing"]["rules"].append({"type": "field", "inboundTag": ["i%d" % i], "outboundTag": "o%d" % i})
    fd, path = tempfile.mkstemp(suffix=".json")
    with os.fdopen(fd, "w") as f:
        json.dump(conf, f)
    proc = subprocess.Popen([CONF["xray"], "run", "-c", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            env=dict(os.environ, XRAY_LOCATION_ASSET=os.path.dirname(CONF["xray"])))
    try:
        time.sleep(1.5)
        result = {}
        for (name, _), port in zip(items, ports):
            ms = probe(port)
            if ms is None:
                ms = probe(port)               # вторая попытка — один сбой ещё не поломка
            result[name] = ms
        return result
    finally:
        proc.terminate()
        try:
            proc.wait(5)
        except subprocess.TimeoutExpired:
            proc.kill()
        os.unlink(path)


def set_sni(ib, sni):
    """новая маскировка Reality у подключения (ключи прежние)"""
    full = api("GET", "/inbounds/get/%s" % ib["id"])["obj"]
    full = obj(full)
    st = obj(full.get("streamSettings"))
    rs = st.setdefault("realitySettings", {})
    rs["serverNames"] = [sni]
    rs.pop("dest", None)
    rs["target"] = sni + ":443"
    full["streamSettings"] = st
    for key in ("settings", "streamSettings", "sniffing"):
        if not isinstance(full.get(key), str):
            full[key] = json.dumps(full.get(key) or {})
    full.pop("clientStats", None)
    r = api("POST", "/inbounds/update/%s" % ib["id"], body=full)
    return bool(r.get("success"))


def main():
    os.makedirs(DATA, exist_ok=True)
    state_path = os.path.join(DATA, "state.json")
    try:
        state = json.load(open(state_path))
    except (OSError, ValueError):
        state = {}
    traffic = state.get("traffic") or {}
    inbounds = api("GET", "/inbounds/list").get("obj") or []
    own = [ib for ib in inbounds if not ib.get("nodeId") and ib.get("enable", True)]
    # 1) трафик клиентов: сколько прошло с прошлой проверки (сглаженно — за последние ~10–20 минут)
    for ib in own:
        key, total = str(ib["id"]), int(ib.get("up") or 0) + int(ib.get("down") or 0)
        prev = traffic.get(key) or {}
        delta = max(0, total - int(prev.get("total") or total))
        traffic[key] = {"total": total, "avg": round(0.7 * float(prev.get("avg") or 0) + delta)}
    # 2) маскировка: у запасного XHTTP — сменить, если сайт перестал открываться; у остальных — сообщить
    for ib in own:
        st = obj(ib.get("streamSettings"))
        if st.get("security") != "reality":
            continue
        sni = ((st.get("realitySettings") or {}).get("serverNames") or [""])[0]
        if not sni or sni_ok(sni):
            continue
        if ib.get("tag") == CONF.get("alt_tag"):
            new = next((d for d in CONF.get("alt_sni") or [] if d != sni and sni_ok(d)), "")
            if new and set_sni(ib, new):
                log("«%s»: маскировка %s перестала открываться — переключил на %s." % (ib.get("remark"), sni, new))
            else:
                log("«%s»: маскировка %s не открывается, замены из списка нет." % (ib.get("remark"), sni))
        else:
            log("«%s»: маскировка %s не открывается с сервера — подключение не будет работать (смените SNI)." % (ib.get("remark"), sni))
    # 3) настоящий запрос через каждое подключение
    try:
        test = self_test()
    except (OSError, ValueError) as err:
        test = {}
        log("Самопроверка не прошла: %s" % err)
    # 4) порядок в подписке: рабочие Reality первыми, затем остальные рабочие, затем нерабочие;
    #    внутри — у кого есть трафик клиентов, затем меньший пинг. Подключения к выходам («через РФ») — как были.
    pexit = CONF.get("pexit_tag") or "vpn-exit-"
    rows = []
    for ib in own:
        if str(ib.get("tag") or "").startswith(pexit):
            continue
        st = obj(ib.get("streamSettings"))
        name = ib.get("remark") or ""
        ms = test.get(name)
        works = ms is not None or name not in test     # не попало в проверку (например, UDP) — не наказываем
        reality = st.get("security") == "reality"
        avg = (traffic.get(str(ib["id"])) or {}).get("avg") or 0
        rows.append(((0 if works else 1, 0 if reality else 1, 0 if avg > 0 else 1, -avg, ms if ms is not None else 10 ** 6),
                     ib, ms, avg, works))
    rows.sort(key=lambda r: r[0])
    changed = []
    for place, (_, ib, ms, avg, works) in enumerate(rows, 2):    # 1 — «Автовыбор»
        if int(ib.get("subSortIndex") or 0) != place:
            try:
                api("POST", "/inbounds/%s/subSortIndex" % ib["id"], form={"subSortIndex": place})
                changed.append(ib.get("remark") or str(ib["id"]))
            except OSError:
                pass
    status = {"time": int(time.time()), "order": [
        {"name": ib.get("remark"), "works": works, "ms": ms, "traffic": avg,
         "reality": obj(ib.get("streamSettings")).get("security") == "reality"} for _, ib, ms, avg, works in rows],
        "tested": test}
    json.dump(status, open(os.path.join(DATA, "status.json"), "w"), ensure_ascii=False, indent=1)
    state["traffic"] = traffic
    json.dump(state, open(state_path, "w"))
    line = " · ".join("%s %s" % ("✓" if r["works"] else "✗", r["name"]) + (" %d мс" % r["ms"] if r["ms"] else "")
                      for r in status["order"])
    log("Порядок: " + line + (" (изменён)" if changed else ""))
    if len(sys.argv) > 2 and sys.argv[2] == "status":
        print(json.dumps(status, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY
  chmod 755 "$WATCH_PY"
}
watch_setup() {   # watch_setup URL-подписки — программа, настройки и таймер службы vpn-watch
  local py
  py="$(command -v python3)"
  write_watch_program
  mkdir -p "$WATCH_DATA"
  API="${API_SCHEME}://127.0.0.1:${PANEL_PORT}/${WEBPATH}/panel/api" TOKEN="$API_TOKEN" XR="$XRAY_BIN" SUB="$1" \
  WL="$([ "$WHITE_READY" = "1" ] && printf '%s' "$WHITE_LABEL")" ALT="$REALITY_ALT_SNI" DATA="$WATCH_DATA" \
  python3 - "$WATCH_CONF" <<'PY' || return 1
import json, os, sys
e = os.environ
json.dump({"api": e["API"], "token": e["TOKEN"], "xray": e["XR"], "sub": e["SUB"], "wl_label": e["WL"],
           "alt_tag": "vpn-reality-alt", "alt_sni": e["ALT"].split(), "pexit_tag": "vpn-exit-", "data": e["DATA"]},
          open(sys.argv[1], "w"), ensure_ascii=False, indent=1)
PY
  chmod 600 "$WATCH_CONF"
  cat > /etc/systemd/system/vpn-watch.service <<UNIT
[Unit]
Description=VPN watch: test every connection, follow client traffic, Reality first in the subscription
After=network-online.target x-ui.service

[Service]
Type=oneshot
ExecStart=${py} ${WATCH_PY} ${WATCH_CONF}
Nice=10
TimeoutStartSec=5min
UNIT
  cat > /etc/systemd/system/vpn-watch.timer <<UNIT
[Unit]
Description=VPN watch every ${WATCH_MIN} minutes

[Timer]
OnActiveSec=1min
OnUnitActiveSec=${WATCH_MIN}min
AccuracySec=15s

[Install]
WantedBy=timers.target
UNIT
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl enable vpn-watch.timer >/dev/null 2>&1 || true
  systemctl restart vpn-watch.timer >/dev/null 2>&1
}
if [ "${WATCH:-1}" != "0" ] && [ -n "${OWN_URL:-}" ]; then
  if watch_setup "$OWN_URL"; then
    grn "    Наблюдение vpn-watch: каждые ${WATCH_MIN} мин сервер проверяет подключения и ставит рабочие Reality первыми."
    "$(command -v python3)" "$WATCH_PY" "$WATCH_CONF" 2>&1 | sed 's/^/    /' || true
  else
    ylw "    Наблюдение vpn-watch не настроилось."
  fi
elif [ -f /etc/systemd/system/vpn-watch.timer ]; then
  systemctl disable --now vpn-watch.timer >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/vpn-watch.timer /etc/systemd/system/vpn-watch.service
  systemctl daemon-reload >/dev/null 2>&1 || true
fi

step "Формирую профиль..."
VLESS_URL="vless://${UUID}@${ADDR}:${VPN_PORT}?type=tcp&encryption=none&security=reality&pbk=${PUBLIC_KEY}&fp=chrome&sni=${SNI}&sid=${SHORT_ID}&spx=%2F${CLIENT_FLOW:+&flow=${CLIENT_FLOW}}#${LABEL}"
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
if [ "$BRIDGE" = "1" ]; then
  echo
  ylw "============================ МОСТ ============================"
  echo "Вход (этот сервер, Россия): ${SERVER_IP}"
  if [ "$POOL_SERVERS" -gt 1 ]; then
    echo "Выходы за рубеж (трафик идёт через лучшие по пингу и стабильности, одновременно — ${POOL_EXPECTED};"
    echo "пинг больше ${RTT_TEXT} или потери — выход отключается, пока не наладится):"
  elif [ "${#EXIT_OK_N[@]}" -gt 1 ]; then echo "Выходы за рубеж:"
  else echo "Выход за рубеж:"; fi
  for n in "${EXIT_OK_N[@]}"; do
    echo "  ${n}) ${EX_NAME[$n]:+${EX_NAME[$n]} — }${EX_HOST[$n]}${EX_RTT[$n]:+ — задержка ${EX_RTT[$n]} мс}${EX_NET[$n]:+, интернет сервера ≈ ${EX_NET[$n]} Мбит/с}"
  done
  if [ -n "$TUNNEL_SPEED" ]; then echo "Скорость через мост: ≈ ${TUNNEL_SPEED} Мбит/с (лучший выход)"; fi
  if [ -n "$SPEED_HINT" ]; then ylw "$SPEED_HINT"; fi
  echo "Российские сайты открываются напрямую, все остальные — через зарубежные серверы."
  if [ "$NODE_OK_COUNT" -gt 0 ]; then
    echo "Зарубежные серверы — узлы этой панели (раздел «Узлы»): клиенты, их трафик и лимиты"
    echo "ведутся здесь. Новому клиенту в панели отметьте и подключения «(напрямую)» — они на узлах."
  fi
  echo "Добавить или убрать выход: запустите скрипт снова, перечислив серверы в EXIT_HOST."
  echo "Панели зарубежных серверов закрыты от интернета, доступы — в ${PROFILE} на каждом."
fi
echo
ylw "========================== ПОДПИСКА =========================="
echo "Добавьте в приложение ЭТУ ссылку (один раз):"
grn "${SUB_URL}"
echo
qrencode -t ANSIUTF8 "${SUB_URL}" 2>/dev/null || ylw "(qrencode недоступен — используйте ссылку)"
echo "Как добавить:"
echo "  • Happ (Android / iPhone / ПК): «+» → вставить ссылку из буфера или отсканировать QR."
echo "  • v2rayNG (Android): «+» → «Импорт из буфера обмена» → «Обновить подписку»."
if [ -n "$TUNNEL_URL" ]; then
  echo "  • Tunnel (Android): ссылка «Открыть в Tunnel» — ниже, в разделе TUNNEL."
  echo "  • FlClash, Clash Meta, Clash Verge: эта же ссылка — они сами получат профиль Mihomo."
fi
if [ "$XHTTP_OK" = "1" ] || [ "$WS_OK" = "1" ] || [ "$HY2_OK" = "1" ] || [ "$AUTO_OK" = "1" ] || [ -n "$WHITE_URL_SUB" ]; then
  echo "Подключения в подписке:"
  if [ "$FILTER_TUNE" = "1" ]; then
    echo "  • «${AUTO_LABEL}» — приложение само ведёт трафик через лучшие подключения (одновременно — ${BALANCE_EXPECTED});"
    echo "    пинг больше ${APP_RTT_TEXT} или потери — подключение отключается (выберите этот профиль);"
  elif [ "$AUTO_OK" = "1" ]; then echo "  • «${AUTO_LABEL}» — приложение само выбирает лучший путь (выберите его);"; fi
  if [ "$XHTTP_OK" = "1" ]; then echo "  • «${XHTTP_LABEL}» — XHTTP: сайты открываются быстрее;"; fi
  echo "  • «${LABEL}» — обычное Reality, запасное;"
  if [ "$WS_OK" = "1" ]; then echo "  • «${WS_LABEL}» — WebSocket + TLS, как «LTE»-профили; через CDN — для режима белых списков;"; fi
  if [ "$ALT_OK" = "1" ]; then echo "  • «${ALT_LABEL}» — запасной XHTTP с маскировкой под ${ALT_SNI}: если обычный XHTTP «н/д», берите его;"; fi
  if [ "$HY2_OK" = "1" ]; then echo "  • «${HY2_LABEL}» — Hysteria2 (QUIC по UDP): быстрее на мобильном интернете с потерями; если оператор режет UDP, не подключится — тогда берите другие;"; fi
  if [ -n "$PEXIT_LIST" ]; then echo "  • через РФ к одному зарубежному серверу, каждый отдельно: ${PEXIT_LIST};"; fi
  if [ -n "$DIRECT_LIST" ]; then echo "  • напрямую к зарубежному серверу (телефон → сервер, без России): ${DIRECT_LIST}."; fi
  if [ -n "$WHITE_URL_SUB" ]; then
    if [ "${WA:-0}" -gt 0 ]; then
      echo "  • «${WHITE_AUTO_NAME}» — белые списки с автоподбором по пингу: телефон сам пингует самые быстрые"
      echo "    (в профиле: ${WA}) и ведёт трафик через самый быстрый из работающих у него (Happ, v2rayNG, v2rayN);"
    fi
    echo "  • «${WHITE_LABEL} …» — в конце списка: белые списки для мобильного интернета (${WHITE_ALIVE} самых быстрых по пингу из ${WHITE_WORKING} рабочих);"
    echo "    включайте их, когда оператор пускает только на «разрешённые» сайты и свой VPN не подключается."
  fi
fi
echo
echo "Правила для всех устройств (приходят с сервера и обновляются сами):"
echo "  • российские сайты и российские IP-адреса → напрямую, через интернет пользователя;"
echo "  • реклама и трекеры → ${ADS_TEXT};"
if [ "$BRIDGE" = "1" ]; then
  echo "  • всё остальное → через VPN: этот сервер → ${EXIT_TEXT}."
else
  echo "  • всё остальное → через VPN."
fi
echo
echo "JSON-вариант той же подписки (для приложений, которым нужен Xray JSON):"
echo "  ${JSON_URL}"
MIHOMO_PROFILE=""
if [ -n "$TUNNEL_URL" ]; then
  echo
  ylw "================ TUNNEL И ДРУГИЕ ПРИЛОЖЕНИЯ НА MIHOMO ================"
  mihomo_text
  MIHOMO_PROFILE="$(printf '\n=== Tunnel и приложения на Mihomo (Clash Meta) ===\n'; mihomo_text)"
fi
FT_PROFILE=""
if [ "${#FT_LINKS[@]}" -gt 0 ]; then
  if [ "$BRIDGE" = "1" ]; then FT_WHERE="на зарубежных серверах моста"; else FT_WHERE="на этом сервере"; fi
  echo
  ylw "======== FREETURN — VPN ЧЕРЕЗ ЗВОНКИ VK (работает и при белых списках) ========"
  freeturn_text "${FT_LINKS[@]}"
  echo "Сервер FreeTurn — ${FT_WHERE}; там же управление: freeturn (ещё клиент: freeturn client add имя)."
  FT_PROFILE="$(printf '\n=== FreeTurn — VPN через звонки VK ===\n'; freeturn_text "${FT_LINKS[@]}"
                echo "Сервер FreeTurn — ${FT_WHERE}; там же управление: freeturn (ещё клиент: freeturn client add имя).")"
fi
WHITE_PROFILE=""
if [ "$WHITE_ON" = "1" ]; then
  echo
  ylw "============ БЕЛЫЕ СПИСКИ ДЛЯ МОБИЛЬНОГО ИНТЕРНЕТА ============"
  if [ "$WHITE_READY" = "1" ] && [ "$FILTER" = "1" ]; then
    white_summary
    WHITE_PROFILE="$(printf '\n=== Белые списки для мобильного интернета ===\n'; white_summary)"
  else
    ylw "Не настроены (причина — выше). Запустите скрипт ещё раз и выберите пункт 3."
  fi
fi
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
if [ "$BRIDGE" = "1" ]; then
  cp "$WORK/bridge.json" "$BRIDGE_FILE" 2>/dev/null || true
  BRIDGE_TEXT="Мост: вход ${SERVER_IP} (этот сервер) → выходы:"
  for n in "${EXIT_OK_N[@]}"; do BRIDGE_TEXT+=" $(exit_title "$n")${EX_RTT[$n]:+ ${EX_RTT[$n]} мс};"; done
  BRIDGE_TEXT="${BRIDGE_TEXT%;}${TUNNEL_SPEED:+; скорость через мост ≈ ${TUNNEL_SPEED} Мбит/с}"
  if [ "$POOL_SERVERS" -gt 1 ]; then
    BRIDGE_TEXT+=$'\n'"Балансировка моста: лучших выходов одновременно — ${POOL_EXPECTED}, пинг до ${RTT_TEXT} (BALANCE_EXPECTED, BALANCE_MAX_RTT)."
  fi
  if [ "$NODE_OK_COUNT" -gt 0 ]; then
    BRIDGE_TEXT+=$'\n'"Узлы этой панели: ${NODE_OK_COUNT} шт. Прямые подключения: ${DIRECT_LIST}."
  fi
else
  rm -f "$BRIDGE_FILE"
  BRIDGE_TEXT="Мост: не используется (один сервер)"
fi
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
${BRIDGE_TEXT}

=== Подключение VLESS + Reality ===
Сервер:    ${ADDR}:${VPN_PORT} (IP ${SERVER_IP})
SNI:       ${SNI}
UUID:      ${UUID}
PublicKey: ${PUBLIC_KEY}
ShortID:   ${SHORT_ID}
XHTTP:     $([ "$XHTTP_OK" = "1" ] && echo "порт ${XHTTP_PORT}, путь ${XHTTP_PATH} (в подписке — первым)" || echo "не настроен")
WebSocket: $([ "$WS_OK" = "1" ] && echo "порт ${WS_PORT}, путь ${WS_PATH}, TLS на ${ADDR}" || echo "не настроен")
Hysteria2: $([ "$HY2_OK" = "1" ] && echo "UDP-порт ${HY2_PORT}, TLS на ${ADDR} (пароль у каждого клиента свой — в подписке)" || echo "не настроен")
Автовыбор: $(if [ "$FILTER_TUNE" = "1" ]; then echo "лучших подключений одновременно — ${BALANCE_EXPECTED}, пинг до ${APP_RTT_TEXT} (настройки дописывает фильтр подписки vpn-sub-filter)"; elif [ "$AUTO_OK" = "1" ]; then echo "есть, без тонких настроек"; else echo "нет"; fi)
Одиночная ссылка (БЕЗ правил подписки — весь трафик через VPN):
${VLESS_URL}
${WHITE_PROFILE}
${MIHOMO_PROFILE}
${FT_PROFILE}
TXT
chmod 600 "$PROFILE"
echo
ylw "Всё сохранено на сервере: ${PROFILE}"
ylw "========================================================="
