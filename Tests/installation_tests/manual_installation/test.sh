#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"

function info {
  echo "[$(basename "${0}")] [INFO] ${1}"
}

function die {
  echo "[$(basename "${0}")] [ERROR] ${1}"
  exit 1
}

# Verify xcpretty is installed
if ! command -v xcpretty > /dev/null; then
  if [[ "${CI}" != "true" ]]; then
    die "Please install xcpretty: https://github.com/supermarin/xcpretty#installation"
  fi

  info "Installing xcpretty..."
  gem install xcpretty --no-ri --no-rdoc || die "Executing \`gem install xcpretty\` failed"
fi

# Build and verify static library
info "Building and verifying static library..."

sh "${root_dir}/ci_scripts/export_builds.sh" --only-static || die "Executing export_builds.sh failed"

sh "${root_dir}/ci_scripts/validate_zip.sh" "${root_dir}/build/StripeiOS-Static.zip" || die "Validating zip failed"

# Perform manual installation
framework_dir="${script_dir}/ManualInstallationTest/Frameworks"

info "Performing manual installation..."

rm -rf "${framework_dir}"

mkdir -p "${framework_dir}"

ditto -xk \
  "${root_dir}/build/StripeiOS-Static.zip" \
  "${framework_dir}"

# Determine xcodebuild simulator destination
destination=(
  -destination "platform=iOS Simulator,name=iPhone 6,OS=10.3.1"
)

if xcodebuild -version | grep -q "Xcode 9"; then
  destination=(
    -destination "platform=iOS Simulator,name=iPhone 6,OS=11.0"
  )
fi

# Execute xcodebuild
info "Executing xcodebuild..."

xcodebuild clean test \
  -project "${script_dir}/ManualInstallationTest.xcodeproj" \
  -scheme "ManualInstallationTest" \
  -sdk "iphonesimulator" \
  "${destination[@]}" \
  | xcpretty

xcodebuild_build_exit_code="${PIPESTATUS[0]}"

if [[ "${xcodebuild_build_exit_code}" != 0 ]]; then
  die "Executing xcodebuild failed with status code: ${xcodebuild_build_exit_code}"
fi

info "All good!"
