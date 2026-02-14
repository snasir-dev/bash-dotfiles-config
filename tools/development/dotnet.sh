#!/bin/bash

# Configuration for the .NET CLI ecosystem

# --- ENVIRONMENT VARIABLES ---
# Ensure the .NET tools are on the PATH.
# This is a best practice to avoid adding to PATH multiple times.
# --- ENVIRONMENT VARIABLES ---
# This block safely adds the .NET global tools directory to the PATH.
# It only runs if the directory exists and only adds the path if it's not already present.
if [ -d "$HOME/.dotnet/tools" ]; then
    # Check the PATH variable to see if the tools directory is already in it.
    # We wrap PATH in colons to ensure we match the exact path, not a substring.
    # For example, if PATH contains "/usr/bin:/home/user/.dotnet/tools-extra",
    # we don't want it to mistakenly match ".dotnet/tools".
    case ":$PATH:" in
        # If the exact path is already in PATH, do nothing.
        # This pattern means: if ":$PATH:" contains ":$HOME/.dotnet/tools:" anywhere in the string
        # The * is a wildcard meaning "anything before or after"
        # So "*:$HOME/.dotnet/tools:*" matches if the tools path appears anywhere in PATH
        *":$HOME/.dotnet/tools:"*)
            # This double semicolon ';;' ends the match case.
            # Since the tools path is already in PATH, we do nothing.
            ;;
        # If the path is not found, prepend it to the PATH variable.
        # This ensures .NET global tools can be run from the command line.
        # This is the "default" catch-all case: if the previous case didn't match
        # The * alone matches anything — so this block runs if the tools path was NOT found in PATH
        *)
            # We prepend the tools path to PATH so that .NET CLI tools installed globally will be usable
            export PATH="$HOME/.dotnet/tools:$PATH"

            # End of this case clause
            ;;
    esac
fi

# Check if the directory "$HOME/.dotnet/tools" exists.
# This is where global .NET tools are installed by default.
if [ -d "$HOME/.dotnet/tools" ]; then

    # Check if the PATH environment variable already includes the tools path.
    # We add colons before and after PATH to prevent partial matches.
    case ":$PATH:" in

        # If the exact path is already in PATH, do nothing.
        *":$HOME/.dotnet/tools:"*) ;;

        # If the path is not found, prepend it to the PATH variable.
        # This ensures .NET global tools can be run from the command line.
        *)
            export PATH="$HOME/.dotnet/tools:$PATH"
            ;;
    esac

fi

# --- FUNCTIONS ---
# Create a new solution and add a minimal API project to it
# Usage: newapi MyAwesomeApi
# newapi() {
#     if [ -z "$1" ]; then
#         echo "Usage: newapi <ProjectName>"
#         return 1
#     fi

#     local project_name="$1"
#     local solution_name="${project_name}Sln"

#     # Create solution and project
#     dotnet new sln -n "$solution_name"
#     dotnet new webapi -minimal -o "$project_name"

#     # Add project to solution
#     dotnet sln "$solution_name.sln" add "$project_name"

#     echo "✅ Created solution '$solution_name' with Minimal API project '$project_name'."
# }

# --- ALIASES ---
alias dn='dotnet'
alias dnb='dotnet build'
alias dnr='dotnet run'
alias dnw='dotnet watch'
alias dnt='dotnet test'
alias dnef='dotnet ef' # For Entity Framework

# --- COMPLETIONS ---
#===============================================
# .NET CLI (dotnet) Auto-Completion Script      #
#===============================================
# Official Docs: https://learn.microsoft.com/en-us/dotnet/core/tools/enable-tab-autocomplete
# This enables bash tab-completion for `dotnet` commands, subcommands, and options.
# Pre-requisite: Ensure `dotnet` is installed and in your PATH.
# You can install .NET on Windows with: winget install Microsoft.DotNet.SDK.8
# Completion script is built into the CLI via `dotnet complete`

# bash parameter completion for the dotnet CLI - Copied directly from the link above
function _dotnet_bash_complete() {
    #   local cur="${COMP_WORDS[COMP_CWORD]}" IFS=$'\n' # On Windows you may need to use use IFS=$'\r\n'
    local cur="${COMP_WORDS[COMP_CWORD]}" IFS=$'\r\n' # On Windows you may need to use use IFS=$'\r\n'
    local candidates

    read -d '' -ra candidates < <(dotnet complete --position "${COMP_POINT}" "${COMP_LINE}" 2> /dev/null)

    read -d '' -ra COMPREPLY < <(compgen -W "${candidates[*]:-}" -- "$cur")
}

complete -f -F _dotnet_bash_complete dotnet
