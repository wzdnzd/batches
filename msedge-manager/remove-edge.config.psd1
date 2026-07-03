@{
    # Default parent folder for backup sessions. Relative paths are resolved from the current directory.
    BackupRoot = '.\EdgeRemovalBackups'

    # Registry and scheduled-task backups are enabled by default. Set to $false to disable by default.
    # The command-line switch -NoBackup also disables backups for one run.
    BackupEnabled = $true

    # Maximum number of backup folders to keep under the backup parent folder.
    # 0 means unlimited/no automatic cleanup. Example: 5 keeps the newest 5 backup folders.
    # The command-line parameter -MaxBackups overrides this value for one run.
    MaxBackups = 2

    # Preserve per-user Edge data such as profiles, cache, AppX user data, and per-user shortcuts.
    # Equivalent to passing -SkipUserData. Command-line -SkipUserData / -SkipUserData:$false overrides this value.
    SkipUserData = $true
}
