# Changelog

All notable changes to this module are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module uses [semantic versioning](https://semver.org/): a new major version means callers must change their code.

## [Unreleased]

## [1.0.0] - 2026-10-05

Initial release.

### Added

- An AWS Systems Manager document of any type, from YAML, JSON or text content, with a new default version for each change.
- `target_type`, `version_name` and `attachments`, for the resources a document can run on, named versions, and files such as scripts and packages.
- Checks at plan time for empty content, reserved name prefixes, version names and attachments.
- A change of `document_type` replaces the document, instead of an update that does nothing in AWS.
- `Scope`, `Purpose` and `Environment` tags from the `details` input.
- `region`, to create the document in a Region other than the provider's.
- A `metadata` output with the document's name, ARN, versions and everything else the module created.
- Offline tests, and examples for a `Command` document and for an `Automation` runbook with an attached script.

[Unreleased]: https://github.com/AutomateTheCloud/terraform-aws-ssm_document/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/AutomateTheCloud/terraform-aws-ssm_document/releases/tag/v1.0.0
