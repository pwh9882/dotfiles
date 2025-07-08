# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository that manages configuration files for development tools using a modular XDG-compliant approach. The setup is optimized for macOS development workflows with a focus on terminal productivity and modern editors.

## Installation and Setup

- **Main installation**: `./init.sh` - Runs initialization scripts for all configured tools
- **Modular setup**: Each directory can contain its own `init.sh` for specific setup tasks
- **Configuration location**: Uses `~/.config/` following XDG Base Directory specification

## Key Configuration Components

### Terminal Environment
- **WezTerm** (`.config/wezterm/wezterm.lua`): Advanced terminal with workspace management, session resurrection, and custom keybindings (leader key: Ctrl+A)
- **Zsh Shell** (`~/.zshrc`): Oh-my-zsh configuration with conda/mamba environment management, zoxide for directory jumping, and various productivity aliases
- **Starship Prompt** (`.config/starship.toml`): 262-line configuration with Catppuccin Mocha theme, git integration, and development context awareness

### Editors
- **Neovim** (`.config/nvim/`): Uses AstroNvim v4 distribution with Lazy.nvim plugin management, modular plugin configuration in `lua/plugins/`
- **Zed Editor** (`.config/zed/settings.json`): Configured for remote development via SSH with AI assistant integration

### System Tools
- **Karabiner Elements** (`.config/karabiner/`): Keyboard remapping
- **Neofetch** (`.config/neofetch/`): System information display
- **iTerm2** (`.config/iterm2/`): Terminal emulator settings

## Dependencies

- **Fonts**: JetBrainsMonoNL Nerd Font, Berkeley Mono
- **Terminal**: WezTerm with specific plugins
- **Shell**: Zsh with Oh-my-zsh, zoxide for directory navigation
- **Python**: Mamba/Conda package management
- **Editor**: Neovim with AstroNvim
- **System**: macOS (configurations are macOS-focused)

## Architecture

The repository uses a modular approach where each tool maintains its own configuration space. The setup prioritizes:
- Professional development workflows
- Terminal productivity with advanced features
- Modern plugin-based extensions
- XDG Base Directory compliance
- Cross-application theme consistency (dark themes)

## Working with This Repository

When making changes:
- Test installations by running `./init.sh` 
- Configuration files are in `.config/` subdirectories
- Each tool's init script should be idempotent
- WezTerm and Neovim configurations are highly customized with specific plugin dependencies

## Security Guidelines

**CRITICAL**: This repository contains sensitive development environments. Follow these security practices:

### Files to NEVER Commit
- **`.config/zed/conversations/`** - Contains AI assistant conversations with potential API tokens, personal projects, and sensitive development discussions
- Any files containing API keys, tokens, or credentials
- Personal project data, proprietary code snippets, or confidential information
- Temporary files with sensitive output or debugging information

### Git Safety Practices
- Always review `git status` and `git diff` before committing
- Use `.gitignore` to exclude sensitive directories (already configured for Zed conversations)
- If sensitive data is accidentally committed, immediately:
  1. Stop any pending pushes
  2. Reset git history to before the problematic commit
  3. Selectively re-commit only safe files
  4. Force push the cleaned history

### Repository Maintenance
- Regularly audit `.gitignore` for completeness
- Be especially careful with editor conversation/history files
- Consider using `git secrets` or similar tools for additional protection
- Remember: Once pushed to GitHub, sensitive data requires history rewriting to fully remove

**Note**: A previous incident involved accidentally committing Zed conversations containing Docker and GitHub Personal Access Tokens, requiring complete git history cleanup. This configuration helps prevent similar issues.