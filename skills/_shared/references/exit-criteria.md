# Exit criteria — the step contract

Every `### Step` in a skill declares the state it must leave behind. Not the keystrokes
that get there.

Used by every skill in this plugin. `scripts/validate-skills.sh` enforces the presence of
the `**Exit criteria:**` line on every `### Step` heading — a step without one fails the
build.

---

## Why

A procedural step ("run the test, then write the fix") is satisfied by *having been
performed*. A step with exit criteria is satisfied by *having produced a verifiable
result*. Only the second one survives a capable executor improvising a different route to
the same place — which is what a strong model does, and should do.

The rule of thumb: **delete a "how" line when a competent engineer would do it anyway;
never delete a "done" line, because a competent engineer under pressure will still
rationalise past it.**

## The shape

```markdown
### Step N: <short name>

<one or two lines of intent — what this step is for, and any non-obvious constraint>

**Exit criteria:** <observable state that must be true to move on>
**Evidence:** <the command output, file, or count that proves it>
**Blocker:** <conditions that forbid proceeding, and what to do instead>
```

`**Exit criteria:**` is mandatory. `**Evidence:**` and `**Blocker:**` are included when
they carry weight — a pure question-to-the-user step needs neither; anything that touches
code, files, or the palace needs both.

## Writing the three lines

**Exit criteria** — a state, in the past tense or as a predicate, that someone else could
check without having watched the work. Multiple criteria go on one line separated by `;`.

- Good: *contract file exists at a recorded path and the user approved it verbatim.*
- Bad: *write the contract and show it to the user.* (That is a procedure.)
- Bad: *the contract is good.* (Not checkable.)

**Evidence** — name the artifact or the command whose output settles it. Prefer something
deterministic: an exit code, a path, a count, a diff stat. "The model believes it is done"
is not evidence.

**Blocker** — the failure modes that must stop the step, stated as conditions, not
warnings. A blocker always says what happens next: stop and ask, repair and re-run, or
escalate. If a step has no way to fail badly, omit the line rather than inventing one.

## Anti-gaming

An exit criterion is a contract with the user, and every contract can be satisfied
dishonestly. These are never acceptable routes to a green step — in a skill, in a
subagent, or in a self-repair attempt:

- deleting, skipping, or `xfail`-ing a failing test
- weakening an assertion, or narrowing its inputs until it stops covering the failure
- reducing the scope handed to a reviewer or security checker so a finding disappears
- adding `# noqa`, `eslint-disable`, `@ts-ignore`, or any equivalent suppression
- restating the criterion more loosely so the current state satisfies it
- reporting a step as met on the grounds that the remaining gap is small

Concluding that the *criterion itself* is wrong is a legitimate finding — but it is an
**escalation to the user**, never a repair the skill performs on its own.

## What this replaces

Do not restate what a delegated skill does. `superpowers:systematic-debugging` documents
its own hypotheses-and-evidence loop; a step that invokes it needs the invocation plus the
exit criteria, not a summary of its internals. The same holds for micro-editing
instructions (which characters to replace, which line to insert after) — state the
resulting file state instead.
