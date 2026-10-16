#!/usr/bin/env bash
# ============================================================================
# start-a-new-project.sh — student machine setup (macOS + Linux/WSL)
# (was start-a-new-website.sh; renamed 15 Oct; v4 16 Oct: installation log
#  lives in the folder you ran this from, project picker for existing
#  projects, Pi refuses to launch without an Ollama API key)
#
# Installs the full taught toolchain in the class order, pre-empts the common
# student-machine failures (missing build tools, old Node, missing provider
# extension, WSL-on-/mnt/c pitfalls), walks every credential, and finishes
# with the working folder created, repo pushed, and Vercel import ready.
#
# Why each tool is in the chain:
#   git        — the memory: every file save remembered locally
#   gh (CLI)   — GitHub login + one-line repo creation/push from the terminal
#   Node (nvm) — runtime the Pi agent harness needs (keep it current)
#   Ollama     — the brain: cloud model access via prepaid credits
#   Pi         — the hands: agent that runs the terminal, edits files, pushes
#   Vercel CLI — the publisher: deploys and fixes when the dashboard misbehaves
#
# Re-runnable: every step checks before acting, so re-run after any mid-way
# failure without side effects. Updates to existing machines are merge-only:
# settings.json gets only its missing/different keys set, and AGENTS.md gets
# any missing rule appended (Directory Boundary, Temporary Folder).
#
# Usage:
#   bash start-a-new-project.sh         # full setup (interactive)
#   bash start-a-new-project.sh --dry-run   # print what it would do, change nothing
#   bash start-a-new-project.sh --log=/path  # real runs write a verbose install log
#                                            # (default: start-a-new-project-installation.log
#                                            #  in the folder you ran this from) — attach it
#                                            # when asking for help
#
# Tested: syntax + --dry-run on Linux and simulated macOS branch; logging
# mechanism + excerpt tests 16 Oct; v4 (log rename, project picker, key-gated
# Pi launch, Vercel link check) 16 Oct. Do one live pass on a fresh Mac and a
# fresh WSL before class.
# ============================================================================

set -euo pipefail

# --- tunables ---------------------------------------------------------------
NVM_VERSION="v0.40.3"                 # pin for reproducibility; bump if class notes say so
PI_PACKAGE="@earendil-works/pi-coding-agent"   # the real Pi (bin 'pi'); @pi-dev/pi does NOT exist on npm
PI_INSTALL_FLAGS="--ignore-scripts"   # official install form; pi needs no lifecycle scripts
PI_OLLAMA_EXT="pi-ollama-cloud"
DEFAULT_MODEL="glm-5.3-flash"   # confirm current id against the course outline before class
WORKDIR_DEFAULT="my-website"

# --- flags ------------------------------------------------------------------
DRY_RUN=0
FORCE_OS=""
SKILLS_DIR=""
LOG_PATH_FLAG=""
# Absolute location of THIS script, resolved BEFORE any cd: later steps change
# the working directory (project folder), and a relative $0 plus a mid-script
# cd made sibling-file discovery look inside the project folder instead.
SCRIPT_ABS="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_ABS=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force-os=*) FORCE_OS="${arg#*=}" ;;
    --skills-dir=*) SKILLS_DIR="${arg#*=}" ;;
    --log=*) LOG_PATH_FLAG="${arg#*=}" ;;
    *) echo "unknown flag: $arg (accepted: --dry-run, --force-os=mac|linux|wsl, --skills-dir=/path, --log=/path)"; exit 2 ;;
  esac
done

# --- cosmetics --------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'
else
  B=""; G=""; Y=""; R=""; N=""
fi
step()  { printf '\n%s== %s ==%s\n' "$B" "$1" "$N"; }
info()  { printf '  %s\n' "$*"; }
ok()    { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn()  { printf '  %s⚠%s %s\n'  "$Y" "$N" "$*"; }
die()   { printf '  %s✗ %s%s\n'  "$R" "$*" "$N" >&2; exit 1; }
pause() { msg="${1:-continue}"; if [ -t 0 ] && [ "$DRY_RUN" = 0 ]; then
            printf '  %s>> %s — Press Enter when done%s' "$Y" "$msg" "$N"; read -r _; else info "(dry-run: would pause here — $msg)"; fi; }
ask()   { if [ -t 0 ] && [ "$DRY_RUN" = 0 ]; then read -r -p "  $1" "$2"; else printf '  (non-interactive) defaulting %s to: %s\n' "$2" "${!2}"; fi; }
run()   { if [ "$DRY_RUN" = 1 ]; then info "[dry-run] $*"; else printf '  + %s\n' "$*"; "$@"; fi; }
have()  { command -v "$1" >/dev/null 2>&1; }

ensure_ollama_key() { # idempotent: already in env, already saved in profile, or prompt+save
  # Pi cannot reach the cloud model without OLLAMA_API_KEY. Called from the
  # credentials step AND again at the Pi-launch gate — a no-op whenever the
  # key is already set, so the gate is the single enforcement point.
  if [ -n "${OLLAMA_API_KEY:-}" ]; then
    ok "OLLAMA_API_KEY already in this shell's environment — skipping the key prompt"
    return 0
  fi
  PROFILE_FILE="$HOME/.bashrc"; [ "${IS_MAC:-0}" = 1 ] && PROFILE_FILE="$HOME/.zshrc"
  SAVED_KEY_LINE="$(grep -h '^export OLLAMA_API_KEY=' "$PROFILE_FILE" 2>/dev/null | tail -1 || true)"
  if [ -n "$SAVED_KEY_LINE" ]; then
    # The line was written by this script (safely quoted); reuse it instead of
    # asking the user to paste the key again on a re-run/new project.
    eval "$SAVED_KEY_LINE"
    export OLLAMA_API_KEY
    ok "OLLAMA_API_KEY loaded from $PROFILE_FILE — no key prompt needed"
    return 0
  fi
  if [ -t 0 ]; then
    cat <<KEYPASTE

  --- Ollama API key needed (Pi cannot reach the cloud model without it) ------
    1. Open   https://ollama.com/settings/keys
    2. Click  "Create API Key"
    3. Copy the key and paste it below
KEYPASTE
    printf '  Paste your Ollama API key (input hidden): '
    read -rs OLLAMA_KEY_INPUT; printf '\n'
    OLLAMA_KEY_INPUT="$(printf '%s' "$OLLAMA_KEY_INPUT" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -z "$OLLAMA_KEY_INPUT" ]; then
      warn "no key entered — Pi will NOT be launched without one. Get it at https://ollama.com/settings/keys (click \"Create API Key\"), then re-run, or before launching pi run:  export OLLAMA_API_KEY=\"<your-key>\""
      return 1
    fi
    export OLLAMA_API_KEY="$OLLAMA_KEY_INPUT"
    printf '\n# Ollama API key — used by Pi (ollama-cloud provider)\nexport OLLAMA_API_KEY=%q\n' "$OLLAMA_KEY_INPUT" >> "$PROFILE_FILE"
    ok "OLLAMA_API_KEY exported and saved to $PROFILE_FILE — all future terminals auto-load it; Pi picks it up from the environment (no /login)"
    unset OLLAMA_KEY_INPUT
    return 0
  fi
  warn "non-interactive run: put the key in the environment before launching pi (export OLLAMA_API_KEY=...)"
  return 1
}

pick_project_menu() { # pick_project_menu "name1\nname2\n..." — prints the picked folder name, or __NEW__
  # Up/down + Enter menu for a terminal; direct number keys 1-9 also work and
  # double as the numbered-list fallback. Bash-3.2-safe (no mapfile/no assoc
  # arrays): macOS ships 3.2 and this script supports it everywhere else.
  __PM_CHOICES="$1"
  PM_N=0
  while IFS= read -r __PM_LINE; do
    [ -n "$__PM_LINE" ] || continue
    PM_ITEMS[$PM_N]="$__PM_LINE"; PM_N=$((PM_N+1))
  done <<EOF
$__PM_CHOICES
New project
EOF
  PM_TOTAL=$PM_N
  PM_SEL=$((PM_TOTAL-1))   # default highlight: "New project"
  printf '  Existing project(s) found in this folder — up/down arrows, Enter to choose:\n'
  while :; do
    PM_I=0
    while [ "$PM_I" -lt "$PM_TOTAL" ]; do
      if [ "$PM_I" -eq "$PM_SEL" ]; then
        printf '  %s> %s%s%s\n' "$B" "$G" "${PM_ITEMS[$PM_I]}" "$N"
      else
        printf '    %s\n' "${PM_ITEMS[$PM_I]}"
      fi
      PM_I=$((PM_I+1))
    done
    read -rsn1 PM_KEY
    case "$PM_KEY" in
      ""|$'\n'|$'\r') break ;;                        # Enter
      $'\033') read -rsn2 PM_KEY                       # arrow: "[A" up, "[B" down
               case "$PM_KEY" in
                 '[A') PM_SEL=$(( (PM_SEL+PM_TOTAL-1) % PM_TOTAL )) ;;
                 '[B') PM_SEL=$(( (PM_SEL+1) % PM_TOTAL )) ;;
               esac ;;
      [1-9]) PM_J=$((PM_KEY-1))
             if [ "$PM_J" -lt "$PM_TOTAL" ]; then PM_SEL=$PM_J; break; fi ;;
    esac
    printf '\033[%dA' "$PM_TOTAL"                       # cursor up: redraw items
  done
  if [ "$PM_SEL" -eq "$((PM_TOTAL-1))" ]; then echo "__NEW__"; else echo "${PM_ITEMS[$PM_SEL]}"; fi
}
# In dry-run nothing is installed, so 'missing tool' must not abort the walkthrough.
require_or_skip() { # require_or_skip <cmd> <fail-message>
  if have "$1"; then return 0; fi
  if [ "$DRY_RUN" = 1 ]; then info "[dry-run] '$1' would be installed by this script"; else die "$2"; fi
}

# --- verbose install logging (real runs only; dry-run writes no log) ---------
# Everything the script prints (stdout+stderr) is mirrored to
# start-a-new-project-installation.log (in the folder the student ran this
# from) via tee, probe commands that used to fail silently now append their
# error output there, and each install command is echoed before it runs. When
# the script ends badly the student is told where the log is — attach it when
# asking for help. The log is scrubbed on exit: ANSI colours stripped, gh's
# one-time device code redacted.
LOG_FILE=""
probe() { # probe <cmd...> — like >/dev/null 2>&1, but failure output is logged
  if [ -n "$LOG_FILE" ]; then "$@" >>"$LOG_FILE" 2>&1; else "$@" >/dev/null 2>&1; fi
}
census() { # one line per managed tool: path on PATH or MISSING
  printf -- '--- tools on PATH (%s) ---\n' "$(date -u '+%Y-%m-%d %H:%M:%SZ')"
  for t in git gh nvm node npm ollama pi vercel curl; do
    printf '%-8s %s\n' "$t" "$(command -v "$t" 2>/dev/null || echo MISSING)"
  done
}
ESC="$(printf '\033')"
log_scrub() { # strip ANSI colours + redact one-time codes; idempotent, best effort
  [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ] || return 0
  sleep 0.3   # let tee flush its tail before we rewrite the file
  sed -E -e "s/${ESC}\[[0-9;]*[A-Za-z]//g" \
         -e "s/one-time code:[[:space:]]*[A-Za-z0-9]{4}-[A-Za-z0-9]{4}/one-time code: ****-****/" \
         "$LOG_FILE" > "${LOG_FILE}.tmp2" 2>/dev/null \
    && mv "${LOG_FILE}.tmp2" "$LOG_FILE" || true
}
if [ "$DRY_RUN" = 0 ]; then
  # Log lives in the LAUNCH DIRECTORY (the folder the student ran this from) —
  # visible to a complete beginner, not buried in $HOME. The path is captured
  # as an absolute value BEFORE any cd so that mid-script cd's into the
  # project folder and the exit-time scrubber (which writes by path) can never
  # resolve it elsewhere. Unwritable launch dir -> fall back to $HOME.
  LOG_FILE="${LOG_PATH_FLAG:-$PWD/start-a-new-project-installation.log}"
  LOG_DIR="$(dirname "$LOG_FILE")"
  if ! mkdir -p "$LOG_DIR" 2>/dev/null || [ ! -w "$LOG_DIR" ]; then
    LOG_FILE="$HOME/start-a-new-project-installation.log"
  fi
  : > "$LOG_FILE" 2>/dev/null || { LOG_FILE="$HOME/start-a-new-project-installation.log"; : > "$LOG_FILE"; }
  {
    echo "=== install-log: start-a-new-project.sh ==="
    echo "started: $(date -u '+%Y-%m-%d %H:%M:%SZ')"
    echo "user: $(id -un 2>/dev/null || id -u)   home: $HOME   invoked from: $PWD"
    echo "bash: $BASH_VERSION"
    echo "PATH: $PATH"
    echo "--- system ---"
    uname -a 2>&1 || true
    [ -r /etc/os-release ] && grep -E '^(NAME|VERSION)=' /etc/os-release || true
    { [ -r /proc/version ] && grep -qi microsoft /proc/version && echo "platform: WSL"; } || true
    census
    echo "=============================================="
  } >> "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
  info "verbose install log: $LOG_FILE — attach this file when asking for help"
  trap '_rc=$?; log_scrub; if [ "$_rc" -ne 0 ]; then printf "  NOTE install ended early (exit code %s) — full log: %s\n" "$_rc" "$LOG_FILE"; fi' EXIT
fi

# --- OS detection -----------------------------------------------------------
IS_MAC=0; IS_LINUX=0; IS_WSL=0; OS_TAG="linux"
# v4 fix: normalise to lowercase. '--force-os=linux' promised in the usage
# block previously died here ('Linux|wsl' matched only the system value).
case "$(printf '%s' "${FORCE_OS:-$(uname -s)}" | tr '[:upper:]' '[:lower:]')" in
  darwin|mac)     IS_MAC=1;  OS_TAG="mac" ;;
  linux|wsl)      IS_LINUX=1; OS_TAG="linux"
                  if grep -qi microsoft /proc/version 2>/dev/null; then IS_WSL=1; OS_TAG="wsl"; fi ;;
  *) die "Unsupported OS. Supported: macOS (Darwin), Linux/WSL. On Windows, run windows-wsl-bootstrap.ps1 first." ;;
esac
if [ "$(id -u)" = "0" ]; then SUDO=""; else SUDO="sudo"; fi
if [ "$IS_LINUX" = 1 ]; then export DEBIAN_FRONTEND=noninteractive; fi
# Adopt any pre-existing nvm installation into THIS shell immediately: without
# this, a re-run from a shell that hasn't sourced nvm would fail `have pi` and
# install a second, parallel node/npm stack via the system npm.
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  set +u; . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1; set -u
fi
info "Detected platform: $OS_TAG"
# Relative-invocation safety: students often run 'bash start-a-new-project.sh'
# from the extracted folder — remind them of the absolute form this script has
# already resolved for itself (used by the WSL relocation hint later).
case "${BASH_SOURCE[0]:-$0}" in
  /*) ;;
  *) [ -n "$SCRIPT_ABS" ] && info "Tip: from any directory you can run it as:  bash \"$SCRIPT_ABS/start-a-new-project.sh\"" ;;
esac

# ============================================================================
step "1/10  Build tools & base packages"
# git/build-essential (Linux) or Xcode CLT (Mac) are what npm/package builds
# sit on; a fresh OS hides both until the first install fails.
if [ "$IS_MAC" = 1 ]; then
if have git; then ok "git present: $(git --version)"; else
  warn "git missing on a fresh Mac = Xcode CLT install pending, launching it"
  run xcode-select --install || true
  info "A GUI window pops up — click Install, this takes a few minutes."
  pause "finish the Xcode CLT install"
  require_or_skip git "git still missing after CLT install — re-run this script"
fi
if xcode-select -p >/dev/null 2>&1; then ok "Xcode CLT installed"; else
  warn "CLT path missing — installing"
  run xcode-select --install || true
  pause "finish the Xcode CLT install"
fi
else
  if have apt-get; then
    MISSING=""
    # zstd: ollama's installer hard-refuses without it ("ERROR: This version
    # requires zstd for extraction") — the wall hit in the live run.
    for p in curl git ca-certificates build-essential zstd; do
      probe dpkg -s "$p" || MISSING="$MISSING $p"
    done
    if [ -n "$MISSING" ]; then
      run $SUDO apt-get update
      # build-essential = gcc/g++/make: without it, npm builds die with
      # "gyp ERR!" / "gcc: not found" — today's most common WSL wall.
      run env DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y $MISSING
    else ok "curl, git, build-essential, zstd all present"; fi
  else
    warn "No apt-get — install curl/git/build-essential with your distro's package manager, then re-run."
    pause
  fi
fi

# ============================================================================
step "2/10  Mac-only quality-of-life (Homebrew, JumpCut, .md preview)"
if [ "$IS_MAC" = 1 ]; then
  if have brew; then ok "Homebrew present"; else
    info "Installing Homebrew (needed for JumpCut)"
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)";
    elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
  fi
  have brew || require_or_skip brew "Homebrew install did not complete — re-run this script"
  if [ "$DRY_RUN" = 0 ] && ! /usr/libexec/PlistBuddy -c "Print" /Applications/JumpCut.app/Contents/Info.plist >/dev/null 2>&1 \
     && [ ! -d /Applications/JumpCut.app ]; then
    run brew install --cask jumpcut   # multi-item clipboard: saves copy-paste pain during setup
  else ok "JumpCut (installed or dry-run)"; fi
  info "Markdown preview needs no install: 'qlmanage <file>.md' in Terminal."
else
  info "(macOS-only step — skipped on $OS_TAG)"
fi

# ============================================================================
step "3/10  Working folder (created HERE — in the directory you ran this from)"
WORKDIR="$WORKDIR_DEFAULT"
# If project folder(s) already exist in the Launch Directory (folder containing
# .git), let the student CONTINUE one instead of silently starting a parallel,
# un-hooked project next to it. No projects found -> plain folder-name prompt
# exactly as before. Dry-run mentions the picker without blocking; a piped
# (non-TTY) run lists what it found and takes the 'New project' default.
PM_PROJECTS=""
for d in */; do
  d="${d%/}"
  if [ -e "$d/.git" ]; then PM_PROJECTS="$PM_PROJECTS$d"$'\n'; fi   # if-form: a plain '&&' would kill the script under set -e when the last folder has no .git
done
PM_PROJECTS="${PM_PROJECTS%$'\n'}"
if [ -n "$PM_PROJECTS" ] && [ "$DRY_RUN" = 1 ]; then
  info "[dry-run] project folder(s) already exist here — would present a picker: continue one, or start a new project"
  ask "Project folder name [$WORKDIR]: " WORKDIR
elif [ -n "$PM_PROJECTS" ] && [ ! -t 0 ]; then
  printf '%s\n' "$PM_PROJECTS" | while IFS= read -r d; do info "existing project found: $d"; done
  printf '  (non-interactive) defaulting to a NEW project named: %s\n' "$WORKDIR"
elif [ -n "$PM_PROJECTS" ]; then
  PM_PICKED="$(pick_project_menu "$PM_PROJECTS")"
  if [ "$PM_PICKED" = "__NEW__" ]; then
    ask "Project folder name [$WORKDIR]: " WORKDIR
  else
    WORKDIR="$PM_PICKED"
    ok "continuing existing project: $WORKDIR"
  fi
else
  ask "Project folder name [$WORKDIR]: " WORKDIR
fi
WORKDIR="${WORKDIR:-$WORKDIR_DEFAULT}"
PROJECT_DIR="$PWD/$WORKDIR"
info "Project will live at: $PROJECT_DIR"
if [ "$DRY_RUN" = 1 ]; then
  info "[dry-run] mkdir -p '$PROJECT_DIR' + git init (branch: main) if not already a repo"
else
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"
  if [ -d .git ]; then ok "already a git repo"; else
    git init -b main 2>/dev/null || { git init; git branch -M main; }
    ok "git repo initialised (branch: main)"
  fi
fi
# .gitignore FIRST — .env must never reach GitHub (safety standard, not paranoia)
# Entries are ensured INDIVIDUALLY: a new project gets the full file; a resumed
# project gets only the missing lines appended — never a wholesale rewrite
# (same merge-only semantics as AGENTS.md and settings.json).
GITIG_FULL='.env
.env.*
node_modules/
.vercel/
.DS_Store
Thumbs.db
*.log
tmp/'
if [ ! -f "$PROJECT_DIR/.gitignore" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    info "[dry-run] would create $PROJECT_DIR/.gitignore (env secrets, node_modules, Vercel state, OS junk, logs, tmp/)"
  else
    printf '%s\n' "$GITIG_FULL" > "$PROJECT_DIR/.gitignore"
    ok "wrote .gitignore (.env + .env.* secrets, node_modules, .vercel, OS junk, logs, tmp/)"
  fi
else
  GITIG_MISSING=""
  while IFS= read -r gi_entry; do
    [ -n "$gi_entry" ] || continue
    grep -qxF "$gi_entry" "$PROJECT_DIR/.gitignore" || GITIG_MISSING="$GITIG_MISSING$gi_entry"$'\n'
  done <<EOF
$GITIG_FULL
EOF
  if [ -z "$GITIG_MISSING" ]; then
    ok ".gitignore already covers every entry — nothing to add"
  elif [ "$DRY_RUN" = 1 ]; then
    info "[dry-run] would append missing entries to .gitignore: $(printf '%s' "$GITIG_MISSING" | tr '\n' ' ' | sed 's/ $//')"
  else
    printf '\n# added by start-a-new-project (merge — existing entries untouched)\n%s' "$GITIG_MISSING" >> "$PROJECT_DIR/.gitignore"
    ok ".gitignore updated (appended: $(printf '%s' "$GITIG_MISSING" | tr '\n' ' ' | sed 's/ $//')) — existing entries untouched"
  fi
fi
if [ ! -f "$PROJECT_DIR/SPECIFICATION.md" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    info "[dry-run] would write $PROJECT_DIR/SPECIFICATION.md stub"
  else
    printf '# SPECIFICATION\n\nDraft this with a frontier LLM chat (Gemini/ChatGPT/Claude): pages, sections, purpose, copy, brand colours. The agent builds FROM this file.\n' > "$PROJECT_DIR/SPECIFICATION.md"
    ok "wrote SPECIFICATION.md stub"
  fi
else ok "SPECIFICATION.md already present"; fi
if [ "$IS_WSL" = 1 ]; then
  case "$PROJECT_DIR" in
    /mnt/*)
      warn "Project is under /mnt/ (the Windows filesystem) — git and npm run many times slower there, and dev-server file watching breaks."
      case "$PROJECT_DIR" in
        *OneDrive*|*onedrive*)
          warn "This path is inside OneDrive as well — OneDrive syncing .git internals causes lock conflicts and stalls on top of the /mnt tax, and cloud-only placeholder files can break git entirely."
          ;;
      esac
      info 'Where projects belong on Windows/WSL: inside the Linux home (~ = /home/<user>). That is a real Linux filesystem — fast.'
      info 'You still reach it from Windows: Explorer address bar  \\wsl.localhost\Ubuntu\home\<user>\\<project>  — browse, drag files in, pin to Quick Access. (Same location as \\wsl$\<distro>\...)'
      info "Easiest fix: run this script from your Linux home instead:   cd ~ && bash \"$SCRIPT_ABS/start-a-new-project.sh\""
      info 'Editing from Windows: use VS Code with the WSL remote (it opens the Linux folder natively), or edit through the \\wsl.localhost path — just never BUILD from a /mnt/c copy.'
      ;;
    *)
      ok "good project location (native Linux filesystem — full-speed git/npm)"
      ;;
  esac
fi

# ============================================================================
step "4/10  GitHub (account + gh CLI + git credentials)"
if [ "$IS_MAC" = 1 ]; then have gh || run brew install gh
else
  if ! have gh; then
    if have apt-get && probe apt-cache show gh; then run env DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y gh
    else
      # gh not in this Ubuntu's repos — add GitHub's official apt repo
      run bash -c "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
      run bash -c "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | $SUDO tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
      run $SUDO apt-get update && run env DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y gh
    fi
  fi
fi
have gh || require_or_skip gh "gh CLI install failed — install gh manually then re-run"
if [ "$DRY_RUN" = 0 ] && ! probe gh auth status; then
  info "No GitHub login on this machine."
  info "A one-time code will appear — open https://github.com/login/device in ANY browser (your phone is fine; a headless WSL box cannot open one itself) and enter it."
  # Flags pre-answer gh's four prompts (account/protocol/auth/web) so students
  # skip straight to the device code.
  run gh auth login --hostname github.com --git-protocol https --web
fi
run gh auth setup-git   # git now uses gh as its credential helper — pushes work without tokens in URLs
if [ "$DRY_RUN" = 0 ]; then
  if probe gh auth status; then
    # Canonical GitHub noreply identity, (re)set on EVERY run: idempotent and
    # self-healing (a live run filled user.email with a 404 JSON blob when the
    # user/emails scope was missing, so the old only-if-unset logic kept it).
    GH_LOGIN="$(gh api user --jq .login)"
    GH_ID="$(gh api user --jq .id)"
    git config user.name  "$GH_LOGIN"
    git config user.email "${GH_ID}+${GH_LOGIN}@users.noreply.github.com"
    ok "git identity set from GitHub: $GH_LOGIN <$(git config user.email)>"
  else ok "git identity present: $(git config user.name || echo unset)"; fi
fi
if [ "$DRY_RUN" = 0 ] && ! probe gh auth status; then
  warn "Still not authenticated — run 'gh auth login' manually, then re-run this script."
fi

# ============================================================================
step "5/10  Node.js via nvm (runtime Pi needs)"
# Two failure modes to dodge:
#  - no/too-old node -> nvm
#  - SYSTEM distro node (>=18) looks fine but its global prefix
#    (/usr/lib/node_modules) is root-owned -> every 'npm i -g' dies with
#    EACCES (hit live on Windows/WSL 14 Oct; students then reach for sudo,
#    which also poisons ~/.npm with root-owned cache files). In that case
#    switch to nvm-managed node instead: no sudo, ever.
NODE_READY=0
if have node; then
  NODE_MAJOR="$(node -v | sed 's/^v//' | cut -d. -f1)"
  NPM_PREFIX="$(npm config get prefix 2>/dev/null || echo /usr)"
  if [ "${NODE_MAJOR:-0}" -ge 18 ] && [ -w "$NPM_PREFIX" ]; then
    NODE_READY=1; ok "node $(node -v) OK (>=18), npm global prefix user-writable ($NPM_PREFIX)"
  else
    if [ "${NODE_MAJOR:-0}" -ge 18 ]; then
      warn "node $(node -v) is the system install with a root-owned global prefix ($NPM_PREFIX) — 'npm i -g' would need sudo. Switching to nvm-managed node instead (keeps installs user-owned, no sudo)."
    else
      warn "node too old ($(node -v)) — installing current LTS via nvm"
    fi
  fi
else
  info "node not installed — installing via nvm"
fi
if [ "$NODE_READY" = 0 ]; then
  export NVM_DIR="$HOME/.nvm"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then run bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash" || warn "nvm install script failed — check network, then re-run"; fi
  if [ -s "$NVM_DIR/nvm.sh" ]; then set +u; . "$NVM_DIR/nvm.sh"; set -u; else require_or_skip nvm "nvm install failed — re-run"; fi
  run nvm install --lts || warn "nvm install --lts failed — check network, then re-run"
  # Belt-and-braces: activate the LTS even when it was already installed
  # (otherwise a system node stays first on PATH), then persist the default.
  if [ "$DRY_RUN" = 1 ]; then
    info "[dry-run] nvm use --lts + nvm alias default lts/*"
  else
    nvm use --lts >/dev/null 2>&1 || true
    nvm alias default lts/* >/dev/null 2>&1 || true
  fi
  require_or_skip node "node still missing after nvm install — open a NEW terminal and re-run (nvm needs a fresh shell PATH)"
  ok "node $(node -v) / npm $(npm -v)"
fi
# Guarantee NEW shells get node — runs on EVERY pass, even when node was
# already present: future terminals depend on .bashrc, not on this script's
# own sourced copy of nvm.
if [ "$DRY_RUN" = 1 ]; then
  info "[dry-run] would ensure the nvm loader is in ~/.bashrc and probe a fresh shell for node"
else
  if [ -f "$HOME/.bashrc" ] && ! grep -q 'NVM_DIR' "$HOME/.bashrc"; then
    run bash -c "printf '\\nexport NVM_DIR=\"\$HOME/.nvm\"\\n[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"\\n' >> $HOME/.bashrc"
    ok "appended nvm loader to .bashrc (new terminals get node automatically)"
  fi
  if ! bash -ic 'command -v node >/dev/null 2>&1' 2>/dev/null; then
    warn "a FRESH shell does not see node (this terminal does — it has nvm sourced). If pi later says 'command not found': run 'source ~/.nvm/nvm.sh' in that shell, or open the terminal as an interactive/login bash."
  fi
fi

# ============================================================================
step "6/10  Ollama (the brain — cloud models)"
if [ "$IS_MAC" = 1 ]; then
  have ollama || run brew install ollama
else
  # ollama's installer aborts without zstd ("ERROR: This version requires
  # zstd for extraction") — confirmed in the live run. Pre-install it.
  if ! have zstd; then
    warn "zstd missing (ollama's installer needs it) — installing"
    if have apt-get; then run env DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y zstd
    elif have dnf; then run $SUDO dnf install -y zstd
    elif have pacman; then run $SUDO pacman -S --noconfirm zstd
    else warn "unknown package manager — install zstd manually, then re-run"
    fi
  fi
  if have ollama; then ok "ollama present"; else
    if run bash -c "curl -fsSL https://ollama.com/install.sh | sh"; then ok "ollama installed"; else
      warn "ollama installer failed — fix with 'sudo apt-get install zstd' and re-run. Cloud models via Pi + API key still work without the local daemon."
    fi
  fi
fi
if [ "$DRY_RUN" = 0 ]; then
  if ! probe ollama list; then
    if [ "$IS_MAC" = 1 ]; then run brew services start ollama; else
      nohup ollama serve >/dev/null 2>&1 & sleep 2
      if ! probe ollama list; then
        if have systemctl && systemctl is-system-running >/dev/null 2>&1; then
          run bash -c "systemctl start ollama 2>/dev/null || true"
        fi
        pause "Ollama daemon may need its own terminal ('ollama serve')."
      fi
    fi
  fi
  probe ollama list && ok "ollama daemon reachable" || warn "ollama daemon not reachable yet — cloud models may still work; check later with 'ollama list'"
fi
info "NOTE: cloud models via Pi need NO 'ollama signin'/'ollama login' — authentication is the OLLAMA_API_KEY environment variable (prompted for in step 8)."

# ============================================================================
step "7/10  Pi (agent harness) + Ollama provider extension + Vercel CLI"
# sudo only as a LAST resort: if step 5 could not get us onto nvm node and
# the npm global prefix is still root-owned, install with sudo rather than
# fail — and self-heal the ~/.npm damage older 'sudo npm' runs left behind.
NPM_SUDO=""
if [ "$DRY_RUN" = 0 ] && have npm; then
  NPfx="$(npm config get prefix 2>/dev/null || echo /usr)"
  if [ -w "$NPfx" ]; then :; else NPM_SUDO="$SUDO"
    warn "npm global prefix $NPfx is not user-writable — global installs fall back to sudo (last resort; nvm-managed node avoids this entirely)"
  fi
fi
if [ "$DRY_RUN" = 0 ] && [ -d "$HOME/.npm" ] && [ -n "$(find "$HOME/.npm" -maxdepth 3 -user root -print -quit 2>/dev/null || true)" ]; then
  warn "found root-owned files in ~/.npm (left by a previous 'sudo npm') — fixing ownership"
  run bash -c "$SUDO chown -R '$(id -u):$(id -g)' $HOME/.npm"
  ok "~/.npm ownership restored to $(id -un)"
fi
npm_g() { # global npm install: sudo-aware + dry-run aware
  if [ "$DRY_RUN" = 1 ]; then info "[dry-run] ${NPM_SUDO:+sudo }npm install -g $*"; else printf '  + %snpm install -g %s\n' "${NPM_SUDO:+sudo }" "$*"; ${NPM_SUDO:+"$NPM_SUDO "}"npm" install -g "$@"; fi
}
# Each install runs only when the tool is missing — re-runs (new project on a
# set-up machine) skip straight through.
if have pi; then ok "pi present ($(pi --version 2>/dev/null | head -1 || echo installed))"; else
  npm_g $PI_INSTALL_FLAGS $PI_PACKAGE || warn "pi npm install failed — check node/npm, then re-run"
fi
require_or_skip pi "Pi not on PATH after npm install — check node/npm, then re-run"
# CRITICAL: without this extension Ollama never appears in Pi's provider list,
# and cloud auth blocks with 'upgrade required'/'pro account needed' — even
# with paid credits. Verified fix in class.
if have pi; then
  if run bash -c "pi install npm:$PI_OLLAMA_EXT"; then ok "pi-ollama-cloud extension present"; else
    warn "pi install npm:pi-ollama-cloud failed — NOT fatal: settings.json lists it under packages, so Pi installs+loads it on first launch"
  fi
fi
if have vercel; then ok "vercel CLI present"; else
  npm_g vercel@latest || warn "vercel CLI install failed — run 'npm i -g vercel@latest' manually"
fi
require_or_skip vercel "Vercel CLI missing after install — re-run or 'npm i -g vercel@latest' manually"

# --- 7b. Ryan's agent skills -> ~/.pi/agent/skills/ -------------------------
# Pi auto-discovers skills here at launch; no registration step needed.
PI_AGENT_DIR="$HOME/.pi/agent"
SKILLS_DEST="$PI_AGENT_DIR/skills"
run mkdir -p "$SKILLS_DEST"
if [ -z "$SKILLS_DIR" ]; then
  for cand in "$SCRIPT_ABS/ryans-ai-agent-skills" "$HOME/ryans-ai-agent-skills" "$HOME/Downloads/ryans-ai-agent-skills"; do
    if [ -d "$cand" ]; then SKILLS_DIR="$cand"; break; fi
  done
fi
if [ -n "$SKILLS_DIR" ] && [ -d "$SKILLS_DIR" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    info "[dry-run] would MOVE skills from '$SKILLS_DIR' into $SKILLS_DEST/ (source removed afterwards; overwrites same-named skills)"
  else
    cp -R "$SKILLS_DIR/." "$SKILLS_DEST/"
    SKILL_COUNT=0
    shopt -s nullglob   # no subdirs -> zero iterations, not one with a literal '*' path
    for d in "$SKILLS_DEST"/*/; do [ -f "${d}SKILL.md" ] && SKILL_COUNT=$((SKILL_COUNT+1)) || true; done
    shopt -u nullglob
    ok "agent skills installed: $SKILL_COUNT skills with SKILL.md in $SKILLS_DEST (moved from: $SKILLS_DIR)"
    [ "$SKILL_COUNT" -gt 0 ] || warn "no SKILL.md found in copied folders — check the skills folder layout (skill-name/SKILL.md); moving would have deleted the source"
    # Copy-then-move (same volume => atomic rename via mv); the source folder
    # must NOT remain behind once skills are installed. On re-runs the source
    # is already gone (moved previously), which is the expected state.
    mv "$SKILLS_DIR" "${SKILLS_DIR}.moved.$$" 2>/dev/null && rm -rf "${SKILLS_DIR}.moved.$$"
    ok "source skills folder removed — skills live only in ~/.pi/agent/skills now"
  fi
else
  DEST_SKILLS=0
  shopt -s nullglob
  for d in "$SKILLS_DEST"/*/; do [ -f "${d}SKILL.md" ] && DEST_SKILLS=$((DEST_SKILLS+1)) || true; done
  shopt -u nullglob
  if [ "$DEST_SKILLS" -gt 0 ]; then
    ok "skills already installed in ~/.pi/agent/skills ($DEST_SKILLS skills) — nothing to move; update kits by replacing folders there"
  else
    warn "skills folder 'ryans-ai-agent-skills' not found (looked beside start-a-new-project.sh, ~, ~/Downloads) and ~/.pi/agent/skills is empty — re-run with --skills-dir=/path to add Ryan's skills. Pi runs fine without them."
  fi
fi

# --- 7c. Pi settings.json (Ryan's class defaults — idempotent merge) --------
# MISSING file -> write the canonical defaults. EXISTING file -> merge-only:
# keys this script owns are set when absent or different, everything else
# (other keys, extra packages entries) is preserved, and an already-correct
# file is NOT rewritten. Previous copy kept as settings.json.previous whenever
# a write happens. This also removes the /model step: default provider + model
# are preset, and Pi auto-installs the listed packages (pi-ollama-cloud,
# pi-hide-providers, web-search) on its first launch.
SETTINGS_FILE="$PI_AGENT_DIR/settings.json"
if [ "$DRY_RUN" = 1 ]; then
  info "[dry-run] would ensure $SETTINGS_FILE carries the class defaults (merge-only: missing/different keys set, rest of the file untouched)"
else
  MERGED=""
  if [ -f "$SETTINGS_FILE" ] && command -v node >/dev/null 2>&1; then
    # Update-in-place: merge the class defaults into an EXISTING settings.json.
    # Only keys this script owns are added or corrected; everything else
    # (extra keys, extra packages) is preserved; an already-up-to-date file is
    # never rewritten. packages[] is a set-union so Pi's own packages stay.
    MERGED="$(node -e '
      const fs = require("fs");
      const f = process.argv[1];
      let cur = {};
      try { cur = JSON.parse(fs.readFileSync(f, "utf8")); } catch (e) { console.log("invalid"); process.exit(0); }
      const want = {
        defaultModel: "glm-5.3-flash",
        defaultProvider: "ollama-cloud",
        hideThinkingBlock: true,
        defaultThinkingLevel: "high"
      };
      const wantPkgs = ["npm:pi-ollama-cloud", "npm:pi-hide-providers", "npm:@ollama/pi-web-search"];
      const missing = {};
      for (const k of Object.keys(want)) {
        if (JSON.stringify(cur[k]) !== JSON.stringify(want[k])) missing[k] = want[k];
      }
      const pkgs = Array.from(new Set([...(Array.isArray(cur.packages) ? cur.packages : []), ...wantPkgs]));
      if (JSON.stringify(cur.packages) !== JSON.stringify(pkgs)) missing.packages = pkgs;
      if (Object.keys(missing).length === 0) { console.log("unchanged"); process.exit(0); }
      fs.copyFileSync(f, f + ".previous");
      fs.writeFileSync(f, JSON.stringify(Object.assign({}, cur, missing), null, 2) + String.fromCharCode(10));
      console.log("updated:" + Object.keys(missing).join(","));
    ' "$SETTINGS_FILE" 2>/dev/null)" || MERGED=""
  fi
  case "$MERGED" in
    unchanged)
      ok "settings.json already carries the class defaults — nothing to change"
      ;;
    updated:*)
      if node -e "JSON.parse(require('fs').readFileSync('$SETTINGS_FILE','utf8'))" 2>/dev/null; then
        ok "settings.json merged (${MERGED#updated:} set) + JSON-validated — other keys untouched (previous copy kept as settings.json.previous)"
      else
        warn "settings.json merge FAILED JSON validation — fix it at $SETTINGS_FILE before launching Pi"
      fi
      ;;
    *)
      # No node, missing file, or unparseable settings: fall back to the full
      # canonical write (same output as a first install). Flag a pre-existing
      # file as replaced — that's the one destructive-ish path here.
      HAD_SETTINGS=0
      [ -f "$SETTINGS_FILE" ] && HAD_SETTINGS=1
      [ "$HAD_SETTINGS" = 1 ] && cp "$SETTINGS_FILE" "$SETTINGS_FILE.previous" 2>/dev/null || true
      cat > "$SETTINGS_FILE" <<'JSON'
{
  "defaultModel": "glm-5.3-flash",
  "defaultProvider": "ollama-cloud",
  "hideThinkingBlock": true,
  "defaultThinkingLevel": "high",
  "packages": [
    "npm:pi-ollama-cloud",
    "npm:pi-hide-providers",
    "npm:@ollama/pi-web-search"
  ]
}
JSON
      if command -v node >/dev/null 2>&1; then
        if node -e "JSON.parse(require('fs').readFileSync('$SETTINGS_FILE','utf8'))" 2>/dev/null; then
          if [ "$HAD_SETTINGS" = 1 ]; then
            warn "settings.json REPLACED with class defaults (node unavailable for a merge-only update; previous copy kept as settings.json.previous)"
          else
            ok "settings.json written + JSON-validated (previous copy kept as settings.json.previous)"
          fi
        else
          warn "settings.json written but FAILED JSON validation — fix it at $SETTINGS_FILE before launching Pi"
        fi
      else
        ok "settings.json written (no node free to validate JSON — eyeball $SETTINGS_FILE once)"
      fi
      ;;
  esac
fi

# --- 7d. AGENTS.md — boundary + temp-folder rules (Pi reads it at launch) ----
# Idempotent per rule: create the file when missing; append ONLY the missing
# rules to an existing file; touch nothing when every rule is already there.
AGENTS_FILE="$PI_AGENT_DIR/AGENTS.md"
AGENTS_RULE_1='Confine all operations strictly to the project root and its subdirectories.'
AGENTS_RULE_2='never navigate to parent directories or external paths outside the project root'
AGENTS_TMP_RULE="If a temporary folder is needed, use ./tmp/ or create it if it doesn't exist yet. Do not use /tmp/ or create any folders outside of this working directory."
agents_boundary_block() {
  cat <<'AGENTS'
# Directory Boundary Rule
- Confine all operations strictly to the project root and its subdirectories.
- You may use `cd` into subdirectories, but never navigate to parent directories or external paths outside the project root.
AGENTS
}
agents_tmp_block() {
  cat <<'AGENTS'
# Temporary Folder Rule
- If a temporary folder is needed, use ./tmp/ or create it if it doesn't exist yet. Do not use /tmp/ or create any folders outside of this working directory.
AGENTS
}
agents_has_boundary() {
  [ -f "$AGENTS_FILE" ] && grep -qF "$AGENTS_RULE_1" "$AGENTS_FILE" && grep -qF "$AGENTS_RULE_2" "$AGENTS_FILE"
}
agents_has_tmp() {
  [ -f "$AGENTS_FILE" ] && grep -qF "$AGENTS_TMP_RULE" "$AGENTS_FILE"
}
if [ "$DRY_RUN" = 1 ]; then
  if [ ! -f "$AGENTS_FILE" ]; then
    info "[dry-run] would create $AGENTS_FILE with the Directory Boundary + Temporary Folder rules"
  elif ! agents_has_boundary && ! agents_has_tmp; then
    info "[dry-run] would append both rules to $AGENTS_FILE (existing content untouched)"
  elif ! agents_has_boundary; then
    info "[dry-run] would append the Directory Boundary Rule to $AGENTS_FILE (existing content untouched)"
  elif ! agents_has_tmp; then
    info "[dry-run] would append the Temporary Folder Rule to $AGENTS_FILE (existing content untouched)"
  else
    info "[dry-run] AGENTS.md already contains both rules — nothing to do"
  fi
elif [ ! -f "$AGENTS_FILE" ]; then
  { agents_boundary_block; printf '\n'; agents_tmp_block; } > "$AGENTS_FILE"
  ok "AGENTS.md created with the Directory Boundary + Temporary Folder rules"
else
  APPENDED=""
  if ! agents_has_boundary && ! agents_has_tmp; then
    { agents_boundary_block; printf '\n'; agents_tmp_block; } >> "$AGENTS_FILE"
    APPENDED="Directory Boundary + Temporary Folder rules"
  elif ! agents_has_boundary; then
    { printf '\n'; agents_boundary_block; } >> "$AGENTS_FILE"
    APPENDED="Directory Boundary Rule"
  elif ! agents_has_tmp; then
    { printf '\n'; agents_tmp_block; } >> "$AGENTS_FILE"
    APPENDED="Temporary Folder Rule"
  fi
  if [ -n "$APPENDED" ]; then
    ok "$APPENDED appended to AGENTS.md — existing content untouched"
  else
    ok "AGENTS.md already contains both rules — nothing to do"
  fi
fi

# ============================================================================
step "8/10  Credentials (Ollama API key + Vercel login)"
cat <<TOKENS

  --- What you need, step by step -------------------------------

  1) GitHub account (if new):  https://github.com/signup
     Login already happened in step 4 via 'gh auth login' — nothing to paste.

  2) Ollama (the ONLY auth Pi needs — no /login, no token files):
       a. https://ollama.com -> sign up / sign in (free account)
       b. Add your prepaid credit (class uses ~US\$5) in billing/settings
       c. https://ollama.com/settings/keys -> "Create API Key" -> COPY it
     You will paste that key below; the script exports it for this session
     AND saves it to your shell profile so every future terminal has it.
     IMPORTANT: Pi will NOT launch without this key — the script asks again
     at the end if it's still missing.
     (If a model ever says 'pro account needed' — that was the missing
      EXTENSION, already installed in step 7, not your account.)

  3) Vercel account: created automatically by 'vercel login' (browser).

  4) OPTIONAL fine-grained GitHub PAT (only if Pi is configured to call the
     GitHub API itself with GITHUB_TOKEN in .env):
       github.com/settings/personal-access-tokens/new
       -> scope to THIS ONE repo, read/write Contents only (blast radius = 1 repo)
     Plain 'git push' needs NO token — gh owns git credentials (step 4).

TOKENS
if [ "$DRY_RUN" = 1 ]; then
  info "[dry-run] would ensure OLLAMA_API_KEY (prompt only if not already set) and run 'vercel login' (only if not authed)"
else
  ensure_ollama_key || warn "setup continues — the Pi launch at the end will ask for the key again before Pi starts"
fi
if [ "$DRY_RUN" = 1 ]; then : ; elif have vercel && probe vercel whoami; then
  ok "Vercel already logged in ($(vercel whoami 2>/dev/null)) — skipping login"
else
  have vercel && vercel login || warn "run 'vercel login' later"
fi

# ============================================================================
step "9/10  Repo creation + first push"
# The repo name is only ever needed to CREATE a repo — if origin is already
# linked from a previous run/resume, there is nothing to name, so skip the
# prompt entirely instead of re-asking a noob a question that has no effect.
if [ "$DRY_RUN" = 0 ]; then
  cd "$PROJECT_DIR"
  HAVE_ORIGIN=0
  if probe git remote get-url origin; then   # if-form, not '&&': set -e must not treat a missing origin as fatal
    HAVE_ORIGIN=1
    ok "remote already linked ($(git remote get-url origin)) — no repo-name prompt needed"
  fi
else
  HAVE_ORIGIN=0   # dry-run: assume fresh-project walkthrough, keep the ask line
fi
REPO_NAME="$WORKDIR"
if [ "${HAVE_ORIGIN:-0}" = 1 ]; then
  :   # name comes from the existing remote
else
  ask "GitHub repo name [$REPO_NAME]: " REPO_NAME
  REPO_NAME="${REPO_NAME:-$WORKDIR}"
fi
if [ "$DRY_RUN" = 0 ]; then
  OWNER="$(gh api user --jq .login 2>/dev/null || echo unknown)"
  if ! probe git remote get-url origin; then
    git add -A
    if git diff --cached --quiet; then info "nothing to commit (skipping commit)"; else
      git commit -m "Initial commit" >/dev/null && ok "initial commit made"
    fi
    git branch -M main 2>/dev/null || true
    # If a repo with this name already exists on the account (earlier run
    # created it; local folder was deleted/recreated), LINK it instead of
    # letting 'gh repo create' die on the duplicate name — gh's own error
    # gets captured and shown either way, never swallowed again.
    if [ "$DRY_RUN" = 0 ] && probe gh repo view "$OWNER/$REPO_NAME"; then
      warn "remote repo $OWNER/$REPO_NAME already exists — linking it rather than creating a duplicate"
      git remote add origin "https://github.com/$OWNER/$REPO_NAME.git"
      PUSH_ERR="$(git push -u origin main 2>&1)" || true
      if [ -n "$PUSH_ERR" ]; then printf '%s\n' "$PUSH_ERR" | sed 's/^/    /'; fi
      if probe git ls-remote --heads origin main; then
        ok "verified: branch 'main' pushed to github.com/$OWNER/$REPO_NAME"
      else
        warn "push did not land — try: gh auth setup-git && git push -u origin main"
      fi
    else
      CREATE_OUT="$(gh repo create "$REPO_NAME" --private --source=. --push 2>&1)" || true
      if [ -n "$CREATE_OUT" ]; then printf '%s\n' "$CREATE_OUT" | sed 's/^/    /'; fi
      if probe git ls-remote --heads origin main; then
        ok "verified: branch 'main' pushed to github.com/$OWNER/$REPO_NAME"
      else
        warn "repo create/push did not complete (see gh output above) — manual recovery:  gh repo create $REPO_NAME --private --source=. --push   ·   or, if the repo already exists:  git remote add origin https://github.com/$OWNER/$REPO_NAME.git && git push -u origin main"
      fi
    fi
  else ok "origin already set: $(git remote get-url origin)"
    git add -A; git commit -m "setup update" >/dev/null 2>&1 || true
    git push origin main 2>/dev/null && ok "pushed" || warn "push failed — 'gh auth status' then 'git push origin main'"
  fi
else
  info "[dry-run] gh repo create $REPO_NAME --private --source=. --push"
fi

# ============================================================================
step "10/10  Vercel (the publisher)"
# --- Vercel hookup status ----------------------------------------------------
# Two notions of 'hooked up': the dashboard import (deploys on push, invisible
# in the folder) and the CLI link (.vercel/project.json). The link is what the
# toolchain uses and what we can verify for free: 'vercel link --yes --project
# <name>' repairs the main real-world case — a dashboard-imported project with
# the same repo name — without parsing any CLI output.
VERCEL_INSTRUCTIONS_SHOWN=0
if [ "$DRY_RUN" = 1 ]; then
  info "[dry-run] would check the Vercel CLI link (.vercel/project.json) and run 'vercel link --yes --project $REPO_NAME' if missing"
elif [ ! -f "$PROJECT_DIR/.vercel/project.json" ]; then
  warn "this project folder is not linked to Vercel yet — trying: vercel link --yes --project $REPO_NAME"
  if have vercel && [ -t 0 ] && vercel link --yes --project "$REPO_NAME"; then
    ok "Vercel CLI linked to project '$REPO_NAME'"
  else
    warn "could not link automatically (no vercel CLI / project not on this account / non-interactive) — finish the hookup as described below, or run 'vercel link' and pick the right project from the list"
    VERCEL_INSTRUCTIONS_SHOWN=1
  fi
else
  ok "Vercel: this folder is linked to a Vercel project (.vercel/project.json present) — every push redeploys"
fi
if [ "$DRY_RUN" = 1 ] || [ ! -f "$PROJECT_DIR/.vercel/project.json" ]; then
cat <<VERCEL

  In a browser (one-time, ~2 min):
    1. https://vercel.com/new  (log in with the same GitHub account)
    2. Import the '$REPO_NAME' repository
    3. Framework preset: leave default ('Other' for a static site)
    4. Deploy -> you get a <project>.vercel.app URL. LIVE in ~30 s.

  From now on every 'git push' redeploys automatically. Verify the live URL
  with a HARD refresh (Cmd/Ctrl+Shift+R) — a plain refresh can show cache.

  If deploys stall later: 'vercel login' from this machine (CLI was installed
  in step 7) has saved sessions where the dashboard alone did not.

  Production branch note: Vercel should track 'main' (Settings -> Environments
  -> Production). If the site lags behind pushes, check that first.

VERCEL
fi

# ============================================================================
step "DONE — daily loop from tomorrow"
cat <<NEXT

  Where things live: node/npm/pi are installed inside nvm (~/.nvm/versions/...),
  NOT system-wide. A fresh terminal loads them via .bashrc automatically. If a
  shell ever says 'pi: command not found', fix that shell with:
      source ~/.nvm/nvm.sh
  ('ollama launch pi' needs the same PATH, since it just searches for node.)

  Install log: ${LOG_FILE:-none} — every run overwrites it; it lives in the folder
  you ran this script from (or wherever --log= pointed). Attach it when asking for help.

  Resume loop (every session):
    cd "$PROJECT_DIR"            # go to the project (created in the directory
                                 # you ran start-a-new-project.sh from)
    pi                       # launch the agent
    write a FEATURE_<x>.md   # describe one feature for Pi
    -> Pi implements, commit + push -> Vercel redeploys -> verify live URL

  First demo prompt (works, keep scope small):
    "Create a very basic landing page with a button and a heading.
     Once you're done, push it and let me know when you've finished."

NEXT
# ==========================================================================
step "Final step — launch Pi inside your project"
cat <<PISTART

  Everything Pi needs is now in place:
    - working directory:  $PROJECT_DIR (Pi opens HERE — this folder IS the project)
    - settings.json:      default provider ollama-cloud + model glm-5.3-flash + thinking high
    - AGENTS.md:          Directory Boundary + Temporary Folder rules — Pi stays inside the project (tmp goes to ./tmp/)
    - skills:             Ryan's skills copied into ~/.pi/agent/skills/
    - authentication:     OLLAMA_API_KEY exported (this shell) + saved to your profile
                          (new terminals load it automatically — no /login ever needed;
                           Pi WILL REFUSE to start without it)
    - packages:           pi-ollama-cloud + pi-hide-providers + web-search install on Pi's first launch

PISTART
if [ "$DRY_RUN" = 1 ]; then
  info "[dry-run] would require OLLAMA_API_KEY (prompt if missing), then run:  cd '$PROJECT_DIR' && pi"
elif [ -t 0 ]; then
  cd "$PROJECT_DIR" || die "project folder missing: $PROJECT_DIR"
  if ! have pi; then
    warn "pi is not on PATH in this shell — run:  source ~/.nvm/nvm.sh && cd \"$PROJECT_DIR\" && pi"
  elif [ -z "${OLLAMA_API_KEY:-}" ] && ! ensure_ollama_key; then
    # Second-chance prompt happened inside ensure_ollama_key and produced no
    # key — Pi must NEVER start unauthenticated (its first action would be a
    # cloud error far from the one sentence that fixes it).
    warn "Pi NOT launched — it needs an Ollama API key. Get it at https://ollama.com/settings/keys (click \"Create API Key\"), then:  export OLLAMA_API_KEY=\"<key>\" && cd \"$PROJECT_DIR\" && pi"
  else
    info "Launching Pi in $PROJECT_DIR — quitting Pi (ctrl+c/ctrl+d) returns you here."
    # Child process, never exec: quitting Pi must not end this script's session.
    pi || true
    info "Pi exited. Relaunch any time with:  cd \"$PROJECT_DIR\" && pi"
    # A child script cannot modify the parent shell's PATH: if this terminal
    # predates the first setup, 'pi' stays invisible there until it re-reads
    # .bashrc. Detect (Linux: inspect the parent's environment) and say so.
    if [ -r "/proc/$PPID/environ" ] && tr '\0' '\n' < "/proc/$PPID/environ" 2>/dev/null | grep -q '\.nvm'; then
      ok "this terminal already has node/pi on PATH — keep using it"
    else
      warn "in THIS terminal 'pi' may still say 'command not found' (this script cannot change its parent shell). Fix now:  source ~/.nvm/nvm.sh  — or just open a new terminal; every future terminal loads pi automatically."
    fi
  fi
else
  info "Non-interactive run — get your key at https://ollama.com/settings/keys (click \"Create API Key\") if not yet exported, then start Pi yourself:  export OLLAMA_API_KEY=\"<key>\" ; cd \"$PROJECT_DIR\" && pi"
fi
if [ "$DRY_RUN" = 1 ]; then
  ok "Setup complete ($OS_TAG, DRY-RUN — nothing was changed)"
else
  if [ -n "$LOG_FILE" ]; then
    census >> "$LOG_FILE" 2>/dev/null || true
    ok "full install log: $LOG_FILE (attach this file when asking for help)"
  fi
  ok "Setup complete ($OS_TAG, real run)"
fi