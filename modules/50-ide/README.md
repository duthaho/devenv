# 50-ide

Installs VS Code + Cursor and applies the project-level extension list / settings overlay.

## Config

- `config/ide/vscode-extensions.txt` — one extension id per line (use `code --list-extensions` to seed)
- `config/ide/cursor-extensions.txt` — same shape for Cursor
- `config/ide/vscode-settings.json` — merged onto the user settings (overlay wins on conflict)
- `config/ide/cursor-settings.json` — same for Cursor

## Install

| OS      | Method                                                      |
|---------|-------------------------------------------------------------|
| macOS   | `brew install --cask visual-studio-code cursor`             |
| Linux   | Warn-and-skip — install VS Code from packages.microsoft.com |
| WSL2    | Warn-and-skip — Cursor not packaged for Linux desktop       |
| Windows | `winget install Microsoft.VisualStudioCode Anysphere.Cursor`|

Settings paths:
- Linux / WSL: `~/.config/{Code,Cursor}/User/settings.json`
- macOS: `~/Library/Application Support/{Code,Cursor}/User/settings.json`
- Windows: `%APPDATA%\{Code,Cursor}\User\settings.json`

Existing user settings are preserved; the overlay only sets the keys it defines.
