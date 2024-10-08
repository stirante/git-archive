@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

:: git-archive: Archive and restore git branches using tags.
:: Usage: git-archive [options] <put|restore> [branch]

:: Initialize variables
SET VERBOSE=false
SET command=
SET branch=

:: Process options and arguments
:parse_options
IF "%~1"=="" GOTO after_parse_options

IF "%~1"=="-h" (
    GOTO show_help
) ELSE IF "%~1"=="--help" (
    GOTO show_help
) ELSE IF "%~1"=="-v" (
    SET VERBOSE=true
    SHIFT
    GOTO parse_options
) ELSE IF "%~1"=="--verbose" (
    SET VERBOSE=true
    SHIFT
    GOTO parse_options
) ELSE IF "%~1"=="put" (
    SET command=put
    SHIFT
    GOTO after_parse_options
) ELSE IF "%~1"=="restore" (
    SET command=restore
    SHIFT
    GOTO after_parse_options
) ELSE (
    ECHO Error: Unknown option or command '%~1'
    GOTO show_help
)

:after_parse_options

:: Check if command is provided
IF NOT DEFINED command (
    ECHO Error: No command provided.
    GOTO show_help
)

:: Get the branch name if provided
IF NOT "%~1"=="" (
    SET branch=%~1
    SHIFT
)

:: Check for extra arguments
IF NOT "%~1"=="" (
    ECHO Error: Too many arguments.
    GOTO show_help
)

:: Determine the default branch dynamically
FOR /F "tokens=3 delims=: " %%i IN ('git remote show origin ^| findstr /C:"HEAD branch"') DO (
    SET default_branch=%%i
)
SET default_branch=!default_branch:refs/remotes/origin/=!
IF "!default_branch!"=="" SET default_branch=main
IF "%VERBOSE%"=="true" ECHO Default branch is '!default_branch!'

:: Handle 'put' command
IF "%command%"=="put" (
    :: Use current branch if none specified
    IF NOT DEFINED branch (
        FOR /F "delims=" %%i IN ('git rev-parse --abbrev-ref HEAD') DO (
            SET branch=%%i
        )
    )
    IF "%VERBOSE%"=="true" ECHO Branch to archive is '!branch!'

    :: Get the current branch
    FOR /F "delims=" %%i IN ('git rev-parse --abbrev-ref HEAD') DO (
        SET current_branch=%%i
    )
    IF "%VERBOSE%"=="true" ECHO Current branch is '!current_branch!'

    :: Check if the branch to archive is the current branch
    IF "!branch!"=="!current_branch!" (
        SET is_current_branch=true
    ) ELSE (
        SET is_current_branch=false
    )

    :: Cannot archive the default branch
    IF "!branch!"=="!default_branch!" (
        ECHO Error: Cannot archive the default branch '!default_branch!'.
        EXIT /B 1
    )

    IF "%VERBOSE%"=="true" ECHO Archiving branch '!branch!'...

    :: Ensure branch exists locally
    git rev-parse --verify "!branch!" >nul 2>&1
    IF ERRORLEVEL 1 (
        IF "%VERBOSE%"=="true" ECHO Branch '!branch!' does not exist locally. Attempting to fetch from remote...
        git fetch origin "!branch!":"!branch!"
        IF ERRORLEVEL 1 (
            ECHO Error: Failed to fetch branch '!branch!' from remote.
            EXIT /B 1
        )
    )

    :: Create a tag
    git tag "archive/!branch!" "!branch!"
    git push origin "archive/!branch!"

    :: Switch to default branch if archiving current branch
    IF "!is_current_branch!"=="true" (
        IF "%VERBOSE%"=="true" ECHO Switching to default branch '!default_branch!'...
        git checkout "!default_branch!"
    )

    :: Delete the branch locally and remotely
    git branch -D "!branch!"
    git push origin --delete "!branch!"

    ECHO Branch '!branch!' has been archived and deleted.

    EXIT /B 0
)

:: Handle 'restore' command
IF "%command%"=="restore" (
    :: Branch must be specified for restore
    IF "!branch!"=="" (
        ECHO Error: Please specify the branch to restore.
        GOTO show_help
    )

    :: Cannot restore the default branch
    IF "!branch!"=="!default_branch!" (
        ECHO Error: Cannot restore the default branch '!default_branch!'.
        EXIT /B 1
    )

    IF "%VERBOSE%"=="true" ECHO Restoring branch '!branch!' from tag 'archive/!branch!'...

    :: Check if the tag exists
    git rev-parse --verify "refs/tags/archive/!branch!" >nul 2>&1
    IF ERRORLEVEL 1 (
        ECHO Error: Tag 'archive/!branch!' does not exist.
        EXIT /B 1
    )

    :: Create a new branch from the tag
    git checkout -b "!branch!" "archive/!branch!"

    :: Push the restored branch to remote
    git push origin "!branch!"

    :: Delete the tag
    git tag -d "archive/!branch!"
    git push origin ":refs/tags/archive/!branch!"

    ECHO Branch '!branch!' has been restored from tag 'archive/!branch!'.

    EXIT /B 0
)

:: Invalid command
ECHO Error: Invalid command '%command%'.
GOTO show_help

:show_help
ECHO Usage: git-archive [options] ^<put^|restore^> [branch]
ECHO.
ECHO Commands:
ECHO   put [branch]     Archive the specified branch. If no branch is specified, archives the current branch.
ECHO   restore ^<branch^> Restore the specified archived branch.
ECHO.
ECHO Options:
ECHO   -h, --help       Show this help message and exit
ECHO   -v, --verbose    Enable verbose logging
EXIT /B 1
