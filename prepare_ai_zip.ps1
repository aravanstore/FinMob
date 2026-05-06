# Script to create a lightweight ZIP for AI debugging
# It excludes heavy dependency folders and build artifacts

$zipName = "FinMob_Source_Code.zip"
$rootPath = Get-Location

Write-Host "Creating $zipName..." -ForegroundColor Cyan

# Define folders to exclude
$excludeFolders = @(
    "node_modules",
    ".dart_tool",
    "build",
    ".idea",
    ".vscode",
    ".git",
    "ios/Pods",
    "android/.gradle",
    "android/app/build",
    "windows/flutter"
)

# Define file patterns to exclude
$excludeFilePatterns = @(
    "*.log",
    "*.apk",
    "*.exe",
    "*.zip",
    "*.7z",
    "*.rar"
)

# Collect files
$files = Get-ChildItem -Path $rootPath -Recurse -File | Where-Object {
    $relativePath = $_.FullName.Substring($rootPath.Path.Length + 1)
    
    $shouldExclude = $false
    
    # Check folders
    foreach ($folder in $excludeFolders) {
        if ($relativePath -like "$folder\*" -or $relativePath -eq $folder -or $relativePath -like "*\$folder\*") {
            $shouldExclude = $true
            break
        }
    }
    
    if ($shouldExclude) { return $false }
    
    # Check file patterns
    foreach ($pattern in $excludeFilePatterns) {
        if ($_.Name -like $pattern) {
            $shouldExclude = $true
            break
        }
    }
    
    !$shouldExclude
}

Write-Host "Found $($files.Count) files to include." -ForegroundColor Green

if (Test-Path $zipName) {
    Remove-Item $zipName -Force
}

# Use Compress-Archive
# Note: Compress-Archive can be flaky with many files, but for source code it's usually fine.
Compress-Archive -Path $files.FullName -DestinationPath $zipName -Force

Write-Host "Done! ZIP file created: $zipName" -ForegroundColor Yellow
Write-Host "You can now send this file to the AI." -ForegroundColor Green
