#!/usr/bin/env bash
# ==============================================================================
# X11 helper, sourced by shell.sh.
#
# push_xauth_into_container(): copy the cookie for the CURRENT $DISPLAY into a
# running container's own ~/.Xauthority, wildcarding the host field so the
# containerized UID is accepted. Injecting at exec-time (instead of bind-mounting
# a cookie file) survives xauth's rename()-based rewrites and works for local
# terminals and `ssh -Y` sessions alike.
# ==============================================================================
push_xauth_into_container() {
    local container="$1"
    local user="$2"

    [ -n "${DISPLAY:-}" ] || return 0
    command -v xauth > /dev/null 2>&1 || return 0

    local source_auth="${XAUTHORITY:-$HOME/.Xauthority}"
    [ -f "${source_auth}" ] || return 0

    # nlist selects this display's entry; sed rewrites the family field to ffff
    # (FamilyWild) so the cookie is accepted regardless of host identity.
    xauth -f "${source_auth}" nlist "${DISPLAY}" 2>/dev/null \
        | sed -e 's/^..../ffff/' \
        | docker exec -i -u "${user}" "${container}" \
              bash -c 'xauth -f "$HOME/.Xauthority" nmerge - 2>/dev/null' || true
}
