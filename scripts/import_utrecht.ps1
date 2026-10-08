param(
    [string]$Database = 'housing_2025',
    [string]$User = 'root',
    [string]$Server = 'localhost',
    [int]$Port = 3306
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$pythonExe = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
if (-not (Test-Path -LiteralPath $pythonExe)) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCommand) { $pythonExe = $pythonCommand.Source }
}
if (-not (Test-Path -LiteralPath $pythonExe)) { throw 'Python was not found. Install Python 3.11+ first.' }
$dependencyDirectory = Join-Path (Get-Location) 'output/real_data/host_packages'
# Use one dedicated package path, not a stale PYTHONPATH from a different Python.
$env:PYTHONPATH = $dependencyDirectory
& $pythonExe -c 'import openpyxl; import mysql.connector; assert callable(openpyxl.load_workbook); assert callable(mysql.connector.connect)'
if ($LASTEXITCODE -ne 0) {
    & $pythonExe -m pip install --upgrade --target $dependencyDirectory -r requirements.txt
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
    & $pythonExe -c 'import openpyxl; import mysql.connector; assert callable(openpyxl.load_workbook); assert callable(mysql.connector.connect)'
    if ($LASTEXITCODE -ne 0) { throw 'Python dependencies are incomplete; import was not attempted.' }
}
& $pythonExe scripts/prepare_real_data.py
if ($LASTEXITCODE -ne 0) { throw 'Data preparation failed; nothing imported.' }
Write-Host 'Enter your MySQL password at the private prompt below. It is not stored in the report.'
& $pythonExe scripts/import_real_data.py --host $Server --port $Port --user $User --database $Database
if ($LASTEXITCODE -ne 0) { throw 'Import failed. See the error above; do not assume the data were committed.' }
