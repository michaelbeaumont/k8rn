write-talosconfig outfile:
    terraform output -raw talosconfig > {{ outfile }}

write-kubeconfig outfile:
    #!/usr/bin/env bash
    terraform output -raw kubeconfig > {{ outfile }}
    KUBECONFIG={{ outfile }} kubectl config delete-user admin@k8rn
    KUBECONFIG={{ outfile }} kubectl config delete-context admin@k8rn
    issuer=$(terraform output -raw cluster_oidc_issuer_host)
    KUBECONFIG={{ outfile }} kubectl config set-credentials ${issuer} \
        --exec-api-version=client.authentication.k8s.io/v1 \
        --exec-interactive-mode=Never \
        --exec-command=kubectl \
        --exec-arg=oidc-login \
        --exec-arg=get-token \
        --exec-arg="--oidc-issuer-url=https://${issuer}" \
        --exec-arg="--oidc-client-id=$(terraform output -raw cluster_oidc_client_id)" \
        --exec-arg="--oidc-extra-scope=profile" \
        --exec-arg="--oidc-extra-scope=groups" \
        --exec-arg="--oidc-pkce-method=S256"
    KUBECONFIG={{ outfile }} kubectl config set-context k8rn --cluster=k8rn --user=${issuer}
    KUBECONFIG={{ outfile }} kubectl config use-context k8rn

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
