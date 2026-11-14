# AIra Lug - Windows installer (PowerShell).
# Checks Git, Obsidian, QMD (with Node.js >= 22) and Hermes Agent, and offers
# to install each missing program. Default answer is "yes".
#
# Remote usage:
#   irm https://raw.githubusercontent.com/CarlosLongarela/aira-lug/main/install/install.ps1 | iex
#
# Note: user-facing strings avoid accented characters on purpose, so the script
# renders correctly in Windows PowerShell 5.1 regardless of file encoding.

$ErrorActionPreference = 'Continue'

$script:Results = [ordered]@{}
$script:NodeMinMajor = 22
$script:HermesInstallUrl = 'https://hermes-agent.nousresearch.com/install.ps1'

function Write-Info( $Message ) { Write-Host "  $Message" -ForegroundColor Cyan }
function Write-Ok( $Message ) { Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Warn( $Message ) { Write-Host "  [!] $Message" -ForegroundColor Yellow }
function Write-Err( $Message ) { Write-Host "  [X] $Message" -ForegroundColor Red }
function Write-Step( $Message ) { Write-Host ''; Write-Host "== $Message ==" -ForegroundColor White }

# Ask a yes/no question. Empty answer means yes.
function Ask-YesNo( $Question ) {
	while ( $true ) {
		$answer = Read-Host "  $Question [S/n]"
		if ( $null -eq $answer ) { $answer = '' }
		switch -Regex ( $answer.Trim().ToLower() ) {
			'^$' { return $true }
			'^(s|si|y|yes)$' { return $true }
			'^(n|no)$' { return $false }
			default { Write-Warn 'Responde S (si) o N (no).' }
		}
	}
}

# Reload PATH from the registry so freshly installed tools are found.
function Update-SessionPath {
	$machine = [Environment]::GetEnvironmentVariable( 'Path', 'Machine' )
	$user = [Environment]::GetEnvironmentVariable( 'Path', 'User' )
	$env:Path = "$machine;$user"
}

function Test-Command( $Name ) {
	return [bool]( Get-Command $Name -ErrorAction SilentlyContinue )
}

function Test-Winget {
	if ( Test-Command 'winget' ) { return $true }
	Write-Err 'No se encuentra winget (App Installer).'
	Write-Info 'Instalalo desde Microsoft Store: https://apps.microsoft.com/detail/9NBLGGH4NNS1'
	return $false
}

function Install-WingetPackage( $Id ) {
	if ( -not ( Test-Winget ) ) { return $false }
	winget install --id $Id -e --source winget --accept-source-agreements --accept-package-agreements
	$ok = ( 0 -eq $LASTEXITCODE )
	Update-SessionPath
	return $ok
}

# Run a remote PowerShell installer in a child process, so an "exit" inside it
# does not close this session.
function Invoke-RemoteInstaller( $Url ) {
	$shell = ( Get-Process -Id $PID ).Path
	& $shell -NoProfile -ExecutionPolicy Bypass -Command "irm '$Url' | iex"
	$ok = ( 0 -eq $LASTEXITCODE )
	Update-SessionPath
	return $ok
}

function Get-NodeMajor {
	if ( -not ( Test-Command 'node' ) ) { return 0 }
	$version = ( node --version ) 2>$null
	if ( $version -match '^v(\d+)\.' ) { return [int]$Matches[1] }
	return 0
}

function Test-Obsidian {
	$paths = @(
		"$env:LOCALAPPDATA\Programs\Obsidian\Obsidian.exe",
		"$env:LOCALAPPDATA\Obsidian\Obsidian.exe",
		"$env:ProgramFiles\Obsidian\Obsidian.exe"
	)
	foreach ( $path in $paths ) {
		if ( Test-Path $path ) { return $true }
	}
	if ( Test-Command 'winget' ) {
		winget list --id Obsidian.Obsidian -e --accept-source-agreements *> $null
		if ( 0 -eq $LASTEXITCODE ) { return $true }
	}
	return $false
}

# --- Program steps ----------------------------------------------------------

function Step-Git {
	Write-Step 'Git'
	if ( Test-Command 'git' ) {
		Write-Ok ( git --version )
		$script:Results['Git'] = 'ya instalado'
		return
	}
	Write-Warn 'Git no se encuentra en el sistema.'
	if ( -not ( Ask-YesNo 'Quieres instalar Git?' ) ) { $script:Results['Git'] = 'omitido'; return }
	if ( ( Install-WingetPackage 'Git.Git' ) -and ( Test-Command 'git' ) ) {
		Write-Ok ( git --version )
		$script:Results['Git'] = 'instalado'
	} else {
		Write-Err 'No se pudo instalar Git. Descargalo desde https://git-scm.com/downloads'
		$script:Results['Git'] = 'error'
	}
}

function Step-Obsidian {
	Write-Step 'Obsidian'
	if ( Test-Obsidian ) {
		Write-Ok 'Obsidian esta instalado.'
		$script:Results['Obsidian'] = 'ya instalado'
		return
	}
	Write-Warn 'Obsidian no se encuentra en el sistema.'
	if ( -not ( Ask-YesNo 'Quieres instalar Obsidian?' ) ) { $script:Results['Obsidian'] = 'omitido'; return }
	if ( Install-WingetPackage 'Obsidian.Obsidian' ) {
		Write-Ok 'Obsidian instalado.'
		$script:Results['Obsidian'] = 'instalado'
	} else {
		Write-Err 'No se pudo instalar Obsidian. Descargalo desde https://obsidian.md/download'
		$script:Results['Obsidian'] = 'error'
	}
}

# Node.js >= 22 is a QMD prerequisite.
function Ensure-Node {
	$major = Get-NodeMajor
	if ( $major -ge $script:NodeMinMajor ) {
		Write-Ok "Node.js $( node --version )"
		return $true
	}
	if ( $major -gt 0 ) {
		Write-Warn "QMD necesita Node.js $( $script:NodeMinMajor ) o superior; tienes $( node --version )."
		$question = 'Quieres instalar/actualizar Node.js LTS?'
	} else {
		Write-Warn 'QMD necesita Node.js y no se encuentra en el sistema.'
		$question = 'Quieres instalar Node.js LTS?'
	}
	if ( -not ( Ask-YesNo $question ) ) { return $false }
	$null = Install-WingetPackage 'OpenJS.NodeJS.LTS'
	if ( ( Get-NodeMajor ) -ge $script:NodeMinMajor ) {
		Write-Ok "Node.js $( node --version )"
		return $true
	}
	Write-Err 'Node.js no esta disponible en esta sesion. Abre una terminal nueva y vuelve a ejecutar el instalador.'
	return $false
}

function Step-Qmd {
	Write-Step 'QMD'
	if ( Test-Command 'qmd' ) {
		Write-Ok "QMD $( qmd --version 2>$null )"
		$script:Results['QMD'] = 'ya instalado'
		return
	}
	Write-Warn 'QMD no se encuentra en el sistema.'
	if ( -not ( Ask-YesNo 'Quieres instalar QMD?' ) ) { $script:Results['QMD'] = 'omitido'; return }
	if ( -not ( Ensure-Node ) ) {
		Write-Err 'QMD no se instala sin Node.js 22 o superior.'
		$script:Results['QMD'] = 'error (falta Node.js)'
		return
	}
	npm install -g @tobilu/qmd
	Update-SessionPath
	if ( Test-Command 'qmd' ) {
		Write-Ok "QMD $( qmd --version 2>$null )"
		$script:Results['QMD'] = 'instalado'
	} else {
		Write-Err 'No se pudo instalar QMD. Revisa la salida de npm.'
		$script:Results['QMD'] = 'error'
	}
}

function Step-Hermes {
	Write-Step 'Hermes Agent'
	if ( Test-Command 'hermes' ) {
		Write-Ok 'Hermes Agent esta instalado.'
		$script:Results['Hermes'] = 'ya instalado'
		return
	}
	Write-Warn 'Hermes Agent no se encuentra en el sistema.'
	Write-Info 'Se usara el instalador oficial para Windows nativo (en fase beta segun Nous Research).'
	if ( -not ( Ask-YesNo 'Quieres instalar Hermes Agent?' ) ) { $script:Results['Hermes'] = 'omitido'; return }
	$null = Invoke-RemoteInstaller $script:HermesInstallUrl
	if ( Test-Command 'hermes' ) {
		Write-Ok 'Hermes Agent instalado.'
		$script:Results['Hermes'] = 'instalado'
	} else {
		Write-Warn 'Instalador ejecutado, pero "hermes" no aparece en el PATH de esta sesion. Abre una terminal nueva para comprobarlo.'
		$script:Results['Hermes'] = 'revisar'
	}
}

# --- Main -------------------------------------------------------------------

Write-Host ''
Write-Host 'AIra Lug - instalador para Windows' -ForegroundColor Magenta
Write-Host 'Se comprobara Git, Obsidian, QMD y Hermes Agent.'

Step-Git
Step-Obsidian
Step-Qmd
Step-Hermes

Write-Step 'Resumen'
foreach ( $key in $script:Results.Keys ) {
	Write-Host ( '  {0,-10} {1}' -f $key, $script:Results[$key] )
}
Write-Host ''
Write-Info 'Abre una terminal nueva para que el PATH actualizado tenga efecto.'
Write-Info 'Siguientes pasos: https://github.com/CarlosLongarela/aira-lug#readme'
Write-Host ''
