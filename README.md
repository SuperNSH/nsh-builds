# nsh-builds

Prebuilt [NSH](https://github.com/longbridge/nsh) for the machines its own releases leave out:

| Platform | Where it comes from |
|---|---|
| macOS arm64, Linux x86_64, Windows x86_64 | NSH's own release |
| macOS x86_64 (Intel), Linux arm64, Windows arm64 | This repository's releases |

Releases here use NSH's tags (`v0.4.0` and so on). A workflow checks NSH every 6 hours and builds any release it has not built yet.

## Install

The installers pick the right download for the machine they run on, from either repository.

macOS and Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/SuperNSH/nsh-builds/master/install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/SuperNSH/nsh-builds/master/install.ps1 | iex
```

Set `NSH_VERSION` (e.g. `v0.4.0`) to pin a release, and `NSH_INSTALL_DIR` to change where it goes. They work the same way as NSH's own installers.

In GitHub Actions:

```yaml
- name: Install NSH
  if: runner.os != 'Windows'
  env:
    NSH_VERSION: v0.4.0
  run: |
    curl -fsSL https://raw.githubusercontent.com/SuperNSH/nsh-builds/master/install.sh | sh
    echo "$HOME/.nsh/bin" >> "$GITHUB_PATH"
- name: Install NSH
  if: runner.os == 'Windows'
  shell: pwsh
  env:
    NSH_VERSION: v0.4.0
  run: |
    irm https://raw.githubusercontent.com/SuperNSH/nsh-builds/master/install.ps1 | iex
    "$env:LOCALAPPDATA\nsh\bin" | Out-File -FilePath $env:GITHUB_PATH -Append
```

## How a build is made

[`.github/workflows/build.yml`](.github/workflows/build.yml) runs on a runner of the target architecture (`macos-15-intel`, `ubuntu-24.04-arm`, `windows-11-arm`). It:

1. Downloads NSH's own archive for the same OS (macOS arm64, Linux x86_64 or Windows x86_64) and checks its checksum.
2. Builds the parts that depend on the processor from the release tag's source: the `nsh` CLI, the desktop development host and release runner, and the GPUI development host.
3. Puts those in place of NSH's, and keeps everything else as NSH shipped it: the web runtime, the iOS and Android runtimes and the embedding SDKs, which do not depend on the machine that builds the app.
4. Smoke tests the result: `nsh init`, `nsh build`, and `nsh package` for the desktop, with the runtime built here.
5. Publishes `nsh-<platform>` archives with `.sha256` files under NSH's tag.

On an Intel Mac the iOS runtimes are NSH's own. Packaging for iOS works, but the Mac Catalyst development host (`runtime/ios/maccatalyst`) is built for Apple silicon and does not run on Intel.
