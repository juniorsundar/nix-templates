# Add to `.zshrc` so that it loads and unloads autocompletions
```zsh
autoload -Uz add-zsh-hook

_source_project_zsh() {
    local current_conf=""
    if [[ -n "$DIRENV_DIR" ]]; then
        local clean_dir="${DIRENV_DIR#-}"
        if [[ -f "$clean_dir/.env_local" ]]; then
            current_conf="$clean_dir/.env_local"
        fi
    fi

    if [[ "$current_conf" != "$_LAST_PROJECT_ZSH" ]]; then

        if [[ -n "$_PROJECT_CLEANUP" ]]; then
            eval "$_PROJECT_CLEANUP"
            unset _PROJECT_CLEANUP
        fi

        if [[ -n "$current_conf" ]]; then
            source "$current_conf"
        fi
        export _LAST_PROJECT_ZSH="$current_conf"
    fi
}

add-zsh-hook precmd _source_project_zsh

```
