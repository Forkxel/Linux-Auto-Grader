#!/bin/bash
set -euo pipefail

TASKS_FILE="/opt/lab-grader/tasks.conf"
STATE_FILE="/var/lib/lab-grader/state"
SEED_FLAG="/var/lib/lab-grader/seeded"

init_state() {
  if [ ! -s "$STATE_FILE" ]; then
    : > "$STATE_FILE"
    while IFS='|' read -r id desc; do
      [[ -z "${id:-}" || "${id:0:1}" == "#" ]] && continue
      echo "$id=0" >> "$STATE_FILE"
    done < "$TASKS_FILE"
  fi
}

get_state() {
  local id="$1"
  grep -E "^${id}=" "$STATE_FILE" | tail -n1 | cut -d= -f2 || echo "0"
}

set_state() {
  local id="$1"
  local val="$2"
  if grep -qE "^${id}=" "$STATE_FILE"; then
    sed -i "s/^${id}=.*/${id}=${val}/" "$STATE_FILE"
  else
    echo "${id}=${val}" >> "$STATE_FILE"
  fi
}

announce_done() {
    local id="$1"

    /usr/bin/wall -n "SPLNĚNO: $id"

    sleep 1

    /usr/bin/wall -n "$(sudo /usr/local/bin/lab-status 2>/dev/null)"
}

# ---- Kontroly ----

# T01: testuser existuje + home existuje
check_T01() { id -u testuser >/dev/null 2>&1 && [ -d /home/testuser ]; }

# T02: olduser musí být smazán včetně /home (seed ho vytvoří, takže nezačne jako hotový)
check_T02() {
  [ -f "$SEED_FLAG" ] &&
  ! id -u olduser >/dev/null 2>&1 &&
  [ ! -d /home/olduser ]
}

# T03: file1 existuje a obsahuje přesně LinuxTest (může být i s newline)
check_T03() {
  [ -f /home/vivi/lab/file1.txt ] &&
  grep -qx "LinuxTest" /home/vivi/lab/file1.txt
}

# T04: file2 je kopie file1 a temp.txt neexistuje
check_T04() {
  [ -f /home/vivi/lab/file1.txt ] &&
  [ -f /home/vivi/lab/file2.txt ] &&
  cmp -s /home/vivi/lab/file1.txt /home/vivi/lab/file2.txt &&
  [ ! -f /home/vivi/lab/temp.txt ]
}

# T05: práva lab=0750 a file1=0640 + group root
check_T05() {
  [ -d /home/vivi/lab ] &&
  [ -f /home/vivi/lab/file1.txt ] &&
  [ "$(stat -c %a /home/vivi/lab)" = "750" ] &&
  [ "$(stat -c %a /home/vivi/lab/file1.txt)" = "640" ] &&
  [ "$(stat -c %G /home/vivi/lab/file1.txt)" = "root" ]
}

# T06: proces sleep 9999 už neběží
check_T06() {
  local pidfile="/home/vivi/lab/sleep.pid"


  [ -f "$pidfile" ] || return 1

  local pid
  pid="$(cat "$pidfile" 2>/dev/null | tr -d '[:space:]')"
  echo "$pid" | grep -Eq '^[0-9]+$' || return 1

  kill -0 "$pid" >/dev/null 2>&1 && return 1

  return 0
}

# T07: archiv existuje a obsahuje adresář lab/
check_T07() {
  [ -f /home/vivi/lab-archive.tar.xz ] &&
  tar -tf /home/vivi/lab-archive.tar.xz 2>/dev/null | grep -qE '(^|/)lab(/|$)'
}

# T08: rozbaleno do extracted_lab a existuje file1
check_T08() {
  [ -f /home/vivi/lab-archive.tar.xz ] &&
  [ -f /home/vivi/extracted_lab/lab/file1.txt ]
}

# T09: hidden_note zkopírovaný do found/
check_T09() { [ -f /home/vivi/found/hidden_note.txt ]; }

# T10: grep_result.txt obsahuje cestu k souboru s SECRET123
check_T10() {
  [ -f /home/vivi/grep_result.txt ] &&
  grep -q "hidden_note.txt" /home/vivi/grep_result.txt &&
  grep -q "SECRET123" /home/vivi/maze/a/b/c/d/hidden_note.txt
}

check_T11() {
  getent group project >/dev/null 2>&1 &&
  id -nG testuser 2>/dev/null | grep -qw project &&
  [ "$(stat -c %G /home/vivi/lab 2>/dev/null)" = "project" ] &&
  [ "$(stat -c %a /home/vivi/lab 2>/dev/null)" = "770" ]
}

check_T12() {
  id -u testuser >/dev/null 2>&1 || return 1
  [ -f /var/lib/lab-grader/t12_shadow_before ] || return 1

  local before now
  before="$(cat /var/lib/lab-grader/t12_shadow_before 2>/dev/null)"
  now="$(getent shadow testuser | cut -d: -f3)"

  [ -n "$before" ] && [ -n "$now" ] && [ "$before" != "$now" ]
}

check_T13() {
  command -v mc >/dev/null 2>&1
}

check_T15() {
  local f="/home/vivi/lab/date.txt"
  [ -f "$f" ] || return 1
  grep -Eq '^[0-9]{2}\.[0-9]{2}\.[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}$' "$f"
}

# ---- Loop ----
init_state

while true; do
  if pgrep -f "sleep 9999" >/dev/null 2>&1; then
      touch /var/lib/lab-grader/t06_started
  fi
  if id -u testuser >/dev/null 2>&1 && [ ! -f /var/lib/lab-grader/t12_shadow_before ]; then
      getent shadow testuser | cut -d: -f3 > /var/lib/lab-grader/t12_shadow_before
  fi
  while IFS='|' read -r id desc; do
    [[ -z "${id:-}" || "${id:0:1}" == "#" ]] && continue
    cur="$(get_state "$id")"
    if [ "$cur" != "1" ]; then
      fn="check_${id}"
      if declare -f "$fn" >/dev/null 2>&1; then
        if "$fn"; then
          set_state "$id" "1"
          announce_done "$id"
        fi
      fi
    fi
  done < "$TASKS_FILE"
  sleep 2
done
