# NOTICE / AVISO

## English

**Original work (MIT, see `LICENSE`):** installer scripts, `tools/hy300tool.c`, `maintainer/`, documentation.

**`patch/hy300-minimal.bin` is NOT MIT-licensed work.** It contains the bytes that differ between the stock
HY300 firmware (build `UI_Veng.projector.20250221.201033`) and the modified one. Those bytes include
re-built, re-themed versions of proprietary applications (launcher, Settings, File Manager, App Store) and
filesystem metadata. The rights to that code belong to its respective owners (Magcubic/HTC-branded OEM
software, Allwinner). **No license from those owners is granted or implied.** The patch contains no complete
firmware image and no third-party boot files; it only works on top of a device that already runs the stock
firmware. It is shared for interoperability and personal customization of hardware you own. If you are a
rights holder and want it removed, open an issue and it will be taken down.

**Third-party components**

| Component | Use | License |
|---|---|---|
| [libefex](https://github.com/YuzukiTsuru/libefex) by Yuzuki Tsuru (pinned commit `3752e38`) | USB/FEL protocol, built on the user's machine; `tools/sunxi_hdr.h` is derived from its `test/fes_flash.c` | MIT |
| libusb | USB access | LGPL-2.1 (linked dynamically from your system) |
| AOSP `platform` test key | the patched apps are signed with the **public** Android test key, as the original apps already were | Apache-2.0 (key published by AOSP) |
| apktool, uber-apk-signer | used by the maintainer to rebuild/sign the apps; not shipped | Apache-2.0 |
| e2fsprogs (`debugfs`, `e2fsck`) | used by the maintainer to edit the ext4 images; not shipped | GPL-2.0 / LGPL |
| Community firmware `HY300_H713_Android11_By_Marcal.img` | NOT included. The installer extracts `fes1.fex` and `u-boot.fex` from the copy you provide, uses them only in RAM, and checks their SHA-256 | unknown / not ours |

**Security note.** The AOSP test key is public. On a device that trusts it (as the stock HY300 does), anyone can
craft an app with system privileges. This patch does not change that (the stock apps use the same key), but you
should not install apps from untrusted sources on this projector.

**No affiliation.** This project is not affiliated with or endorsed by Magcubic, HTC, Allwinner or Google.
"Android" and "Google Play" are trademarks of Google LLC.

## Português (Brasil)

**Trabalho original (MIT, veja `LICENSE`):** scripts de instalação, `tools/hy300tool.c`, `maintainer/`, documentação.

**`patch/hy300-minimal.bin` NÃO é trabalho sob licença MIT.** Ele contém os bytes que diferem entre o firmware
original do HY300 (build `UI_Veng.projector.20250221.201033`) e o modificado. Esses bytes incluem versões
reconstruídas e com novo tema de aplicativos proprietários (launcher, Configurações, Gerenciador de Arquivos,
App Store) e metadados do sistema de arquivos. Os direitos sobre esse código pertencem aos respectivos donos
(software de OEM da Magcubic/HTC, Allwinner). **Nenhuma licença desses donos é concedida ou implícita.** O patch
não contém imagem de firmware completa nem arquivos de boot de terceiros; só funciona sobre um aparelho que já
roda o firmware original. É compartilhado para interoperabilidade e personalização de hardware que você possui.
Se você é titular de direitos e quer a remoção, abra uma issue e será retirado.

**Componentes de terceiros:** libefex (MIT, commit fixo `3752e38`), libusb (LGPL-2.1, ligada dinamicamente a partir
do seu sistema), chave de teste pública do AOSP (Apache-2.0), apktool e uber-apk-signer (Apache-2.0, só do
mantenedor), e2fsprogs (GPL-2.0/LGPL, só do mantenedor). O firmware da comunidade
`HY300_H713_Android11_By_Marcal.img` **não** está incluído: o instalador extrai `fes1.fex` e `u-boot.fex` da cópia
que você fornecer, usa só na RAM e confere o SHA-256.

**Nota de segurança.** A chave de teste do AOSP é pública. Num aparelho que confia nela (como o HY300 original),
qualquer pessoa pode criar um app com privilégios de sistema. Este patch não muda isso (os apps originais já usam a
mesma chave), mas não instale apps de origem não confiável neste projetor.

**Sem vínculo.** Este projeto não tem vínculo nem aval da Magcubic, HTC, Allwinner ou Google. "Android" e "Google
Play" são marcas da Google LLC.
