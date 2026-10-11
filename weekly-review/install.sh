#!/usr/bin/env bash
# Install the weekly review timer for the invoking user.
#
# Paths resolve from this script's own location, so a relocated checkout does
# not leave the unit pointing at a directory that no longer exists.
set -euo pipefail
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workspace="$(dirname -- "$(dirname -- "$source_dir")")"
unit_dir="$HOME/.config/systemd/user"
skill_dir="${CODEX_HOME:-$HOME/.codex}/skills/weekly-review"

skill_src="$workspace/skills/weekly-review/SKILL.md"
if [[ ! -f "$skill_src" ]]; then
  printf 'install.sh: weekly-review skill not found at %s\n' "$skill_src" >&2
  exit 66
fi

mkdir -p "$unit_dir" "$skill_dir"
# The unit is rewritten to this checkout's absolute paths, so the installed
# copy matches where the code actually lives on this host.
sed -e "s#@WORKSPACE@#$workspace#g" "$source_dir/ragbaz-weekly-review.service" \
  > "$unit_dir/ragbaz-weekly-review.service"
install -m 644 "$source_dir/ragbaz-weekly-review.timer" "$unit_dir/"
install -m 644 "$skill_src" "$skill_dir/SKILL.md"

systemctl --user daemon-reload
systemctl --user enable --now ragbaz-weekly-review.timer
systemctl --user list-timers ragbaz-weekly-review.timer --no-pager