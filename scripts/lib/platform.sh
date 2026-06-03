# Helpers for mapping a GitHub Actions runner to the OS and CPU-arch suffixes
# used by Databricks CLI release archives and snapshot artifacts.
#
# Source this file from a Bash script; it defines functions only and assigns
# nothing at the top level.

# Map RUNNER_OS (Linux | macOS | Windows) to the suffix used in Databricks CLI
# release archive names. Prints to stdout; exits 1 on unknown OS.
detect_release_os() {
  case "${RUNNER_OS:-}" in
    Linux)   printf 'linux'   ;;
    macOS)   printf 'darwin'  ;;
    Windows) printf 'windows' ;;
    *)
      printf 'unsupported runner OS: %s\n' "${RUNNER_OS:-<unset>}" >&2
      return 1
      ;;
  esac
}

# Map RUNNER_ARCH (X86 | X64 | ARM | ARM64) to the suffix used in Databricks
# CLI release archive names. Prints to stdout; exits 1 on unknown arch.
detect_release_arch() {
  case "${RUNNER_ARCH:-}" in
    X86)   printf '386'   ;;
    X64)   printf 'amd64' ;;
    ARM)   printf 'arm'   ;;
    ARM64) printf 'arm64' ;;
    *)
      printf 'unsupported runner arch: %s\n' "${RUNNER_ARCH:-<unset>}" >&2
      return 1
      ;;
  esac
}

# Same as detect_release_arch but for snapshot artifact subdirectories, which
# follow a slightly different convention (amd64_v1, arm_6).
detect_snapshot_arch() {
  case "${RUNNER_ARCH:-}" in
    X86)   printf '386'      ;;
    X64)   printf 'amd64_v1' ;;
    ARM)   printf 'arm_6'    ;;
    ARM64) printf 'arm64'    ;;
    *)
      printf 'unsupported runner arch: %s\n' "${RUNNER_ARCH:-<unset>}" >&2
      return 1
      ;;
  esac
}
