#!/usr/bin/env python3
"""
Localization Management Script for Pesto Clipboard

Manages Localizable.xcstrings with markdown files as the primary editing interface.
Each language gets its own markdown file that can be reviewed, edited, and PRed.

Workflow:
  xcstrings → export → locales/*.md → edit/review/PR → import → xcstrings

Commands:
  export   - Generate per-language markdown files from xcstrings
  import   - Sync changes from markdown back to xcstrings
  status   - Show translation summary
  validate - Check xcstrings integrity
"""

import argparse
import json
import os
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

# Configuration
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
XCSTRINGS_PATH = PROJECT_ROOT / "PestoClipboard" / "PestoClipboard" / "Localizable.xcstrings"
LOCALES_DIR = PROJECT_ROOT / "locales"

LANGUAGES = {
    "ca": "Catalan",
    "da": "Danish",
    "de": "German",
    "en-GB": "English (UK)",
    "es": "Spanish",
    "fr": "French",
    "hi": "Hindi",
    "it": "Italian",
    "ja": "Japanese",
    "ko": "Korean",
    "nl": "Dutch",
    "ru": "Russian",
    "sv": "Swedish",
    "zh-Hans": "Chinese (Simplified)",
}

# Status symbols
STATUS_TRANSLATED = "✓"
STATUS_MISSING = "✗"
STATUS_STALE = "⚠"


def load_xcstrings() -> dict:
    """Load and parse the xcstrings JSON file."""
    if not XCSTRINGS_PATH.exists():
        print(f"Error: xcstrings file not found at {XCSTRINGS_PATH}", file=sys.stderr)
        sys.exit(1)

    with open(XCSTRINGS_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def save_xcstrings(data: dict, backup: bool = True) -> None:
    """Save xcstrings data back to file, preserving Xcode's formatting."""
    if backup:
        # Create backup with timestamp
        backup_path = XCSTRINGS_PATH.with_suffix(f".xcstrings.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}")
        shutil.copy2(XCSTRINGS_PATH, backup_path)
        print(f"Backup created: {backup_path.name}")

    # Write with Xcode's formatting: 2-space indent, " : " key separator, sorted keys
    with open(XCSTRINGS_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=True, separators=(",", " : "))
        f.write("\n")

    # Validate the written JSON
    try:
        with open(XCSTRINGS_PATH, "r", encoding="utf-8") as f:
            json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: Written file is not valid JSON: {e}", file=sys.stderr)
        sys.exit(1)


def escape_markdown_table(text: str) -> str:
    """Escape special characters for markdown table cells."""
    if not text:
        return ""
    # Escape pipes and newlines
    text = text.replace("|", "\\|")
    text = text.replace("\n", "\\n")
    return text


def unescape_markdown_table(text: str) -> str:
    """Unescape special characters from markdown table cells."""
    if not text:
        return ""
    # Unescape pipes and newlines
    text = text.replace("\\|", "|")
    text = text.replace("\\n", "\n")
    return text


def get_translation_status(string_data: dict, lang: str) -> tuple[str, str]:
    """
    Get the status and value of a translation.
    Returns (status_symbol, translated_value)
    """
    localizations = string_data.get("localizations", {})
    lang_data = localizations.get(lang, {})
    string_unit = lang_data.get("stringUnit", {})

    state = string_unit.get("state", "")
    value = string_unit.get("value", "")

    if not value and not lang_data:
        return STATUS_MISSING, ""
    elif state == "stale" or state == "needs_review":
        return STATUS_STALE, value
    elif state == "translated" or value:
        return STATUS_TRANSLATED, value
    else:
        return STATUS_MISSING, ""


def export_language(data: dict, lang: str, output_dir: Path) -> Path:
    """Export translations for a single language to a markdown file."""
    source_lang = data.get("sourceLanguage", "en")
    strings = data.get("strings", {})

    # Filter out empty keys and collect translation data
    translations = []
    for key in sorted(strings.keys()):
        if not key.strip():  # Skip empty keys
            continue
        string_data = strings[key]
        status, value = get_translation_status(string_data, lang)
        translations.append((status, key, value))

    # Calculate stats
    total = len(translations)
    translated = sum(1 for t in translations if t[0] == STATUS_TRANSLATED)
    missing = sum(1 for t in translations if t[0] == STATUS_MISSING)
    stale = sum(1 for t in translations if t[0] == STATUS_STALE)

    # Generate markdown
    lang_name = LANGUAGES.get(lang, lang)
    lines = [
        f"# {lang_name} ({lang}) Translations",
        "",
        f"Source language: English ({source_lang})",
        f"Total strings: {total}",
        f"Translated: {translated} ({100*translated//total if total else 0}%)",
        f"Missing: {missing}",
        f"Stale: {stale}",
        "",
        "---",
        "",
        "## Translations",
        "",
        f"| Status | English | {lang_name} |",
        "|--------|---------|" + "-" * (len(lang_name) + 2) + "|",
    ]

    for status, english, translated_value in translations:
        english_escaped = escape_markdown_table(english)
        translated_escaped = escape_markdown_table(translated_value)
        lines.append(f"| {status} | {english_escaped} | {translated_escaped} |")

    # Write file
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{lang}.md"

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
        f.write("\n")

    return output_path


def parse_markdown_table(filepath: Path) -> dict[str, str]:
    """
    Parse a markdown file and extract translations.
    Returns a dict mapping English source strings to translated values.
    """
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    translations = {}

    # Find the table rows (skip header and separator)
    # Pattern matches: | status | english | translated |
    table_pattern = re.compile(r"^\|\s*([✓✗⚠])\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|$", re.MULTILINE)

    for match in table_pattern.finditer(content):
        status = match.group(1)
        english = unescape_markdown_table(match.group(2).strip())
        translated = unescape_markdown_table(match.group(3).strip())

        if english:  # Only include non-empty keys
            translations[english] = translated

    return translations


def import_language(data: dict, lang: str, locales_dir: Path, dry_run: bool = False) -> tuple[int, int, int]:
    """
    Import translations from a markdown file back to xcstrings data.
    Returns (added, updated, unchanged) counts.
    """
    md_path = locales_dir / f"{lang}.md"
    if not md_path.exists():
        print(f"  Warning: {md_path.name} not found, skipping", file=sys.stderr)
        return 0, 0, 0

    md_translations = parse_markdown_table(md_path)
    strings = data.get("strings", {})

    added = 0
    updated = 0
    unchanged = 0

    for english, translated in md_translations.items():
        if english not in strings:
            continue  # Skip strings not in xcstrings

        string_data = strings[english]
        current_status, current_value = get_translation_status(string_data, lang)

        if not translated:
            # No translation provided in markdown
            unchanged += 1
            continue

        if current_value == translated:
            unchanged += 1
            continue

        # Update the translation
        if current_value:
            updated += 1
            action = "Update"
        else:
            added += 1
            action = "Add"

        if dry_run:
            print(f"  {action}: \"{english[:50]}{'...' if len(english) > 50 else ''}\"")
            print(f"    Old: \"{current_value[:50] if current_value else '(empty)'}\"")
            print(f"    New: \"{translated[:50]}{'...' if len(translated) > 50 else ''}\"")
        else:
            # Ensure the structure exists
            if "localizations" not in string_data:
                string_data["localizations"] = {}
            if lang not in string_data["localizations"]:
                string_data["localizations"][lang] = {}

            string_data["localizations"][lang]["stringUnit"] = {
                "state": "translated",
                "value": translated
            }

    return added, updated, unchanged


def cmd_export(args):
    """Handle the export command."""
    data = load_xcstrings()
    output_dir = Path(args.output) if args.output else LOCALES_DIR

    languages = [args.lang] if args.lang else list(LANGUAGES.keys())

    print(f"Exporting translations to {output_dir}/")

    for lang in languages:
        if lang not in LANGUAGES:
            print(f"Warning: Unknown language '{lang}', skipping", file=sys.stderr)
            continue

        output_path = export_language(data, lang, output_dir)

        # Count stats
        strings = data.get("strings", {})
        total = sum(1 for k in strings if k.strip())
        translated = sum(1 for k, v in strings.items() if k.strip() and get_translation_status(v, lang)[0] == STATUS_TRANSLATED)

        print(f"  {lang}.md - {translated}/{total} translated")

    print(f"\nExported {len(languages)} language(s)")


def cmd_import(args):
    """Handle the import command."""
    data = load_xcstrings()
    locales_dir = Path(args.input) if args.input else LOCALES_DIR

    if not locales_dir.exists():
        print(f"Error: Locales directory not found at {locales_dir}", file=sys.stderr)
        sys.exit(1)

    languages = [args.lang] if args.lang else list(LANGUAGES.keys())

    if args.dry_run:
        print("DRY RUN - No changes will be made")
        print()

    print(f"Importing translations from {locales_dir}/")

    total_added = 0
    total_updated = 0

    for lang in languages:
        if lang not in LANGUAGES:
            print(f"Warning: Unknown language '{lang}', skipping", file=sys.stderr)
            continue

        print(f"\n{lang}:")
        added, updated, unchanged = import_language(data, lang, locales_dir, args.dry_run)
        total_added += added
        total_updated += updated

        if not args.dry_run:
            print(f"  Added: {added}, Updated: {updated}, Unchanged: {unchanged}")

    print()
    if args.dry_run:
        print(f"Would add {total_added} and update {total_updated} translations")
        print("Run without --dry-run to apply changes")
    else:
        if total_added > 0 or total_updated > 0:
            save_xcstrings(data)
            print(f"Added {total_added} and updated {total_updated} translations")
        else:
            print("No changes to import")


def cmd_status(args):
    """Handle the status command."""
    data = load_xcstrings()
    strings = data.get("strings", {})

    # Count total non-empty strings
    total = sum(1 for k in strings if k.strip())

    print("=== Translation Status ===")
    print(f"Total strings: {total}")
    print()

    for lang, lang_name in sorted(LANGUAGES.items(), key=lambda x: x[1]):
        translated = 0
        missing = 0
        stale = 0

        for key, string_data in strings.items():
            if not key.strip():
                continue
            status, _ = get_translation_status(string_data, lang)
            if status == STATUS_TRANSLATED:
                translated += 1
            elif status == STATUS_MISSING:
                missing += 1
            elif status == STATUS_STALE:
                stale += 1

        pct = 100 * translated // total if total else 0
        status_parts = []
        if missing:
            status_parts.append(f"{missing} missing")
        if stale:
            status_parts.append(f"{stale} stale")
        status_str = ", ".join(status_parts) if status_parts else "complete"

        print(f"{lang:8} {lang_name:20} {translated:3}/{total} ({pct:2}%) - {status_str}")


def cmd_validate(args):
    """Handle the validate command."""
    print("Validating xcstrings file...")

    # Check file exists
    if not XCSTRINGS_PATH.exists():
        print(f"FAIL: File not found at {XCSTRINGS_PATH}", file=sys.stderr)
        sys.exit(1)

    # Check valid JSON
    try:
        data = load_xcstrings()
    except json.JSONDecodeError as e:
        print(f"FAIL: Invalid JSON - {e}", file=sys.stderr)
        sys.exit(1)

    print("  ✓ Valid JSON")

    # Check required fields
    if "sourceLanguage" not in data:
        print("  ✗ Missing sourceLanguage field", file=sys.stderr)
        sys.exit(1)
    print(f"  ✓ Source language: {data['sourceLanguage']}")

    if "strings" not in data:
        print("  ✗ Missing strings field", file=sys.stderr)
        sys.exit(1)

    strings = data["strings"]
    print(f"  ✓ {len(strings)} string entries")

    # Check for common issues
    empty_keys = sum(1 for k in strings if not k.strip())
    if empty_keys:
        print(f"  ⚠ {empty_keys} empty key(s)")

    # Check for missing localizations structure
    malformed = 0
    for key, value in strings.items():
        if not key.strip():
            continue
        if value and not isinstance(value.get("localizations", {}), dict):
            malformed += 1

    if malformed:
        print(f"  ✗ {malformed} malformed entries", file=sys.stderr)
        sys.exit(1)

    print("  ✓ All entries well-formed")

    # Check version
    if "version" in data:
        print(f"  ✓ Version: {data['version']}")

    print("\nValidation passed!")


def main():
    parser = argparse.ArgumentParser(
        description="Localization management for Pesto Clipboard",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s export                    # Export all languages
  %(prog)s export --lang de          # Export only German
  %(prog)s import --dry-run          # Preview import changes
  %(prog)s import --lang de          # Import only German
  %(prog)s status                    # Show translation summary
  %(prog)s validate                  # Check xcstrings integrity
"""
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Export command
    export_parser = subparsers.add_parser("export", help="Generate markdown files from xcstrings")
    export_parser.add_argument("--lang", help="Export single language (e.g., 'de')")
    export_parser.add_argument("--output", help="Custom output directory")

    # Import command
    import_parser = subparsers.add_parser("import", help="Sync markdown back to xcstrings")
    import_parser.add_argument("--lang", help="Import single language (e.g., 'de')")
    import_parser.add_argument("--input", help="Custom input directory")
    import_parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing")

    # Status command
    subparsers.add_parser("status", help="Show translation summary")

    # Validate command
    subparsers.add_parser("validate", help="Check xcstrings integrity")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    if args.command == "export":
        cmd_export(args)
    elif args.command == "import":
        cmd_import(args)
    elif args.command == "status":
        cmd_status(args)
    elif args.command == "validate":
        cmd_validate(args)


if __name__ == "__main__":
    main()
