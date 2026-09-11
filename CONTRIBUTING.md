# Contributing

This is a fork of
[strategic-zone/Archlinux-aarch64-rpi-ImageBuilder](https://github.com/strategic-zone/Archlinux-aarch64-rpi-ImageBuilder)
that builds an Arch Linux ARM image for a Raspberry Pi 5 and publishes it as a
release asset you can flash without unwrapping anything first.

Fixes that apply to any image built from this repository are welcome, and are
worth sending upstream too.

## Proposing a change

`main` takes pull requests only; direct pushes are turned off. Fork, branch,
open a PR. Squash and rebase merges are both enabled, and merged branches are
deleted automatically.

Keep commits atomic — one coherent change each — and say in the message why
the change is needed, not just what it does. Most of the comments in
`build.sh` exist because something failed on real hardware, and that reason is
the part worth keeping.

## Running the checks

```bash
./test/all
```

Everything that would touch a disk or an account is stubbed, so this is safe
to run on the machine you are working on. It does not build an image. A change
to anything under `src/usr/local/bin/` should come with a check.

Building the image itself needs a privileged Arch container; the GitHub
Actions workflow is the supported path, and `./run-act.sh` runs it locally
through [act](https://github.com/nektos/act).

## Things that are deliberately personal

These are configuration for one person's machine, not defaults to improve:

- `OS_TIMEZONE` is set for where the cards get used. Nothing in the build can
  detect that — the runner is always UTC and the Pi has no clock.

## Security

The image is published, so treat anything written into it as public. In
particular, never add a credential at build time. `SSH_PUB_KEY_URLS` is empty
and must stay empty here: a key baked into a published image is a key every
person who flashes it grants root to, whoever ran the build. `root` and
`alarm` ship locked for the same reason. Both the key and the password are
provisioned per card, on first boot, from files on its boot partition.

Do not set the `WIFI_SSID` / `WIFI_PASSWORD` secrets
while this repository is public — the PSK would be baked into a downloadable
image.

If you find a security problem, open an issue; there is nothing here worth a
private disclosure process.
