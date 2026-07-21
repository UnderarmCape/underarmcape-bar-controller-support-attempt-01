# Frozen runtime manifest

The release workflow builds the four win-x64 self-contained executables once and records them in `frozen-runtime-manifest.json`. Each record identifies the source commit, .NET SDK, runtime identifier, project, output filename, file and product versions, byte size, architecture, and SHA-256 digest.

Deployment, deterministic staging, installer tests, and the public package all consume this same frozen set. The staging script rejects a manifest from another source commit or version and rejects any executable whose size, digest, version, project, or architecture differs from the manifest.

The compiler settings are deterministic, but separate .NET 5 single-file bundle builds are not claimed to be byte-identical. Package reproducibility is established by staging twice from the same hash-frozen executables and requiring identical ZIP digests.
