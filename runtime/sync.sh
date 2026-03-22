#!/usr/bin/env bash
# sync.sh — Self-update .scaffold/ from upstream scaffold repo
# Usage: bash .scaffold/sync.sh
# Reads .scaffold/upstream.json for repo URL, branch, and last-synced commit.
# Overwrites upstream-owned directories. Never touches .scaffold/project/.

set -euo pipefail

SCAFFOLD_DIR="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM_JSON="$SCAFFOLD_DIR/upstream.json"

if [ ! -f "$UPSTREAM_JSON" ]; then
  echo "[scaffold] No upstream.json found — skipping sync"
  exit 0
fi

# Parse upstream.json (requires python3 or node)
parse_json() {
  local key="$1"
  if command -v python3 &>/dev/null; then
    python3 -c "import json,sys; print(json.load(sys.stdin)['$key'])" < "$UPSTREAM_JSON"
  elif command -v python &>/dev/null; then
    python -c "import json,sys; print(json.load(sys.stdin)['$key'])" < "$UPSTREAM_JSON"
  elif command -v node &>/dev/null; then
    node -e "const fs=require('fs'); process.stdout.write(JSON.parse(fs.readFileSync(process.argv[1],'utf8'))['$key'])" "$UPSTREAM_JSON"
  else
    echo "[scaffold] ERROR: python3 or node required for JSON parsing" >&2
    exit 1
  fi
}

REPO_URL="$(parse_json repo_url)"
BRANCH="$(parse_json branch)"
LAST_COMMIT="$(parse_json last_synced_commit)"

echo "[scaffold] Checking upstream: $REPO_URL ($BRANCH)"

# Get current remote HEAD
REMOTE_HEAD="$(git ls-remote "$REPO_URL" "$BRANCH" 2>/dev/null | awk '{print $1}')" || {
  echo "[scaffold] WARNING: Could not reach upstream — continuing with local copy"
  exit 0
}

if [ -z "$REMOTE_HEAD" ]; then
  echo "[scaffold] WARNING: No remote HEAD found for branch '$BRANCH' — continuing with local copy"
  exit 0
fi

if [ "$REMOTE_HEAD" = "$LAST_COMMIT" ]; then
  echo "[scaffold] Up to date (${REMOTE_HEAD:0:8})"
  exit 0
fi

echo "[scaffold] Update available: ${LAST_COMMIT:0:8} → ${REMOTE_HEAD:0:8}"

# Clone to temp directory (sparse checkout of runtime/ only)
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if ! git clone --depth 1 --branch "$BRANCH" --filter=blob:none --sparse "$REPO_URL" "$TMPDIR/repo" 2>&1; then
  echo "[scaffold] WARNING: Could not clone upstream — continuing with local copy"
  exit 0
fi

CLONE_DIR="$TMPDIR/repo"
git -C "$CLONE_DIR" sparse-checkout set runtime 2>/dev/null

# Count changes
CHANGED=0
CHANGED_FILES=""

# Sync upstream-owned directories (never touch project/)
UPSTREAM_DIRS="orchestration skills tools references rules docs-templates"

for dir in $UPSTREAM_DIRS; do
  if [ -d "$CLONE_DIR/runtime/$dir" ]; then
    # Count files that differ
    if [ -d "$SCAFFOLD_DIR/$dir" ]; then
      while IFS= read -r file; do
        rel="${file#$CLONE_DIR/runtime/$dir/}"
        if [ ! -f "$SCAFFOLD_DIR/$dir/$rel" ] || ! diff -q "$file" "$SCAFFOLD_DIR/$dir/$rel" &>/dev/null; then
          CHANGED=$((CHANGED + 1))
          CHANGED_FILES="${CHANGED_FILES:+$CHANGED_FILES, }$dir/$rel"
        fi
      done < <(find "$CLONE_DIR/runtime/$dir" -type f)
    else
      CHANGED=$((CHANGED + $(find "$CLONE_DIR/runtime/$dir" -type f | wc -l)))
    fi
    rm -rf "$SCAFFOLD_DIR/$dir"
    cp -r "$CLONE_DIR/runtime/$dir" "$SCAFFOLD_DIR/$dir"
  fi
done

# Sync root-level files (sync.sh itself)
if [ -f "$CLONE_DIR/runtime/sync.sh" ]; then
  if ! diff -q "$CLONE_DIR/runtime/sync.sh" "$SCAFFOLD_DIR/sync.sh" &>/dev/null 2>&1; then
    CHANGED=$((CHANGED + 1))
    CHANGED_FILES="${CHANGED_FILES:+$CHANGED_FILES, }sync.sh"
  fi
  cp "$CLONE_DIR/runtime/sync.sh" "$SCAFFOLD_DIR/sync.sh"
fi

# Update upstream.json with new commit hash via environment variables (no shell injection)
SYNC_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export REMOTE_HEAD SYNC_DATE

if command -v python3 &>/dev/null; then
  python3 -c "
import json, os
with open('$SCAFFOLD_DIR/upstream.json', 'r+') as f:
    data = json.load(f)
    data['last_synced_commit'] = os.environ['REMOTE_HEAD']
    data['last_synced_date'] = os.environ['SYNC_DATE']
    f.seek(0)
    json.dump(data, f, indent=2)
    f.truncate()
"
elif command -v python &>/dev/null; then
  python -c "
import json, os
with open('$SCAFFOLD_DIR/upstream.json', 'r+') as f:
    data = json.load(f)
    data['last_synced_commit'] = os.environ['REMOTE_HEAD']
    data['last_synced_date'] = os.environ['SYNC_DATE']
    f.seek(0)
    json.dump(data, f, indent=2)
    f.truncate()
"
elif command -v node &>/dev/null; then
  node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
data.last_synced_commit = process.env.REMOTE_HEAD;
data.last_synced_date = process.env.SYNC_DATE;
fs.writeFileSync(process.argv[1], JSON.stringify(data, null, 2));
" "$SCAFFOLD_DIR/upstream.json"
else
  echo "[scaffold] WARNING: Could not update upstream.json — no python3 or node available"
fi

if [ "$CHANGED" -gt 0 ]; then
  echo "[scaffold] Updated: $CHANGED files changed ($CHANGED_FILES)"
else
  echo "[scaffold] Synced to ${REMOTE_HEAD:0:8} (no file changes)"
fi
