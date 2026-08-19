#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/platform.sh
. "$SCRIPT_DIR/lib/platform.sh"

UPSTREAM_REPO="databricks/cli"
SNAPSHOT_WORKFLOW="release-snapshot"

die() {
  printf 'databricks-setup-cli: %s\n' "$*" >&2
  exit 1
}

# Look up the most recent successful run of $SNAPSHOT_WORKFLOW on the branch.
# Echoes the run id to stdout; exits non-zero if there is none.
latest_successful_run() {
  local branch="$1"
  local run_id
  run_id=$(
    gh run list \
      --repo "$UPSTREAM_REPO" \
      --workflow "$SNAPSHOT_WORKFLOW" \
      --branch "$branch" \
      --limit 20 \
      --json databaseId,conclusion \
      --jq 'map(select(.conclusion == "success")) | .[0].databaseId'
  ) || die "gh run list failed for $UPSTREAM_REPO/$SNAPSHOT_WORKFLOW@$branch"

  if [ -z "$run_id" ] || [ "$run_id" = "null" ]; then
    die "no successful $SNAPSHOT_WORKFLOW run found on branch $branch"
  fi
  printf '%s' "$run_id"
}

main() {
  local target_branch host_os arch_suffix
  target_branch="${SC_BRANCH:-main}"
  host_os=$(detect_release_os)
  arch_suffix=$(detect_snapshot_arch)

  local artifact_name binary_subdir work_dir download_dir run_id binary_dir
  artifact_name="cli_${host_os}_snapshot"
  binary_subdir="cli_${host_os}_${arch_suffix}"
  work_dir="$(mktemp -d "${RUNNER_TEMP:?RUNNER_TEMP must be set inside a GitHub Actions step}/databricks.XXXXXX")"
  download_dir="$work_dir"

  printf 'databricks-setup-cli: resolving latest %s snapshot on %s\n' \
    "$UPSTREAM_REPO" "$target_branch"
  run_id=$(latest_successful_run "$target_branch")

  printf 'databricks-setup-cli: downloading artifact %s from run %s\n' \
    "$artifact_name" "$run_id"
  gh run download "$run_id" \
    --repo "$UPSTREAM_REPO" \
    --name "$artifact_name" \
    --dir "$download_dir"

  binary_dir="$download_dir/$binary_subdir"
  [ -d "$binary_dir" ] || die "expected artifact subdirectory missing: $binary_dir"

  # Windows artifacts ship as databricks.exe; rename for PATH consistency.
  if [ "$host_os" = "windows" ] && [ -f "$binary_dir/databricks.exe" ]; then
    mv "$binary_dir/databricks.exe" "$binary_dir/databricks"
  fi

  chmod +x "$binary_dir/databricks"
  printf '%s\n' "$binary_dir" >> "$GITHUB_PATH"
  printf 'databricks-setup-cli: installed snapshot from %s/%s into %s\n' \
    "$target_branch" "$run_id" "$binary_dir"
}

main "$@"
