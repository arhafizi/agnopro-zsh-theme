# Agnopro ZSH Theme
# Inspired by and based on the Agnoster ZSH theme
# Features: Performance caching, configurable segments, error handling, Docker support
#
# Configuration:
# - Set ENABLE_*_PROMPT=0 to disable segments (e.g., ENABLE_GO_PROMPT=0).
# - Set CUSTOM_*_BG and CUSTOM_*_FG for custom colors (e.g., CUSTOM_DIR_BG=34).
# - Adjust PROMPT_ORDER to reorder segments.
#
# Requirements: Powerline-compatible font (e.g., Nerd Fonts) for icons.

### Enable/Disable Prompt Segments (default: enabled)
: ${ENABLE_STATUS_PROMPT:=1}
: ${ENABLE_CONTEXT_PROMPT:=1}
: ${ENABLE_DIR_PROMPT:=1}
: ${ENABLE_NODE_PROMPT:=1}
: ${ENABLE_GO_PROMPT:=1}
: ${ENABLE_DOTNET_PROMPT:=1}
: ${ENABLE_DOCKER_PROMPT:=1}
: ${ENABLE_GIT_PROMPT:=1}
: ${ENABLE_AWS_PROMPT:=1}
: ${ENABLE_VIRTUALENV_PROMPT:=1}


### Color Configuration
typeset -gA AGNOSTER_COLORS
AGNOSTER_COLORS=(
    dir_fg    255  # White
    dir_bg    33   # Blue
    context_fg 250    # Light Gray
    context_bg 236    # Dark Gray
    go_fg     255  # White
    go_bg     166  # Orange
    node_fg   255  # White
    node_bg   70   # Green
    dotnet_fg 255  # White
    dotnet_bg 54   # Purple
    docker_fg 255  # White
    docker_bg 33   # Blue (Docker-like)
    git_clean_fg 255  # White
    git_clean_bg 64   # Green
    git_dirty_fg 236  # Dark Gray
    git_dirty_bg 178  # Goldenrod
    status_bg 238     # Gray
    retval_fg 196     # Red
    aws_fg    255  # White
    aws_bg    70   # Green
    aws_prod_fg 255  # White
    aws_prod_bg 160  # Red
    virtualenv_fg 255  # White
    virtualenv_bg 33   # Blue
)

# Allow color overrides
[[ -n $CUSTOM_DIR_BG ]] && AGNOSTER_COLORS[dir_bg]=$CUSTOM_DIR_BG
[[ -n $CUSTOM_DIR_FG ]] && AGNOSTER_COLORS[dir_fg]=$CUSTOM_DIR_FG


### Powerline Separator
SEGMENT_SEPARATOR=$'\ue0b4'  # Rounded right triangle

### Drawing Functions
CURRENT_BG='NONE'

prompt_segment() {
    local bg fg
    [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
    [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
    if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
        echo -n "%{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%}"
    else
        echo -n "%{$bg%}%{$fg%}"
    fi
    echo -n " "
    CURRENT_BG=$1
    [[ -n $3 ]] && echo -n $3
}

prompt_end() {
    if [[ -n $CURRENT_BG ]]; then
        echo -n "%{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
    else
        echo -n "%{%k%}"
    fi
    echo -n "%{%f%}"
    CURRENT_BG=''
}

prompt_context() {
    [[ $ENABLE_CONTEXT_PROMPT -eq 1 ]] || return

    # Show context ONLY if:
    # 1. In an SSH session, OR
    # 2. User is not DEFAULT_USER
    if [[ -n "$SSH_CONNECTION" ]] || [[ "$USER" != "$DEFAULT_USER" ]]; then
       prompt_segment ${AGNOSTER_COLORS[context_bg]} ${AGNOSTER_COLORS[context_fg]} "%n@%m"
    fi
}

# Go - Cached version, only in Go projects
typeset -g LAST_GO_VERSION LAST_GO_CHECK
prompt_go() {
    [[ $ENABLE_GO_PROMPT -eq 1 ]] || return
    (( $+commands[go] )) || return
    local now=$(date +%s)
    if [[ -z $LAST_GO_VERSION || $((now - LAST_GO_CHECK)) -gt 300 ]]; then
        local gomodule=$(go env GOMOD 2>/dev/null)
        if [[ -n $gomodule && $gomodule != "/dev/null" ]]; then
            LAST_GO_VERSION=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//') || LAST_GO_VERSION=""
            LAST_GO_CHECK=$now
        else
            LAST_GO_VERSION=""
        fi
    fi
    [[ -n $LAST_GO_VERSION ]] && prompt_segment $AGNOSTER_COLORS[go_bg] $AGNOSTER_COLORS[go_fg] " ${LAST_GO_VERSION}"
    #[[ -n $LAST_GO_VERSION ]] && prompt_segment $AGNOSTER_COLORS[go_bg] $AGNOSTER_COLORS[go_fg] "go ${LAST_GO_VERSION}"

}

# Node.js - Cached version, only in Node projects
typeset -g LAST_NODE_VERSION LAST_NODE_CHECK
prompt_node() {
    [[ $ENABLE_NODE_PROMPT -eq 1 ]] || return
    (( $+commands[node] )) || return
    [[ -f package.json || -f yarn.lock || -f pnpm-lock.yaml || -f package-lock.json ]] || return
    local now=$(date +%s)
    if [[ -z $LAST_NODE_VERSION || $((now - LAST_NODE_CHECK)) -gt 300 ]]; then
        LAST_NODE_VERSION=$(node -v 2>/dev/null | cut -d'v' -f2) || LAST_NODE_VERSION=""
        LAST_NODE_CHECK=$now
    fi
    if [[ -n $LAST_NODE_VERSION ]]; then
        prompt_segment $AGNOSTER_COLORS[node_bg] $AGNOSTER_COLORS[node_fg] " ${LAST_NODE_VERSION}"
        [[ -f yarn.lock ]] && echo -n " (yarn)"
        [[ -f pnpm-lock.yaml ]] && echo -n " (pnpm)"
        [[ -f package-lock.json ]] && echo -n " (npm)"
    fi
}

# .NET - Cached version, only in .NET projects
typeset -g LAST_DOTNET_VERSION LAST_DOTNET_CHECK
prompt_dotnet() {
    [[ $ENABLE_DOTNET_PROMPT -eq 1 ]] || return
    (( $+commands[dotnet] )) || return
    local dotnet_project=$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)
    if [[ -n $(find "$dotnet_project" -maxdepth 1 -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' -o -name '*.sln') ]]; then
        local now=$(date +%s)
        if [[ -z $LAST_DOTNET_VERSION || $((now - LAST_DOTNET_CHECK)) -gt 300 ]]; then
            LAST_DOTNET_VERSION=$(dotnet --version 2>/dev/null) || LAST_DOTNET_VERSION=""
            LAST_DOTNET_CHECK=$now
        fi
        [[ -n $LAST_DOTNET_VERSION ]] && prompt_segment $AGNOSTER_COLORS[dotnet_bg] $AGN
OSTER_COLORS[dotnet_fg] " ${LAST_DOTNET_VERSION}"
    fi
}

# Docker - Icon if Dockerfile or docker-compose.yml exists
prompt_docker() {
    [[ $ENABLE_DOCKER_PROMPT -eq 1 ]] || return
    local docker_project=$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)
    if [[ -f "$docker_project/Dockerfile" || -f "$docker_project/docker-compose.yml" ]]; then
        prompt_segment $AGNOSTER_COLORS[docker_bg] $AGNOSTER_COLORS[docker_fg] "🐳"
    fi
}

# Directory
prompt_dir() {
    [[ $ENABLE_DIR_PROMPT -eq 1 ]] || return
    prompt_segment $AGNOSTER_COLORS[dir_bg] $AGNOSTER_COLORS[dir_fg] '%~'
}

# Git
prompt_git() {
    # Skip if Git prompt is disabled or git command isn’t available
    [[ $ENABLE_GIT_PROMPT -eq 1 ]] || return
    (( $+commands[git] )) || return

    # Check if we’re in a Git repository
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local ref dirty
        # Get the branch name (or commit hash if detached)
        ref=$(git symbolic-ref HEAD 2>/dev/null) || ref="➦ $(git rev-parse --short HEAD 2>/dev/null)"
        ref="${ref/refs\/heads\// }"  # Replace "refs/heads/" with " "

        # Check if the repository is dirty
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            dirty=" ±"  # Dirty state: append "±"
            prompt_segment $AGNOSTER_COLORS[git_dirty_bg] $AGNOSTER_COLORS[git_dirty_fg]
        else
            dirty=""  # Clean state: no extra symbol
            prompt_segment $AGNOSTER_COLORS[git_clean_bg] $AGNOSTER_COLORS[git_clean_fg]
        fi

        # Output the cleaned-up prompt
        echo -n "${ref}${dirty}"
    fi
}

prompt_aws() {
    [[ $ENABLE_AWS_PROMPT -eq 1 && -n $AWS_PROFILE ]] || return
    if [[ $AWS_PROFILE =~ (production|-prod)$ ]]; then
        prompt_segment $AGNOSTER_COLORS[aws_prod_bg] $AGNOSTER_COLORS[aws_prod_fg] "AWS: $AWS_PROFILE"
    else
        prompt_segment $AGNOSTER_COLORS[aws_bg] $AGNOSTER_COLORS[aws_fg] "AWS: $AWS_PROFILE"
    fi
}

prompt_virtualenv() {
    [[ $ENABLE_VIRTUALENV_PROMPT -eq 1 && -n $VIRTUAL_ENV && -z $VIRTUAL_ENV_DISABLE_PROMPT ]] || return
    prompt_segment $AGNOSTER_COLORS[virtualenv_bg] $AGNOSTER_COLORS[virtualenv_fg] "(${VIRTUAL_ENV:t})"
}

# Status (exit code + ...)
prompt_status() {
    [[ $ENABLE_STATUS_PROMPT -eq 1 ]] || return
    local symbols
    [[ $RETVAL -ne 0 ]] && symbols+="%{%F{$AGNOSTER_COLORS[retval_fg]}%}✘"
    [[ $UID -eq 0 ]] && symbols+="%{%F{$AGNOSTER_COLORS[retval_fg]}%}⚡"
    [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{$AGNOSTER_COLORS[retval_fg]}%}⚙"
    [[ -n $symbols ]] && prompt_segment $AGNOSTER_COLORS[status_bg] "" "$symbols"
}

### Prompt Order
typeset -a PROMPT_ORDER=(status virtualenv aws context dir node go dotnet docker git)
### Build Prompt
build_prompt() {
    RETVAL=$?
    for segment in $PROMPT_ORDER; do
        prompt_$segment
    done
    prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '
