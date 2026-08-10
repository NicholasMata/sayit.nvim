# Changelog

All notable changes to sayit.nvim are documented here. This project follows
[Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- Voice and speaking-rate configuration.
- Line, paragraph, buffer, range, and operator-based speech.
- Stable `<Plug>` mappings and `:SayVoices`.
- `:checkhealth sayit` support.
- Headless tests, formatting, linting, and continuous integration.

### Fixed

- Toggling now stops active speech instead of immediately restarting it.
- Process state is cleared after natural completion without stale callback races.
- Character-, line-, block-, backward-, and Unicode selection extraction.
- The `exit_visual` option is now respected.
- AppleScript fallback arguments no longer rely on shell quoting.
