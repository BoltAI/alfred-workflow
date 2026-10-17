#!/bin/bash
# BoltAI for Alfred. Every action goes through BoltAI's `bolt` command-line tool, which talks to the
# running app (opening it in the background when needed). This script never reads keys or data.
#
# Script filters print Alfred items. Actions print {"alfredworkflow": …} with a `next` variable
# that the workflow's filters route on: paste, copy, error or none.

# pbpaste picks its encoding from the locale, and Alfred runs scripts without one.
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

here="$(cd "$(dirname "$0")" && pwd)"
alfred() { /usr/bin/osascript -l JavaScript "$here/alfred.js" "$@"; }

find_bolt() {
  if [[ -n "${bolt_path:-}" ]]; then
    local custom="${bolt_path/#\~/$HOME}"
    [[ -x "$custom" ]] && echo "$custom"
    return
  fi
  # Any BoltAI*.app, so a renamed app (Setapp's "BoltAI 2.app", a later "BoltAI 3.app") is found;
  # an app without bolt (before 3.0) is skipped.
  local candidate
  for candidate in "$HOME/.local/bin/bolt" \
    /Applications/BoltAI.app/Contents/Helpers/bolt \
    /Applications/BoltAI*.app/Contents/Helpers/bolt \
    "$HOME"/Applications/BoltAI*.app/Contents/Helpers/bolt \
    /Applications/Setapp/BoltAI*.app/Contents/Helpers/bolt; do
    [[ -x "$candidate" ]] && { echo "$candidate"; return; }
  done
}

# call_bolt <stdin text> <bolt arguments…>
# Sets $out on success; $fail_title and $fail_message on failure (exit codes: SharedIPC/BoltCLIProtocol.swift).
call_bolt() {
  local input="$1"
  shift
  local bolt errors code
  bolt="$(find_bolt)"
  if [[ -z "$bolt" ]]; then
    fail_title="bolt not found"
    if [[ -n "${bolt_path:-}" ]]; then
      fail_message="Nothing runnable at $bolt_path. Fix the path in the workflow's configuration."
    else
      fail_message="Needs BoltAI 3.0 or later, which includes the bolt tool: get it at boltai.com. If BoltAI is somewhere else, set the bolt path in Configure Workflow."
    fi
    return 1
  fi
  errors="$(mktemp -t boltai-alfred)"
  out="$(printf '%s' "$input" | "$bolt" "$@" 2>"$errors")"
  code=$?
  fail_message="$(sed 's/^bolt: //' "$errors")"
  rm -f "$errors"
  [[ $code -eq 0 ]] && return 0
  case $code in
    2) fail_title="BoltAI didn't understand the request" ;;
    3) fail_title="Not found in BoltAI" ;;
    4) fail_title="The AI request failed" ;;
    5) fail_title="BoltAI needs attention" ;;
    6) fail_title="BoltAI isn't responding" ;;
    130) fail_title="Cancelled" ;;
    *) fail_title="BoltAI failed" ;;
  esac
  [[ -n "$fail_message" ]] || fail_message="bolt exited with code $code."
  return 1
}

command="$1"
shift
case "$command" in
  workflows)
    if call_bolt "" workflows --json; then
      alfred workflows "$out" "${input:+selection}"
    else
      alfred error "$fail_title" "$fail_message"
    fi
    ;;
  prompts)
    if call_bolt "" prompts --json; then
      alfred prompts "$out"
    else
      alfred error "$fail_title" "$fail_message"
    fi
    ;;
  workflow)
    id="$1"
    if [[ "${action:-paste}" == "edit" ]]; then
      if call_bolt "" open workflow "$id"; then alfred done; else alfred failure "$fail_title" "$fail_message"; fi
      exit 0
    fi
    # `input` is set by the Universal Action; otherwise the workflow runs on the clipboard.
    text="${input-$(pbpaste)}"
    if [[ -z "${text//[[:space:]]/}" ]]; then
      alfred failure "Nothing to run the workflow on" "Copy some text first, or select text and use the Run BoltAI Workflow Universal Action."
    elif call_bolt "$text" run "$id"; then
      alfred result "$out" "${action:-paste}" "Copied the workflow result"
    else
      alfred failure "$fail_title" "$fail_message"
    fi
    ;;
  prompt)
    if call_bolt "" prompts show "$1"; then
      alfred result "$out" "${action:-paste}" "Copied the prompt"
    else
      alfred failure "$fail_title" "$fail_message"
    fi
    ;;
  ask)
    if call_bolt "" ask -- "$1"; then
      alfred result "$out" copy "Copied BoltAI's answer"
    else
      alfred failure "$fail_title" "$fail_message"
    fi
    ;;
  chat)
    # Without a message BoltAI opens a new empty chat; with one it opens the chat and sends it.
    if [[ -n "${1//[[:space:]]/}" ]]; then set -- chat new -- "$1"; else set -- chat new; fi
    if call_bolt "" "$@"; then alfred done; else alfred failure "$fail_title" "$fail_message"; fi
    ;;
  *)
    echo "usage: boltai.sh workflows|prompts|workflow <id>|prompt <id>|ask <prompt>|chat [message]" >&2
    exit 2
    ;;
esac
