# BoltAI for Alfred

An Alfred workflow (Alfred 5 with the Powerpack) that runs everything through BoltAI's `bolt` command-line tool.

| Trigger | What it does |
|---|---|
| `ask <question>` | One-off answer from your default model, copied to the clipboard. |
| `bolt [message]` | New chat in BoltAI; with a message, it is sent. |
| `workflow` | Run an AI Workflow or Multi-step Workflow on the clipboard. ↵ pastes the result, ⌘ copies it, ⌥ opens the workflow in BoltAI. |
| `prompts` | Paste a saved prompt (⌘ copies it). |
| Universal Action **Run BoltAI Workflow** | Pick a workflow and run it on the selected text. |

Keywords and the `bolt` path are in the workflow's **Configure Workflow** sheet.

## Install

Needs [BoltAI](https://boltai.com) 3.0 or later, which includes `bolt`, and Alfred 5 with the [Powerpack](https://www.alfredapp.com/powerpack/).

Download [BoltAI.alfredworkflow](https://github.com/BoltAI/alfred-workflow/releases/latest/download/BoltAI.alfredworkflow) and open it. BoltAI › Settings › Labs links to the same file. To update, download it again and open it; Alfred keeps your keywords and settings.

## Releases

The source lives in BoltAI's main repository (`integrations/alfred`). [BoltAI/alfred-workflow](https://github.com/BoltAI/alfred-workflow) is a public copy that publishes releases:

1. Raise `version` in `src/info.plist`.
2. Run `./sync-public-repo.sh` (default target `~/Codes/project-notes/alfred-workflow`). It copies the source there and shows `git status`.
3. Commit and push that repository's `main`. Its GitHub Action builds the workflow and creates release `v<version>` with `BoltAI.alfredworkflow` attached. A push without a new version releases nothing.

## Build

```bash
./build.sh
```

This writes `build/BoltAI.alfredworkflow`; open it to install. `src/info.plist` is the workflow itself. After changing objects in Alfred's editor, copy the exported `info.plist` back into `src/`.

## How it works

- `src/boltai.sh` finds `bolt` (`bolt_path`, then `~/.local/bin/bolt`, then `/Applications/BoltAI.app`, then the Setapp app), runs it and maps its exit codes to messages.
- `src/alfred.js` (JavaScript for Automation, built into macOS) formats Alfred's JSON, so the workflow needs no `jq` or Python.
- Actions set a `next` variable (`paste`, `copy`, `error` or `none`). One Conditional utility routes it to Copy to Clipboard (with or without auto-paste) or to a notification, so a failed run never touches the clipboard. (The legacy Filter utility didn't stop the flow: a failed run pasted whatever was on the clipboard.)
- ⌘ and ⌥ on a `workflow` or `prompts` row work through the item's `mods` variables plus a connection for that modifier. Items set no top-level `action`; the script defaults to paste.
- The Universal Action stores the selection in the `input` variable; without it, `workflow` uses the clipboard.
