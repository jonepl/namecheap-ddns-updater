#!/bin/bash
ENV_FILE="$(dirname "$0")/.env"
FQDN="$SUBDOMAIN.$DOMAIN"
WILDCARD_IP="143.244.220.150"
MAX_LOG_SIZE=1048576  # 1MB in bytes
LOG_DIR="/var/log/vpn"
LOG_FILE="$LOG_DIR/namecheap-ddns.log"
LOG_BACKUP="$LOG_DIR/namecheap-ddns.log.bak"

ip=""
old_ip=""
ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'

log_message() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a "$LOG_FILE"
}

initialize_env_vars() {
  if [ -e "$ENV_FILE" ]; then
      log_message "INFO" "Setting environment variables for $ENV_FILE file"
      set -o allexport
      . "$ENV_FILE"
      set +o allexport
  else
      log_message "WARN" "No application configurations found."
  fi
}

verify_env_vars() {
  log_message "INFO" "Checking if all required environment variables are set..."
  local required_env_vars=(
    DOMAIN
    SUBDOMAIN
    PASSWORD
  )

  for env_var in "${required_env_vars[@]}"; do
    if [[ -z "${!env_var}" ]]; then
      log_message "ERROR" "The environment variable $env_var is not defined"
      return 1
    fi
  done

  log_message "INFO" "All required environment variables are set."
  return 0
}

create_log_file() {
  # Ensure the log directory exists
  if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR"
    if [[ $? -ne 0 ]]; then
      log_message "ERROR" "Failed to create log directory at $LOG_DIR. Check permissions."
      exit 1
    fi
    log_message "INFO" "Log directory created at $LOG_DIR"
  fi

  if [[ ! -f "$LOG_FILE" ]]; then
    touch "$LOG_FILE"

    if [[ $? -ne 0 ]]; then
      log_message "ERROR" "Failed to create log file at $LOG_FILE. Check permissions."
      exit 1
    fi

    log_message "INFO" "Log file created at $LOG_FILE"
  fi
}

rotate_log_file_if_needed() {
  if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE")" -ge "$MAX_LOG_SIZE" ]; then
    log_message "INFO" "Log file size exceeds $MAX_LOG_SIZE bytes. Rotating log file..."
    [ -f "$LOG_BACKUP" ] && rm "$LOG_BACKUP"
    cp "$LOG_FILE" "$LOG_BACKUP"
    : > "$LOG_FILE"
    log_message "INFO" "Log rotated: $LOG_BACKUP created, $LOG_FILE cleared."
  fi
}


set_fqdn() {
  FQDN="$SUBDOMAIN.$DOMAIN"
  if [[ -z "$FQDN" ]]; then
      log_message "ERROR" "FQDN is not set. Please check SUBDOMAIN and DOMAIN variables."
      exit 1
  fi
  log_message "INFO" "FQDN set to $FQDN"
}

fetch_local_ip() {
  ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip=' | cut -d= -f2)

  if [[ -z "$ip" ]]; then
      # fallback providers
      ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
  fi

  # Validate IP format
  if [[ ! "$ip" =~ ^$ipv4_regex$ ]]; then
      log_message "ERROR" "Invalid IP address detected: $ip"
      exit 1
  fi

  log_message "DEBUG" "Fetched local IP: $ip"
}

fetch_fqdn_ip() {
  old_ip=$(dig +short "$FQDN" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)

  if [[ -z "$old_ip" ]]; then
      log_message "ERROR" "No IP found for $FQDN — the DNS record may not exist."
      exit 1
  fi

  if [[ "$old_ip" == "$WILDCARD_IP" ]]; then
      log_message "WARNING" "$FQDN resolved to wildcard IP ($WILDCARD_IP). DNS record likely doesn't exist."
      exit 2
  fi

  log_message "DEBUG" "Fetched old IP for $FQDN: $old_ip"
}

compare_ips() {
  if [[ "$ip" == "$old_ip" ]]; then
      log_message "INFO" "Remote IP ($ip) has not changed."
      exit 0
  fi

  log_message "INFO" "Remote IP has changed from $old_ip to $ip. Updating DNS record for $FQDN..."
}

update_fqdn_ip() {
  url="https://dynamicdns.park-your-domain.com/update?host=${SUBDOMAIN}&domain=${DOMAIN}&password=${PASSWORD}&ip=${ip}"
  
  if [[ "$DRY_RUN" == "true" ]]; then
      log_message "INFO" "[DRY RUN] Would have updated $FQDN to $ip."
      return
  fi
  
  response=$(curl -s "$url")

  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  if echo "$response" | grep -q "<ErrCount>0</ErrCount>"; then
      log_message "INFO" "[SUCCESS] $FQDN updated to $ip"
  else
      log_message "ERROR" "[FAILURE] Error updating $FQDN"
      echo "$response" >> "$LOG_FILE"
      exit 1
  fi
}

create_log_file

rotate_log_file_if_needed

initialize_env_vars

verify_env_vars

set_fqdn

fetch_local_ip

fetch_fqdn_ip

compare_ips

update_fqdn_ip
