Deduplicate products tool

This folder contains a one-time utility to merge exact duplicate product rows in the app's SQLite database.

Purpose
- Merge products that have the same manufacturer_id and equivalent part_number (case-insensitive, trimmed).
- Reassign related rows in product_images, product_inventory, product_compatibility.
- Update references inside customer_bills.items JSON arrays (product_id entries).
- Delete duplicate product rows after reassignment.

Usage (Windows PowerShell):
1. Backup your database file. The DB path is usually in the app documents folder: %USERPROFILE%\AppData\Local\auto_parts2\database\auto_parts.db or follow the app's DatabaseHelper.getDatabasePath().
2. Run the tool with Dart (ensure dart is installed):
   dart run tools/dedupe_products.dart "C:\path\to\auto_parts.db"

Notes
- This tool is conservative and only merges exact part_number duplicates; it does not attempt fuzzy merging (e.g., NGK-CR8E vs CR8E). For fuzzy cases a manual review or an extended script is required.
- Always backup before running.
- If you want the script adapted (e.g., change merge heuristics), ask and I'll modify it.
