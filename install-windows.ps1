# HY300 Minimal Black - Windows installer (interactive, English / Portugues-BR). MIT License.
# Run from PowerShell:  powershell -ExecutionPolicy Bypass -File .\install-windows.ps1 [-Lang en|pt] [-Firmware C:\path\fw.img] [-DryRun] [-Restore]
# STATUS: written but NOT tested on a real Windows machine (the author only had macOS/Linux). Read the warnings in RELEASE.md.
param([string]$Lang = "", [string]$Firmware = "", [switch]$DryRun, [switch]$Restore, [string]$WorkDir = "$env:USERPROFILE\.hy300-minimal")
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$LibefexUrl = "https://github.com/YuzukiTsuru/libefex.git"
$LibefexCommit = "3752e38ff8e69190c53cd43290a8102beab55e73"
$RestoreDir = "$env:USERPROFILE\hy300-restore"
$RestoreFile = "$RestoreDir\restore-original-segments.bin"
$Msys = "C:\msys64"

$M = @{
 en = @{
  title="HY300 Minimal Black - installer"; riskHead="READ THIS BEFORE CONTINUING"
  risk=@("This tool writes to the internal storage (eMMC) of a Magcubic HY300 projector (Allwinner H713).",
   "It was made and tested on ONE unit, firmware build UI_Veng.projector.20250221.201033.","",
   "  * Nothing here is endorsed by Magcubic or Allwinner. You do this at your own risk.",
   "  * It replaces the launcher, Settings, File Manager and App Store with black-themed versions, and removes 18 apps.",
   "    The Google Play Store and any apps YOU installed are not part of it.",
   "  * Only 54 small areas of the system partitions are written (about 15 MB). Your data is not touched.",
   "  * Before writing, the tool checks that every area holds the exact original bytes. If anything differs it stops",
   "    without writing. It also saves YOUR original bytes so you can undo it.",
   "  * A mistake or a power cut while writing can leave the projector not booting. FEL mode (BootROM) is not affected,",
   "    so it is normally recoverable with -Restore, but there is NO guarantee.",
   "  * The patched apps are signed with the public AOSP test key (see NOTICE.md). Do not install apps from sources you",
   "    do not trust on this projector.","  * Use a stable power source and do not unplug anything while it is writing.",
   "  * THIS WINDOWS SCRIPT HAS NOT BEEN TESTED ON REAL WINDOWS. Prefer Linux or macOS if you can.")
  word="I UNDERSTAND"; typeIt="To continue, type exactly"; aborted="Aborted. Nothing was changed."
  deps="[1/6] Checking what is installed on this computer"; ok="found"; missing="MISSING"
  askInstall="Install the missing items now with winget / MSYS2?"; manual="Install them yourself and run this script again:"
  src="[2/6] Getting and building the flashing tool (libefex, MIT license)"; net="This downloads source code from github.com (about 1 MB). Continue?"
  built="Tool built:"; buildFail="Build failed. See the messages above."
  fw="[3/6] Community firmware (needed ONLY to borrow two small boot files)"
  fwExplain=@("FEL mode needs two small boot files (fes1.fex, u-boot.fex). They are not ours to redistribute, so this installer",
   "extracts them from the community firmware image you already have: HY300_H713_Android11_By_Marcal.img (name may differ).",
   "Only these two files are used, and only in RAM. The firmware itself is NOT flashed.")
  askFw="Path to the firmware .img file"; fwBad="Could not use that file. Check the path and that it is the right firmware."
  fel="[4/6] Put the projector in FEL mode"
  felHow=@("  1. Unplug the projector's power and wait ~10 s.",
   "  2. Connect it to this computer with an A-to-A (or A-to-C) USB data cable. If nothing is detected, use a powered USB hub.",
   "  3. Press and HOLD the small pinhole button under the HDMI port (use a pin) while you plug the power in; release after",
   "     a few seconds. The projector stays dark (no logo shown).",
   "  4. WINDOWS ONLY: the FEL device (USB ID 1F3A:EFE8) needs the WinUSB driver. Open Zadig (https://zadig.akeo.ie),",
   "     choose the device named 'USB Device(VID_1f3a_PID_efe8)', select WinUSB and click 'Replace Driver'.")
  felEnter="Press ENTER when ready (the installer waits up to 10 minutes)"; felFound="Device detected. Loading the RAM-only helper (about a minute)..."
  felFail="No device in FEL mode was found, or it could not be prepared. Nothing was written."
  check="[5/6] Checking the projector (read-only)"; checkFail="The projector does not match what this patch was made for. Nothing was written."
  askApply="Everything checks out. Write the patch now?"; apply="[6/6] Writing and verifying (do NOT unplug anything)"
  applyFail="The write or its verification failed. Run this script again with -Restore BEFORE powering on normally."
  saved="Your original bytes are saved here (keep this file):"
  done=@("DONE. Next:","  1. Unplug the power for ~10 s and plug it back WITHOUT holding the button.",
   "  2. Recommended: on the projector open Settings > Other settings > Factory reset, so the system starts from the new image.",
   "     The projector will start in English; set the time zone.","  3. To undo everything later: put it in FEL again and run this script with -Restore.")
  dry="DRY RUN finished: all checks passed, nothing was written."; restoreHead="RESTORE mode: puts your saved original bytes back."
  noRestore="No restore file found at:"; restoreOk="Original bytes restored and verified. Power-cycle the projector."; yn="[y/N]"; yes=@("y","yes")
 }
 pt = @{
  title="HY300 Minimal Black - instalador"; riskHead="LEIA ANTES DE CONTINUAR"
  risk=@("Esta ferramenta grava no armazenamento interno (eMMC) de um projetor Magcubic HY300 (Allwinner H713).",
   "Foi feita e testada em UMA unidade, firmware build UI_Veng.projector.20250221.201033.","",
   "  * Nada aqui tem aval da Magcubic ou da Allwinner. Voce faz por sua conta e risco.",
   "  * Troca o launcher, as Configuracoes, o Gerenciador de Arquivos e a App Store por versoes em tema preto e remove 18 apps.",
   "    A Google Play Store e os apps que VOCE instalou nao fazem parte disso.",
   "  * So 54 areas pequenas das particoes do sistema sao gravadas (cerca de 15 MB). Seus dados nao sao tocados.",
   "  * Antes de gravar, a ferramenta confere se cada area tem exatamente os bytes originais. Se algo for diferente, ela para",
   "    sem gravar. Ela tambem guarda os SEUS bytes originais para voce desfazer.",
   "  * Um erro ou queda de energia durante a gravacao pode deixar o projetor sem dar boot. O modo FEL (BootROM) nao e afetado,",
   "    entao normalmente da para recuperar com -Restore, mas NAO ha garantia.",
   "  * Os apps modificados sao assinados com a chave de teste publica do AOSP (veja NOTICE.md). Nao instale apps de origem",
   "    desconhecida neste projetor.","  * Use uma fonte de energia estavel e nao desconecte nada durante a gravacao.",
   "  * ESTE SCRIPT DE WINDOWS NAO FOI TESTADO EM WINDOWS REAL. Prefira Linux ou macOS se puder.")
  word="EU ENTENDO"; typeIt="Para continuar, digite exatamente"; aborted="Cancelado. Nada foi alterado."
  deps="[1/6] Verificando o que esta instalado neste computador"; ok="encontrado"; missing="FALTANDO"
  askInstall="Instalar agora o que falta com winget / MSYS2?"; manual="Instale voce mesmo e rode este script de novo:"
  src="[2/6] Baixando e compilando a ferramenta de gravacao (libefex, licenca MIT)"; net="Isto baixa codigo-fonte de github.com (cerca de 1 MB). Continuar?"
  built="Ferramenta compilada:"; buildFail="A compilacao falhou. Veja as mensagens acima."
  fw="[3/6] Firmware da comunidade (necessario SO para emprestar dois arquivos de boot)"
  fwExplain=@("O modo FEL precisa de dois arquivos de boot pequenos (fes1.fex, u-boot.fex). Nao podemos redistribui-los, entao este",
   "instalador os extrai da imagem de firmware da comunidade que voce ja tem: HY300_H713_Android11_By_Marcal.img (nome pode variar).",
   "So esses dois arquivos sao usados, e so na RAM. O firmware em si NAO e gravado.")
  askFw="Caminho do arquivo .img do firmware"; fwBad="Nao consegui usar esse arquivo. Confira o caminho e se e o firmware certo."
  fel="[4/6] Coloque o projetor em modo FEL"
  felHow=@("  1. Tire a energia do projetor da tomada e espere ~10 s.",
   "  2. Ligue-o a este computador com um cabo USB de dados A-A (ou A-C). Se nada for detectado, use um hub USB alimentado.",
   "  3. Aperte e SEGURE o botaozinho no furo embaixo da porta HDMI (use um alfinete) enquanto liga a energia; solte depois de",
   "     alguns segundos. O projetor fica escuro (sem mostrar o logo).",
   "  4. SO NO WINDOWS: o dispositivo FEL (ID USB 1F3A:EFE8) precisa do driver WinUSB. Abra o Zadig (https://zadig.akeo.ie),",
   "     escolha o dispositivo 'USB Device(VID_1f3a_PID_efe8)', selecione WinUSB e clique em 'Replace Driver'.")
  felEnter="Aperte ENTER quando estiver pronto (o instalador espera ate 10 minutos)"; felFound="Aparelho detectado. Carregando o auxiliar so na RAM (cerca de um minuto)..."
  felFail="Nenhum aparelho em modo FEL foi encontrado ou ele nao pode ser preparado. Nada foi gravado."
  check="[5/6] Verificando o projetor (somente leitura)"; checkFail="O projetor nao corresponde ao que este patch espera. Nada foi gravado."
  askApply="Tudo conferido. Gravar o patch agora?"; apply="[6/6] Gravando e verificando (NAO desconecte nada)"
  applyFail="A gravacao ou a verificacao falhou. Rode este script de novo com -Restore ANTES de ligar normalmente."
  saved="Seus bytes originais estao guardados aqui (guarde este arquivo):"
  done=@("PRONTO. Agora:","  1. Tire a energia por ~10 s e ligue de novo SEM segurar o botao.",
   "  2. Recomendado: no projetor abra Configuracoes > Outras configuracoes > Restaurar padrao de fabrica, para o sistema comecar da imagem nova.",
   "     O projetor inicia em ingles; ajuste o fuso horario.","  3. Para desfazer tudo depois: entre em FEL de novo e rode este script com -Restore.")
  dry="SIMULACAO concluida: tudo conferiu, nada foi gravado."; restoreHead="Modo RESTAURAR: devolve os seus bytes originais salvos."
  noRestore="Nenhum arquivo de restauracao encontrado em:"; restoreOk="Bytes originais restaurados e verificados. Desligue e ligue o projetor."; yn="[s/N]"; yes=@("s","sim","y","yes")
 }
}
function Die($msg) { Write-Host "`n$msg" -ForegroundColor Red; exit 1 }
function Ask-Yes($text) { $a = Read-Host "$text $($T.yn)"; return ($T.yes -contains $a.Trim().ToLower()) }
function Have($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

if (-not $Lang) { $c = Read-Host "1) English`n2) Portugues (Brasil)`n>"; $Lang = $(if ($c -eq "2" -or $c -like "pt*") { "pt" } else { "en" }) }
if ($Lang -like "pt*" -or $Lang -like "br*") { $Lang = "pt" } else { $Lang = "en" }
$T = $M[$Lang]

Write-Host "`n=== $($T.title) ===`n"; Write-Host "*** $($T.riskHead) ***`n"; $T.risk | ForEach-Object { Write-Host $_ }
$w = Read-Host "`n$($T.typeIt): $($T.word)`n>"
if ($w -ne $T.word) { Die $T.aborted }

# ---- 1. dependencies
Write-Host "`n$($T.deps)"
$gitOk = Have "git"; $msysOk = Test-Path "$Msys\usr\bin\bash.exe"
Write-Host ("  {0,-26} {1}" -f "git", $(if ($gitOk) { $T.ok } else { $T.missing }))
Write-Host ("  {0,-26} {1}" -f "MSYS2 (gcc, libusb)", $(if ($msysOk) { $T.ok } else { $T.missing }))
if (-not ($gitOk -and $msysOk)) {
  $cmds = @(); if (-not $gitOk) { $cmds += "winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements" }; if (-not $msysOk) { $cmds += "winget install --id MSYS2.MSYS2 -e --accept-package-agreements --accept-source-agreements" }
  if ((Have "winget") -and (Ask-Yes $T.askInstall)) { foreach ($c in $cmds) { Invoke-Expression $c } ; Write-Host "(open a NEW PowerShell window if git is still not found)" }
  else { Write-Host $T.manual; $cmds | ForEach-Object { Write-Host "  $_" }; exit 1 }
  if (-not (Test-Path "$Msys\usr\bin\bash.exe")) { Die "MSYS2 not found in $Msys" }
  if (-not (Have "git")) { Die "git not found; open a new PowerShell window and run this script again" }
}
function Msys-Run($cmd) { $env:MSYSTEM = "MINGW64"; $env:CHERE_INVOKING = "1"; & "$Msys\usr\bin\bash.exe" -lc $cmd; if ($LASTEXITCODE -ne 0) { Die $T.buildFail } }
& "$Msys\usr\bin\bash.exe" -lc "pacman -Q mingw-w64-x86_64-gcc mingw-w64-x86_64-libusb mingw-w64-x86_64-pkgconf" 2>$null | Out-Null
$pkgOk = ($LASTEXITCODE -eq 0)
Write-Host ("  {0,-26} {1}" -f "gcc + libusb + pkgconf", $(if ($pkgOk) { $T.ok } else { $T.missing }))
if (-not $pkgOk) {
  if (Ask-Yes $T.askInstall) { Msys-Run "pacman -S --needed --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-libusb mingw-w64-x86_64-pkgconf" }
  else { Write-Host $T.manual; Write-Host "  (MSYS2 shell) pacman -S --needed mingw-w64-x86_64-gcc mingw-w64-x86_64-libusb mingw-w64-x86_64-pkgconf"; exit 1 }
}

# ---- 2. fetch + build
Write-Host "`n$($T.src)"
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$Lib = "$WorkDir\libefex"
if (-not (Test-Path "$Lib\.git")) { if (-not (Ask-Yes $T.net)) { Die $T.aborted }; git clone --quiet $LibefexUrl $Lib; if ($LASTEXITCODE -ne 0) { Die $T.buildFail } }
git -C $Lib checkout --quiet $LibefexCommit; if ($LASTEXITCODE -ne 0) { Die $T.buildFail }
if ((git -C $Lib rev-parse HEAD).Trim() -ne $LibefexCommit) { Die "libefex commit mismatch" }
$Tool = "$WorkDir\hy300tool.exe"
$build = 'cd "$(cygpath -u ''' + $WorkDir + ''')" && L=libefex && T="$(cygpath -u ''' + $Root + ''')/tools" && ' +
  'gcc -O2 -I$L/includes -I"$T" $(pkg-config --cflags libusb-1.0) "$T/hy300tool.c" $L/src/efex-common.c $L/src/efex-fel.c $L/src/efex-fes.c $L/src/efex-payloads.c $L/src/efex-usb.c ' +
  '$L/src/usb/usb_layer.c $L/src/usb/usb_layer_libusb.c $L/src/usb/usb_layer_winusb.c $L/src/arch/*.c $(pkg-config --libs libusb-1.0) -lsetupapi -lwinusb -o hy300tool.exe && cp /mingw64/bin/libusb-1.0.dll .'
Msys-Run $build
Write-Host "$($T.built) $Tool"

# ---- 3. firmware (fes1 / u-boot)
Write-Host "`n$($T.fw)"; $T.fwExplain | ForEach-Object { Write-Host $_ }
New-Item -ItemType Directory -Force -Path "$WorkDir\fes" | Out-Null
if (-not ((Test-Path "$WorkDir\fes\fes1.fex") -and (Test-Path "$WorkDir\fes\u-boot.fex"))) {
  while ($true) {
    if (-not $Firmware) { $Firmware = Read-Host $T.askFw }
    & $Tool extract-fes $Firmware "$WorkDir\fes"
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host $T.fwBad; $Firmware = ""
  }
}
$Manifest = "$Root\patch\manifest.txt"; $Patch = "$Root\patch\hy300-minimal.bin"
function Enter-Fel {
  Write-Host "`n$($T.fel)"; $T.felHow | ForEach-Object { Write-Host $_ }; Read-Host "`n$($T.felEnter)" | Out-Null
  & $Tool wait-fel 600; if ($LASTEXITCODE -ne 0) { Die $T.felFail }
  Write-Host $T.felFound
  & $Tool load "$WorkDir\fes\fes1.fex" "$WorkDir\fes\u-boot.fex"; if ($LASTEXITCODE -ne 0) { Die $T.felFail }
}

if ($Restore) {
  Write-Host $T.restoreHead
  if (-not (Test-Path $RestoreFile)) { Die "$($T.noRestore) $RestoreFile" }
  Enter-Fel
  & $Tool restore $Manifest $RestoreFile; if ($LASTEXITCODE -ne 0) { Die "restore failed" }
  Write-Host $T.restoreOk; exit 0
}

Enter-Fel
Write-Host "`n$($T.check)"
New-Item -ItemType Directory -Force -Path $RestoreDir | Out-Null
& $Tool apply $Manifest $Patch $RestoreFile --dry-run; if ($LASTEXITCODE -ne 0) { Die $T.checkFail }
if ($DryRun) { Write-Host $T.dry; exit 0 }
if (-not (Ask-Yes $T.askApply)) { Die $T.aborted }
Write-Host "`n$($T.apply)"
& $Tool apply $Manifest $Patch $RestoreFile; if ($LASTEXITCODE -ne 0) { Die $T.applyFail }
Write-Host "`n$($T.saved) $RestoreFile`n"; $T.done | ForEach-Object { Write-Host $_ }
