# Display wake fixes — September 2026

Targeted patches for **Hyprland 0.56.2 / Aquamarine 0.15.0 / Waybar 0.15.0**.
These packages preserve the current Lua compositor and Aquamarine's `.so.14`
ABI. They are local builds, not official openSUSE updates. The bootstrap does
not silently install or pin them.

## Why these patches exist

On a long DPMS wake, the HDMI link disconnected and returned. Aquamarine
rejected the compositor's final disable with `Cannot commit a disconnected
output`, then discarded its CRTC assignment without releasing the kernel's
display state. On reconnect, every modeset failed with `EINVAL`. Hyprland
reported HDMI as enabled at **0×0**, and Hyprlock had no usable output to draw on.
This matches [Aquamarine issue #386](https://github.com/hyprwm/aquamarine/issues/386),
introduced in the 0.15.0 async-commit changes.

Waybar had a second failure: creating bars synchronously inside an output
callback can trigger GTK layer shell's initial-configure timeout. The window
becomes unmapped while its process keeps running. `Restart=on-failure` cannot
detect that condition. [Waybar PR #4984](https://github.com/Alexays/Waybar/pull/4984)
fixes the callback ordering; the 0.15.0 release predates that merged change.

The Aquamarine patch permits an **explicit disable** through both commit guards
during destruction, retaining the stale-output and enable checks. It is a local
patch addressing the upstream report; it has not been submitted or accepted
upstream. The Waybar patch is a backport of merged commit
`f57decf81c3770d857c611898d2841b33ba5f579`.

## Build

The specs derive from these X11:Wayland source revisions:

| Package | OBS source revision | Local release |
| --- | --- | --- |
| aquamarine | `7387407675e679c706fda829ee634742` | `1.1.wakefix1` |
| waybar | `271a14d81ce94667cb064e81d58d03d1` | `1.7.wakefix1` |

Use separate build roots and run the builds sequentially. Concurrent `osc`
downloads can race in the shared package cache when Factory publishes new RPMs.
From the repository root, an Aquamarine build looks like this:

```bash
repo=$PWD
work=$(mktemp -d)
osc checkout -r 7387407675e679c706fda829ee634742 \
  -o "$work/aquamarine" X11:Wayland aquamarine
cp "$repo"/packaging/display-wake/aquamarine/{aquamarine.spec,aquamarine.changes,0001-drm-allow-disconnect-disable.patch,drm-disconnect-regression.cpp,source.sha256} \
  "$work/aquamarine/"
cd "$work/aquamarine"
sha256sum -c source.sha256
osc build --clean --alternative-project=openSUSE:Factory \
  --root=/var/tmp/build-root/aquamarine-wakefix-x86_64 \
  --release=1.1.wakefix1 --buildtool-opt=--noclean \
  standard x86_64 aquamarine.spec
```

For Waybar, use its revision above, copy `waybar.spec`, `waybar.changes`,
`waybar.rpmlintrc`, `0001-client-defer-bar-creation.patch`, and `source.sha256`
from the adjacent `waybar/` directory, then build with a separate
`waybar-wakefix-x86_64` root and release `1.7.wakefix1`. Run the source validator
and inspect the `%check` and rpmlint results before installing.

Install only the resulting `libaquamarine14` and `waybar` runtime RPMs through
the package manager. All their runtime requirements must already be satisfied;
do not force dependency removal or downgrade Hyprland to make them install.
Restart Waybar after installation. **Log out and back in to load the corrected
Aquamarine library:** reloading Lua does not replace a library already mapped
into the running compositor.

From a terminal in the fresh session, run
`python3 ~/.config/hypr/scripts/check-display-session.py`. It checks whether
Hyprland actually loaded the installed library, whether awake outputs have
usable resolutions, and whether Waybar has mapped surfaces. It changes nothing
and does not restart any process.

## Verification and limits

- Both patched packages built locally; rpmlint reported zero errors and warnings.
- Aquamarine's three headless upstream tests passed. `simpleWindow` requires a
  compositor and is excluded from the package's headless `%check`.
- The added regression fixture invokes the real output/connector teardown with
  a fake KMS implementation. The installed, unpatched library fails the cleanup
  assertions; the patched library passes all 15 checks. Private fixture access
  is confined to the test compiler invocation, with no library API changes.
- Patched Waybar passed its three test suites and ten monitor-add/remove cycles
  in an isolated nested compositor, keeping all three bars mapped and the same
  process throughout, with no initial-configure timeouts.
- A physical HDMI wake and password unlock after a fresh login still need
  verification. Short DPMS cycles and virtual monitors do not reproduce the
  display's overnight link behavior.

After future package updates, check whether they contain these changes before
dropping the local patches. A higher package version alone is not proof that
the regression is fixed. No package locks are installed.

Source patches retain their upstream licensing: Aquamarine's BSD-3-Clause and
Waybar's MIT, with the license texts alongside each package. Specs retain their
openSUSE license headers; the new DRM regression fixture is BSD-3-Clause.
