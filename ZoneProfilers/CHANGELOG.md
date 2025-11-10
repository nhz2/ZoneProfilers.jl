# Release Notes

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## Unreleased

## [v0.1.1](https://github.com/nhz2/ZoneProfilers.jl/tree/ZoneProfilers-v0.1.1) - 2025-11-10

- Added `profiler_smoke_test` to help test `Profiler` implementations. [#5](https://github.com/nhz2/ZoneProfilers.jl/pull/5)
- `@zone profiler sqrt(2.0)` will now label the zone with "sqrt", instead of using the module name. The zone name can still be set with `name=` to override the automatic label. [#3](https://github.com/nhz2/ZoneProfilers.jl/pull/3)

## [v0.1.0](https://github.com/nhz2/ZoneProfilers.jl/tree/ZoneProfilers-v0.1.0) - 2025-11-01

### Added

- Initial release
