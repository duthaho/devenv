# 45-platform-cli

Optional, independently selectable Kubernetes and infrastructure-as-code CLIs.
The first-run menu lets you select `kubectl`, Helm and OpenTofu separately;
with no tool selected, this module installs nothing.

## Install

To enable a tool outside the menu, set one or more of
`DEVENV_PLATFORM_KUBECTL=1`, `DEVENV_PLATFORM_HELM=1`, and
`DEVENV_PLATFORM_OPENTOFU=1`, then run
`devenv up --force --only 45-platform-cli`. In PowerShell, set the same
variables to `'1'` in `$env:` and run `devenv up -Force -Only 45-platform-cli`.

`--force` / `-Force` is required after a previously skipped run because module
markers cache module files rather than environment-variable selections.

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
  uses Homebrew on macOS, the pinned `v1.37` official `pkgs.k8s.io` apt/rpm
  repositories on Debian/Ubuntu and Fedora-family Linux, and `kubectl` from
  Arch's official repositories. Windows uses winget package
  `Kubernetes.kubectl`.
- [Helm](https://helm.sh/docs/intro/install/) uses Homebrew on macOS, the
  Buildkite-hosted Helm apt repository with its published key fingerprint on
  Debian/Ubuntu, distro packages on Fedora family/Arch Linux, and winget
  package `Helm.Helm` on Windows.
- [OpenTofu](https://opentofu.org/docs/intro/install/) uses Homebrew on macOS,
  OpenTofu's signed official apt/dnf repositories on Debian/Ubuntu and
  Fedora-family Linux, the Arch package, and winget package
  `OpenTofu.OpenTofu` on Windows.

Each installer detects an executable before doing work and verifies it with a
version command after installation. kubectl's repository minor is pinned to
`v1.37`, as required by its official repository URLs; version-manifest
consolidation remains tracked separately in DUTH-17.

## Configuration and safety

The bootstrap never creates, edits, or reads a cluster, state backend, or
kubeconfig. It does not run `kubectl`, `helm`, or `tofu` commands other than
version checks. Set `KUBECONFIG` yourself after installation if you need a
non-default Kubernetes configuration.

## CI and troubleshooting

- `DEVENV_SKIP_PLATFORM_CLI_INSTALL=1` skips the whole module.
- `DEVENV_SKIP_KUBECTL_INSTALL=1` skips only kubectl.
- `DEVENV_SKIP_HELM_INSTALL=1` skips only Helm.
- `DEVENV_SKIP_OPENTOFU_INSTALL=1` skips only OpenTofu.
- `devenv doctor` reports every tool independently.
