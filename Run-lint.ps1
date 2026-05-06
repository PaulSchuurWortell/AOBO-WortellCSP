# This script runs the Super Linter process Locally.
#
# QA: Using Super-Linter Locally (before committing code)
# Super linter can also be run locally. This way checks can be done before committing or creating a (draft) pull request.
# Docker is used to run the super linter Image which is called from VS Code.
# See documentation here: https://github.com/github/super-linter/blob/master/docs/run-linter-locally.md.
# Steps:
# - Install Docker
# - Ensure WSL-2 engine is enabled in Docker settings
# - In VS Code, Terminal Window (Powershell) execute './run-lint.ps1' to lint the solution.


# If using ISE
if ($psISE) {
    $path = Split-Path -Parent $psISE.CurrentFile.FullPath
    # If Using PowerShell 3 or greater
}
elseif ($PSVersionTable.PSVersion.Major -gt 3) {
    $path = $PSScriptRoot
}

docker pull github/super-linter:latest

# Run locally in debug mode, excluding most linters
# omitted -e VALIDATE_NATURAL_LANGUAGE=false
# Verbose: add -e ACTIONS_RUNNER_DEBUG=true
# docker run -e RUN_LOCAL=true  -e VALIDATE_JSON=false -e VALIDATE_GETLEAKS=false -e VALIDATE_MARKDOWNLINT=false  -e VALIDATE_SQLFLUFF=false -e VALIDATE_JSCPD=false -e VALIDATE_YAML=false -e VALIDATE_SQL=false -e FILTER_REGEX_EXCLUDE=.*Generated/.* -v "$($path):/tmp/lint" github/super-linter

#Run locally excluding SQLFLUFF linter
# Temp solution for Bug #102250 and #102214 (Errors with SQL-Lint and SQLFLuff)
docker run -e RUN_LOCAL=true -e VALIDATE_SQLFLUFF=false -e VALIDATE_SQL=false -e FILTER_REGEX_EXCLUDE='(.*Generated/.*)|(.*Deployment-NoDevOps/.*)' -v "$($path):/tmp/lint" github/super-linter
