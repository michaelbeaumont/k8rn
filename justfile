write-talosconfig outfile:
    terraform output -raw talosconfig > {{ outfile }}

write-kubeconfig outfile:
    terraform output -raw kubeconfig > {{ outfile }}

write-secrets-yaml outfile:
    terraform output -raw machine_secrets > {{ outfile }}

get-secureboot-iso node:
    wget -O {{ node }}-talos.iso `terraform output -json talos_url | jq -r '.["{{ node }}"]'`

get-upgrade-image node:
    terraform output -json talos_image | jq -r '.["{{ node }}"]'
