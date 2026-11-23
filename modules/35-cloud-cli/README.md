# 35-cloud-cli

Opt-in installation of Cloudflare command-line tools. The first-run menu first
selects this module, then lets you choose `wrangler` and `cloudflared`
independently. No selection means this module does not install anything.

## Install

Enable either tool outside the menu with `DEVENV_CLOUD_WRANGLER=1` or
`DEVENV_CLOUD_CLOUDFLARED=1`, then run
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

Each installer first detects an existing executable and verifies its version
after a new installation. The two installers and their doctor checks are
separate so another cloud CLI can be added without coupling their behavior.

## Authentication

The bootstrap does not log in, create a tunnel, or write credentials. Configure
authentication after installation using `CLOUDFLARE_API_TOKEN` for Cloudflare
API operations or `TUNNEL_TOKEN` for a managed tunnel, where appropriate.

## CI and troubleshooting

- `DEVENV_SKIP_NPM_INSTALL=1` skips global npm installs, including Wrangler.
- `DEVENV_SKIP_WRANGLER_INSTALL=1` skips only Wrangler.
- `DEVENV_SKIP_CLOUDFLARED_INSTALL=1` skips only cloudflared.
- `devenv doctor` reports each CLI independently, including a missing Node/npm
  dependency for Wrangler.
