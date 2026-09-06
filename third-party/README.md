# Bundled source records

This directory accompanies third-party files described in
[`THIRD_PARTY.md`](../THIRD_PARTY.md). Upstream material keeps its own license;
the project's MPL notice does not replace it.

## Obsidian Style Settings

The unmodified 1.0.9 release files are under
[`portable/obsidian/plugins/obsidian-style-settings/`](../portable/obsidian/plugins/obsidian-style-settings/).
The complete upstream source archive includes TypeScript, CSS, build scripts,
`yarn.lock`, documentation and the upstream license.

| Property | Value |
|---|---|
| Upstream | [community-archive/obsidian-style-settings](https://github.com/community-archive/obsidian-style-settings) |
| Tag | `1.0.9` |
| Commit | `4ebec6ae0131a9d5e8307bb5e26d59db5ba2e81c` |
| Source archive | [`obsidian-style-settings-1.0.9.tar.gz`](obsidian-style-settings-1.0.9.tar.gz) |
| Archive SHA-256 | `bc3aea1f93b6a241f904fe6c5aadd158879f77b4f24520dec34fca8eae5c56ec` |
| Release `main.js` SHA-256 | `1828abaacdab4c5578b705a625c585b30512f8efad4c7cfc5a18e70cc3557468` |

Source origin:
[GitHub archive at the pinned commit](https://codeload.github.com/community-archive/obsidian-style-settings/tar.gz/4ebec6ae0131a9d5e8307bb5e26d59db5ba2e81c).
The archive's license, manifest and release stylesheet match the bundled files.
See the [license notice](../THIRD_PARTY.md#obsidian-style-settings-109--upstream-gplv3-notice)
for the upstream metadata inconsistency.

To inspect or build the source in a separate directory, with Node.js and Yarn
Classic available:

```bash
tar -xzf /path/to/hypr-configs/third-party/obsidian-style-settings-1.0.9.tar.gz
cd obsidian-style-settings-4ebec6ae0131a9d5e8307bb5e26d59db5ba2e81c
yarn install --frozen-lockfile
yarn build
```

These are the upstream build commands. Dependency downloads use the upstream
lockfile; a byte-for-byte reproduction of the release has not been asserted.
The desktop bootstrap installs the existing release assets and does not run
this build. Keep this source archive when redistributing those assets.

## Helix query

The RPM-spec highlighting query is identical to
[Helix's upstream file](https://github.com/helix-editor/helix/blob/faaf9d9eed7ad96a4000764696ed1fe9f28dda59/runtime/queries/rpmspec/highlights.scm).

- Revision: `faaf9d9eed7ad96a4000764696ed1fe9f28dda59`.
- File: `portable/helix/runtime/queries/rpmspec/highlights.scm`.
- SHA-256: `ff2a714ae5d6ec1b0a2c65767e0c01197c66adf2ad4a063ec7b55342560ebd88`.
- License: MPL 2.0; [upstream license](https://github.com/helix-editor/helix/blob/faaf9d9eed7ad96a4000764696ed1fe9f28dda59/LICENSE),
  with the complete text also supplied in the root [`LICENSE`](../LICENSE).
