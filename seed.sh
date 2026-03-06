#!/bin/bash
set -euo pipefail

SEED_FLAG="/var/lib/lab-grader/seeded"

# run only once
if [ -f "$SEED_FLAG" ]; then
  exit 0
fi

# Uživatelský účet, který se má mazat (aby T02 nebyl hotový hned)
if ! id -u olduser >/dev/null 2>&1; then
  useradd -m olduser
fi

# Připrav pracovní složku vivi
mkdir -p /home/vivi/lab
chown -R vivi:vivi /home/vivi/lab

# temp.txt má existovat a student ho má smazat (T04)
touch /home/vivi/lab/temp.txt
chown vivi:vivi /home/vivi/lab/temp.txt

# Proces, který musí student najít a vypnout (T06)
if [ -f "$SEED_FLAG" ]; then
  exit 0
fi

# vytvoření prostředí

nohup sleep 9999 >/dev/null 2>&1 &

touch "$SEED_FLAG"
# Maze se skrytým souborem + tajným řetězcem (T09, T10)
mkdir -p /home/vivi/maze/a/b/c/d
echo "Tady je tajemství: SECRET123" > /home/vivi/maze/a/b/c/d/hidden_note.txt
chown -R vivi:vivi /home/vivi/maze

# Cíl pro kopii
mkdir -p /home/vivi/found
chown -R vivi:vivi /home/vivi/found

touch "$SEED_FLAG"
chmod 644 "$SEED_FLAG"
