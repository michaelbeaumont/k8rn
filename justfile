write-talosconfig outfile:
    terraform output -raw talosconfig > {{ outfile }}

write-kubeconfig outfile:
    terraform output -raw kubeconfig > {{ outfile }}

write-secrets-yaml outfile:
    terraform output -raw machine_secrets > {{ outfile }}

get-secureboot-iso:
    wget `terraform output -raw talos_url`
