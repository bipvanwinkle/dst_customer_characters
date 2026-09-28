#!/usr/bin/env bash
# Sync a local mod folder over the installed workshop copy of that mod on a Linux machine.
# Runs from macOS or Linux, regardless of the local or remote login shell (zsh, fish, ...).
#
# Usage: deploy_mod.sh <mod_dir> <workshop_id> <ssh_target>
#   e.g. deploy_mod.sh tuning 1234567890 deck@steamdeck
#
# If <ssh_target> is the machine this runs on, the copy is done locally instead of over ssh.
# Steam may restore the published version when it checks for workshop updates, so this is
# for quick iteration between Workshop uploads. Restart DST to pick up changes.
#
# Environment:
#   DEPLOY_SSH  command used to reach the target (default: "tailscale ssh" if installed, else "ssh").
#               Tailscale SSH verifies host keys through the tailnet, so no known_hosts entry is needed.
#   DRY_RUN=1   show what rsync would change without copying anything
set -euo pipefail

# Internal: rsync invokes its remote shell as `<rsh> -l <user> <host> <command...>`, but
# `tailscale ssh` has no -l flag, so rsync is pointed back at this script to rebuild user@host.
if [ "${1:-}" = "--rsh" ]; then
	shift
	user=
	if [ "${1:-}" = "-l" ]; then
		user=$2@
		shift 2
	fi
	host=$1
	shift
	# shellcheck disable=SC2086
	exec $DEPLOY_SSH "$user$host" "$@"
fi

if [ $# -ne 3 ]; then
	echo "usage: $0 <mod_dir> <workshop_id> <ssh_target>" >&2
	exit 2
fi

mod_dir=$1
workshop_id=$2
target=$3
host=${target#*@}

if [ ! -f "$mod_dir/modinfo.lua" ]; then
	echo "error: $mod_dir/modinfo.lua not found" >&2
	exit 1
fi

# macOS ships an old rsync without -s (--protect-args, renamed --secluded-args in 3.2.4);
# prefer Homebrew's if present
rsync_bin=rsync
for candidate in /opt/homebrew/bin/rsync /usr/local/bin/rsync; do
	if [ -x "$candidate" ]; then
		rsync_bin=$candidate
		break
	fi
done
rsync_help=$("$rsync_bin" --help 2>&1 || true)
if [[ $rsync_help != *--protect-args* && $rsync_help != *--secluded-args* ]]; then
	echo "error: $rsync_bin is too old (need rsync >= 3); on macOS run: brew install rsync" >&2
	exit 1
fi

if [ -z "${DEPLOY_SSH:-}" ]; then
	if command -v tailscale >/dev/null 2>&1; then
		DEPLOY_SSH="tailscale ssh"
	else
		DEPLOY_SSH=ssh
	fi
fi
export DEPLOY_SSH

is_local_target() {
	if [ "$host" = "localhost" ] || [ "$host" = "$(hostname -s 2>/dev/null || hostname)" ]; then
		return 0
	fi
	if command -v tailscale >/dev/null 2>&1; then
		local self_ip target_ip
		self_ip=$(tailscale ip -4 2>/dev/null | head -n1) || return 1
		target_ip=$(tailscale ip -4 "$host" 2>/dev/null | head -n1) || return 1
		[ -n "$self_ip" ] && [ "$self_ip" = "$target_ip" ]
		return
	fi
	return 1
}

# Prints where the workshop copy is installed (native vs Flatpak Steam, new vs legacy layout).
# Sent to bash on stdin so the remote login shell (e.g. fish) never parses it.
find_workshop_dir_script='
id=$1
for d in \
	"$HOME/.local/share/Steam/steamapps/workshop/content/322330/$id" \
	"$HOME/.steam/steam/steamapps/workshop/content/322330/$id" \
	"$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/workshop/content/322330/$id" \
	"$HOME/.local/share/Steam/steamapps/common/Don'"'"'t Starve Together/mods/workshop-$id"; do
	if [ -f "$d/modinfo.lua" ]; then
		echo "$d"
		exit 0
	fi
done
exit 1
'

if is_local_target; then
	dest_dir=$(bash -s "$workshop_id" <<<"$find_workshop_dir_script") || dest_dir=
	dest=$dest_dir
else
	# Word-splitting DEPLOY_SSH is intended ("tailscale ssh")
	# shellcheck disable=SC2086
	dest_dir=$($DEPLOY_SSH "$target" bash -s "$workshop_id" <<<"$find_workshop_dir_script") || dest_dir=
	dest=$target:$dest_dir
fi

if [ -z "$dest_dir" ]; then
	echo "error: no installed copy of workshop mod $workshop_id found on $target (is it subscribed?)" >&2
	exit 1
fi

rsync_opts=(-a -s --delete --exclude '.DS_Store' --exclude 'mod.manifest' --itemize-changes -e "$(printf '%q' "$0") --rsh")
if [ "${DRY_RUN:-}" = "1" ]; then
	rsync_opts+=(--dry-run)
	echo "Dry run: $mod_dir -> $dest"
else
	echo "Deploying $mod_dir -> $dest"
fi
"$rsync_bin" "${rsync_opts[@]}" "$mod_dir/" "$dest/"
