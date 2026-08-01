# Skills ecosystem

17 skills, grouped by lifecycle stage. Render natively on GitHub.

```mermaid
flowchart LR
    subgraph SETUP [Setup]
        direction TB
        s1[init-project]
        s2[attach-project]
        s3[ingest]
        s1 ~~~ s2 ~~~ s3
    end


    subgraph BUILD [Build]
        direction TB
        b1[add-feature]
        b2[fix-bug]
        b3[swiftui-pro]
        b1 ~~~ b2 ~~~ b3
    end

    subgraph SHIP [Docs Ship Memory]
        direction TB
        sh1[write-project-docs]
        sh2[write-user-stories]
        sh3[write-test-docs]
        sh4[pre-release-check]
        sh5[compact-save]
        sh6[save]
        sh1 ~~~ sh2 ~~~ sh3 ~~~ sh4 ~~~ sh5 ~~~ sh6
    end

    classDef cluster fill:#e8eef9,stroke:#3b5998,color:#1c2e5e
    class SETUP,BUILD,SHIP cluster
```

## Cluster meaning

- **Setup** — старт нового або підхоплення існуючого проекту, плюс довідник скілів
- **Discover and Design** — дослідження ринку, контракт продукту, design system, генерація екранів
- **Build** — лайфцикл фічі / багфіксу + iOS-специфічне ревю
- **Docs, Ship and Memory** — документація, фінальна верифікація перед релізом, кросс-сесійна пам'ять
