[![StepSecurity Maintained Action](https://raw.githubusercontent.com/step-security/maintained-actions-assets/main/assets/maintained-action-banner.png)](https://docs.stepsecurity.io/actions/stepsecurity-maintained-actions)

# StepSecurity Setup Databricks CLI

`step-security/databricks-setup-cli` is a GitHub Action that installs the [Databricks CLI](https://github.com/databricks/cli).

## Usage

Install the default CLI version pinned in this action's `VERSION` file:

```yaml
- uses: step-security/databricks-setup-cli@v1
```

Install a specific version:

```yaml
- uses: step-security/databricks-setup-cli@v1
  with:
    version: 1.1.0
```

Install a snapshot build produced by the `release-snapshot` workflow in `databricks/cli`:

```yaml
- uses: step-security/databricks-setup-cli@v1
  with:
    snapshot: 'true'
    branch: main
```

## Inputs

| Name       | Required | Default            | Description |
| ---------- | -------- | ------------------ | ----------- |
| `version`  | no       | _(value of `VERSION` file)_ | Specific Databricks CLI version (for example `1.1.0`). When empty the default pinned version is read from the `VERSION` file at the root of this action. |
| `snapshot` | no       | `false`            | Set to `'true'` to install a snapshot build instead of a tagged release. |
| `branch`   | no       | `main`             | Branch whose snapshot to install. Only consulted when `snapshot` is `'true'`. |

## Snapshot mode and authentication

`snapshot: 'true'` downloads a workflow artifact from `databricks/cli` using the GitHub Actions `gh` CLI. The workflow's default `GITHUB_TOKEN` is forwarded for authentication. If your workflow runs in a repository whose default token cannot read another repository's artifacts, supply a personal access token via the `GH_TOKEN` environment variable on the step.

## License

This action is released under the [MIT License](./LICENSE).
