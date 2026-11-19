# Changelog

All notable changes to this project are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- PowerShell publish script that publishes only tagged releases of each graph repo, with a double-click `.bat` launcher.
- Local `publish-config.json` (git-ignored) for paths, created from `publish-config.example.json` on first run.
- `_versions.txt` in the publish folder showing the live version of each graph.

### Changed
- Replaces the old `publish_dynamo.bat`, which copied the newest `.dyn` on disk whether finished or not and compared by file date.

### Fixed
