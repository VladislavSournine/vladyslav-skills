# Pre-Release Check — iOS Apple Review (Check 6)

This file contains the iOS-only Apple App Store review check. The orchestrator (`SKILL.md`) instructs the subagent to apply this check **in addition to** the cross-platform checks when `platform == ios`.

For non-iOS platforms (`web`, `backend`, `plugin`, `other`), skip this entire file.

---

### Check 6: Apple App Store review (iOS only)

**Skip this check entirely if `platform` is NOT `ios`.**

**Why this check exists:** a pre-development Apple review (section 11 of `start-project.md`) audits the IDEA before coding. This step audits the SHIPPED ARTIFACT — screenshots, metadata, final UI strings, privacy manifest, IAP wiring — against the same guidelines, plus anything new Apple has flagged in between.

1. **Read prior audit.** Open `docs/product/apple-review.md` (a pre-development Apple review, if one was done). If missing, warn: "No pre-development Apple review found. Submission-phase check will only catch issues visible in the shipped artifact — earlier architectural risks may already be baked in." Continue anyway.

2. **Refresh rejection patterns.** Run cross-wing MemPalace searches to pick up anything new since the pre-dev check:
   ```
   mempalace_search wing=swift-calories "apple rejection"
   mempalace_search wing=swift-calories "review feedback"
   mempalace_search "apple rejection 2025"
   mempalace_search "apple rejection 2026"
   ```
   Compile findings — anything not in `docs/product/apple-review.md` is new and must be checked.

3. **Apply apple-appstore-reviewer checklist.** Read the skill at `~/.claude/skills/apple-appstore-reviewer/SKILL.md` (plain prompt-based skill — use Read tool, not Skill tool). Apply it against the shipped artifact with this input:

   ```
   You are reviewing a shipped iOS app BEFORE submission to App Store Connect.
   This is the LAST gate before upload.

   Prior audit (pre-development): <paste docs/product/apple-review.md summary>
   New rejection patterns since prior audit: <paste MemPalace findings>

   Audit the shipped artifact against Apple App Store Review Guidelines, with
   emphasis on things that can ONLY be verified after implementation:

   A. Guideline 2.1 — demo account: credentials in App Store Connect reviewer notes
   B. Guideline 2.3 — screenshots match shipped UI (no placeholders, no mockups)
   C. Guideline 5.1.1 — privacy: PrivacyInfo.xcprivacy exists, all tracked APIs declared,
      third-party SDK privacy manifests present
   D. Guideline 5.1.2 — Info.plist usage descriptions for every requested permission
   E. Guideline 3.1.1 — IAP: no external payment links for digital goods, no
      "subscribe on website" text
   F. Guideline 4.0 — accessibility: VoiceOver labels, dynamic type, dark mode
   G. AI-content disclosure (if any LLM features) — visible UI disclosure, not
      just App Store description
   H. Guideline 4.2 — minimum functionality: does the shipped app do more than
      a web wrapper / simple list?
   I. Guideline 5.1.5 — background modes and location justifications in Info.plist
      match actual usage

   For EACH finding, report:
   - Severity: BLOCKER / HIGH / MEDIUM / LOW
   - Where in the artifact: file path or App Store Connect field
   - Exact fix (not "consider adding X" — give the text/code)

   Also verify each item from the pre-dev audit's "decisions locked in" list is
   actually in the shipped code.
   ```

4. **Process findings:**
   - **BLOCKER or HIGH** → Apple check = FAIL (severity: blocker), regardless of other checks. Block the release.
   - **MEDIUM** → Apple check = WARN (severity: medium), let user decide.
   - **LOW** → list in summary as FYI.

5. **Write findings** to `docs/release/apple-review-submission.md` (new file). Format:
   ```markdown
   # Apple App Store Submission Review — <date>

   ## Blockers
   - <severity> <guideline> — <what> → <exact fix>

   ## Warnings
   - ...

   ## FYI
   - ...

   ## Pre-dev audit verification
   - [x] <decision from apple-review.md> — verified in <file>
   - [ ] <decision> — NOT implemented (BLOCKER)
   ```

6. **MemPalace writeback.** If you discovered NEW rejection patterns during this audit (patterns not already in `swift-calories` wing), write them via `mempalace_add_drawer`:
   - **wing:** `swift-calories`
   - **room:** `problem`
   - **content:** `[WHAT] New Apple rejection pattern: <name>. [DETAILS] <trigger>. [DISCOVERED DURING] <project> submission review, <date>.`
   - **added_by:** `pre-release-check`

   Check duplicates first with `mempalace_check_duplicate`.

---

## Apple review integration — why it's a hard gate

Apple BLOCKER/HIGH findings make the whole check FAIL even if tests/config/docs all pass. Reasoning: shipping an iOS build that will be rejected is worse than holding a release — rejection means a review cycle lost (typically a week) and a worse signal to Apple about the project. Better to catch it at this step than after upload.

If you find yourself wanting to override this — STOP. The right move is to fix the finding, not weaken the gate.
