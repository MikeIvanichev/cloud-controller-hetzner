#!/bin/bash
script_dir="$(dirname "$(realpath "$0")")/.."

terraform output -raw talosconfig >"$script_dir/configs/talosconfig"
terraform output -raw kubeconfig >"$script_dir/configs/kubeconfig"
export TALOSCONFIG="$script_dir/configs/talosconfig"
export KUBECONFIG="$script_dir/configs/kubeconfig"
