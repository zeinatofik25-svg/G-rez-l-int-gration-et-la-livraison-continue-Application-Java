#!/usr/bin/env bash
set -u

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$PROJECT_DIR/test-results"

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1"; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "Missing dependency: '$1'. $2"
    exit 2
  fi
}

fix_java_home() {
  local candidate="${JAVA_HOME:-}"

  if [ -n "$candidate" ] && [ ! -d "$candidate" ]; then
    candidate=""
  fi

  if [ -z "$candidate" ]; then
    local java_bin
    java_bin="$(command -v java)"
    candidate="$(cd "$(dirname "$(readlink -f "$java_bin")")/.." && pwd -P)"
  fi

  if command -v cygpath >/dev/null 2>&1; then
    candidate="$(cygpath -u "$candidate")"
  fi

  if [ ! -x "$candidate/bin/java" ] && [ ! -x "$candidate/bin/java.exe" ]; then
    log_error "Resolved JAVA_HOME is not executable: $candidate"
    exit 2
  fi

  export JAVA_HOME="$candidate"
  log_info "Using JAVA_HOME=$JAVA_HOME"
}

copy_junit_reports() {
  local source_dir="$1"
  local target_dir="$2"
  local count=0

  mkdir -p "$target_dir"
  while IFS= read -r -d '' report; do
    cp "$report" "$target_dir/$(basename "$report")"
    count=$((count + 1))
  done < <(find "$source_dir" -type f -name '*.xml' -print0 2>/dev/null)

  echo "$count"
}

if [ ! -f "$PROJECT_DIR/build.gradle" ]; then
  log_error "Unsupported project: build.gradle was not found."
  exit 2
fi

if [ ! -f "$PROJECT_DIR/gradlew" ]; then
  log_error "Gradle wrapper was not found."
  exit 2
fi

require_command java "Install JDK 21 and add it to PATH."

rm -rf "$RESULTS_DIR" "$PROJECT_DIR/build/test-results/test"
mkdir -p "$RESULTS_DIR"

fix_java_home
log_info "Detected Java/Gradle project. Running unit tests..."
(
  cd "$PROJECT_DIR" || exit 99
  sed -i 's/\r$//' gradlew
  chmod +x gradlew
  ./gradlew clean test --no-daemon
)
test_exit=$?

report_count="$(copy_junit_reports "$PROJECT_DIR/build/test-results/test" "$RESULTS_DIR/java")"
if [ "$report_count" -eq 0 ]; then
  log_error "No JUnit XML report was generated."
  exit 1
fi

if [ "$test_exit" -ne 0 ]; then
  log_error "Java tests failed with exit code $test_exit."
  exit "$test_exit"
fi

log_info "Java tests passed. JUnit reports: $RESULTS_DIR/java"
