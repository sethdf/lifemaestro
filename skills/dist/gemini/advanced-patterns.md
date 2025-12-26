# Advanced Patterns

Advanced usage patterns for the universal skill format.

## Multi-Source Aggregator

When a skill needs to query multiple data sources:

```
src/multi-source/
├── skill.md
├── refs/
│   ├── source-a.md
│   ├── source-b.md
│   └── source-c.md
└── scripts/
    ├── fetch-a.sh
    ├── fetch-b.sh
    └── fetch-c.sh
```

## Conditional Workflows

Route based on user intent:

```markdown
## Instructions

1. Determine the type:
   - **Creating new?** → See @ref:create-workflow
   - **Editing existing?** → See @ref:edit-workflow
```

## Domain-Specific Organization

For skills covering multiple domains:

```
src/analytics/
├── skill.md
└── refs/
    ├── finance.md
    ├── sales.md
    └── product.md
```

The main skill.md routes to the appropriate domain based on user query.

## Variables for Feature Flags

Use variables to enable/disable features:

```markdown
## Variables

- enable_experimental: false
- default_format: json
- max_results: 100
```

Check these in your instructions to conditionally include guidance.
