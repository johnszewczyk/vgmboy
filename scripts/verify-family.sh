#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAMILY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="verify"
RESULT_ROOT=""
PROJECTS=(CatalogReader VGMBoy FrontendCore ScanSong CocoaSpice SPCBoyWK)

usage() {
  echo "Usage: $0 [--inventory-only] [--output-dir PATH]"
  echo
  echo "Records exact source/tool state for all six VGMMan components."
  echo "The default mode also runs the family package and renderer checks."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --inventory-only)
      MODE="inventory"
      shift
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || { echo "--output-dir needs a path" >&2; exit 2; }
      RESULT_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$RESULT_ROOT" ]]; then
  RESULT_ROOT="$(mktemp -d "/private/tmp/vgmman-family-verification.XXXXXX")"
else
  if [[ -e "$RESULT_ROOT" && -n "$(ls -A "$RESULT_ROOT" 2>/dev/null)" ]]; then
    echo "Output directory is not empty: $RESULT_ROOT" >&2
    exit 2
  fi
  mkdir -p "$RESULT_ROOT"
  RESULT_ROOT="$(cd "$RESULT_ROOT" && pwd)"
fi

STATE_DIR="$RESULT_ROOT/source-state"
LOG_DIR="$RESULT_ROOT/logs"
mkdir -p "$STATE_DIR" "$LOG_DIR"

MANIFEST="$RESULT_ROOT/repositories.tsv"
TOOLS="$RESULT_ROOT/toolchain.tsv"
CHECKS="$RESULT_ROOT/checks.tsv"
COMMANDS="$RESULT_ROOT/commands.tsv"
SUMMARY="$RESULT_ROOT/summary.md"

printf 'project\tpath\tbranch\thead\tupstream\tahead\tbehind\tdirty_count\tpatch_sha256\tuntracked_sha256\tsubmodules_sha256\n' > "$MANIFEST"
printf 'key\tvalue\n' > "$TOOLS"
printf 'check\tproject\tstatus\tduration_seconds\tlog\n' > "$CHECKS"
printf 'check\tworking_directory\tcommand\n' > "$COMMANDS"

hash_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

record_repository() {
  local project="$1"
  local repository="$FAMILY_ROOT/$project"
  local status_file="$STATE_DIR/$project.status"
  local patch_file="$STATE_DIR/$project.patch"
  local untracked_file="$STATE_DIR/$project.untracked-sha256"
  local submodule_file="$STATE_DIR/$project.submodules"
  local branch head upstream ahead behind dirty_count patch_hash untracked_hash submodule_hash
  local git_root="$repository"
  local file_root="$repository"
  local -a scope_args=(.)

  if ! git -C "$repository" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_root="$FAMILY_ROOT"
    file_root="$FAMILY_ROOT"
    scope_args=("$project")
    if ! git -C "$git_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Not a Git worktree: $repository or $FAMILY_ROOT" >&2
      exit 1
    fi
  fi

  git -C "$git_root" status --porcelain=v1 -uall -- "${scope_args[@]}" > "$status_file"
  git -C "$git_root" diff --binary HEAD -- "${scope_args[@]}" > "$patch_file"
  git -C "$git_root" submodule status --recursive > "$submodule_file" 2>/dev/null || true

  : > "$untracked_file"
  while IFS= read -r untracked_path; do
    [[ -n "$untracked_path" ]] || continue
    if [[ -f "$file_root/$untracked_path" ]]; then
      printf '%s  %s\n' "$(shasum -a 256 "$file_root/$untracked_path" | awk '{print $1}')" "$untracked_path" >> "$untracked_file"
    else
      printf '%s  %s\n' "NONREGULAR" "$untracked_path" >> "$untracked_file"
    fi
  done < <(git -C "$git_root" ls-files --others --exclude-standard -- "${scope_args[@]}" | LC_ALL=C sort)

  branch="$(git -C "$git_root" branch --show-current)"
  [[ -n "$branch" ]] || branch="DETACHED"
  head="$(git -C "$git_root" rev-parse HEAD)"
  upstream="$(git -C "$git_root" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"
  ahead=0
  behind=0
  if [[ -n "$upstream" ]]; then
    read -r ahead behind < <(git -C "$git_root" rev-list --left-right --count "HEAD...$upstream")
  fi
  dirty_count="$(wc -l < "$status_file" | tr -d ' ')"
  patch_hash="$(hash_file "$patch_file")"
  untracked_hash="$(hash_file "$untracked_file")"
  submodule_hash="$(hash_file "$submodule_file")"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$project" "$repository" "$branch" "$head" "$upstream" "$ahead" "$behind" \
    "$dirty_count" "$patch_hash" "$untracked_hash" "$submodule_hash" >> "$MANIFEST"
}

record_tool() {
  local key="$1"
  shift
  local value
  value="$($@ 2>&1 | tr '\n\t' '  ')"
  printf '%s\t%s\n' "$key" "$value" >> "$TOOLS"
}

for project in "${PROJECTS[@]}"; do
  record_repository "$project"
done

record_tool timestamp_utc date -u '+%Y-%m-%dT%H:%M:%SZ'
record_tool host_arch uname -m
record_tool macos sw_vers -productVersion
record_tool xcode xcodebuild -version
record_tool swift swift --version
if command -v brew >/dev/null 2>&1; then
  record_tool homebrew brew --version
  for formula in game-music-emu ffmpeg libogg libvorbis libopenmpt libsidplayfp uade; do
    record_tool "brew_prefix_$formula" brew --prefix "$formula"
  done
else
  printf 'homebrew\tNOT_FOUND\n' >> "$TOOLS"
fi

failure_count=0

run_check() {
  local label="$1"
  local project="$2"
  shift 2
  local repository="$FAMILY_ROOT/$project"
  local log="$LOG_DIR/$label.log"
  local started=$SECONDS
  local status
  local command_text=""
  local argument

  for argument in "$@"; do
    printf -v command_text '%s%q ' "$command_text" "$argument"
  done
  printf '%s\t%s\t%s\n' "$label" "$repository" "$command_text" >> "$COMMANDS"
  echo "[$label] running"
  (
    cd "$repository" || exit 1
    "$@"
  ) > "$log" 2>&1
  status=$?
  if [[ $status -eq 0 ]]; then
    printf '%s\t%s\tPASS\t%s\t%s\n' "$label" "$project" "$((SECONDS - started))" "$log" >> "$CHECKS"
    echo "[$label] passed"
  else
    printf '%s\t%s\tFAIL(%s)\t%s\t%s\n' "$label" "$project" "$status" "$((SECONDS - started))" "$log" >> "$CHECKS"
    echo "[$label] failed; see $log" >&2
    failure_count=$((failure_count + 1))
  fi
}

if [[ "$MODE" == "verify" ]]; then
  run_check catalogreader-tests CatalogReader swift test --disable-sandbox
  run_check vgmboy-tests VGMBoy swift test --disable-sandbox --jobs 1
  run_check frontendcore-tests FrontendCore swift test --disable-sandbox
  run_check scansong-tests ScanSong swift test --disable-sandbox --jobs 1
  run_check cocoaspice-tests CocoaSpice swift test --disable-sandbox --jobs 1
  run_check spcboywk-build SPCBoyWK swift build --disable-sandbox
  run_check spcboywk-app-core-check SPCBoyWK node --check Sources/SPCBoyWK/Resources/app-core.js
  run_check spcboywk-app-playback-check SPCBoyWK node --check Sources/SPCBoyWK/Resources/app-playback.js
  run_check spcboywk-app-ui-check SPCBoyWK node --check Sources/SPCBoyWK/Resources/app-ui.js
  run_check spcboywk-renderer-tests SPCBoyWK node --test Tests/SPCBoyWKTransport.test.js
fi

{
  echo "# VGMMan Family Verification"
  echo
  echo "- Mode: \`$MODE\`"
  echo "- Family root: \`$FAMILY_ROOT\`"
  echo "- Repository manifest: \`repositories.tsv\`"
  echo "- Toolchain manifest: \`toolchain.tsv\`"
  if [[ "$MODE" == "verify" ]]; then
    echo "- Check results: \`checks.tsv\`"
    echo "- Exact commands: \`commands.tsv\`"
    echo "- Failures: $failure_count"
  fi
  echo
  echo "The source-state directory contains component status, binary Git patch,"
  echo "untracked-file hashes, and submodule state used to derive each manifest hash."
  echo "It records working-tree state without copying untracked source payloads."
} > "$SUMMARY"

echo "Verification evidence: $RESULT_ROOT"
if [[ $failure_count -ne 0 ]]; then
  exit 1
fi
