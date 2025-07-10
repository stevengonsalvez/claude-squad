#!/bin/bash
# ABOUTME: Script to install MCP servers from configuration file
# ABOUTME: Reads mcp-servers.txt and executes claude mcp add commands with environment variable substitution

set -e

MCP_CONFIG_FILE="/app/mcp-servers.txt"

if [ ! -f "$MCP_CONFIG_FILE" ]; then
    echo "MCP config file not found: $MCP_CONFIG_FILE"
    exit 0
fi

echo "Installing MCP servers from $MCP_CONFIG_FILE"

# Function to check if all required environment variables for a command are set
check_env_vars() {
    local command="$1"
    local missing_vars=""
    
    # Extract environment variable references (${VAR_NAME} format)
    local env_vars=$(echo "$command" | grep -o '\${[^}]*}' | sed 's/\${//g' | sed 's/}//g' | sort -u)
    
    for var in $env_vars; do
        if [ -z "${!var}" ]; then
            missing_vars="$missing_vars $var"
        fi
    done
    
    if [ -n "$missing_vars" ]; then
        echo "  ⚠️  Skipping due to missing environment variables:$missing_vars"
        return 1
    fi
    
    return 0
}

# Function to substitute environment variables in command
substitute_env_vars() {
    local command="$1"
    
    # Use envsubst to replace ${VAR_NAME} with actual values
    echo "$command" | envsubst
}

# Read and process each line
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    echo "Processing: $line"
    
    # Check if all required environment variables are set
    if check_env_vars "$line"; then
        # Substitute environment variables
        processed_command=$(substitute_env_vars "$line")
        echo "  Executing: $processed_command"
        
        # Execute the command
        if eval "$processed_command"; then
            echo "  ✓ Successfully installed"
        else
            echo "  ✗ Failed to install (exit code: $?)"
        fi
    fi
    
    echo ""
done < "$MCP_CONFIG_FILE"

echo "MCP server installation complete"