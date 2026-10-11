#!/usr/bin/env bash
# Weekly project report and social draft.
#
# Codex is tried first because it produces the richest report. When it is
# unavailable (account limit, outage, missing binary) the run degrades to local
# OpenCode models rather than producing nothing: a weaker report on time beats
# no report, and the run records which model actually wrote it.
set -euo pipefail

# Prepend the invoking user's tool directories rather than one account's home:
# this script runs as whoever installs it.
export PATH="$HOME/.volta/bin:$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
report_root="$(dirname -- "$(dirname -- "$here")")"

# One run at a time; the lock lives beside the reports so a fallback attempt
# cannot race the primary one into the same directory.
out_dir="$report_root/reports/.automation"
if ! mkdir -p "$out_dir" 2>/dev/null; then
  out_dir="$(mktemp -d "${TMPDIR:-/tmp}/weekly-review.XXXXXX")"
fi
exec 9>"$out_dir/weekly-review.lock"
flock -n 9 || exit 0

run_stamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
cd "$report_root"

skill="$report_root/skills/weekly-review/SKILL.md"
if [[ ! -f "$skill" ]]; then
  printf 'weekly-review: skill not found at %s\n' "$skill" >&2
  exit 66
fi
prompt="$(sed "s#skills/weekly-review/SKILL.md#$skill#" "$here/prompt.txt")"

# Ordered by report quality, then by tier. The hosted models need the network
# and are preferred. The local model is the backstop: Ollama is loopback-only,
# so it answers during an outage when nothing hosted can be reached.
models=(
  "codex"
  "opencode/big-pickle"
  "opencode/nemotron-3.5-lightning-free"
  "opencode/space-bunny-free"
  "ollama/qwen2.5:3b"
)

# Bound each attempt so an unresponsive service cannot hold the unit open until
# TimeoutStartSec kills it without leaving a usable record.
attempt_timeout="${WEEKLY_REVIEW_ATTEMPT_TIMEOUT:-3600}"

record() { # model status duration attempts
  cat > "$out_dir/$run_stamp.model.json" <<JSON
{
  "schema": "ragbaz.weekly-review.model.v1",
  "run_stamp": "$run_stamp",
  "model": "$1",
  "status": "$2",
  "duration_seconds": $3,
  "attempt": $4
}
JSON
}

total=${#models[@]}
attempt=0
for model in "${models[@]}"; do
  attempt=$((attempt + 1))
  started=$(date +%s)
  status=0

  case "$model" in
    codex)
      if ! command -v codex >/dev/null; then status=127; else
        timeout --signal=TERM --kill-after=60 "$attempt_timeout" \
          codex --no-daemon -a never exec --sandbox workspace-write --skip-git-repo-check \
          --output-last-message "$out_dir/$run_stamp.txt" - <<<"$prompt" || status=$?
      fi
      ;;
    *)
      slug="${model//\//-}"
      if ! command -v opencode >/dev/null; then status=127; else
        timeout --signal=TERM --kill-after=60 "$attempt_timeout" \
          opencode run --model "$model" --format default --dir "$report_root" "$prompt" \
          > "$out_dir/$run_stamp.$slug.txt" 2> "$out_dir/$run_stamp.$slug.log" || status=$?
      fi
      ;;
  esac

  elapsed=$(($(date +%s) - started))
  if [[ $status -eq 0 ]]; then
    record "$model" "completed" "$elapsed" "$attempt"
    printf 'weekly-review: completed with %s after %ds (attempt %d/%d)\n' \
      "$model" "$elapsed" "$attempt" "$total" >&2
    exit 0
  fi

  printf 'weekly-review: %s failed with status %d after %ds; trying the next model\n' \
    "$model" "$status" "$elapsed" >&2
  record "$model" "failed" "$elapsed" "$attempt"
done

printf 'weekly-review: every model failed after %d attempts; no report produced\n' "$total" >&2
exit 1