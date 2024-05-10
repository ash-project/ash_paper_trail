# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

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
