sshd_path=$(which sshd)
if [ -x "$sshd_path" ]; then
  echo "Starting sshd on port ${GL_SSH_PORT}"
  $sshd_path -D -p "${GL_SSH_PORT}" &
else
  echo "'sshd' not found in path. Not starting SSH server."
fi
"${GL_TOOLS_DIR}/init_tools.sh"
