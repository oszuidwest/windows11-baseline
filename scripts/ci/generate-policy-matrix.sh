#!/usr/bin/env bash
# Generate the policy matrix in policies/README.md from policies/config.json.
#
# Usage:
#   generate-policy-matrix.sh           Print the matrix table to stdout.
#   generate-policy-matrix.sh generate  Same as above.
#   generate-policy-matrix.sh write     Replace the matrix between BEGIN/END
#                                       markers in policies/README.md.
#   generate-policy-matrix.sh check     Verify policies/README.md matches what
#                                       would be generated; exit 1 if not.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$REPO_ROOT/policies/config.json"
README="$REPO_ROOT/policies/README.md"
BEGIN_MARKER="<!-- BEGIN_POLICY_MATRIX -->"
END_MARKER="<!-- END_POLICY_MATRIX -->"

humanize() {
    # Title-case slugs, then fix known acronyms and brand spellings.
    echo "$1" | awk '{
        n = split($0, parts, "-");
        for (i = 1; i <= n; i++) {
            word = parts[i];
            first = toupper(substr(word, 1, 1));
            rest  = substr(word, 2);
            parts[i] = first rest;
        }
        out = parts[1];
        for (i = 2; i <= n; i++) out = out " " parts[i];
        print out;
    }' | perl -pe '
        s/\bUi\b/UI/g;
        s/\bNtlm\b/NTLM/g;
        s/\bPua\b/PUA/g;
        s/\bWifi\b/WiFi/g;
        s/\bOnedrive\b/OneDrive/g;
        s/\bPowershell\b/PowerShell/g;
        s/\bBitlocker\b/BitLocker/g;
        s/\bSmartscreen\b/SmartScreen/g;
    '
}

generate_table() {
    echo "| Scope | Category | Policy | Description | Purposes | Shared | Personal | Dedicated |"
    echo "|:-----:|----------|--------|-------------|----------|:------:|:--------:|:---------:|"

    # Emit TSV so the shell loop does not parse JSON.
    jq -r '
        .policies
        | to_entries
        | map({
            parts: (.key | split("/")),
            description: .value.description,
            ownership: .value.ownership,
            purposes: .value.purposes,
          })
        | map({
            scope: .parts[0],
            category: .parts[1],
            slug: (.parts[2] | sub("\\.(txt|inf)$"; "")),
            description: .description,
            purposes: (if (.purposes | index("all")) then "all" else (.purposes | join(", ")) end),
            shared: (if (.ownership | index("all")) or (.ownership | index("shared")) then "x" else " " end),
            personal: (if (.ownership | index("all")) or (.ownership | index("personal")) then "x" else " " end),
            dedicated: (if (.ownership | index("all")) or (.ownership | index("dedicated")) then "x" else " " end),
          })
        | sort_by(.scope, .category, .slug)
        | .[]
        | [.scope, .category, .slug, .description, .purposes, .shared, .personal, .dedicated]
        | @tsv
    ' "$CONFIG" |
    while IFS=$'\t' read -r scope category slug description purposes shared personal dedicated; do
        policy_name=$(humanize "$slug")
        echo "| $scope | $category | $policy_name | $description | $purposes | $shared | $personal | $dedicated |"
    done
}

mode="${1:-generate}"

case "$mode" in
    generate)
        generate_table
        ;;
    write)
        if ! grep -q "$BEGIN_MARKER" "$README" || ! grep -q "$END_MARKER" "$README"; then
            echo "ERROR: $README is missing BEGIN_POLICY_MATRIX / END_POLICY_MATRIX markers." >&2
            exit 1
        fi
        table_file=$(mktemp)
        generate_table > "$table_file"
        awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v tablefile="$table_file" '
            $0 == begin {
                print;
                while ((getline line < tablefile) > 0) print line;
                close(tablefile);
                in_block = 1;
                next;
            }
            $0 == end   { in_block = 0; print; next }
            !in_block   { print }
        ' "$README" > "$README.tmp"
        mv "$README.tmp" "$README"
        rm -f "$table_file"
        echo "Updated $README"
        ;;
    check)
        if ! grep -q "$BEGIN_MARKER" "$README" || ! grep -q "$END_MARKER" "$README"; then
            echo "ERROR: $README is missing BEGIN_POLICY_MATRIX / END_POLICY_MATRIX markers." >&2
            exit 1
        fi
        current=$(awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
            $0 == begin { in_block = 1; next }
            $0 == end   { in_block = 0; next }
            in_block    { print }
        ' "$README")
        expected=$(generate_table)
        if [ "$current" != "$expected" ]; then
            echo "Policy matrix in $README is out of sync with $CONFIG." >&2
            echo "Run: ./scripts/ci/generate-policy-matrix.sh write" >&2
            echo "" >&2
            echo "--- expected ---" >&2
            echo "$expected" >&2
            echo "--- actual ---" >&2
            echo "$current" >&2
            exit 1
        fi
        echo "Policy matrix is up to date."
        ;;
    *)
        echo "Unknown mode: $mode" >&2
        echo "Usage: $0 [generate|write|check]" >&2
        exit 1
        ;;
esac
