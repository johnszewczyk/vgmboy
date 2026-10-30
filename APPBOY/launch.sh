#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

BUILD_DIR="${APPBOY_BUILD_DIR:-$ROOT_DIR/.build}"
BUNDLE_IDENTIFIER="${APPBOY_BUNDLE_IDENTIFIER:-com.john.spcboy.appboy}"
APP_DIR="${APPBOY_SIM_APP_DIR:-$BUILD_DIR/APPBOY-Simulator.app}"
REQUESTED_DEVICE="${APPBOY_SIM_DEVICE:-}"
SKIP_BUILD=0
OPEN_GUI=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      REQUESTED_DEVICE="${2:-}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --headless)
      OPEN_GUI=0
      shift
      ;;
    *)
      echo "Usage: $0 [--device <name-or-udid>] [--skip-build] [--headless]" >&2
      exit 2
      ;;
  esac
done

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  "$ROOT_DIR/build.sh" --target simulator
fi

if [[ ! -d "$APP_DIR" ]]; then
  echo "Missing simulator app bundle: $APP_DIR" >&2
  exit 1
fi

RESOLVE_JSON="$(
  REQUESTED_DEVICE="$REQUESTED_DEVICE" node -e '
const { execFileSync } = require("child_process");

function simctlJson(args) {
  return JSON.parse(execFileSync("xcrun", ["simctl", ...args, "-j"], { encoding: "utf8" }));
}

const requested = (process.env.REQUESTED_DEVICE || "").trim();
const runtimesData = simctlJson(["list", "runtimes"]);
const iosRuntimes = (runtimesData.runtimes || []).filter(
  (rt) => rt.isAvailable && (rt.platform === "iOS" || String(rt.identifier || "").includes("SimRuntime.iOS"))
);

if (iosRuntimes.length === 0) {
  console.error("No available iOS Simulator runtime found. Install one with: xcodebuild -downloadPlatform iOS -architectureVariant arm64");
  process.exit(2);
}

const nonDuoRuntimes = iosRuntimes.filter((rt) => {
  const types = rt.supportedDeviceTypes || [];
  return types.length === 0 || types.some((t) => !String(t.name || "").includes("Duo"));
});
const candidateRuntimes = (!requested.toLowerCase().includes("duo") && nonDuoRuntimes.length > 0)
  ? nonDuoRuntimes
  : iosRuntimes;
const chosenRuntime = candidateRuntimes[candidateRuntimes.length - 1];
const devicesData = simctlJson(["list", "devices", "available"]);
const allDevices = [];
for (const [runtimeId, list] of Object.entries(devicesData.devices || {})) {
  if (!runtimeId.includes("SimRuntime.iOS")) continue;
  for (const dev of list) {
    if (dev.isAvailable !== false) {
      allDevices.push({ ...dev, runtimeId });
    }
  }
}

let match = null;
if (requested) {
  const lower = requested.toLowerCase();
  match =
    allDevices.find((d) => d.udid.toLowerCase() === lower) ||
    allDevices.find((d) => d.name.toLowerCase() === lower) ||
    allDevices.find((d) => d.name.toLowerCase().includes(lower));
} else {
  match = allDevices.find((d) => d.state === "Booted" && !d.name.includes("Duo"));
  if (!match) {
    const preferredPlusNames = ["iPhone 16 Plus", "iPhone 15 Plus", "iPhone 14 Plus"];
    for (const pref of preferredPlusNames) {
      match = allDevices.find((d) => d.name === pref);
      if (match) break;
    }
  }
  if (!match) {
    match = allDevices.find((d) => d.name.includes("Plus") && d.name.startsWith("iPhone")) || null;
  }
}

if (match) {
  console.log(JSON.stringify({ action: "use", udid: match.udid, name: match.name, state: match.state }));
  process.exit(0);
}

const typesData = simctlJson(["list", "devicetypes"]);
const supportedIds = new Set((chosenRuntime.supportedDeviceTypes || []).map((t) => t.identifier));
const devTypes = (typesData.devicetypes || []).filter(
  (t) => (supportedIds.size === 0 || supportedIds.has(t.identifier)) && (requested || !t.name.includes("Duo"))
);
let chosenType = null;
if (requested) {
  const lower = requested.toLowerCase();
  chosenType =
    devTypes.find((t) => t.name.toLowerCase() === lower || String(t.identifier).toLowerCase() === lower) ||
    devTypes.find((t) => t.name.toLowerCase().includes(lower));
}
if (!chosenType) {
  const preferredTypes = [
    "iPhone 16 Plus",
    "iPhone 15 Plus",
    "iPhone 14 Plus",
    "iPhone 17 Pro Max",
    "iPhone 16 Pro Max",
    "iPhone 18 Pro Max",
    "iPhone 17"
  ];
  for (const pref of preferredTypes) {
    chosenType = devTypes.find((t) => t.name === pref);
    if (chosenType) break;
  }
}
if (!chosenType) {
  chosenType =
    devTypes.find((t) => t.name.includes("Plus") && t.name.startsWith("iPhone")) ||
    devTypes.find((t) => (String(t.productFamily || "").includes("iPhone") || t.name.startsWith("iPhone")) && !t.name.includes("Duo"));
}
if (!chosenType) {
  console.error("Could not find a suitable iOS SimDeviceType to create.");
  process.exit(3);
}

console.log(JSON.stringify({
  action: "create",
  name: chosenType.name,
  deviceTypeId: chosenType.identifier,
  runtimeId: chosenRuntime.identifier
}));
'
)"

ACTION="$(printf '%s' "$RESOLVE_JSON" | node -e 'const d = JSON.parse(require("fs").readFileSync(0, "utf8")); process.stdout.write(d.action);')"

if [[ "$ACTION" == "create" ]]; then
  DEV_NAME="$(printf '%s' "$RESOLVE_JSON" | node -e 'const d = JSON.parse(require("fs").readFileSync(0, "utf8")); process.stdout.write(d.name);')"
  DEV_TYPE="$(printf '%s' "$RESOLVE_JSON" | node -e 'const d = JSON.parse(require("fs").readFileSync(0, "utf8")); process.stdout.write(d.deviceTypeId);')"
  RUNTIME_ID="$(printf '%s' "$RESOLVE_JSON" | node -e 'const d = JSON.parse(require("fs").readFileSync(0, "utf8")); process.stdout.write(d.runtimeId);')"
  echo "Creating Simulator device '$DEV_NAME' ($DEV_TYPE on $RUNTIME_ID)..."
  SIM_UDID="$(xcrun simctl create "$DEV_NAME" "$DEV_TYPE" "$RUNTIME_ID")"
  SIM_NAME="$DEV_NAME"
  SIM_STATE="Shutdown"
else
  SIM_UDID="$(printf '%s' "$RESOLVE_JSON" | node -e 'const d = JSON.parse(require("fs").readFileSync(0, "utf8")); process.stdout.write(d.udid);')"
  SIM_NAME="$(printf '%s' "$RESOLVE_JSON" | node -e 'const d = JSON.parse(require("fs").readFileSync(0, "utf8")); process.stdout.write(d.name);')"
  SIM_STATE="$(printf '%s' "$RESOLVE_JSON" | node -e 'const d = JSON.parse(require("fs").readFileSync(0, "utf8")); process.stdout.write(d.state);')"
fi

if [[ "$SIM_STATE" != "Booted" ]]; then
  echo "Booting Simulator '$SIM_NAME' ($SIM_UDID)..."
  xcrun simctl boot "$SIM_UDID" || true
fi

if [[ "$OPEN_GUI" -eq 1 ]]; then
  if [[ -d "${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}/Applications/Simulator.app" ]]; then
    open -a "${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}/Applications/Simulator.app" --args -CurrentDeviceUDID "$SIM_UDID"
  elif [[ -d "/Applications/Xcode.app/Contents/Applications/DeviceHub.app" ]]; then
    open -a "/Applications/Xcode.app/Contents/Applications/DeviceHub.app"
  else
    open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" 2>/dev/null || true
  fi
fi

xcrun simctl bootstatus "$SIM_UDID" -b

echo "Installing $APP_DIR onto '$SIM_NAME' ($SIM_UDID)..."
xcrun simctl install "$SIM_UDID" "$APP_DIR"

xcrun simctl terminate "$SIM_UDID" "$BUNDLE_IDENTIFIER" >/dev/null 2>&1 || true
echo "Launching $BUNDLE_IDENTIFIER on '$SIM_NAME'..."
xcrun simctl launch "$SIM_UDID" "$BUNDLE_IDENTIFIER"
