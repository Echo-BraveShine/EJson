param(
    [Parameter(Mandatory)][string]$BundleDir,
    [Parameter(Mandatory)][string]$InstallerDir
)
$ErrorActionPreference = 'Stop'

$toolDir = Join-Path $env:RUNNER_TEMP 'ejson-wix'
dotnet tool install wix --tool-path $toolDir --version 6.0.2
if ($LASTEXITCODE -ne 0) { throw "Installing WiX failed with code $LASTEXITCODE" }

$msi = Join-Path (Get-Location).Path 'EJson-Windows-x64.msi'
$definition = Join-Path $InstallerDir 'ejson.wxs'
# WiX resolves relative source paths against the working directory or bind paths.
Push-Location $InstallerDir
try {
    & "$toolDir/wix.exe" build -arch x64 `
        -d "AppVersion=$env:EXPECTED_VERSION" -d "BuildNumber=$env:EXPECTED_BUILD" `
        -d "BundleDir=$BundleDir" -bindpath $InstallerDir -o $msi $definition
    if ($LASTEXITCODE -ne 0) { throw "Building MSI failed with code $LASTEXITCODE" }
} finally {
    Pop-Location
}

$installer = New-Object -ComObject WindowsInstaller.Installer
$database = $installer.OpenDatabase($msi, 0)
$view = $database.OpenView('SELECT `Property`, `Value` FROM `Property`')
$view.Execute()
$properties = @{}
while ($record = $view.Fetch()) {
    $properties[$record.StringData(1)] = $record.StringData(2)
}
$view.Close()
if ($properties.ProductVersion -ne $env:EXPECTED_VERSION -or
    $properties.EJSON_BUILD_NUMBER -ne $env:EXPECTED_BUILD) {
    throw "Unexpected MSI version: $($properties.ProductVersion)+$($properties.EJSON_BUILD_NUMBER)"
}
[void][Runtime.InteropServices.Marshal]::ReleaseComObject($view)
[void][Runtime.InteropServices.Marshal]::ReleaseComObject($database)
[void][Runtime.InteropServices.Marshal]::ReleaseComObject($installer)

$log = Join-Path $env:RUNNER_TEMP 'ejson-msi.log'
$process = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart /L*v `"$log`"" -Wait -PassThru
if ($process.ExitCode -ne 0) {
    Get-Content $log -Tail 100
    throw "Installing MSI failed with code $($process.ExitCode)"
}
try {
    $installDir = Join-Path $env:ProgramFiles 'EJson'
    foreach ($file in 'ejson.exe', 'flutter_windows.dll', 'vcruntime140.dll', 'data/flutter_assets/AssetManifest.bin') {
        if (-not (Test-Path (Join-Path $installDir $file))) { throw "Missing installed file: $file" }
    }
    $version = (Get-Item (Join-Path $installDir 'ejson.exe')).VersionInfo
    if ($version.ProductVersion -ne "$env:EXPECTED_VERSION+$env:EXPECTED_BUILD") {
        throw "Unexpected installed Flutter version: $($version.ProductVersion)"
    }
} finally {
    $process = Start-Process msiexec.exe -ArgumentList "/x $($properties.ProductCode) /qn /norestart" -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Uninstalling MSI failed with code $($process.ExitCode)" }
}
