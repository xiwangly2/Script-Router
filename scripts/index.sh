#!/bin/sh

# Check if curl or wget is installed on the system
if command -v curl >/dev/null 2>&1; then
  # Use curl to fetch the script from the remote
  download_command="curl -sSo"
elif command -v wget >/dev/null 2>&1; then
  # Use wget to fetch the script from the remote
  download_command="wget -qO"
elif command -v fetch >/dev/null 2>&1; then
  # Use fetch to fetch the script from the remote
  download_command="fetch -o"
elif command -v axel >/dev/null 2>&1; then
  # Use axel to fetch the script from the remote
  download_command="axel -o"
else
  echo "Unable to fetch the script. curl or wget is not installed on the system."
  exit 1
fi

# Check if the shell is bash or zsh or others
if [ -n "$BASH_VERSION" ]; then
  # Bash specific code
  # It is recommended to use the command 'bash <(curl -sSL vs8.top)' to execute directly.
  shell_name="main.bash"
elif [ -n "$ZSH_VERSION" ]; then
  # Zsh specific code
  # It is recommended to use the command 'zsh <(curl -sSL vs8.top)' to execute directly.
  shell_name="main.zsh"
elif [ -n "$FISH_VERSION" ]; then
  # Fish specific code
  # It is recommended to use the command 'fish <(curl -sSL vs8.top)' to execute directly.
  # TODO: Add fish script
  shell_name="main.fish"
else
  echo "Unsupported shell. Please use bash or zsh."
  exit 1
fi

# Download the script
tmp_script=$(mktemp)
if ! $download_command "$tmp_script" "http://vs8.top/scripts/$shell_name"; then
  echo "Failed to download the script."
  rm "$tmp_script"
  exit 1
fi

tr -d '\r' < "$tmp_script" > "$tmp_script.tmp" && mv "$tmp_script.tmp" "$tmp_script"
# Make the script executable
chmod +x "$tmp_script"

# Execute the script with the appropriate shell
"$SHELL" "$tmp_script"

# Clean up the temporary script file
rm "$tmp_script"
