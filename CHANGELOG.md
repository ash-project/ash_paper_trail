# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.4.0](https://github.com/ash-project/ash_paper_trail/compare/v0.3.1...v0.4.0) (2025-01-02)




### Features:

* Add `store_action_inputs?` option (#136)

* support bulk actions (#131)

### Bug Fixes:

* handle empty batch in after batch

* handle struct values in casted params

* batch: handle OriginalDataNotAvailable case (#135)

## [v0.3.1](https://github.com/ash-project/ash_paper_trail/compare/v0.3.0...v0.3.1) (2024-12-20)




### Improvements:

* "full_diff tracking not atomic" error message (#123)

* "full_diff tracking not atomic" error message

## [v0.3.0](https://github.com/ash-project/ash_paper_trail/compare/v0.2.1...v0.3.0) (2024-09-20)




### Features:

* Add ability to ignore sensitive attributes. (#117)

* Add support for redacting sensitive attributes from versions. (#116)

## [v0.2.1](https://github.com/ash-project/ash_paper_trail/compare/v0.2.0...v0.2.1) (2024-09-16)




### Bug Fixes:

* incorrectly applied base filter. (#114)

## [v0.2.0](https://github.com/ash-project/ash_paper_trail/compare/v0.1.4...v0.2.0) (2024-09-15)




### Features:

* Add `table_name` and `store_resource_name?` DSL options. (#110)

* Add `store_resource_identifier?` DSL option.

* Add `table_name` DSL option.

* ignore_actions: allow to ignore actions by configuration (#107)

### Bug Fixes:

* define_attribute?: invert if logic (#113)

* Regenerate .formatter.exs

* simplify setting attributes to avoid issue w/ private attributes returning errors (#102)

* small test fix keyword equality (#99)

### Improvements:

* Add builtin support for ash_sqlite. (#108)

* add `:primary_key_type` option

* add global? to multitenancy section (#101)

## [v0.1.4](https://github.com/ash-project/ash_paper_trail/compare/v0.1.3...v0.1.4) (2024-07-10)




### Bug Fixes:

* use `String.to_atom/1` instead of `to_existing_atom`

## [v0.1.3](https://github.com/ash-project/ash_paper_trail/compare/v0.1.2...v0.1.3) (2024-07-10)




### Bug Fixes:

* fix bulk destroy handling

* Check if `Ash.Domain` requires authorization (#82)

### Improvements:

* pick new values off of result

* allow opts to be passed to the generated relationship (#92)

* add `include_versions?` option

* add `atomic/3` callback to `CreateNewVersion`

* set context that can be used in policies

## [v0.1.2](https://github.com/ash-project/ash_paper_trail/compare/v0.1.2-rc.0...v0.1.2) (2024-05-10)




### Bug Fixes:

* fix tenant attribute must allow_nil?: true (#56)

* Replace private in AshPaperTrail.Resource.Changes.CreateNewVersion with public (#54)

## [v0.1.2-rc.0](https://github.com/ash-project/ash_paper_trail/compare/v0.1.1...v0.1.2-rc.0) (2024-03-30)




### Improvements:

* update to Ash 3.0

## [v0.1.1](https://github.com/ash-project/ash_paper_trail/compare/v0.1.0...v0.1.1) (2024-03-30)




### Bug Fixes:

* correctly carry over first primary key attribute type and constraints (#36)

* carry over first primary key attribute type and constraints

## [v0.1.0](https://github.com/ash-project/ash_paper_trail/compare/v0.1.0...v0.1.0) (2024-01-31)
### Breaking Changes:

* remove defaults for ignored_attributes (#27)



### Features:

* Full diff change tracking mode (#18)

### Bug Fixes:

* Honour upstream attribute constraints. (#31)

* properly set added relationship sources

* take only existing attributes for private attributes

* update deps and fix introspection

### Improvements:

* belongs_to_actor (#16)

* add store_action_name option (#14)

* support embedded resources (#10)

* use api resources or registry (#6)

* update to latest ash and use new docs

* flesh out options/tools

* make it all work, add some tests
