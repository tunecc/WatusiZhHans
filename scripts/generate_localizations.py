#!/usr/bin/env python3

import csv
import json
import plistlib
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
WORKSPACE = ROOT.parent
EXTRACTED = WORKSPACE / "extracted" / "watusi"

RESOURCES_EN = EXTRACTED / "var/jb/Library/Application Support/Watusi/Resources.bundle/en.lproj/Localizable.strings"
TOGGLE_EN = EXTRACTED / "var/jb/Library/ControlCenter/Bundles/WatusiToggle.bundle/en.lproj/Localizable.strings"

COMMON_OVERRIDES = ROOT / "sources/translations/common_value_overrides.json"
RESOURCES_OVERRIDES = ROOT / "sources/translations/resources_key_overrides.json"
TOGGLE_OVERRIDES = ROOT / "sources/translations/toggle_key_overrides.json"

RESOURCES_OUT = ROOT / "layout/var/jb/Library/Application Support/Watusi/Resources.bundle/zh-Hans.lproj/Localizable.strings"
TOGGLE_OUT = ROOT / "layout/var/jb/Library/ControlCenter/Bundles/WatusiToggle.bundle/zh-Hans.lproj/Localizable.strings"
ZH_ALIAS_DIRS = [
    "zh-Hans.lproj",
    "zh_CN.lproj",
    "zh-CN.lproj",
    "zh.lproj",
    "zh_Hans.lproj",
    "zh-Hans-CN.lproj",
    "zh_Hans_CN.lproj",
]

INVENTORY_OUT = ROOT / "output/spreadsheet/watusi_zh_hans_inventory.csv"
MISSING_OUT = ROOT / "output/spreadsheet/watusi_zh_hans_missing.csv"
SUMMARY_OUT = ROOT / "output/spreadsheet/watusi_zh_hans_summary.json"


def load_plist(path: Path) -> dict:
    with path.open("rb") as fh:
        return plistlib.load(fh)


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def build_bundle(bundle_name: str, source: dict, value_overrides: dict, key_overrides: dict):
    localized = {}
    inventory_rows = []
    key_hits = 0
    value_hits = 0
    fallback_hits = 0

    for key, english in source.items():
        if key in key_overrides:
            zh_hans = key_overrides[key]
            source_type = "key_override"
            key_hits += 1
        elif english in value_overrides:
            zh_hans = value_overrides[english]
            source_type = "value_override"
            value_hits += 1
        else:
            zh_hans = english
            source_type = "fallback_en"
            fallback_hits += 1

        localized[key] = zh_hans
        inventory_rows.append(
            {
                "bundle": bundle_name,
                "key": key,
                "english": english,
                "zh_hans": zh_hans,
                "source": source_type,
            }
        )

    stats = {
        "bundle": bundle_name,
        "total": len(source),
        "key_override": key_hits,
        "value_override": value_hits,
        "fallback_en": fallback_hits,
    }
    return localized, inventory_rows, stats


def write_plist(path: Path, data: dict) -> None:
    ensure_parent(path)
    with path.open("wb") as fh:
        plistlib.dump(data, fh, sort_keys=False)


def write_alias_localizations(canonical_path: Path, data: dict) -> list[str]:
    written = []
    parent = canonical_path.parent.parent
    for alias in ZH_ALIAS_DIRS:
        path = parent / alias / canonical_path.name
        write_plist(path, data)
        written.append(str(path.relative_to(ROOT)))
    return written


def write_inventory(path: Path, rows) -> None:
    ensure_parent(path)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=["bundle", "key", "english", "zh_hans", "source"])
        writer.writeheader()
        writer.writerows(rows)


def write_missing_inventory(path: Path, rows) -> None:
    ensure_parent(path)
    missing_rows = [row for row in rows if row["source"] == "fallback_en"]
    missing_rows.sort(key=lambda row: (row["bundle"], row["key"]))
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=["bundle", "key", "english", "zh_hans", "source"])
        writer.writeheader()
        writer.writerows(missing_rows)


def main() -> None:
    for required in [RESOURCES_EN, TOGGLE_EN, COMMON_OVERRIDES, RESOURCES_OVERRIDES, TOGGLE_OVERRIDES]:
        if not required.exists():
            raise SystemExit(f"missing required input: {required}")

    value_overrides = load_json(COMMON_OVERRIDES)
    resources_overrides = load_json(RESOURCES_OVERRIDES)
    toggle_overrides = load_json(TOGGLE_OVERRIDES)

    # Clean the earlier rootful-style output path if it exists.
    shutil.rmtree(ROOT / "layout/Library", ignore_errors=True)

    resources_localized, resources_rows, resources_stats = build_bundle(
        "Resources.bundle",
        load_plist(RESOURCES_EN),
        value_overrides,
        resources_overrides,
    )
    toggle_localized, toggle_rows, toggle_stats = build_bundle(
        "WatusiToggle.bundle",
        load_plist(TOGGLE_EN),
        value_overrides,
        toggle_overrides,
    )

    resources_aliases = write_alias_localizations(RESOURCES_OUT, resources_localized)
    toggle_aliases = write_alias_localizations(TOGGLE_OUT, toggle_localized)
    all_rows = resources_rows + toggle_rows
    write_inventory(INVENTORY_OUT, all_rows)
    write_missing_inventory(MISSING_OUT, all_rows)

    summary = {
        "resources": resources_stats,
        "toggle": toggle_stats,
        "outputs": {
            "resources_strings": str(RESOURCES_OUT.relative_to(ROOT)),
            "toggle_strings": str(TOGGLE_OUT.relative_to(ROOT)),
            "inventory_csv": str(INVENTORY_OUT.relative_to(ROOT)),
            "missing_csv": str(MISSING_OUT.relative_to(ROOT)),
            "resource_locale_aliases": resources_aliases,
            "toggle_locale_aliases": toggle_aliases,
        },
    }
    ensure_parent(SUMMARY_OUT)
    with SUMMARY_OUT.open("w", encoding="utf-8") as fh:
        json.dump(summary, fh, ensure_ascii=False, indent=2)

    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
