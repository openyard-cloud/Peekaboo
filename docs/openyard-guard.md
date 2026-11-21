---
summary: 'Action guard added by the openyard-cloud fork: confirmation for consequential clicks, no typing into password fields'
read_when:
  - 'running Peekaboo MCP under an unattended agent'
  - 'changing what the guard asks about'
---

# Action guard (openyard-cloud fork)

This fork adds one thing to Peekaboo's MCP tools: a guard that stops an agent before the clicks that matter. It is meant for an agent that runs unattended, such as [beckon](https://github.com/openyard-cloud/beckon), where a person approves the important steps from Slack.

## What it does

| Tool | Guard |
| --- | --- |
| `click` on an element (`on` or `query`) | If the element's label names a consequential step, the click is refused until it is repeated with `confirm` set to that exact label |
| `click` on coordinates | In a sensitive app (Xcode and Transporter by default), refused until repeated with a `confirm` that names what is being clicked |
| `action` with `AXPress`, `AXConfirm`, `AXPick`, `AXOpen`, or a custom action | Same check as an element click, on the element's label (or the custom action's title) |
| `type` into an element, `set_value` | Refused when the target is a password field (`AXSecureTextField`) |

The default words that make a label consequential: submit, upload, distribute, release, publish, roll out, deploy, send, delete, remove, erase, revoke, pay, purchase, buy, subscribe, sign in, log in, approve, confirm, transfer, install. Whole words only, case ignored, so "Resubmission notes" and "Archive" pass.

A refusal looks like this, and the agent's next call carries the label in its input:

```
Guard: "Submit for Review" in Safari is a consequential step and needs confirmation.
Call again with the same arguments plus confirm: "Submit for Review".
```

That second call is the point. The label is now part of the tool input, so anything in front of the MCP client can see it and ask a person first. beckon does this with a PreToolUse hook: a `click` or `action` call that carries `confirm` becomes an **Allow / Deny** message in Slack showing the label.

The guard on its own only adds a step for the agent; it does not ask anyone. Pair it with an approval layer.

## Limits

- `type` without an element ID types into whatever has focus, and the guard cannot see whether that is a password field.
- `press` (keys such as Return) and `hotkey` are not checked: pressing Return in a form can still submit it.
- A coordinate click outside the sensitive apps has no label and is not checked.

## Settings

The guard reads `~/.peekaboo/guard.json`, or the file named by `PEEKABOO_GUARD_CONFIG`. A file that is missing or does not parse leaves the defaults on.

```json
{
  "enabled": true,
  "confirmLabels": ["submit", "upload", "distribute", "release", "delete"],
  "sensitiveApps": ["Xcode", "Transporter"],
  "blockSecureFields": true
}
```

- `confirmLabels`: regex fragments, joined as whole-word alternatives. Replaces the default list.
- `sensitiveApps`: app names where coordinate clicks need `confirm`.
- `"enabled": false` turns the guard off.

## Building on Swift 6.2 (Xcode 26)

Upstream builds with Xcode 27. On Xcode 26.x the only blocker found is `swift-log` 1.17, which uses an attribute that needs Swift 6.3. This fork pins it to 1.16.2 in the committed `Package.resolved` files, and `scripts/pin-swift62.py` re-applies the pin after a `swift package resolve` or `update`:

```sh
python3 scripts/setup-swift-workspace.py run -- swift package --package-path Apps/CLI resolve
python3 scripts/pin-swift62.py
python3 scripts/setup-swift-workspace.py run -- swift build --package-path Apps/CLI   # debug
python3 scripts/setup-swift-workspace.py run -- swift build --package-path Apps/CLI -c release
```

The binary is `Apps/CLI/.build/<debug|release>/peekaboo`. Verified on an Intel Mac with Xcode 26.1.1.
