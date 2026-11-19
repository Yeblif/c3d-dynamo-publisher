# c3d-dynamo-publisher

Publishes the released version of each Civil 3D Dynamo graph (`c3d-dynamo-*` repos) into the folder Civil 3D reads graphs from.

## What it does

- Scans every graph repo in the source folder (folders starting `_` are skipped).
- For each repo, finds the newest release tag (`v1`, `v2`, …) and takes the `.dyn` files from the repo root **as they were at that tag**. Unfinished work on `main`, branches or test folders is never published.
- Copies them into `_Published`, comparing file contents to report **New / Updated / Unchanged**. Repos with no tag are listed as **Not released**; two repos with the same `.dyn` name are flagged as a **CLASH**.
- Writes `_versions.txt` in `_Published` showing which version of each graph is live, and keeps a log of each run (last 50 by default).

## How to use

### First-time setup

1. Clone this repo into the folder that holds the graph repos, with a leading underscore so it isn't treated as a graph:
   ```bash
   cd ~/dev/c3d-dynamo
   git clone https://github.com/Yeblif/c3d-dynamo-publisher.git _publisher
   ```
2. Double-click `publish-dynamo.bat`. On the first run it creates `publish-config.json` and opens it in Notepad.
3. Set `DestRoot` to your `_Published` folder and save. Use `\\` for each backslash, e.g. `"C:\\Users\\me\\Graphs\\_Published"`. `%USERPROFILE%` and other environment variables work.
4. Run `publish-dynamo.bat` again.

`publish-config.json` is git-ignored, so your paths stay on your machine.

| Setting | Default | Meaning |
|---|---|---|
| `DestRoot` | *(required)* | Folder Civil 3D reads published graphs from |
| `SourceRoot` | folder this repo is cloned into | Folder containing the `c3d-dynamo-*` repos |
| `MaxLogs` | `50` | Number of run logs to keep |

Any setting can also be overridden for one run, e.g. `publish-dynamo.bat -DestRoot "D:\Test\_Published" -NoFetch`.

### Releasing a graph

Tag the commit you want published, then run the publisher:

```bash
cd ~/dev/c3d-dynamo/<graph-repo>
git tag -a v2 -m "What changed"
git push origin v2
```

Or create a release on GitHub (**Releases → Draft a new release**); the publisher fetches tags before it runs.

## Files

| File | Purpose |
|---|---|
| `publish-dynamo.bat` | Double-click launcher |
| `publish-dynamo.ps1` | The publish logic |
| `publish-config.example.json` | Template for your local `publish-config.json` |

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
