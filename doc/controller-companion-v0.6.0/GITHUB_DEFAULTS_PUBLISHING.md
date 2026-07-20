# GitHub defaults publishing

## Security boundary

`BARControllerUIDefaultsPublisher` is a developer-only .NET 5 helper. It accepts no token, embeds no credential, and uses the existing `gh` session only for an explicitly confirmed publish. Lua writes local JSON files only.

Unarmed watch mode validates `shipping-defaults.draft.json` and cannot publish. `watch --arm-explicit-publish` is intentionally conspicuous: it processes only a separate `publish-request.json` with `explicit: true`, an explicit authoring-intent draft, and a repository/branch matching the armed watcher. Ordinary Save, Save Draft, and recovery data do not qualify. Failures retain the request/draft and write `publish-result.json` for retry and editor status.

## First manual publish

From the repository root:

```powershell
gh auth status
dotnet run --project tools/controller-ui-publisher/BARControllerUIDefaultsPublisher.csproj -- validate
```

Prepare an explicit editor draft as a stable pair:

```powershell
dotnet run --project tools/controller-ui-publisher/BARControllerUIDefaultsPublisher.csproj -- prepare `
  --draft "<BAR data>\LuaUI\Config\BARControllerSupport\outbox\shipping-defaults.draft.json" `
  --version 0.6.0-2 `
  --output controller-ui
```

Exercise the commit path in a disposable local repository:

```powershell
dotnet run --project tools/controller-ui-publisher/BARControllerUIDefaultsPublisher.csproj -- dry-run `
  --local-repository "<disposable empty directory>"
```

Inspect both JSON files and the dry-run commit. Then, and only then, publish explicitly:

```powershell
dotnet run --project tools/controller-ui-publisher/BARControllerUIDefaultsPublisher.csproj -- publish `
  --confirm-publish `
  --repository UnderarmCape/underarmcape-bar-controller-support-attempt-01 `
  --branch controller-ui-live-defaults
```

The helper revalidates the pair/hash, checks `gh auth status`, clones into a new temporary directory, commits exactly the pair, and pushes only the dedicated defaults branch. It never pushes the source branch or creates a release.

## Optional authorized watcher

Only on Kailil's authorized development machine:

```powershell
dotnet run --project tools/controller-ui-publisher/BARControllerUIDefaultsPublisher.csproj -- watch `
  --outbox "<BAR data>\LuaUI\Config\BARControllerSupport\outbox" `
  --arm-explicit-publish
```

Ctrl+Alt+S or Publish Request in Developer Authoring Mode writes one request. Duplicate file notifications are debounced by request ID. The resulting Git commit is recorded in `publish-result.json`; embedding a commit's own hash inside the same commit's manifest would be self-referential, so the manifest records source state while the result file records the actual commit.

No live publish, push, release, or package publication was performed during this development pass.
