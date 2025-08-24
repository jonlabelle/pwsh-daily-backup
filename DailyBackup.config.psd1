# DailyBackup Configuration File
#
# This file contains default settings for the DailyBackup module.
# You can modify these values to customize the behavior of the module.
#
# To use this configuration file, place it in one of these locations:
# 1. Same directory as the module: DailyBackup.config.psd1
# 2. User profile: $HOME\.dailybackup\config.psd1
# 3. System-wide: $env:ProgramData\DailyBackup\config.psd1

@{
  # Default settings
  DefaultSettings = @{
    # Default destination path for backups
    # Use '.' for current directory, or specify a full path
    DefaultDestination = '.'

    # Default number of daily backups to keep (0 = keep all)
    DefaultBackupsToKeep = 7

    # Default compression level for ZIP archives
    # Valid values: Optimal, Fastest, NoCompression, SmallestSize
    CompressionLevel = 'Optimal'

    # Whether to include hidden files and folders in backups
    IncludeHidden = $false

    # Whether to follow symbolic links
    FollowSymLinks = $false

    # Maximum file size to include in backup (in MB, 0 = no limit)
    MaxFileSizeMB = 0
  }

  # Logging settings
  Logging = @{
    # Enable logging to file
    EnableFileLogging = $true

    # Log file path (relative to destination or absolute)
    LogPath = 'DailyBackup.log'

    # Log level: Error, Warning, Information, Verbose
    LogLevel = 'Information'

    # Maximum log file size in MB before rotation
    MaxLogSizeMB = 10

    # Number of old log files to keep
    LogRetention = 5
  }

  # Performance settings
  Performance = @{
    # Enable progress reporting
    ShowProgress = $true

    # Parallel processing for multiple paths
    UseParallelProcessing = $false

    # Maximum number of parallel jobs
    MaxParallelJobs = 4

    # Buffer size for file operations (in bytes)
    BufferSize = 65536
  }

  # Exclusion patterns
  Exclusions = @{
    # File extensions to exclude (without the dot)
    ExcludeExtensions = @('tmp', 'temp', 'log', 'bak', 'old')

    # File patterns to exclude (supports wildcards)
    ExcludePatterns = @('*~', '*.swp', 'Thumbs.db', '.DS_Store')

    # Directory names to exclude
    ExcludeDirectories = @('.git', '.svn', 'node_modules', 'bin', 'obj')

    # Enable exclusion rules
    EnableExclusions = $true
  }

  # Notification settings
  Notifications = @{
    # Send email notifications on completion
    EnableEmail = $false

    # SMTP settings for email notifications
    SmtpServer = ''
    SmtpPort = 587
    SmtpUsername = ''
    SmtpPassword = ''
    SmtpUseSSL = $true

    # Email recipients
    ToAddress = @()
    FromAddress = ''

    # Send notifications only on errors
    NotifyOnErrorOnly = $true
  }

  # Advanced settings
  Advanced = @{
    # Use alternative removal method for cloud drives
    UseAlternativeRemoval = $true

    # Verify backup integrity after creation
    VerifyBackups = $false

    # Create checksums for backup files
    CreateChecksums = $false

    # Retry failed operations
    RetryCount = 3

    # Delay between retries (in seconds)
    RetryDelay = 5
  }
}
