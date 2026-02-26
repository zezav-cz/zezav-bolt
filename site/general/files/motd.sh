#!/bin/bash
# Minimalist MOTD without logo: system info + last login
# Works on common Linux distros. Requires: awk, sed, tput, ip, df, ps, who, last/lastlog.

export TERM=xterm-256color

# ---------- colors (fallback to no-color if tput fails) ----------
if tput setaf 1 >/dev/null 2>&1; then
  C0="$(tput sgr0)"
  C1="$(tput setaf 1)"; C2="$(tput setaf 2)"; C3="$(tput setaf 3)"
  C4="$(tput setaf 4)"; C5="$(tput setaf 5)"; C6="$(tput setaf 6)"
else
  C0=""; C1=""; C2=""; C3=""; C4=""; C5=""; C6=""
fi

# ---------- helpers ----------
format_uptime() {
  local s up
  s="$(cut -d. -f1 /proc/uptime)"
  printf "%d days, %02dh%02dm%02ds" "$((s/86400))" "$(( (s/3600)%24 ))" "$(( (s/60)%60 ))" "$(( s%60 ))"
}

# df line formatter (expects: df -h line with fields: Filesystem Size Used Avail Use% Mount)
format_df_line() {
  # shellcheck disable=SC2086
  echo "$1" | awk '{printf "%-25s  %6s / %6s (%5s)  free: %6s\n", $6, $3, $2, $5, $4}'
}

# IPv4 via routing decision (default interface)
ipv4_addr() {
  ip -4 route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}'
}

# IPv6 via routing decision (if available)
ipv6_addr() {
  ip -6 route get 2001:4860:4860::8888 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}'
}

# ---------- system facts ----------
HOST_FQDN="$(hostname -f 2>/dev/null || hostname)"
OS_NAME="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-}" || true)"
KERNEL="$(uname -sr)"
CPU_MODEL="$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || echo "CPU")"
CPUS="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN || echo 1)"
UPTIME="$(format_uptime)"
read LOAD1 LOAD5 LOAD15 _ < /proc/loadavg

# Memory: use MemAvailable for realistic "used"
MEM_TOTAL_KB="$(awk '/MemTotal:/ {print $2}' /proc/meminfo)"
MEM_AVAIL_KB="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
if [[ -z "${MEM_AVAIL_KB}" ]]; then
  # Fallback if MemAvailable not present (very old kernels)
  MEM_AVAIL_KB="$(free -k | awk '/Mem:/ {print $7}')"
fi
MEM_USED_KB="$((MEM_TOTAL_KB - MEM_AVAIL_KB))"
MEM_USED_GB="$(awk -v k="$MEM_USED_KB" 'BEGIN{printf "%.2f", k/1024/1024}')"
MEM_TOTAL_GB="$(awk -v k="$MEM_TOTAL_KB" 'BEGIN{printf "%.2f", k/1024/1024}')"
MEM_PCT="$(awk -v u="$MEM_USED_KB" -v t="$MEM_TOTAL_KB" 'BEGIN{printf "%.1f", (u/t)*100.0}')"

PROCS="$(ps ax --no-headers | wc -l | tr -d ' ')"
USERS_NOW="$(who | awk '{print $1}' | sort -u | wc -l | tr -d ' ')"

IPV4="$(ipv4_addr || true)"
IPV6="$(ipv6_addr || true)"

# ---------- last login for current user ----------
CUR_USER="${SUDO_USER:-$USER}"

# ---------- disk usage (top 3) ----------
# Exclude ephemeral/virtual FS types
mapfile -t DF_LINES < <(df -h -x tmpfs -x devtmpfs -x squashfs -x overlay -x aufs --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2)
DISK_OUT=()
COUNT=0
for line in "${DF_LINES[@]}"; do
  # skip boot, run, kubelet pod dirs, container overlay clutter
  mp="$(echo "$line" | awk '{print $6}')"
  if [[ "$mp" =~ ^/boot|^/run|^/var/lib/kubelet/pods|^/var/lib/containers/storage/overlay ]]; then
    continue
  fi
  DISK_OUT+=("$(format_df_line "$line")")
  COUNT=$((COUNT+1))
  [[ $COUNT -ge 3 ]] && break
done

# ---------- print ----------
echo "${C2}========================= System Information =========================${C0}"
echo "${C2}Hostname           | ${C3}${HOST_FQDN}${C0}"
[[ -n "$OS_NAME" ]] && echo "${C2}OS                 | ${C3}${OS_NAME}${C0}"
echo "${C2}Kernel             | ${C3}${KERNEL}${C0}"
echo "${C2}CPU                | ${C3}${CPUS}${C2} x ${C3}${CPU_MODEL}${C0}"
echo "${C2}Uptime             | ${C3}${UPTIME}${C0}"
echo "${C2}Load (1/5/15)      | ${C3}${LOAD1}${C2}, ${C3}${LOAD5}${C2}, ${C3}${LOAD15}${C0}"
echo "${C2}Memory             | ${C3}${MEM_USED_GB}${C2} GB used (${C3}${MEM_PCT}${C2}%) / ${C3}${MEM_TOTAL_GB}${C2} GB total${C0}"
echo "${C2}Processes          | ${C3}${PROCS}${C0}"
if [[ -n "${IPV4:-}" ]]; then echo "${C2}IPv4               | ${C3}${IPV4}${C0}"; fi
if [[ -n "${IPV6:-}" ]]; then echo "${C2}IPv6               | ${C3}${IPV6}${C0}"; fi
echo "${C2}Logged-in users    | ${C3}${USERS_NOW}${C0}"
if ((${#DISK_OUT[@]})); then
  echo "${C2}------------------------- Disk Usage (top 3) -------------------------${C0}"
  echo "${C2}Disks${C0}"
  for d in "${DISK_OUT[@]}"; do echo "  ${C2}-${C0} ${C3}${d}${C0}"; done
fi
echo "${C2}=======================================================================${C0}"
