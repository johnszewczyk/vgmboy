#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[[ "$(uname -s)" == Linux ]] || { echo 'Build this package on Linux.' >&2; exit 1; }
output="$root/.build/linux-prepare"
mkdir -p "$output/runtime/bin" "$output/runtime/lib"
swift build --package-path "$root" --configuration release --product vgmboy-prepare --jobs 2
binary_dir="$(swift build --package-path "$root" --configuration release --show-bin-path)"
install -m 755 "$binary_dir/vgmboy-prepare" "$output/runtime/bin/vgmboy-prepare"
# Bundle Swift's runtime, not a compiler/toolchain. Ubuntu owns libc and system libraries.
ldd "$binary_dir/vgmboy-prepare" > "$output/linkage.txt"
if grep -q 'not found' "$output/linkage.txt"; then cat "$output/linkage.txt" >&2; exit 1; fi
awk '/=> \/.*swift/ {print $3}' "$output/linkage.txt" | while IFS= read -r library; do
  cp -L "$library" "$output/runtime/lib/"
done
export VGMBOY_7Z_BINARY="$(command -v 7zz || command -v 7z)"
export VGMBOY_TAR_BINARY="$(command -v tar)"
export VGMBOY_ZSTD_BINARY="$(command -v zstd)"
LD_LIBRARY_PATH="$output/runtime/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  python3 "$root/scripts/check-prepare.py" "$output/runtime/bin/vgmboy-prepare"
revision="${GITHUB_SHA:-$(git -C "$root" rev-parse HEAD)}"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { echo 'Missing source revision.' >&2; exit 1; }
printf '%s\n' "$revision" > "$output/runtime/SOURCE_REVISION"
tar -czf "$output/vgmboy-prepare-linux.tar.gz" -C "$output/runtime" .
