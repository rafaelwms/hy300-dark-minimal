# HY300 Minimal Black

[English](#english) · [Português (Brasil)](#português-brasil)

---

## English

A small patch for the **Magcubic HY300** projector (Allwinner H713, Android 11) that turns the stock system into a
clean, black, minimal one — and **survives a factory reset**, because it is written into the system partitions
instead of being installed as app updates.

### What you get

- **Black, macOS-like look** everywhere: a one-row launcher (HDMI, App Store, Applications, Settings, Files),
  Settings (home screen and the main sub-menus; a few deeper dialogs may still show stock colors), File Manager (a hard-disk icon for internal storage, a USB-stick icon for
  drives) and the App Store. Charcoal cards, pure black background, blue only for focus.
- **Debloat — 18 apps removed from the image:** `com.android.bips`, `bluetoothmidiservice`, `dreams.basic`,
  `dreams.web`, `dynsystem`, `egg`, `htmlviewer`, `com.android.music` (RKMusic), `printservice.recommendation`, `printspooler`,
  `com.hotack.writesn` (factory SN/MAC writer), `com.htc.eventuploadservice`, `com.htc.hyk_test`,
  `com.mobisystems.office`, `com.softwinner.agingdragonbox`, `com.softwinner.dragonatt`, `com.softwinner.dragonbox`, and `com.android.nfx` (Netflix accessibility
  helper that nagged for an update).
- **App Store without the nag:** its boot-time update check (the "Version update" pop-up) and the promoted
  "GTV free trial" shortcut are gone. The store still opens and works.
- **Starts in English** after a factory reset (set your time zone — the stock default is Costa Rica).
- Untouched on purpose: **keystone**, focus, HDMI input, OTA updater, Wi-Fi/Bluetooth, the hidden engineering apps
  that the HDMI tile depends on. ADB is not enabled by us.

### Risks — please read

- This writes to the projector's **eMMC through the Allwinner FEL/FES protocol**. A power cut or a bad cable in the
  middle of a write can leave it **unable to boot**. FEL lives in the chip's BootROM, so you can normally recover
  with `--restore`, but there is **no guarantee**. You do this at your own risk.
- It was developed and tested on **one unit**, firmware build `UI_Veng.projector.20250221.201033`. The patch checks
  the SHA-256 of every area it will write; if your firmware is different it **refuses and writes nothing**. Do not
  try to force it.
- Only **54 small areas (~15 MB)** of the `system`/`product` logical partitions are written. Boot, bootloader,
  vbmeta, `vendor` and your data are not touched. The stock `fstab` has no `avb` flag for these partitions, so
  verified boot did not need to be altered.
- An **official OTA** update from the vendor would overwrite this and bring the stock look back.
- The patched apps are signed with the **public AOSP test key** (the stock apps already were). Never install apps
  from untrusted sources on this projector.
- Legal: see [NOTICE.md](NOTICE.md). The patch is derived from proprietary vendor software and is not licensed by
  its owners; no complete firmware is distributed.

### What you need

- A computer (Linux, macOS or Windows) with a free USB port, and ~10 minutes.
- A **USB data cable A-to-A** (or A-to-C), and a thin pin for the pinhole button under the HDMI port. If your
  computer does not detect the projector, put a **powered USB hub** between the cable and the computer.
- The community firmware image you already used for this projector (`HY300_H713_Android11_By_Marcal.img`): the
  installer only borrows two small boot files from it, in RAM. The firmware is **not** flashed. The maintainer
  cannot document where this file originally comes from: it is a firmware image for the HY300 that circulates in the
  community and that the maintainer already had. Its two files are checked by SHA-256, so any copy with the same
  content works. This project does **not** distribute it.
- Internet access during install (the installer downloads libefex source from GitHub and builds it on your machine).

### Install

Download/clone this folder, then:

| System | Command |
|---|---|
| Linux | `./install-linux.sh` |
| macOS | `./install-macos.sh` |
| Windows 10/11 | `powershell -ExecutionPolicy Bypass -File .\install-windows.ps1` |

The installer is interactive (English or Brazilian Portuguese): it explains the risks and asks you to type a
confirmation, checks and offers to install what is missing (compiler, git, libusb; Homebrew packages on macOS;
MSYS2 + WinUSB driver on Windows), builds the tool, extracts the two boot files, guides you into FEL mode, **checks
the projector read-only**, saves **your own original bytes** to `~/hy300-restore/` (keep this file!), asks one more
time, writes, and verifies. Options: `--dry-run` (everything except the write), `--lang en|pt-BR`,
`--firmware FILE.img`, `--restore`.

After it finishes: unplug the power for ~10 s and plug it back **without** holding the button. A factory reset on
the projector is recommended (Settings → Other settings → Factory reset) so nothing from the old setup remains.

### Undo

Put the projector in FEL mode again and run the same script with `--restore`. It writes back the bytes it saved
before installing and verifies them. It refuses to run if that file does not contain the original data.

### Tested / not tested

- ✅ The resulting image: booted and ran after a real factory reset on the author's unit (black UI, English, 88
  packages, no crashes, no update pop-up).
- ✅ The complete **macOS** installer, end-to-end on a device reverted to stock: FEL → load → read-only check → backup of
  the original bytes → write → verify; the whole `super` partition then matched the validated image byte for byte.
  The `--restore` path was also run on the real device. (The eMMC write is asynchronous: the tool re-checks and
  rewrites a segment when it did not stick yet — this happened on the last segment in both runs.)
- ✅ The complete **Linux** installer (Ubuntu 26.04 x86_64): `--restore` to stock, then a full install, verified. The
  step that installs missing packages with apt was only checked on a second machine (it printed the right command;
  it did not install).
- ✅ The complete **Windows** installer (Windows 11, PowerShell 5.1, winget + MSYS2, Zadig/WinUSB): `--restore` to
  stock, then a full install, verified. Windows needs the **WinUSB driver** for the FEL device (the script tells you how
  to do it with Zadig; that step is manual and graphical).
- ℹ️ Run `hy300tool diag` (built by the installer) to see what libusb detects if the projector is not found.
- ⚠️ Plugging a real USB stick into the File Manager (icon logic), other firmware builds, other HY300 units.

### How it works (short)

The system lives in a dynamic `super` partition (ext4). The maintainer edited copies of `system` and `product`
(removed the apps, replaced four APKs with black-themed rebuilds, fixed SELinux labels), computed the 4 KiB blocks
that differ, and shipped only those new bytes (`patch/hy300-minimal.bin`) plus a manifest
(`patch/manifest.txt`: LBA, size, SHA-256 before and after for each area). `hy300tool` loads Allwinner's `fes1` and
a U-Boot into RAM over FEL, reads each area, compares hashes, writes, waits for the eMMC, and reads back to verify.

### Credits

[libefex](https://github.com/YuzukiTsuru/libefex) (MIT) · the HY300 community that published the firmware and
guides · AOSP · apktool · uber-apk-signer.

---

## Português (Brasil)

Um patch pequeno para o projetor **Magcubic HY300** (Allwinner H713, Android 11) que transforma o sistema original
em um sistema limpo, preto e minimalista — e **sobrevive ao Factory Reset**, porque é gravado nas partições do
sistema em vez de instalado como atualização de app.

### O que você ganha

- **Visual preto estilo macOS** em tudo: launcher em fileira única (HDMI, App Store, Aplicativos, Configurações,
  Arquivos), Configurações (tela inicial e submenus principais; alguns diálogos mais profundos ainda podem aparecer com as cores originais), Gerenciador de Arquivos (ícone de HD para o armazenamento
  interno, ícone de pendrive para unidades) e a App Store. Cartões em carvão, fundo preto puro, azul só no foco.
- **Debloat — 18 apps removidos da imagem:** `com.android.bips`, `bluetoothmidiservice`, `dreams.basic`,
  `dreams.web`, `dynsystem`, `egg`, `htmlviewer`, `com.android.music` (RKMusic), `printservice.recommendation`, `printspooler`,
  `com.hotack.writesn` (gravador de SN/MAC de fábrica), `com.htc.eventuploadservice`, `com.htc.hyk_test`,
  `com.mobisystems.office`, `com.softwinner.agingdragonbox`, `com.softwinner.dragonatt`, `com.softwinner.dragonbox` e `com.android.nfx` (auxiliar de
  acessibilidade do Netflix que ficava pedindo atualização).
- **App Store sem o incômodo:** a verificação de atualização na inicialização (o aviso "Version update") e o atalho
  promocional "GTV free trial" saíram. A loja continua abrindo e funcionando.
- **Inicia em inglês** depois de um reset de fábrica (ajuste o fuso horário — o padrão original é Costa Rica).
- Intocados de propósito: **keystone**, foco, entrada HDMI, atualizador OTA, Wi-Fi/Bluetooth e os apps de engenharia
  que o tile HDMI usa. Nós não ativamos o ADB.

### Riscos — leia

- Isto grava na **eMMC do projetor pelo protocolo FEL/FES da Allwinner**. Uma queda de energia ou cabo ruim no meio
  da gravação pode deixá-lo **sem dar boot**. O FEL fica na BootROM do chip, então normalmente dá para recuperar com
  `--restore`, mas **não há garantia**. Você faz por sua conta e risco.
- Foi desenvolvido e testado em **uma unidade**, firmware build `UI_Veng.projector.20250221.201033`. O patch confere o
  SHA-256 de cada área que vai gravar; se o seu firmware for outro, ele **se recusa e não grava nada**. Não tente
  forçar.
- Só **54 áreas pequenas (~15 MB)** das partições lógicas `system`/`product` são gravadas. Boot, bootloader, vbmeta,
  `vendor` e seus dados não são tocados. O `fstab` original não tem a flag `avb` nessas partições, então não foi
  preciso mexer na verificação de boot.
- Uma **atualização OTA oficial** do fabricante sobrescreveria isto e traria de volta o visual original.
- Os apps modificados são assinados com a **chave de teste pública do AOSP** (os originais já eram). Nunca instale
  apps de origem não confiável neste projetor.
- Legal: veja [NOTICE.md](NOTICE.md). O patch deriva de software proprietário do fabricante e não é licenciado pelos
  donos; nenhum firmware completo é distribuído.

### O que você precisa

- Um computador (Linux, macOS ou Windows) com uma porta USB livre e ~10 minutos.
- Um **cabo USB de dados A-A** (ou A-C) e um alfinete fino para o botão no furo embaixo da porta HDMI. Se o computador
  não detectar o projetor, ponha um **hub USB alimentado** entre o cabo e o computador.
- A imagem de firmware da comunidade que você já usou neste projetor (`HY300_H713_Android11_By_Marcal.img`): o
  instalador só empresta dois arquivos de boot pequenos dela, na RAM. O firmware **não** é gravado. O mantenedor não
  consegue documentar a origem original desse arquivo: é uma imagem de firmware do HY300 que circula na comunidade e
  que ele já tinha. Os dois arquivos são conferidos por SHA-256, então qualquer cópia com o mesmo conteúdo serve. Este
  projeto **não** a distribui.
- Internet durante a instalação (o instalador baixa o código da libefex do GitHub e compila na sua máquina).

### Instalar

Baixe/clone esta pasta e rode:

| Sistema | Comando |
|---|---|
| Linux | `./install-linux.sh` |
| macOS | `./install-macos.sh` |
| Windows 10/11 | `powershell -ExecutionPolicy Bypass -File .\install-windows.ps1` |

O instalador é interativo (inglês ou português do Brasil): explica os riscos e pede uma confirmação digitada,
confere e oferece instalar o que falta (compilador, git, libusb; pacotes Homebrew no macOS; MSYS2 + driver WinUSB no
Windows), compila a ferramenta, extrai os dois arquivos de boot, guia você até o modo FEL, **confere o projetor só
lendo**, guarda **os seus bytes originais** em `~/hy300-restore/` (guarde esse arquivo!), pergunta mais uma vez,
grava e verifica. Opções: `--dry-run` (tudo menos a gravação), `--lang en|pt-BR`, `--firmware ARQUIVO.img`,
`--restore`.

Ao terminar: tire a energia por ~10 s e ligue de novo **sem** segurar o botão. Recomenda-se um reset de fábrica no
projetor (Configurações → Outras configurações → Restaurar padrão de fábrica) para não sobrar nada da configuração
antiga.

### Desfazer

Coloque o projetor em modo FEL de novo e rode o mesmo script com `--restore`. Ele grava de volta os bytes que guardou
antes de instalar e verifica. Ele se recusa a rodar se esse arquivo não tiver os dados originais.

### Testado / não testado

- ✅ A imagem resultante: iniciou e funcionou depois de um reset de fábrica real na unidade do autor (UI preta,
  inglês, 88 pacotes, sem travamentos, sem aviso de atualização).
- ✅ O instalador de **macOS** completo, de ponta a ponta num aparelho revertido ao original: FEL → carga →
  conferência só de leitura → cópia dos bytes originais → gravação → verificação; a partição `super` inteira ficou
  idêntica, byte a byte, à imagem validada. O caminho `--restore` também foi executado no aparelho real. (A escrita
  na eMMC é assíncrona: a ferramenta reconfere e regrava o trecho que ainda não pegou — isso aconteceu no último
  trecho nas duas execuções.)
- ✅ O instalador **Linux** completo (Ubuntu 26.04 x86_64): `--restore` ao original e depois instalação completa,
  verificada. A etapa que instala pacotes faltantes com apt só foi checada em outra máquina (mostrou o comando certo;
  não instalou).
- ✅ O instalador **Windows** completo (Windows 11, PowerShell 5.1, winget + MSYS2, Zadig/WinUSB): `--restore` ao
  original e depois instalação completa, verificada. O Windows precisa do **driver WinUSB** para o dispositivo FEL (o
  script explica como fazer com o Zadig; essa etapa é manual e gráfica).
- ℹ️ Rode `hy300tool diag` (compilada pelo instalador) para ver o que o libusb detecta se o projetor não for achado.
- ⚠️ Espetar um pendrive de verdade no Gerenciador de Arquivos (lógica do ícone), outros builds de firmware, outras
  unidades do HY300.

### Como funciona (resumo)

O sistema fica numa partição dinâmica `super` (ext4). O mantenedor editou cópias de `system` e `product` (removeu os
apps, trocou quatro APKs por reconstruções em tema preto, ajustou rótulos SELinux), calculou os blocos de 4 KiB que
mudam e publicou só esses bytes novos (`patch/hy300-minimal.bin`) mais um manifesto (`patch/manifest.txt`: LBA,
tamanho e SHA-256 antes e depois de cada área). A `hy300tool` carrega o `fes1` da Allwinner e um U-Boot na RAM via
FEL, lê cada área, compara os hashes, grava, espera a eMMC e lê de volta para verificar.

### Créditos

[libefex](https://github.com/YuzukiTsuru/libefex) (MIT) · a comunidade do HY300 que publicou o firmware e os guias ·
AOSP · apktool · uber-apk-signer.
