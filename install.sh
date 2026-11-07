#!/usr/bin/env sh
# Installs NSH on any macOS or Linux machine, Intel/AMD or Arm.
#
#   curl -fsSL https://raw.githubusercontent.com/SuperNSH/nsh-builds/master/install.sh | sh
#
# macOS arm64 and Linux x86_64 get NSH's own release (longbridge/nsh); macOS
# x86_64 and Linux arm64 get this repository's build of the same release.
#
# NSH_VERSION      a release tag such as v0.4.0 (default: NSH's latest release)
# NSH_INSTALL_DIR  where the distribution goes (default: ~/.nsh)
#
# `nsh` is linked into ~/.local/bin. Running the script again updates it.
set -eu

upstream="longbridge/nsh"
builds="SuperNSH/nsh-builds"
dir="${NSH_INSTALL_DIR:-$HOME/.nsh}"
bin="$HOME/.local/bin"
version="${NSH_VERSION:-latest}"

fail() {
  echo "nsh: $*" >&2
  exit 1
}

command -v curl > /dev/null 2>&1 || fail "curl is required"

case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) platform="macos-arm64" repository="$upstream" ;;
  Darwin/x86_64) platform="macos-x86_64" repository="$builds" ;;
  Linux/x86_64 | Linux/amd64) platform="linux-x86_64" repository="$upstream" ;;
  Linux/aarch64 | Linux/arm64) platform="linux-arm64" repository="$builds" ;;
  *) fail "no NSH build for $(uname -s) $(uname -m)" ;;
esac

# Both repositories name releases by NSH's tag, so resolve "latest" from NSH
# itself: this repository then serves the same version, or says it has not
# built it yet.
if [ "$version" = latest ]; then
  version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$upstream/releases/latest")"
  version="${version##*/}"
  case "$version" in
    v*) ;;
    *) fail "could not find NSH's latest release" ;;
  esac
fi

asset="nsh-$platform.tar.gz"
url="https://github.com/$repository/releases/download/$version/$asset"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

echo "Downloading $url"
curl -fsSL "$url" -o "$work/$asset" || fail "no $asset for $version yet: $url"
curl -fsSL "$url.sha256" -o "$work/$asset.sha256"

(
  cd "$work"
  if command -v shasum > /dev/null 2>&1; then
    shasum -a 256 -c "$asset.sha256" > /dev/null
  else
    sha256sum -c "$asset.sha256" > /dev/null
  fi
) || fail "the checksum of $asset does not match"

tar -xzf "$work/$asset" -C "$work"
[ -x "$work/nsh/bin/nsh" ] || fail "$asset holds no nsh/bin/nsh"

# Replace the whole directory: runtimes of an older release must not stay.
mkdir -p "$(dirname "$dir")" "$bin"
rm -rf "$dir.old"
[ ! -e "$dir" ] || mv "$dir" "$dir.old"
mv "$work/nsh" "$dir"
rm -rf "$dir.old"
ln -sf "$dir/bin/nsh" "$bin/nsh"

echo "Installed $("$dir/bin/nsh" --version) to $dir"
case ":$PATH:" in
  *":$bin:"*) ;;
  *) echo "Add $bin to your PATH: export PATH=\"$bin:\$PATH\"" ;;
esac
case "$platform" in
  linux-*) echo "The Linux runtime needs GTK 4.14 or newer (Ubuntu 24.04 and later)." ;;
esac
