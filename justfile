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

upgrade-node-cache node image-cache-host:
    talosctl --talosconfig "{{ justfile_directory() }}/talosconfig" upgrade -n "{{ node }}" --stage --debug -i "{{ image-cache-host }}$(terraform output -json talos_image_cache | jq -r '.["{{ node }}"]')"

image-cache-serve image-cache-host:
    talosctl images cache-create --force --layout=flat --image-cache-path=/tmp/image-cache \
        --images=$(terraform output -json talos_image | jq -r '[to_entries[].value] | join(",")')
    talosctl image cache-serve --image-cache-path=/tmp/image-cache --address={{ image-cache-host }} \
        --tls-cert-file=<(terraform output -json image_cache_serve_cert | jq -r '.crt') \
        --tls-key-file=<(terraform output -json image_cache_serve_cert | jq -r '.key')
