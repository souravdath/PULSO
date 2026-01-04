# PowerShell Script to Force Clean Flutter Project
# This script kills all processes that might be locking build directories
# and forcefully deletes build and .dart_tool folders

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Flutter Force Clean Script" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Kill all Java/Gradle processes
Write-Host "[1/5] Terminating Java and Gradle processes..." -ForegroundColor Yellow
Get-Process -Name "java", "javaw" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name "gradle*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "  ✓ Java/Gradle processes terminated" -ForegroundColor Green

# Step 2: Kill all Dart and Flutter processes
Write-Host "[2/5] Terminating Dart and Flutter processes..." -ForegroundColor Yellow
Get-Process -Name "dart", "dartaotruntime", "flutter" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "  ✓ Dart/Flutter processes terminated" -ForegroundColor Green

# Step 3: Kill any adb (Android Debug Bridge) processes
Write-Host "[3/5] Terminating ADB processes..." -ForegroundColor Yellow
Get-Process -Name "adb" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "  ✓ ADB processes terminated" -ForegroundColor Green

# Wait a moment for processes to fully terminate
Write-Host "[4/5] Waiting for processes to release file locks..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
Write-Host "  ✓ Wait complete" -ForegroundColor Green

# Step 4: Force delete build directories
Write-Host "[5/5] Deleting build directories..." -ForegroundColor Yellow

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDirs = @(
    "$projectRoot\build",
    "$projectRoot\.dart_tool",
    "$projectRoot\android\build",
    "$projectRoot\android\.gradle",
    "$projectRoot\android\app\build"
)

foreach ($dir in $buildDirs) {
    if (Test-Path $dir) {
        try {
            Write-Host "  Removing: $dir" -ForegroundColor Gray
            Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
            Write-Host "    ✓ Deleted" -ForegroundColor Green
        } catch {
            Write-Host "    ⚠ Warning: Could not delete $dir" -ForegroundColor Red
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            
            # Try robocopy method as fallback (works even with locked files)
            Write-Host "    Attempting alternative deletion method..." -ForegroundColor Yellow
            $emptyDir = "$env:TEMP\empty_flutter_clean"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
            robocopy $emptyDir $dir /MIR /R:0 /W:0 /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $emptyDir -Force -ErrorAction SilentlyContinue
            
            if (-not (Test-Path $dir)) {
                Write-Host "    ✓ Deleted using alternative method" -ForegroundColor Green
            } else {
                Write-Host "    ✗ Failed to delete. Manual intervention required." -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  Skipping: $dir (not found)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Cleanup Complete!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run: flutter pub get" -ForegroundColor White
Write-Host "  2. Run: flutter build apk --debug" -ForegroundColor White
Write-Host "  3. Or run: flutter run" -ForegroundColor White
Write-Host ""
