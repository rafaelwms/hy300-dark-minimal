#!/usr/bin/env bash
# Shared logic for install-linux.sh and install-macos.sh (bash 3.2 compatible).
# MIT License - see LICENSE. Messages: English and Brazilian Portuguese.

LIBEFEX_URL="https://github.com/YuzukiTsuru/libefex.git"
LIBEFEX_COMMIT="3752e38ff8e69190c53cd43290a8102beab55e73"
WORKDIR="${HY300_WORKDIR:-$HOME/.hy300-minimal}"
RESTORE_DIR="${HY300_RESTORE_DIR:-$HOME/hy300-restore}"
RESTORE_FILE="$RESTORE_DIR/restore-original-segments.bin"
LANG_SEL=""
DRY_RUN=0
DO_RESTORE=0
FIRMWARE=""

# ---------------------------------------------------------------- messages
t() {  # t KEY  -> prints the message in the selected language
  case "$LANG_SEL:$1" in
  en:title)        echo "HY300 Minimal Black - installer";;
  pt:title)        echo "HY300 Minimal Black - instalador";;
  en:risk_head)    echo "READ THIS BEFORE CONTINUING";;
  pt:risk_head)    echo "LEIA ANTES DE CONTINUAR";;
  en:risk_body)    printf '%s\n' \
"This tool writes to the internal storage (eMMC) of a Magcubic HY300 projector (Allwinner H713)." \
"It was made and tested on ONE unit, firmware build UI_Veng.projector.20250221.201033." \
"" \
"  * Nothing here is endorsed by Magcubic or Allwinner. You do this at your own risk." \
"  * It replaces the launcher, Settings, File Manager and App Store with black-themed versions," \
"    and removes 18 apps. The Google Play Store and any apps YOU installed are not part of it." \
"  * Only 54 small areas of the system partitions are written (about 15 MB). Your data is not touched." \
"  * Before writing, the tool checks that every area holds the exact original bytes. If anything" \
"    differs it stops without writing. It also saves YOUR original bytes so you can undo it." \
"  * A mistake or a power cut while writing can leave the projector not booting. FEL mode (BootROM)" \
"    is not affected, so it is normally recoverable with --restore, but there is NO guarantee." \
"  * The patched apps are signed with the public AOSP test key (see NOTICE.md). Do not install apps" \
"    from sources you do not trust on this projector." \
"  * Use a stable power source and do not unplug anything while it is writing.";;
  pt:risk_body)    printf '%s\n' \
"Esta ferramenta grava no armazenamento interno (eMMC) de um projetor Magcubic HY300 (Allwinner H713)." \
"Foi feita e testada em UMA unidade, firmware build UI_Veng.projector.20250221.201033." \
"" \
"  * Nada aqui tem aval da Magcubic ou da Allwinner. Você faz por sua conta e risco." \
"  * Troca o launcher, as Configurações, o Gerenciador de Arquivos e a App Store por versões em tema" \
"    preto e remove 18 apps. A Google Play Store e os apps que VOCÊ instalou não fazem parte disso." \
"  * Só 54 áreas pequenas das partições do sistema são gravadas (cerca de 15 MB). Seus dados não são tocados." \
"  * Antes de gravar, a ferramenta confere se cada área tem exatamente os bytes originais. Se algo" \
"    for diferente, ela para sem gravar. Ela também guarda os SEUS bytes originais para você desfazer." \
"  * Um erro ou queda de energia durante a gravação pode deixar o projetor sem dar boot. O modo FEL" \
"    (BootROM) não é afetado, então normalmente dá para recuperar com --restore, mas NÃO há garantia." \
"  * Os apps modificados são assinados com a chave de teste pública do AOSP (veja NOTICE.md). Não instale" \
"    apps de origem desconhecida neste projetor." \
"  * Use uma fonte de energia estável e não desconecte nada durante a gravação.";;
  en:type_word)    echo "I UNDERSTAND";;
  pt:type_word)    echo "EU ENTENDO";;
  en:type_prompt)  echo "To continue, type exactly";;
  pt:type_prompt)  echo "Para continuar, digite exatamente";;
  en:aborted)      echo "Aborted. Nothing was changed.";;
  pt:aborted)      echo "Cancelado. Nada foi alterado.";;
  en:step_deps)    echo "[1/6] Checking what is installed on this computer";;
  pt:step_deps)    echo "[1/6] Verificando o que está instalado neste computador";;
  en:dep_ok)       echo "found";;
  pt:dep_ok)       echo "encontrado";;
  en:dep_missing)  echo "MISSING";;
  pt:dep_missing)  echo "FALTANDO";;
  en:ask_install)  echo "Install the missing packages now?";;
  pt:ask_install)  echo "Instalar agora os pacotes que faltam?";;
  en:manual_cmd)   echo "Install them yourself, then run this script again. Suggested command:";;
  pt:manual_cmd)   echo "Instale você mesmo e rode este script de novo. Comando sugerido:";;
  en:step_src)     echo "[2/6] Getting and building the flashing tool (libefex, MIT license)";;
  pt:step_src)     echo "[2/6] Baixando e compilando a ferramenta de gravação (libefex, licença MIT)";;
  en:net_warn)     echo "This downloads source code from github.com (about 1 MB). Continue?";;
  pt:net_warn)     echo "Isto baixa código-fonte de github.com (cerca de 1 MB). Continuar?";;
  en:build_ok)     echo "Tool built:";;
  pt:build_ok)     echo "Ferramenta compilada:";;
  en:build_fail)   echo "Build failed. See the messages above.";;
  pt:build_fail)   echo "A compilação falhou. Veja as mensagens acima.";;
  en:step_fw)      echo "[3/6] Community firmware (needed ONLY to borrow two small boot files)";;
  pt:step_fw)      echo "[3/6] Firmware da comunidade (necessário SÓ para emprestar dois arquivos de boot)";;
  en:fw_explain)   printf '%s\n' \
"FEL mode needs two small boot files (fes1.fex, u-boot.fex). They are not ours to redistribute," \
"so this installer extracts them from the community firmware image you already have:" \
"  HY300_H713_Android11_By_Marcal.img   (the file name may differ; its content must match)" \
"Only these two files are used, and only in RAM. The firmware itself is NOT flashed.";;
  pt:fw_explain)   printf '%s\n' \
"O modo FEL precisa de dois arquivos de boot pequenos (fes1.fex, u-boot.fex). Não podemos redistribuí-los," \
"então este instalador os extrai da imagem de firmware da comunidade que você já tem:" \
"  HY300_H713_Android11_By_Marcal.img   (o nome pode variar; o conteúdo precisa bater)" \
"Só esses dois arquivos são usados, e só na RAM. O firmware em si NÃO é gravado.";;
  en:ask_fw)       echo "Path to the firmware .img file:";;
  pt:ask_fw)       echo "Caminho do arquivo .img do firmware:";;
  en:fw_bad)       echo "Could not use that file. Check the path and that it is the right firmware.";;
  pt:fw_bad)       echo "Não consegui usar esse arquivo. Confira o caminho e se é o firmware certo.";;
  en:step_fel)     echo "[4/6] Put the projector in FEL mode";;
  pt:step_fel)     echo "[4/6] Coloque o projetor em modo FEL";;
  en:fel_howto)    printf '%s\n' \
"  1. Unplug the projector's power and wait ~10 s." \
"  2. Connect it to this computer with a USB cable: the projector's USB-A port is device-mode," \
"     so you need an A-to-A (or A-to-C) data cable. Direct USB-C ports of some computers do not work:" \
"     if nothing is detected, use a powered USB hub between the cable and the computer." \
"  3. Press and HOLD the small pinhole button under the HDMI port (use a pin) while you plug the power" \
"     in; release after a few seconds. The projector stays dark (no logo shown).";;
  pt:fel_howto)    printf '%s\n' \
"  1. Tire a energia do projetor da tomada e espere ~10 s." \
"  2. Ligue-o a este computador com um cabo USB de dados: a porta USB-A do projetor funciona em modo" \
"     dispositivo, então use um cabo A-A (ou A-C). Portas USB-C diretas de alguns computadores não" \
"     funcionam: se nada for detectado, use um hub USB alimentado entre o cabo e o computador." \
"  3. Aperte e SEGURE o botãozinho no furo embaixo da porta HDMI (use um alfinete) enquanto liga a" \
"     energia; solte depois de alguns segundos. O projetor fica escuro (sem mostrar o logo).";;
  en:fel_enter)    echo "Press ENTER when you are ready (the installer will wait up to 10 minutes for the device)";;
  pt:fel_enter)    echo "Aperte ENTER quando estiver pronto (o instalador espera até 10 minutos pelo aparelho)";;
  en:fel_found)    echo "Device detected. Loading the RAM-only helper (about a minute)...";;
  pt:fel_found)    echo "Aparelho detectado. Carregando o auxiliar só na RAM (cerca de um minuto)...";;
  en:fel_fail)     echo "No device in FEL mode was found, or it could not be prepared. Nothing was written.";;
  pt:fel_fail)     echo "Nenhum aparelho em modo FEL foi encontrado ou ele não pôde ser preparado. Nada foi gravado.";;
  en:step_check)   echo "[5/6] Checking the projector (read-only)";;
  pt:step_check)   echo "[5/6] Verificando o projetor (somente leitura)";;
  en:check_fail)   echo "The projector does not match what this patch was made for. Nothing was written.";;
  pt:check_fail)   echo "O projetor não corresponde ao que este patch espera. Nada foi gravado.";;
  en:ask_apply)    echo "Everything checks out. Write the patch now?";;
  pt:ask_apply)    echo "Tudo conferido. Gravar o patch agora?";;
  en:step_apply)   echo "[6/6] Writing and verifying (do NOT unplug anything)";;
  pt:step_apply)   echo "[6/6] Gravando e verificando (NÃO desconecte nada)";;
  en:apply_fail)   echo "The write or its verification failed. Run this script again with --restore BEFORE powering on normally.";;
  pt:apply_fail)   echo "A gravação ou a verificação falhou. Rode este script de novo com --restore ANTES de ligar normalmente.";;
  en:restore_saved) echo "Your original bytes are saved here (keep this file):";;
  pt:restore_saved) echo "Seus bytes originais estão guardados aqui (guarde este arquivo):";;
  en:done)         printf '%s\n' \
"DONE. Next:" \
"  1. Unplug the power for ~10 s and plug it back WITHOUT holding the button." \
"  2. Recommended: on the projector open Settings > Other settings > Factory reset, so the system starts" \
"     from the new image with no leftovers. The projector will start in English; set the time zone." \
"  3. To undo everything later: put it in FEL again and run this script with --restore.";;
  pt:done)         printf '%s\n' \
"PRONTO. Agora:" \
"  1. Tire a energia por ~10 s e ligue de novo SEM segurar o botão." \
"  2. Recomendado: no projetor abra Configurações > Outras configurações > Restaurar padrão de fábrica," \
"     para o sistema começar da imagem nova sem sobras. O projetor inicia em inglês; ajuste o fuso horário." \
"  3. Para desfazer tudo depois: entre em FEL de novo e rode este script com --restore.";;
  en:dry_done)     echo "DRY RUN finished: all checks passed, nothing was written.";;
  pt:dry_done)     echo "SIMULAÇÃO concluída: tudo conferiu, nada foi gravado.";;
  en:restore_head) echo "RESTORE mode: puts your saved original bytes back.";;
  pt:restore_head) echo "Modo RESTAURAR: devolve os seus bytes originais salvos.";;
  en:no_restore)   echo "No restore file found at:";;
  pt:no_restore)   echo "Nenhum arquivo de restauração encontrado em:";;
  en:restore_ok)   echo "Original bytes restored and verified. Power-cycle the projector.";;
  pt:restore_ok)   echo "Bytes originais restaurados e verificados. Desligue e ligue o projetor.";;
  en:yes_no)       echo "[y/N]";;
  pt:yes_no)       echo "[s/N]";;
  *) echo "$1";;
  esac
}
say() { t "$1"; }
ask_yes() {  # ask_yes KEY -> 0 if yes
  local ans; printf '%s %s ' "$(t "$1")" "$(t yes_no)"; read -r ans
  case "$(printf '%s' "$ans" | tr 'A-Z' 'a-z')" in y|yes|s|sim) return 0;; *) return 1;; esac
}
die() { printf '\n%s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- start
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --lang) LANG_SEL="$(printf '%s' "$2" | tr 'A-Z' 'a-z')"; case "$LANG_SEL" in pt*|br*) LANG_SEL=pt;; *) LANG_SEL=en;; esac; shift 2;;
      --firmware) FIRMWARE="$2"; shift 2;;
      --dry-run) DRY_RUN=1; shift;;
      --restore) DO_RESTORE=1; shift;;
      --workdir) WORKDIR="$2"; shift 2;;
      -h|--help) echo "usage: $0 [--lang en|pt-BR] [--firmware FILE.img] [--dry-run] [--restore] [--workdir DIR]"; exit 0;;
      *) die "unknown option: $1";;
    esac
  done
}
choose_language() {
  [ -n "$LANG_SEL" ] && return
  printf '1) English\n2) Português (Brasil)\n> '; local a; read -r a
  case "$a" in 2|pt*|PT*) LANG_SEL=pt;; *) LANG_SEL=en;; esac
}
confirm_risks() {
  printf '\n=== %s ===\n\n' "$(t title)"; printf '*** %s ***\n\n' "$(t risk_head)"; t risk_body; printf '\n'
  local w; w="$(t type_word)"; printf '%s: %s\n> ' "$(t type_prompt)" "$w"; local a; read -r a
  [ "$a" = "$w" ] || { t aborted; exit 1; }
}

# ---------------------------------------------------------------- build
fetch_and_build() {
  say step_src
  mkdir -p "$WORKDIR"
  if [ ! -d "$WORKDIR/libefex/.git" ]; then
    ask_yes net_warn || { say aborted; exit 1; }
    git clone --quiet "$LIBEFEX_URL" "$WORKDIR/libefex" || die "$(t build_fail)"
  fi
  ( cd "$WORKDIR/libefex" && git checkout --quiet "$LIBEFEX_COMMIT" ) || die "$(t build_fail)"
  local head; head="$(cd "$WORKDIR/libefex" && git rev-parse HEAD)"
  [ "$head" = "$LIBEFEX_COMMIT" ] || die "libefex commit mismatch: $head"
  local L="$WORKDIR/libefex" T="$ROOT/tools"
  TOOL="$WORKDIR/hy300tool"
  # We compile only the library sources + our tool. libefex's test programs are NOT built (one of them erases the flash).
  # shellcheck disable=SC2046
  ${CC:-cc} -O2 -I"$L/includes" -I"$T" $(pkg-config --cflags libusb-1.0) "$T/hy300tool.c" \
    "$L/src/efex-common.c" "$L/src/efex-fel.c" "$L/src/efex-fes.c" "$L/src/efex-payloads.c" "$L/src/efex-usb.c" \
    "$L/src/usb/usb_layer.c" "$L/src/usb/usb_layer_libusb.c" "$L"/src/arch/*.c $(pkg-config --libs libusb-1.0) \
    -o "$TOOL" || die "$(t build_fail)"
  echo "$(t build_ok) $TOOL"
}

# ---------------------------------------------------------------- firmware
get_fes_files() {
  say step_fw; t fw_explain; printf '\n'
  mkdir -p "$WORKDIR/fes"
  if [ -f "$WORKDIR/fes/fes1.fex" ] && [ -f "$WORKDIR/fes/u-boot.fex" ]; then return 0; fi
  while true; do
    if [ -z "$FIRMWARE" ]; then printf '%s ' "$(t ask_fw)"; read -r FIRMWARE; fi
    FIRMWARE="${FIRMWARE/#\~/$HOME}"
    if "$TOOL" extract-fes "$FIRMWARE" "$WORKDIR/fes"; then return 0; fi
    t fw_bad; FIRMWARE=""
  done
}

# ---------------------------------------------------------------- device
enter_fel() {
  say step_fel; t fel_howto; printf '\n%s\n' "$(t fel_enter)"; read -r _
  $RUN "$TOOL" wait-fel 600 || die "$(t fel_fail)"
  say fel_found
  $RUN "$TOOL" load "$WORKDIR/fes/fes1.fex" "$WORKDIR/fes/u-boot.fex" || die "$(t fel_fail)"
}

run_restore() {
  t restore_head
  [ -f "$RESTORE_FILE" ] || die "$(t no_restore) $RESTORE_FILE"
  enter_fel
  $RUN "$TOOL" restore "$ROOT/patch/manifest.txt" "$RESTORE_FILE" || die "restore failed"
  t restore_ok
}

run_install() {
  enter_fel
  say step_check
  mkdir -p "$RESTORE_DIR"
  $RUN "$TOOL" apply "$ROOT/patch/manifest.txt" "$ROOT/patch/hy300-minimal.bin" "$RESTORE_FILE" --dry-run || die "$(t check_fail)"
  if [ "$DRY_RUN" = 1 ]; then t dry_done; exit 0; fi
  ask_yes ask_apply || { say aborted; exit 1; }
  say step_apply
  $RUN "$TOOL" apply "$ROOT/patch/manifest.txt" "$ROOT/patch/hy300-minimal.bin" "$RESTORE_FILE" || die "$(t apply_fail)"
  printf '\n%s %s\n\n' "$(t restore_saved)" "$RESTORE_FILE"
  t 'done'
}

main_flow() {
  choose_language
  confirm_risks
  check_deps            # defined by the OS-specific script; must set RUN (empty or "sudo")
  fetch_and_build
  get_fes_files
  if [ "$DO_RESTORE" = 1 ]; then run_restore; else run_install; fi
}
