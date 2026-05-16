#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
THEOS_DIR="${THEOS:-/Users/tune/Develop/theos-roothide}"
OUTPUT_DIR="$ROOT_DIR/out"
TMP_ROOT=""
BUILD_LOG_ROOT=""
ROOTLESS_STAGE=""
ROOTHIDE_STAGE=""
ROOTFUL_STAGE=""
ROOTLESS_PACKAGE_STAGE=""

PACKAGE_ID="com.tune.watusi3.zh-hans"
PACKAGE_NAME="Watusi 3 Simplified Chinese Language Pack"
PACKAGE_VERSION="$(awk -F': ' '/^Version:/{print $2; exit}' "$ROOT_DIR/control")"
PACKAGE_DEPENDS="$(awk -F': ' '/^Depends:/{print $2; exit}' "$ROOT_DIR/control")"
PACKAGE_DESC="$(awk -F': ' '/^Description:/{print $2; exit}' "$ROOT_DIR/control")"
PACKAGE_MAINTAINER="$(awk -F': ' '/^Maintainer:/{print $2; exit}' "$ROOT_DIR/control")"
PACKAGE_AUTHOR="$(awk -F': ' '/^Author:/{print $2; exit}' "$ROOT_DIR/control")"
PACKAGE_SECTION="$(awk -F': ' '/^Section:/{print $2; exit}' "$ROOT_DIR/control")"

DEFAULT_EXTRACTED="/Users/tune/Documents/Scripts/Jailbreak/Watusi cea"
WATUSI_EXTRACTED_DIR="${WATUSI_EXTRACTED_DIR:-$DEFAULT_EXTRACTED}"

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "[ERR] Missing command: $1" >&2
		exit 1
	}
}

run_logged_command() {
	local log_name="$1"
	shift

	if [ -z "$BUILD_LOG_ROOT" ]; then
		BUILD_LOG_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wzh-build-logs.XXXXXX")"
	fi

	local log_path="$BUILD_LOG_ROOT/${log_name}.log"
	if "$@" >"$log_path" 2>&1; then
		return 0
	fi

	local status=$?
	echo "[ERR] Command failed: $*" >&2
	echo "[ERR] Build log: $log_path" >&2
	echo "[ERR] Last 200 log lines:" >&2
	tail -n 200 "$log_path" >&2 || true
	exit "$status"
}

cleanup() {
	local status=$?
	[ -n "$TMP_ROOT" ] && rm -rf "$TMP_ROOT"
	[ -n "$BUILD_LOG_ROOT" ] && rm -rf "$BUILD_LOG_ROOT"
	return "$status"
}

trap cleanup EXIT INT TERM

require_cmd make
require_cmd python3
require_cmd dpkg-deb
require_cmd rsync
require_cmd plutil
require_cmd file
require_cmd otool
require_cmd ldid

if [ ! -f "$THEOS_DIR/bin/dm.pl" ]; then
	echo "[ERR] Missing theos dm.pl under: $THEOS_DIR" >&2
	exit 1
fi

if [ ! -f "$WATUSI_EXTRACTED_DIR/var/jb/Library/Application Support/Watusi/Resources.bundle/en.lproj/Localizable.strings" ]; then
	echo "[ERR] Missing Resources.bundle english strings under: $WATUSI_EXTRACTED_DIR" >&2
	exit 1
fi

if [ ! -f "$WATUSI_EXTRACTED_DIR/var/jb/Library/ControlCenter/Bundles/WatusiToggle.bundle/en.lproj/Localizable.strings" ]; then
	echo "[ERR] Missing WatusiToggle.bundle english strings under: $WATUSI_EXTRACTED_DIR" >&2
	exit 1
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wzh-pack.XXXXXX")"
ROOTFUL_STAGE="$TMP_ROOT/rootful"
ROOTLESS_STAGE="$TMP_ROOT/rootless"
ROOTHIDE_STAGE="$TMP_ROOT/roothide"
ROOTLESS_PACKAGE_STAGE="$TMP_ROOT/rootless-package"

ROOTFUL_OUT="$OUTPUT_DIR/${PACKAGE_ID}_${PACKAGE_VERSION}_iphoneos-arm_rootful.deb"
ROOTLESS_OUT="$OUTPUT_DIR/${PACKAGE_ID}_${PACKAGE_VERSION}_iphoneos-arm64_rootless.deb"
ROOTHIDE_OUT="$OUTPUT_DIR/${PACKAGE_ID}_${PACKAGE_VERSION}_iphoneos-arm64e_roothide.deb"

mkdir -p "$OUTPUT_DIR"
rm -f "$ROOTFUL_OUT" "$ROOTLESS_OUT" "$ROOTHIDE_OUT"

write_control() {
	local control_path="$1"
	local arch="$2"
	cat >"$control_path" <<EOF
Package: $PACKAGE_ID
Name: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Architecture: $arch
Depends: $PACKAGE_DEPENDS
Description: $PACKAGE_DESC
Maintainer: $PACKAGE_MAINTAINER
Author: $PACKAGE_AUTHOR
Section: $PACKAGE_SECTION
EOF
}

package_stage() {
	local stage_path="$1"
	local out_path="$2"
	COPYFILE_DISABLE=1 "$THEOS_DIR/bin/dm.pl" -Zlzma -z9 -b "$stage_path" "$out_path" >/dev/null
}

generate_locale_stage() {
	local scheme="$1"
	local stage_path="$2"
	WATUSI_EXTRACTED_DIR="$WATUSI_EXTRACTED_DIR" \
	WATUSI_PACKAGE_SCHEME="$scheme" \
	WATUSI_STAGE_ROOT="$stage_path" \
	python3 "$ROOT_DIR/scripts/generate_localizations.py" >/dev/null
}

build_scheme_stage() {
	local scheme="$1"
	local obj_dir_name="$2"
	local stage_path="$3"
	local package_dir="$4"

	rm -rf "$stage_path"
	mkdir -p "$stage_path" "$package_dir"

	run_logged_command "make-${scheme:-rootful}" \
		env THEOS="$THEOS_DIR" \
		THEOS_PACKAGE_SCHEME="$scheme" \
		THEOS_OBJ_DIR_NAME="$obj_dir_name" \
		THEOS_STAGING_DIR="$stage_path" \
		THEOS_PACKAGE_DIR="$package_dir" \
		WATUSI_EXTRACTED_DIR="$WATUSI_EXTRACTED_DIR" \
		make -C "$ROOT_DIR" clean stage
}

copy_tree_contents() {
	local src_dir="$1"
	local dst_dir="$2"
	[ -d "$src_dir" ] || return 0
	mkdir -p "$dst_dir"
	cp -a "$src_dir"/. "$dst_dir"/
}

convert_rootless_stage_to_roothide() {
  local src_stage="$1"
  local dst_stage="$2"

	rm -rf "$dst_stage"
	mkdir -p "$dst_stage"

	mkdir -p "$dst_stage/DEBIAN"
	write_control "$dst_stage/DEBIAN/control" "iphoneos-arm64e"

  copy_tree_contents "$src_stage/MobileSubstrate" "$dst_stage/Library/MobileSubstrate"
  copy_tree_contents "$src_stage/Application Support" "$dst_stage/Library/Application Support"
  copy_tree_contents "$src_stage/ControlCenter" "$dst_stage/Library/ControlCenter"

  find "$dst_stage" -type f | while IFS= read -r file_path; do
		if file -b "$file_path" | grep -q "Mach-O"; then
			ldid -S "$file_path"
		fi
  done
}

build_rootless_package_tree() {
	local src_stage="$1"
	local dst_stage="$2"

	rm -rf "$dst_stage"
	mkdir -p "$dst_stage/DEBIAN"
	write_control "$dst_stage/DEBIAN/control" "iphoneos-arm64"

	copy_tree_contents "$src_stage/Library" "$dst_stage/var/jb/Library"
	copy_tree_contents "$src_stage/var/jb" "$dst_stage/var/jb"
}

verify_rootful_stage() {
	local stage_path="$1"
	[ -f "$stage_path/Library/MobileSubstrate/DynamicLibraries/WatusiZhHans.dylib" ] || {
		echo "[ERR] Missing rootful dylib" >&2
		exit 1
	}
	[ -f "$stage_path/Library/Application Support/Watusi/Resources.bundle/zh-Hans.lproj/Localizable.strings" ] || {
		echo "[ERR] Missing rootful Watusi resource" >&2
		exit 1
	}
	[ ! -e "$stage_path/var/jb" ] || {
		echo "[ERR] Rootful stage still contains var/jb" >&2
		exit 1
	}
}

verify_rootless_stage() {
	local stage_path="$1"
	[ -f "$stage_path/Library/MobileSubstrate/DynamicLibraries/WatusiZhHans.dylib" ] || {
		echo "[ERR] Missing rootless dylib" >&2
		exit 1
	}
	[ -f "$stage_path/var/jb/Library/Application Support/Watusi/Resources.bundle/zh-Hans.lproj/Localizable.strings" ] || {
		echo "[ERR] Missing rootless Watusi resource" >&2
		exit 1
	}
}

verify_rootless_package_stage() {
	local stage_path="$1"
	[ -f "$stage_path/var/jb/Library/MobileSubstrate/DynamicLibraries/WatusiZhHans.dylib" ] || {
		echo "[ERR] Missing rootless package dylib" >&2
		exit 1
	}
	[ -f "$stage_path/var/jb/Library/Application Support/Watusi/Resources.bundle/zh-Hans.lproj/Localizable.strings" ] || {
		echo "[ERR] Missing rootless package Watusi resource" >&2
		exit 1
	}
	[ ! -e "$stage_path/Library" ] || {
		echo "[ERR] Rootless package unexpectedly contains top-level Library" >&2
		exit 1
	}
}

verify_roothide_stage() {
	local stage_path="$1"
	[ -f "$stage_path/Library/MobileSubstrate/DynamicLibraries/WatusiZhHans.dylib" ] || {
		echo "[ERR] Missing roothide dylib" >&2
		exit 1
	}
	[ -f "$stage_path/Library/Application Support/Watusi/Resources.bundle/zh-Hans.lproj/Localizable.strings" ] || {
		echo "[ERR] Missing roothide Watusi resource" >&2
		exit 1
	}
	[ ! -e "$stage_path/var/jb" ] || {
		echo "[ERR] Roothide stage still contains var/jb" >&2
		exit 1
	}
}

echo "[1/8] Build rootful stage..."
build_scheme_stage "" "obj-rootful" "$ROOTFUL_STAGE" "$TMP_ROOT/rootful-pkg"
rm -rf "$ROOTFUL_STAGE/DEBIAN" "$ROOTFUL_STAGE/var"
generate_locale_stage "" "$ROOTFUL_STAGE"
mkdir -p "$ROOTFUL_STAGE/DEBIAN"
write_control "$ROOTFUL_STAGE/DEBIAN/control" "iphoneos-arm"
verify_rootful_stage "$ROOTFUL_STAGE"

echo "[2/8] Build rootless stage..."
build_scheme_stage "rootless" "obj-rootless" "$ROOTLESS_STAGE" "$TMP_ROOT/rootless-pkg"
rm -rf "$ROOTLESS_STAGE/DEBIAN"
generate_locale_stage "rootless" "$ROOTLESS_STAGE"
verify_rootless_stage "$ROOTLESS_STAGE"

build_rootless_package_tree "$ROOTLESS_STAGE" "$ROOTLESS_PACKAGE_STAGE"
verify_rootless_package_stage "$ROOTLESS_PACKAGE_STAGE"

echo "[3/8] Convert rootless stage to roothide..."
convert_rootless_stage_to_roothide "$ROOTLESS_PACKAGE_STAGE/var/jb/Library" "$ROOTHIDE_STAGE"
verify_roothide_stage "$ROOTHIDE_STAGE"

echo "[4/8] Package rootful..."
package_stage "$ROOTFUL_STAGE" "$ROOTFUL_OUT"

echo "[5/8] Package rootless..."
package_stage "$ROOTLESS_PACKAGE_STAGE" "$ROOTLESS_OUT"

echo "[6/8] Package roothide..."
package_stage "$ROOTHIDE_STAGE" "$ROOTHIDE_OUT"

echo "[7/8] Verify package metadata..."
dpkg-deb -I "$ROOTFUL_OUT" >/dev/null
dpkg-deb -I "$ROOTLESS_OUT" >/dev/null
dpkg-deb -I "$ROOTHIDE_OUT" >/dev/null

echo "[8/8] Done"
echo "[OUT] $ROOTFUL_OUT"
echo "[OUT] $ROOTLESS_OUT"
echo "[OUT] $ROOTHIDE_OUT"
