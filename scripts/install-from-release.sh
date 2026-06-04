#!/usr/bin/env bash
#
# Install a tagged Databricks CLI release into the runner's PATH.
#
# Reads from environment:
#   SC_VERSION  optional CLI version string (for example "1.1.0"). When empty
#               the default pinned version is read from the repo's VERSION
#               file alongside this action.
#
# Side effects:
#   - downloads the matching release archive (and its checksums) to $RUNNER_TEMP
#   - verifies the archive against the published SHA256SUMS when available
#   - appends the binary directory to $GITHUB_PATH

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTION_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/platform.sh
. "$SCRIPT_DIR/lib/platform.sh"

# The Databricks CLI is published only on github.com, even when the workflow
# runs on a GHES runner. Hard-coding the public host avoids ever hitting a
# GHES release endpoint by accident.
GH_RELEASE_HOST="https://github.com/databricks/cli/releases/download"

die() {
  printf 'databricks-setup-cli: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf '::warning::databricks-setup-cli: %s\n' "$*"
}

# Resolve $SC_VERSION (or the pinned default in VERSION) into a bare version
# string with no leading "v".
resolve_version() {
  if [ -n "${SC_VERSION:-}" ]; then
    printf '%s' "${SC_VERSION#v}"
    return 0
  fi
  local version_file="$ACTION_ROOT/VERSION"
  [ -f "$version_file" ] || die "missing pinned VERSION file at $version_file"
  local pinned
  pinned=$(tr -d '[:space:]' < "$version_file")
  [ -n "$pinned" ] || die "VERSION file is empty"
  printf '%s' "${pinned#v}"
}

# Compute the SHA-256 of a file, picking whichever tool the runner provides.
# Linux runners ship sha256sum; macOS ships shasum; Windows (Git Bash) ships
# both. Stdout is the bare hash with no trailing fields.
compute_sha256() {
  local target="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$target" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$target" | awk '{print $1}'
  else
    die "no sha256 tool available on this runner (need sha256sum or shasum)"
  fi
}

# Best-effort integrity check. Logs a workflow warning and returns 0 if the
# checksums file is missing or unreachable, so older releases that never
# published one still work. Fails hard only on an actual mismatch.
verify_archive() {
  local archive_path="$1" archive_basename="$2" cli_version="$3"

  local checksums_url checksums_file expected_hash actual_hash
  checksums_url="${GH_RELEASE_HOST}/v${cli_version}/databricks_cli_${cli_version}_SHA256SUMS"
  checksums_file="${archive_path}.SHA256SUMS"

  if ! curl --fail --silent --location --max-time 30 \
        --output "$checksums_file" "$checksums_url"; then
    warn "could not fetch $checksums_url; skipping checksum verification"
    return 0
  fi

  expected_hash=$(awk -v name="$archive_basename" '$2 == name {print $1; exit}' "$checksums_file")
  if [ -z "$expected_hash" ]; then
    warn "no SHA256 entry for $archive_basename in checksums file; skipping verification"
    return 0
  fi

  actual_hash=$(compute_sha256 "$archive_path")
  if [ "$expected_hash" != "$actual_hash" ]; then
    die "checksum mismatch for $archive_basename: expected $expected_hash, got $actual_hash"
  fi
  printf 'databricks-setup-cli: SHA-256 verified for %s\n' "$archive_basename"
}

main() {
  local cli_version host_os host_arch archive_name archive_url work_dir extract_dir archive_path
  cli_version=$(resolve_version)
  host_os=$(detect_release_os)
  host_arch=$(detect_release_arch)

  archive_name="databricks_cli_${cli_version}_${host_os}_${host_arch}.zip"
  archive_url="${GH_RELEASE_HOST}/v${cli_version}/${archive_name}"

  work_dir="${RUNNER_TEMP:?RUNNER_TEMP must be set inside a GitHub Actions step}"
  archive_path="$work_dir/$archive_name"
  extract_dir="$work_dir/databricks-cli"
  mkdir -p "$extract_dir"

  printf 'databricks-setup-cli: fetching %s\n' "$archive_url"
  curl --fail --silent --location --max-time 120 \
    --output "$archive_path" "$archive_url" \
    || die "release download failed: $archive_url"

  verify_archive "$archive_path" "$archive_name" "$cli_version"

  unzip -q -o "$archive_path" -d "$extract_dir"
  chmod +x "$extract_dir/databricks"

  printf '%s\n' "$extract_dir" >> "$GITHUB_PATH"
  printf 'databricks-setup-cli: installed v%s at %s\n' "$cli_version" "$extract_dir"
}

main "$@"
