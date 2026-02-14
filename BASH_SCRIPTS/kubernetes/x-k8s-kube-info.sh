#!/bin/bash
# This is the shebang line, telling the system to execute this script with bash.

# When running scripts, it will execute in a new shell, which by default will not automatically source the .bashrc file which contains the functions we defined. To use the functions in the script, we need to source the functions file. We can do this by adding the following line to the script:
source "$BASH_DIR/functions/_general-functions.sh"

echo -e "Running script: x-k8s-kube-info.sh \n"

# Print Kube Cluster Information
echo "Printing Kube Cluster Information"
print_command_output "kubectl cluster-info"
print_command_output "kubectl config current-context"
print_command_output "kubectl config get-clusters"
print_command_output "kubectl config get-contexts"
print_command_output "kubectl config get-users"
