write-talosconfig outfile:
    terraform output -raw talosconfig > {{ outfile }}

write-kubeconfig outfile:
    terraform output -raw kubeconfig > {{ outfile }}

write-secrets-yaml outfile:
    terraform output -raw machine_secrets > {{ outfile }}

generate-iso-urls:
    terraform apply -target module.infra.data.talos_image_factory_urls.this

get-secureboot-iso node:
    wget -O "{{ justfile_directory() }}/disk-images/{{ node }}-talos.iso" `terraform output -json talos_url | jq -r '.["{{ node }}"]'`

get-upgrade-image node:
    terraform output -json talos_image | jq -r '.["{{ node }}"]'

upgrade-node node:
    talosctl --talosconfig "{{ justfile_directory() }}/talosconfig" upgrade -n "{{ node }}" --stage --debug -i "$(just get-upgrade-image {{ node }})"
