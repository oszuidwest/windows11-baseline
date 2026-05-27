#!/usr/bin/env bash
# Check that every https:// URL referenced from scripts/ is reachable, and that
# the Microsoft Security Baseline still matches its pinned SHA-256.
#
# Outputs one report line per URL. Writes any failures to $GITHUB_OUTPUT under
# `broken_urls_report` so the calling workflow can decide whether to file an
# issue. Returns 0 even when URLs are broken: the workflow inspects the report
# rather than failing the job.

set -uo pipefail

report=""
broken=0

check_url() {
    local url="$1"
    local source="$2"
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 30 "$url" || echo "000")
    if [ "$status" -eq 200 ]; then
        echo "OK   $status  $url"
    else
        echo "FAIL $status  $url  ($source)"
        report+=$'\n'"- \`$url\` (status \`$status\`, referenced in \`$source\`)"
        broken=$((broken + 1))
    fi
}

# Extract every https:// URL from scripts/*.ps1, tag with file:line for the issue body.
# Uses grep -oE (POSIX extended) so this works on both GNU and BSD grep.
urls_found=0
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    url=$(echo "$line" | grep -oE 'https://[^"'\''[:space:]]+' | head -1)
    [ -z "$url" ] && continue
    urls_found=$((urls_found + 1))
    check_url "$url" "$file:$lineno"
done < <(grep -nE 'https://[^"'\''[:space:]]+' scripts/*.ps1)

# Fail loudly if URL extraction collapsed silently (regex tooling mismatch, etc.).
if [ "$urls_found" -eq 0 ]; then
    echo "ERROR: no URLs extracted from scripts/*.ps1 - extraction tooling broken." >&2
    exit 2
fi

# Extra check: the Microsoft Security Baseline is pinned with SHA-256. A 200 on
# the URL is not enough - if Microsoft replaces the artifact, the pin breaks.
# Perl is used instead of grep -P for portability (BSD grep has no -P).
baseline_url=$(perl -ne 'if (/baselineUrl\s*=\s*"([^"]+)"/) { print $1; last }' scripts/_securitybaseline.ps1)
expected_sha=$(perl -ne 'if (/expectedSha256\s*=\s*"([^"]+)"/) { print $1; last }' scripts/_securitybaseline.ps1)

if [ -n "$baseline_url" ] && [ -n "$expected_sha" ]; then
    echo ""
    echo "Verifying Microsoft Security Baseline SHA-256..."
    tmpfile=$(mktemp)
    if curl -s -L --max-time 300 -o "$tmpfile" "$baseline_url"; then
        actual_sha=$(shasum -a 256 "$tmpfile" | awk '{print toupper($1)}')
        expected_sha_upper=$(echo "$expected_sha" | tr '[:lower:]' '[:upper:]')
        if [ "$actual_sha" = "$expected_sha_upper" ]; then
            echo "OK   SHA-256 matches pin"
        else
            echo "FAIL SHA-256 mismatch"
            echo "     expected $expected_sha_upper"
            echo "     actual   $actual_sha"
            report+=$'\n'"- Microsoft Security Baseline SHA-256 mismatch. Expected \`$expected_sha_upper\`, got \`$actual_sha\`. Update \`scripts/_securitybaseline.ps1\` (URL and pin)."
            broken=$((broken + 1))
        fi
    else
        echo "FAIL could not download baseline for hash check"
        report+=$'\n'"- Could not download Microsoft Security Baseline to verify SHA-256."
        broken=$((broken + 1))
    fi
    rm -f "$tmpfile"
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "broken_count=$broken"
        echo "broken_urls_report<<EOF"
        echo "${report# }"
        echo "EOF"
    } >> "$GITHUB_OUTPUT"
fi

echo ""
echo "Summary: $broken broken endpoint(s)"
