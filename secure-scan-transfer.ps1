# Define source and destination folder pairs to watch for new files in source folders and to move them (deletes from source) to their corresponding destination folders. 
# File moves trigger a deletion from the cloud service, removing the files from public sources where the file originated (scanners, public cloud accounts, ect).

# Follow steps 1 - 4 to setup this script. The script only requires R/W permissions for all folders in the array. Admin access is not required.

# 1. Set the account username.
$user = "user"

# 2. Select cloud service to reach its source folder(s).
$service = "My Drive" # '\My Drive\' is the path when using Google Drive for Desktop.
#$service = "DropBox" # Uncomment one cloud provider to select the correct path to its synced folders ('DropBox' is only an example and probably won't work).

# 3. Define folder pairs to listen to the source folder and automatically move all new files in it to the destination folder.
$folderPairs = @(
    # 4. Replace <source folder> and <destination folder> with the desired paths.
    @{ Source = "C:\Users\$user\$service\<source folder>"; Destination = "C:\Users\$user\<destination folder>" },
    # Paste line above to add additional folder pair lines (comma after last line is optional).
)

# Function to detect new files in source folders using a 'FileSystemWatcher' and to move new files to corresponding destination folders.
function Create-FileWatcher {
    param(
        [string]$sourcePath,       # The source folder path to monitor.
        [string]$destinationPath   # The destination folder path where files will be moved.
    )
    # Create a FileSystemWatcher object to monitor changes in the file system.
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $sourcePath                 # Set the folder to monitor.
    $watcher.Filter = "*.*"                     # Monitor all file types.
    $watcher.IncludeSubdirectories = $false     # Do not include subdirectories.
    $watcher.EnableRaisingEvents = $true        # Start listening for changes.

    # Define an action to take when a new file is detected. This action block is invoked for each file creation event.
    $action = {
        param($sender, $eventArgs)  # $sender: the source of the event (FileSystemWatcher), $eventArgs: event data.

        # Accessing source and destination paths passed via MessageData.
        # This ensures each event handler uses the correct paths despite being in a loop (closure-like behavior).
        $source = $Event.MessageData.source
        $dest = $Event.MessageData.dest
        $fileName = $eventArgs.Name  # Name of the created file.
        
        # Construct full paths for the source file and the destination file.
        $sourceFilePath = Join-Path -Path $source -ChildPath $fileName
        $destinationFilePath = Join-Path -Path $dest -ChildPath $fileName

        # Attempt to move the file from source to destination.
        try {
            Move-Item -Path $sourceFilePath -Destination $destinationFilePath -ErrorAction Stop
            Write-Host "Moved file: $fileName from $source to $dest"
        } catch {
            # Log any errors encountered during the move.
            Write-Host ("Error moving file " + $fileName +": " + $_)
        }
    }

    # Register the action as an event handler for the 'Created' event of the FileSystemWatcher.
    # MessageData is used to pass the source and destination paths to the action block.
    Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action -MessageData @{
        source = $sourcePath
        dest = $destinationPath
    }
}

# Iterate through each folder pair, creating and configuring a FileSystemWatcher for each.
foreach ($pair in $folderPairs) {
    Create-FileWatcher -sourcePath $pair.Source -destinationPath $pair.Destination
}

# Message indicating the script is actively listening for file creations in the specified source folders.
# Instructs users on how to terminate the script.
Write-Host "Listening for new files in all source folders. This Power Shell terminal can be minimized. To stop, press Ctrl+C."

# Keep the script running indefinitely, waiting for events (does not consume system resources).
# This command prevents the script from exiting so it keeps listening for file creation events.
Wait-Event
