# Gherkin Summary

## Changed Files

### {{ repository-relative path }}
```gherkin
{{ current target-state gherkin content }}
```

## Deleted Files
- {{ repository-relative path }}

## Related Gherkin

### {{ repository-relative path }}
```gherkin
{{ existing related gherkin statements to re-test }}
```

Stage 1 may leave `Related Gherkin` empty or replace it with `_None identified yet._`.
Stage 2 must review the project-root `.gherkin/` tree, keep this section at the end of the document, and replace the placeholder with only existing Gherkin statements that are related to the changed work.
Related means the scenario shares a product boundary, dependency, workflow, or regression surface with the changed Gherkin and should be re-tested alongside it.
Do not include merely similar or loosely themed scenarios.