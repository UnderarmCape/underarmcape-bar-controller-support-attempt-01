# GitHub release policy

Every successful controller-support milestone must be published as a public GitHub release. The newest milestone is GitHub Latest unless the operation is explicitly publishing historical Recovery Mode data. Experimental and risky builds are permitted, but installation is always opt-in and must never be forced.

Completion requires a unique tag, schema-v1 detached release manifest, package and manifest SHA-256 sidecars, dynamic payload inventory, release notes, successful validation/deployment/rollback, a pushed branch, and verified GitHub assets. Deployment alone is not delivery. Historical releases retain their original commit and ZIP; never rebuild an old asset from current source.

The current publisher is `tools/release/Publish-ControllerRelease.ps1`. Future work must use it, mark the new release Latest, and update release sequence/tag identity even when semantic version remains unchanged.
