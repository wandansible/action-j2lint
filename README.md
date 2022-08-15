# GitHub Action: Jinja2 Lint

Lint jinja2 template files using [j2lint](https://github.com/aristanetworks/j2lint)

## Environment variables

| Environment variable    | Default                                     | Description |
| ----------------------- | ------------------------------------------- | ----------- |
| `J2LINT_FILES_REGEX`    | `'^.*\.(j2\|jinja2\|jinja)$'`               | Regular expression for files to be checked |
| `J2LINT_IGNORE_RULES`   | `""`                                        | Space-separated list of j2lint rules to ignore |
| `J2LINT_WARNING_RULES`  | `""`                                        | Space-separated list of j2lint rules be shown as warnings |
| `VALIDATE_ALL_CODEBASE` | `"false"`                                   | Whether to check all jinja2 files in the repository or just new/edited files (in reference to `DEFAULT_BRANCH`). Make sure to set `fetch-depth: 0` with `actions/checkout` |
| `DEFAULT_BRANCH`        | `"main"`                                    | The default branch of the repository |

## Sample usage

```yaml
---
name: Lint checks

on:
  push:
    branches-ignore:
      - main
  pull_request:
    branches:
      - main

jobs:
  jinja2-lint:
    name: Jinja2 Lint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: Lint jinja2 files
        uses: wanduow/action-j2lint@v1
```
