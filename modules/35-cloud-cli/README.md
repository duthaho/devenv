# 35-cloud-cli

Opt-in installation of cloud command-line tools. The first-run menu first
selects this module, then lets you choose `wrangler`, `cloudflared`, and `aws`
independently. No selection means this module does not install anything.

## Install

Enable a tool outside the menu with `DEVENV_CLOUD_WRANGLER=1`,
`DEVENV_CLOUD_CLOUDFLARED=1`, or `DEVENV_CLOUD_AWS=1`, then run
`devenv up --force --only 35-cloud-cli`. PowerShell users can set the same
variables to `'1'` in `$env:` and run `devenv up -Force -Only 35-cloud-cli`.

`--force` / `-Force` is required when enabling a Cloudflare CLI after an
earlier run skipped this module: bootstrap's module marker caches the module
files, not environment-variable selections.

- [Wrangler](https://developers.cloudflare.com/workers/wrangler/install-and-update/)
  is installed with `npm install -g wrangler` and needs Node/npm from
  `30-toolchains` (mise).
- [cloudflared](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/)
  uses Homebrew on macOS, Cloudflare's official apt/dnf repositories on
  Debian/Ubuntu and Fedora-family Linux, the distro package on Arch, and
  winget package `Cloudflare.cloudflared` on Windows.
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  uses AWS's official `.pkg` on macOS, a signed AWS bundle on Linux
  (`x86_64` and `aarch64`), and AWS's official MSI on Windows. The Linux
  installer verifies the bundle signature against AWS CLI Team key fingerprint
  `FB5D B77F D5C1 18B8 0511 ADA8 A631 0ACC 4672 475C` before installing.

Each installer first detects an existing executable and verifies its version
after a new installation. The two installers and their doctor checks are
separate so another cloud CLI can be added without coupling their behavior.

## Version policy

`config/tool-versions.txt` is the shared source of truth for Wrangler and AWS
CLI versions. Entries currently use `latest`, preserving the existing install
commands. To pin AWS CLI, set its exact `X.Y.Z` version and add a lower-case
SHA-256 for every listed artifact (calculate it with `sha256sum` after
downloading); the installer verifies it before extraction or execution.

## Authentication

The bootstrap does not log in, create a tunnel, or write credentials. Configure
authentication after installation using `CLOUDFLARE_API_TOKEN` for Cloudflare
API operations or `TUNNEL_TOKEN` for a managed tunnel, where appropriate.
For AWS, configure credentials separately with `AWS_PROFILE`, `AWS_REGION`,
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` as
appropriate. The bootstrap never runs `aws configure` or `aws sso login`.

## CI and troubleshooting

- `DEVENV_SKIP_NPM_INSTALL=1` skips global npm installs, including Wrangler.
- `DEVENV_SKIP_WRANGLER_INSTALL=1` skips only Wrangler.
- `DEVENV_SKIP_CLOUDFLARED_INSTALL=1` skips only cloudflared.
- `DEVENV_SKIP_AWS_CLI_INSTALL=1` skips only AWS CLI v2.
- `devenv doctor` reports each CLI independently, including a missing Node/npm
  dependency for Wrangler and whether AWS CLI is missing, v1, or v2.
