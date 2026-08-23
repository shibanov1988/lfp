#!/bin/sh
# Общая часть для post-merge/post-checkout: если изменения затронули src/,
# запускает загрузку конфигурации в локальную базу 1С.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$DIR/../.." && pwd)"
OLD_REV="$1"
NEW_REV="$2"

if [ -z "$OLD_REV" ] || [ -z "$NEW_REV" ]; then
	exit 0
fi

if ! git diff --name-only "$OLD_REV" "$NEW_REV" -- src/ | grep -q .; then
	exit 0
fi

echo "[1C] Обнаружены изменения в src/, обновляю базу..."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$REPO_ROOT/tools/deploy/Update-1C.ps1"
