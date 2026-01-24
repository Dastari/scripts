#!/usr/bin/env bash

# Copyright (c) 2021-2026 tteck
# Author: toby (Dastari)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://supabase.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing dependencies"
$STD apt install -y ca-certificates curl git openssl
msg_ok "Installed dependencies"

msg_info "Installing Docker"
$STD sh <(curl -fsSL https://get.docker.com)
msg_ok "Installed Docker"

msg_info "Fetching Supabase Docker files"
if [[ -d /root/supabase ]]; then
  $STD git -C /root/supabase pull --ff-only
else
  cd /root
  $STD git clone --depth 1 https://github.com/supabase/supabase
fi
msg_ok "Fetched Supabase Docker files"

PROJECT_NAME_DEFAULT="${SUPABASE_PROJECT_NAME:-supabase-project}"
PROJECT_DIR="/root/${PROJECT_NAME_DEFAULT}"
mkdir -p "$PROJECT_DIR"
$STD cp -rf /root/supabase/docker/* "$PROJECT_DIR"
$STD cp /root/supabase/docker/.env.example "$PROJECT_DIR/.env"
chmod -R 755 "$PROJECT_DIR"

FIRST_LOGIN="/root/supabase-first-login.sh"
cat <<'EOF' >"$FIRST_LOGIN"
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

BOLD="\033[1m"
CYN="\033[36m"
CL="\033[0m"

repeat_char() {
  local count="$1"
  local char="$2"
  printf "%*s" "$count" "" | tr ' ' "$char"
}

print_table() {
  local title="$1"
  shift
  local -a labels values
  local max_label=0
  local max_value=0
  while [ "$#" -gt 0 ]; do
    labels+=("$1")
    values+=("$2")
    [ "${#1}" -gt "$max_label" ] && max_label="${#1}"
    [ "${#2}" -gt "$max_value" ] && max_value="${#2}"
    shift 2
  done

  local top_len=$((max_label + max_value + 5))
  local top_line
  top_line="$(repeat_char "$top_len" "─")"
  printf "%b╭%s╮%b\n" "$CYN" "$top_line" "$CL"

  local title_pad=$((top_len - ${#title}))
  if [ "$title_pad" -lt 0 ]; then
    title_pad=0
  fi
  printf "%b│%b %b%s%*s%b %b│%b\n" "$CYN" "$CL" "$BOLD" "$title" "$title_pad" "" "$CL" "$CYN" "$CL"

  local sep_left
  local sep_right
  sep_left="$(repeat_char $((max_label + 2)) "─")"
  sep_right="$(repeat_char $((max_value + 2)) "─")"
  printf "%b├%s┬%s┤%b\n" "$CYN" "$sep_left" "$sep_right" "$CL"

  local i
  for i in "${!labels[@]}"; do
    printf "%b│%b %-*s %b│%b %-*s %b│%b\n" \
      "$CYN" "$CL" "$max_label" "${labels[$i]}" \
      "$CYN" "$CL" "$max_value" "${values[$i]}" \
      "$CYN" "$CL"
  done
  printf "%b╰%s╯%b\n" "$CYN" "$top_line" "$CL"
  echo
}

project_default="__PROJECT_DEFAULT__"
read -r -p "Enter Supabase project directory name [${project_default}]: " project_name
project_name=${project_name:-${project_default}}
cd /root/"${project_name}"

db_password=""
while [ -z "$db_password" ]; do
  read -r -s -p "Enter database password (POSTGRES_PASSWORD): " db_password
  echo
done

jwt_secret=$(openssl rand -hex 64)
anon_key=$(openssl rand -hex 32)
service_role_key=$(openssl rand -hex 32)
secret_key_base=$(openssl rand -base64 48)
vault_enc_key=$(openssl rand -hex 16)
pg_meta_crypto_key=$(openssl rand -base64 24)
logflare_public=$(openssl rand -base64 24)
logflare_private=$(openssl rand -base64 24)
ip_addr=$(hostname -I | awk '{print $1}')
public_url="http://${ip_addr}:8000"
api_url="http://${ip_addr}:8000"
site_url="http://${ip_addr}:3000"
dashboard_password=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9')
dashboard_username="supabase"

sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${db_password}/" .env
sed -i "s/^JWT_SECRET=.*/JWT_SECRET=${jwt_secret}/" .env
sed -i "s/^ANON_KEY=.*/ANON_KEY=${anon_key}/" .env
sed -i "s/^SERVICE_ROLE_KEY=.*/SERVICE_ROLE_KEY=${service_role_key}/" .env
sed -i "s/^SECRET_KEY_BASE=.*/SECRET_KEY_BASE=${secret_key_base}/" .env
sed -i "s/^VAULT_ENC_KEY=.*/VAULT_ENC_KEY=${vault_enc_key}/" .env
sed -i "s/^PG_META_CRYPTO_KEY=.*/PG_META_CRYPTO_KEY=${pg_meta_crypto_key}/" .env
sed -i "s/^LOGFLARE_PUBLIC_ACCESS_TOKEN=.*/LOGFLARE_PUBLIC_ACCESS_TOKEN=${logflare_public}/" .env
sed -i "s/^LOGFLARE_PRIVATE_ACCESS_TOKEN=.*/LOGFLARE_PRIVATE_ACCESS_TOKEN=${logflare_private}/" .env
grep -q '^SUPABASE_PUBLIC_URL=' .env || echo "SUPABASE_PUBLIC_URL=${public_url}" >>.env
grep -q '^API_EXTERNAL_URL=' .env || echo "API_EXTERNAL_URL=${api_url}" >>.env
grep -q '^SITE_URL=' .env || echo "SITE_URL=${site_url}" >>.env
sed -i "s/^DASHBOARD_USERNAME=.*/DASHBOARD_USERNAME=${dashboard_username}/" .env
sed -i "s/^DASHBOARD_PASSWORD=.*/DASHBOARD_PASSWORD=${dashboard_password}/" .env

docker compose pull
docker compose up -d

api_url=$(grep -E '^API_EXTERNAL_URL=' .env | cut -d= -f2-)
site_url=$(grep -E '^SITE_URL=' .env | cut -d= -f2-)
db_port=$(grep -E '^POSTGRES_PORT=' .env | cut -d= -f2-)

api_url="${api_url:-${public_url}}"
site_url="${site_url:-http://${ip_addr}:3000}"
db_port="${db_port:-5432}"

studio_url="${site_url}"
mailpit_url="http://${ip_addr}:54324"
mcp_url="${api_url}/mcp"

project_url="${api_url}"
rest_url="${api_url}/rest/v1"
graphql_url="${api_url}/graphql/v1"
functions_url="${api_url}/functions/v1"

db_url="postgresql://postgres:${db_password}@${ip_addr}:${db_port}/postgres"

publishable_key="${anon_key}"
secret_key="${service_role_key}"

storage_url="${api_url}/storage/v1/s3"
storage_access_key=$(openssl rand -hex 20)
storage_secret_key=$(openssl rand -hex 32)
storage_region="local"

print_table "🔧 Development Tools" \
  "Studio" "${studio_url}" \
  "Mailpit" "${mailpit_url}" \
  "MCP" "${mcp_url}"

print_table "🌐 APIs" \
  "Project URL" "${project_url}" \
  "REST" "${rest_url}" \
  "GraphQL" "${graphql_url}" \
  "Edge Functions" "${functions_url}"

print_table "⛁ Database" \
  "URL" "${db_url}"

print_table "🔑 Authentication Keys" \
  "Publishable" "${publishable_key}" \
  "Secret" "${secret_key}"

print_table "📦 Storage (S3)" \
  "URL" "${storage_url}" \
  "Access Key" "${storage_access_key}" \
  "Secret Key" "${storage_secret_key}" \
  "Region" "${storage_region}"

sed -i '/supabase-first-login.sh/d' ~/.bashrc
rm -f ~/supabase-first-login.sh
EOF

sed -i "s/__PROJECT_DEFAULT__/${PROJECT_NAME_DEFAULT}/" "$FIRST_LOGIN"
chmod +x "$FIRST_LOGIN"

if ! grep -q "supabase-first-login.sh" /root/.bashrc; then
  echo "[ -f /root/supabase-first-login.sh ] && /root/supabase-first-login.sh" >>/root/.bashrc
fi
msg_ok "Created first-login helper"

motd_ssh
customize
cleanup_lxc
