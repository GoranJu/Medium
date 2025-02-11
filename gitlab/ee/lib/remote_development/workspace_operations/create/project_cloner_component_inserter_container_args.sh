if [ -f "%<project_cloning_successful_file>s" ];
then
  echo "Project cloning was already successful";
  exit 0;
fi
if [ -d "%<clone_dir>s" ];
then
  echo "Removing unsuccessfully cloned project directory";
  rm -rf "%<clone_dir>s";
fi
echo "Cloning project";
git clone --branch "%<project_ref>s" "%<project_url>s" "%<clone_dir>s";
exit_code=$?
if [ "${exit_code}" -eq 0 ];
then
  echo "Project cloning successful";
  touch "%<project_cloning_successful_file>s";
  echo "Updated file to indicate successful project cloning";
  exit 0;
else
  echo "Project cloning failed with exit code: ${exit_code}";
  exit "${exit_code}";
fi
