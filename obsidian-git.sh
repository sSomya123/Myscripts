#!/usr/bin/env bash

# -------------------------------
# Configuration
# -------------------------------

OBSIDIAN_BIN="/usr/bin/obsidian"
VAULT_BASE="$HOME/Documents/Obsidian"
BRANCH="main"

# -------------------------------
# Launch Obsidian
# -------------------------------

"$OBSIDIAN_BIN" &
OBSIDIAN_PID=$!

# Wait until Obsidian exits
wait "$OBSIDIAN_PID"

echo "Obsidian closed. Updating vaults..."

# -------------------------------
# Update all vaults
# -------------------------------

for vault in "$VAULT_BASE"/*; do
  # Check if it's a git repo
  if [ -d "$vault/.git" ]; then
    VAULT_NAME=$(basename "$vault")
    echo "→ Processing vault: $VAULT_NAME"

    cd "$vault" || continue

    # Stage changes
    git add .

    # Check if there is anything to commit
    if ! git diff --cached --quiet; then
      COMMIT_MSG="Obsidian update ($VAULT_NAME): $(date '+%Y-%m-%d %H:%M')"

      git commit -m "$COMMIT_MSG"
      git push origin "$BRANCH"
    else
      echo "  No changes detected, skipping."
    fi
  fi
done

echo "All vaults processed."
