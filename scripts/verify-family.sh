#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAMILY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="verify"
RESULT_ROOT=""
PROJECTS=(CatalogReader VGMBoy FrontendCore MetaMan UACMan UACMan/Wrapper ScanSong CocoaSpice SPCBoyWK ViewBoy)

usage() {
  echo "Usage: $0 [--inventory-only] [--output-dir PATH]"
  echo
  echo "Records the single VGMMan repository state and checks all ${#PROJECTS[@]} packages."
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

# A fresh checkout must not require a writable user cache. Keep SwiftPM and
# Clang module products with this run's evidence unless the caller selected
# another writable location explicitly.
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$RESULT_ROOT/cache/clang-modules}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$CLANG_MODULE_CACHE_PATH}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$RESULT_ROOT/cache/xdg}"
export HOMEBREW_CACHE="${HOMEBREW_CACHE:-$RESULT_ROOT/cache/homebrew}"
export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
export HOMEBREW_NO_INSTALL_FROM_API="${HOMEBREW_NO_INSTALL_FROM_API:-1}"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE" "$XDG_CACHE_HOME" "$HOMEBREW_CACHE"

MANIFEST="$RESULT_ROOT/repositories.tsv"
TOOLS="$RESULT_ROOT/toolchain.tsv"
CHECKS="$RESULT_ROOT/checks.tsv"
COMMANDS="$RESULT_ROOT/commands.tsv"
SUMMARY="$RESULT_ROOT/summary.md"

printf 'repository\tpath\tbranch\thead\tupstream\tahead\tbehind\tdirty_count\tpatch_sha256\tuntracked_sha256\tsubmodules_sha256\n' > "$MANIFEST"
printf 'key\tvalue\n' > "$TOOLS"
printf 'check\tproject\tstatus\tduration_seconds\tlog\n' > "$CHECKS"
printf 'check\tworking_directory\tcommand\n' > "$COMMANDS"
printf 'ref\tobject\n' > "$RESULT_ROOT/archive-refs.tsv"

hash_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

record_repository() {
  local repository="$FAMILY_ROOT"
  local status_file="$STATE_DIR/repository.status"
  local patch_file="$STATE_DIR/repository.patch"
  local untracked_file="$STATE_DIR/repository.untracked-sha256"
  local submodule_file="$STATE_DIR/repository.submodules"
  local branch head upstream ahead behind dirty_count patch_hash untracked_hash submodule_hash

  if ! git -C "$repository" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not a Git worktree: $repository" >&2
    exit 1
  fi

  git -C "$repository" status --porcelain=v1 -uall > "$status_file"
  git -C "$repository" diff --binary HEAD > "$patch_file"
  git -C "$repository" submodule status --recursive > "$submodule_file" 2>/dev/null || true

  : > "$untracked_file"
  while IFS= read -r untracked_path; do
    [[ -n "$untracked_path" ]] || continue
    if [[ -f "$repository/$untracked_path" ]]; then
      printf '%s  %s\n' "$(shasum -a 256 "$repository/$untracked_path" | awk '{print $1}')" "$untracked_path" >> "$untracked_file"
    else
      printf '%s  %s\n' "NONREGULAR" "$untracked_path" >> "$untracked_file"
    fi
  done < <(git -C "$repository" ls-files --others --exclude-standard | LC_ALL=C sort)

  branch="$(git -C "$repository" branch --show-current)"
  [[ -n "$branch" ]] || branch="DETACHED"
  head="$(git -C "$repository" rev-parse HEAD)"
  upstream="$(git -C "$repository" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"
  ahead=0
  behind=0
  if [[ -n "$upstream" ]]; then
    read -r ahead behind < <(git -C "$repository" rev-list --left-right --count "HEAD...$upstream")
  fi
  dirty_count="$(wc -l < "$status_file" | tr -d ' ')"
  patch_hash="$(hash_file "$patch_file")"
  untracked_hash="$(hash_file "$untracked_file")"
  submodule_hash="$(hash_file "$submodule_file")"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "VGMMan" "$repository" "$branch" "$head" "$upstream" "$ahead" "$behind" \
    "$dirty_count" "$patch_hash" "$untracked_hash" "$submodule_hash" >> "$MANIFEST"
}

record_tool() {
  local key="$1"
  shift
  local value
  value="$("$@" 2>&1 | tr '\n\t' '  ')"
  printf '%s\t%s\n' "$key" "$value" >> "$TOOLS"
}

record_repository
git -C "$FAMILY_ROOT" for-each-ref \
  --format='%(refname:short)%09%(objectname)' \
  refs/heads/archive refs/remotes/origin/archive \
  | LC_ALL=C sort >> "$RESULT_ROOT/archive-refs.tsv"

record_tool timestamp_utc date -u '+%Y-%m-%dT%H:%M:%SZ'
record_tool host_arch uname -m
record_tool macos sw_vers -productVersion
record_tool xcode xcodebuild -version
record_tool swift swift --version
record_tool macos_sdk xcrun --sdk macosx --show-sdk-path
record_tool cmake cmake --version
record_tool node node --version
record_tool python python3 --version
record_tool zstd zstd --version
record_tool pkg_config pkg-config --version
printf 'clang_module_cache\t%s\n' "$CLANG_MODULE_CACHE_PATH" >> "$TOOLS"
printf 'swiftpm_module_cache\t%s\n' "$SWIFTPM_MODULECACHE_OVERRIDE" >> "$TOOLS"
printf 'xdg_cache_home\t%s\n' "$XDG_CACHE_HOME" >> "$TOOLS"
printf 'homebrew_cache\t%s\n' "$HOMEBREW_CACHE" >> "$TOOLS"
if command -v brew >/dev/null 2>&1; then
  record_tool homebrew brew --version
  for formula in game-music-emu ffmpeg libogg libvorbis libopenmpt libsidplayfp uade; do
    record_tool "brew_version_$formula" brew list --versions "$formula"
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

check_renderer_js() {
  local source
  for source in Sources/*/Resources/*.js; do
    node --check "$source" || return 1
  done
}

run_renderer_tests() {
  node --test Tests/*.test.js
}

if [[ "$MODE" == "verify" ]]; then
  run_check documentation-links . node scripts/check-doc-links.js
  run_check documentation-paradigm . node scripts/check-doc-paradigm.js
  run_check vgmboy-dependencies VGMBoy ./scripts/build-dependencies.sh
  run_check catalogreader-tests CatalogReader swift test --disable-sandbox
  run_check vgmboy-tests VGMBoy swift test --disable-sandbox --jobs 1
  run_check frontendcore-tests FrontendCore swift test --disable-sandbox
  run_check metaman-tests MetaMan swift test --disable-sandbox
  run_check uac-wrapper-tests UACMan/Wrapper swift test --disable-sandbox
  run_check uac-wrapper-python-tests UACMan python3 -B -m unittest discover -s Wrapper/python/tests
  run_check uacman-tests UACMan swift test --disable-sandbox
  run_check scansong-tests ScanSong swift test --disable-sandbox --jobs 1
  run_check cocoaspice-tests CocoaSpice swift test --disable-sandbox --jobs 1
  run_check spcboywk-build SPCBoyWK swift build --disable-sandbox
  run_check spcboywk-js-syntax SPCBoyWK check_renderer_js
  run_check spcboywk-renderer-tests SPCBoyWK run_renderer_tests
  run_check viewboy-build ViewBoy ./build.sh
  run_check viewboy-js-syntax ViewBoy check_renderer_js
  run_check viewboy-renderer-tests ViewBoy run_renderer_tests
fi

{
  echo "# VGMMan Family Verification"
  echo
  echo "- Mode: \`$MODE\`"
  echo "- Family root: \`$FAMILY_ROOT\`"
  echo "- Archived component refs: \`archive-refs.tsv\`"
  echo "- Repository manifest: \`repositories.tsv\`"
  echo "- Toolchain manifest: \`toolchain.tsv\`"
  if [[ "$MODE" == "verify" ]]; then
    echo "- Check results: \`checks.tsv\`"
    echo "- Exact commands: \`commands.tsv\`"
    echo "- Failures: $failure_count"
  fi
  echo
  echo "The source-state directory contains root porcelain status, binary Git patch,"
  echo "untracked-file hashes, and submodule state used to derive the manifest hash."
  echo "It records dirty state without copying untracked source payloads."
} > "$SUMMARY"

echo "Verification evidence: $RESULT_ROOT"
if [[ $failure_count -ne 0 ]]; then
  exit 1
fi
