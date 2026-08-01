# Skill Workflows

Four recommended sequences for achieving results with vladyslav skills. Render natively on GitHub.

---

## New Project

From zero to first deployed feature.

```mermaid
flowchart LR
    A([Start:\nnew idea]):::start
    A --> B["/init-project\nBare AI shell (minimal)\nor opt-in modules (interactive)"]
    B --> D["/ingest\nDocument architecture\nseeds MemPalace"]
    D --> E["/add-feature\nDesign → contract\n→ plan → implement"]
    E --> F["/write-docs\nstories / tests\n/ project docs"]
    F --> G["  "]
    G --> H["/pre-release-check\nFinal gate\nbefore production"]
    H --> I([Shipped 🚀]):::done

    classDef start fill:#d0f0d0,stroke:#006600,color:#003300,font-weight:bold
    classDef done  fill:#d0f0d0,stroke:#006600,color:#003300,font-weight:bold
```

---

## Existing Project

Attach Claude Code to a project that already exists.

```mermaid
flowchart LR
    A([Start:\nexisting codebase]):::start
    A --> B["/attach-project\nAuto-detect stacks\nadd missing structure"]
    B --> C["/ingest\nDocument architecture\n+ seed MemPalace"]
    C --> D["/add-feature\nDesign → contract\n→ plan → implement"]
    D --> E([Continue feature\nloop]):::done

    classDef start fill:#d0f0d0,stroke:#006600,color:#003300,font-weight:bold
    classDef done  fill:#d0f0d0,stroke:#006600,color:#003300,font-weight:bold
```

---

## Before Release

Final docs and verification before shipping.

```mermaid
flowchart LR
    A([Start:\nfeatures done]):::start
    A --> B["/write-docs (all)\nstories → tests\n→ project docs"]
    B --> D["  "]
    D --> E["/pre-release-check\nTasks · tests · config\ndocs · changelog\n+ translations now!"]
    E --> F([Shipped 🚀]):::done

    classDef start fill:#d0f0d0,stroke:#006600,color:#003300,font-weight:bold
    classDef done  fill:#d0f0d0,stroke:#006600,color:#003300,font-weight:bold
```

---

## Bug Fix

Reproduce → fix root cause → verify → ship.

```mermaid
flowchart LR
    A([Start:\nbug reported]):::start
    A --> B["/fix-bug\nReproduce → failing test\n→ fix root cause\n→ code review → merge"]
    B --> C["/write-docs (tests)\nUpdate test plan\nfor the fixed scenario"]
    C --> D["/pre-release-check\nVerify nothing regressed\nbefore hotfix deploy"]
    D --> E([Fixed 🐛→✅]):::done

    classDef start fill:#d0f0d0,stroke:#006600,color:#003300,font-weight:bold
    classDef done  fill:#d0f0d0,stroke:#006600,color:#003300,font-weight:bold
```

---

## Session Continuity

Pause and resume long-running work across sessions.

```mermaid
flowchart LR
    A([Mid-task:\nneed to stop]):::start
    A --> B["PreCompact hook triggers\n/compact-save automatically\n→ MemPalace compact-save drawer"]
    B --> C([Compaction happens])

    D([After compaction\nor new session]) --> E[Compact-Save Continuity rule\nchecks MemPalace for\nrecent compact-save]
    E --> F[Restore context silently:\ntask · files · last decision · next]
    F --> G([Resume exactly\nwhere you stopped]):::done

    classDef start fill:#d0f0d0,stroke:#006600,color:#003300,font-weight:bold
    classDef done  fill:#d0f0d0,stroke:#006600,color:#003300,font-weight:bold
```

