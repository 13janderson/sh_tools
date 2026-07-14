#!/bin/bash
set -euo pipefail

search_root="${1:-$HOME/projects}"

echo "=== Git Worktree Pruner ==="
echo "Search root: $search_root"

# echo ""
# echo "Disk usage before:"
# du -sh "$search_root" 2>/dev/null || true
# echo "---"
# du -sh "$search_root"/*/ 2>/dev/null || true

find "$search_root" -maxdepth 5 \( -name ".git" -type d \) -o \( -name "*.git" -type d -not -name ".git" \) 2>/dev/null | sort -u | while read -r gitdir; do
    if [ "$(basename "$gitdir")" = ".git" ]; then
        repo_dir="$(dirname "$gitdir")"
    else
        repo_dir="$gitdir"
    fi
echo "repo_dir: $repo_dir"

    git -C "$repo_dir" rev-parse --git-dir &>/dev/null || continue
    git -C "$repo_dir" fetch --prune --quiet 2>/dev/null || true

    while read -r wt_path _ branch_field; do
        echo "wt_path: $wt_path"
        [ "$wt_path" = "$repo_dir" ] && continue

        case "$branch_field" in
            \[*\])
                branch="${branch_field#[}"
                branch="${branch%]}"
                ;;
            *)
                continue
                ;;
        esac

        last_commit_ts=$(git -C "$repo_dir" log -1 --format=%ct "refs/heads/$branch" 2>/dev/null || echo "0")
        now_ts=$(date +%s)
        days_old=$(( (now_ts - last_commit_ts) / 86400 ))

        if [ "$days_old" -ge 30 ]; then
            repo_name="$(basename "$repo_dir" .git)"
            echo "Removing: $repo_name/$(basename "$wt_path") (last commit ${days_old}d ago)"
            git -C "$repo_dir" worktree remove "$wt_path" 2>/dev/null ||
                git -C "$repo_dir" worktree remove --force "$wt_path" 2>/dev/null ||
                rm -rf "$wt_path" 2>/dev/null || true
        fi
    done < <(git -C "$repo_dir" worktree list 2>/dev/null || true)

    git -C "$repo_dir" worktree prune 2>/dev/null || true
done

echo ""
echo "Disk usage after:"
du -sh "$search_root" 2>/dev/null || true
echo "---"
du -sh "$search_root"/*/ 2>/dev/null || true
