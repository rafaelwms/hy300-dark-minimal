# HY300 Minimal Black

Black, minimal system for the Magcubic HY300 projector — patch + interactive installers (Linux, macOS, Windows),
English / Português (Brasil). **Read [RELEASE.md](RELEASE.md) first** (risks, requirements, steps) and
[NOTICE.md](NOTICE.md) (licenses, legal).

Sistema preto e minimalista para o projetor Magcubic HY300 — patch + instaladores interativos (Linux, macOS,
Windows), English / Português (Brasil). **Leia primeiro o [RELEASE.md](RELEASE.md)** (riscos, requisitos, passos) e o
[NOTICE.md](NOTICE.md) (licenças, aspectos legais).

```bash
git clone https://github.com/rafaelwms/hy300-dark-minimal.git && cd hy300-dark-minimal
./install-macos.sh      # or ./install-linux.sh  /  install-windows.ps1
```

```
install-linux.sh  install-macos.sh  install-windows.ps1    interactive installers
patch/            hy300-minimal.bin + manifest.txt          the patch (54 areas, ~15 MB) and its hashes
tools/            hy300tool.c                               FEL/FES helper (builds with libefex)
lib/              hy300-common.sh                           shared installer logic
maintainer/       make_patch.py                             how the patch was generated
```
