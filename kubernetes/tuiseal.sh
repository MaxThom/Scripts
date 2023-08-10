#! /bin/bash

manual='
description:
  TuiSeal is an opinionated way of sealing secrets using Kubeseal for the Tui platform.

usage:
  tuiseal <command> <flags>

commands:
  opaque ::: seal a opaque type secret
  env    ::: seal an environment variable file
  tls    ::: seal a tls type secret
  help   ::: display manual

flags:
  global
    -c <context>   ::: optional. kubernetes context to use. default to active one.
    -n <namespace> ::: optional. kubernetes namespace to use. default to active one.
    -s <fullpath>  ::: optional. use custom path for kubeseal certificate. default to $HOME/.kube/tuiseal/<ctx>.pem.
    -w             ::: optional. use cluster wide sealed secret. default to namespace wide.
    -v             ::: optional. add verbose output.
  opaque
    -f ::: required. full file path of the file to be sealed.
   => eg output: sealedsecret.<filename>.<ns>.<ctx>.yaml
  env
    -f ::: required. full file path of the env file to be sealed.
   => eg output: sealedsecret.<filename>.<ns>.<ctx>.yaml
  tls
    -k ::: required. full key path of the tls key.
    -p ::: required. full certificate path of the tls certificate.
   => eg output: sealedtls.<filename>.<ns>.<ctx>.yaml

installation:
 to /usr/local/bin
   1. copy script to /usr/bin/local (sudo cp tuiseal.sh /usr/local/bin/tuiseal)
   2. adjust permission of the script to rwxr-xr-x (sudo chmod 755 /usr/local/bin/tuiseal)
   3. add /usr/bin/local to env path (export PATH=/usr/local/bin:$PATH).
   4. add kubeseal public certificates under .kube/tuiseal/<kube-context-name>.pem if needed
 to $HOME/.local/bin
   1. copy script to $HOME/.local/bin/tuiseal (cp tuiseal.sh $HOME/.local/bin/tuiseal)
   2. adjust permission of the script to rwxr-xr-x (chmod 755 $HOME/.local/bin/tuiseal)
   3. add $HOME/.local/bin to env path (export PATH=$HOME/.local/bin:$PATH).
   4. add kubeseal public certificates under .kube/tuiseal/<kube-context-name>.pem if needed

requirements:
  kubectl  ::: kubernetes binary must be installed and available globally.
               available here https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/.
  kubeseal ::: kubeseal binary must be installed and available globally.
               RocketLab maintains its own version avaiable here https://nexus.rocketlab.global/repository/raw-rl-it/kubeseal/kubeseal.

sealing certificates:
  sealing certificates are managed by tuiseal. they are downloaded from the cluster using the kubeseal utility.
  their download path is $HOME/.kube/tuiseal/<ctx_name>.pem
  if you dont have user cluster access to the kubeseal project inside kubernetes. you can place the certificates manually in that folder
'

set -e

# command and global args
command=""
global_kube_ctx="$(kubectl config view --minify -o jsonpath='{..current-context}')"
global_kube_ns=""
global_seal_scope="namespace"
global_seal_cert="" #"$HOME/.kube/tuiseal/$global_kube_ctx.pem"
global_seal_cert_default=0

# opaque args
opaque_file=""

# tls args
tls_certificate=""
tls_key=""

display_manual () {
    print_color "[37m" "manual";
    echo "$manual"
}

get_args () {
    # colon after flags mean the flag need an arg.
    while getopts c:n:f:k:p:s:wv flag
    do
        case "${flag}" in
            c) global_kube_ctx=${OPTARG};;
            n) global_kube_ns=${OPTARG};;
            w) global_seal_scope="cluster";;
            s)
                global_seal_cert=${OPTARG}
                global_seal_cert_default=1
            ;;
            f) opaque_file=${OPTARG};;
            p) tls_certificate=${OPTARG};;
            k) tls_key=${OPTARG};;
            v) set -x;;
            *) exit 1
            ;;
        esac
    done
}

verify_command_and_args () {
    command=$1
    args_check_error=0
    case "${command}" in
        "opaque")
            if [[ -z $opaque_file ]];
            then
                print_color "[31m" "err: missing path argument for opaque command. -f <path_to_file>"
                (( ++args_check_error ))
            fi
            if [[ ! -r $opaque_file && -n $opaque_file ]];
            then
                print_color "[31m" "err: the file to seal does not exist or cant be read. -f $opaque_file"
                (( ++args_check_error ))
            fi
            ;;
        "env")
            if [[ -z $opaque_file ]];
            then
                print_color "[31m" "err: missing path argument for env command. -f <path_to_file>"
                (( ++args_check_error ))
            fi
            if [[ ! -r $opaque_file && -n $opaque_file ]];
            then
                print_color "[31m" "err: the file to seal does not exist or cant be read. -f $opaque_file"
                (( ++args_check_error ))
            fi
            ;;
        "tls")
            if [[ -z $tls_certificate ]];
            then
                print_color "[31m" "err: missing certificate argument for tls command. -p <path_to_certificate>"
                (( ++args_check_error ))
            fi
            if [[ -z $tls_key ]];
            then
                print_color "[31m" "err: missing key argument for tls command. -k <path_to_key>"
                (( ++args_check_error ))
            fi
            if [[ ! -r $tls_certificate && -n $tls_certificate ]];
            then
                print_color "[31m" "err: the certificate to seal does not exist or cant be read. -p $tls_certificate"
                (( ++args_check_error ))
            fi
            if [[ ! -r $tls_key && -n $tls_key ]];
            then
                print_color "[31m" "err: the key to seal does not exist or cant be read. -k $tls_key"
                (( ++args_check_error ))
            fi
            ;;
        "help")
            display_manual
            exit 1
            ;;
        *)  print_color "[31m" "err: \"${command}\" command not found."
            print_color "[33m" "=> use 'help' command to see available commands and options"
            exit 1
           ;;
    esac

    # Evaluate namespace
    if [[ -z $global_kube_ns ]];
    then
        global_kube_ns="$(kubectl config view -o jsonpath='{.contexts[?(@.name == "'"$global_kube_ctx"'")].context.namespace}')"
    fi

    # Evaluate and verify kubeseal cert path
    if [[ $global_seal_cert_default -eq 0 ]];
    then
        global_seal_cert="$HOME/.kube/tuiseal/$global_kube_ctx.pem"
    elif [[ $global_seal_cert_default -ne 0 && ! -r $global_seal_cert ]];
    then
        print_color "[31m" "err: the kubeseal certificate does not exist or cant be read. -s $global_seal_cert"
        (( ++args_check_error ))
    fi

    # TODO: verify if kube context exist
    #echo $(kubectl config get-contexts --no-headers $global_kube_ctx | grep 'error')
    #echo $?
    #if [[ $(kubectl config get-contexts --no-headers $global_kube_ctx)  =~ "error" ]]; then
    #    echo "Command failed"
    #else
    #    echo "Command succeded"
    #fi

    # TODO: verify if kube namespace exist

    if [[ args_check_error -ne 0 ]];
    then
        print_color "[33m" "=> use 'help' command to see available commands and options"
        exit 1
    fi
}

display_command_and_args () {
    print_color "[37m" "context";
    echo "  cluster:   $global_kube_ctx"
    echo "  namespace: $global_kube_ns"
    echo "  seal cert: $global_seal_cert" #$(get_kubeseal_certificate_path)" # $global_seal_cert
    print_color "[37m" "secret";
    echo "  scope:     $global_seal_scope"
    echo "  type:      $command"

    case "${command}" in
        "opaque")
            echo "  file path: $opaque_file"
            ;;
        "env")
            echo "  file path: $opaque_file"
            ;;
        "tls")
            echo "  cert:      $tls_certificate"
            echo "  key:       $tls_key"
            ;;
        *)  echo "err: \"${command}\" command not found."
            print_color "[33m" "=> use 'help' command to see available commands and options"
            exit 1
           ;;
    esac
}

get_kubeseal_certificate_path () {
    if [[ $global_seal_cert_default ]];
    then
        echo "$HOME/.kube/tuiseal/$global_kube_ctx.pem"
    else
        echo "$global_seal_cert"
    fi
}

get_kubeseal_certificate () {
    if [[ ! -r $global_seal_cert && $global_seal_cert_default -eq 0 ]];
    then
        #echo "err: the kubeseal certificate does not exist or cant be read. -s $global_seal_cert"
        mkdir -p "$HOME"/.kube/tuiseal
        kubeseal --context "$global_kube_ctx" --controller-name sealed-secrets --fetch-cert > "$global_seal_cert"
    fi

}

seal_secret () {
    local scope_arg
    if [[ $global_seal_scope == "cluster" ]];
    then
        scope_arg="--scope cluster-wide"
    fi

    echo "$1" | kubeseal --cert "$global_seal_cert" $scope_arg --format yaml > "$2"
}

#Black        [0;30m     Dark Gray     [1;30m
#Red          [0;31m     Light Red     [1;31m
#Green        [0;32m     Light Green   [1;32m
#Brown/Orange [0;33m     Yellow        [1;33m
#Blue         [0;34m     Light Blue    [1;34m
#Purple       [0;35m     Light Purple  [1;35m
#Cyan         [0;36m     Light Cyan    [1;36m
#Light Gray   [0;37m     White         [1;37m
print_color() {
    echo -e "\033$1$2\033[0m"
}

print_color "[34m" "---";
print_color "[34m" "TuiSeal !";
print_color "[34m" "---";

get_args "${@:2}"
verify_command_and_args "$@"
display_command_and_args

get_kubeseal_certificate

print_color "[34m" "---";
case "${command}" in
    "opaque")
        secret_file_name=$(basename "${opaque_file%.*}")
        secret_content="$(<"$opaque_file")"
        secret_name="sealedsecret"
        ;;
    "tls")
        secret_file_name=$(basename "${tls_certificate%.*}")
        secret_content="$(kubectl create secret tls "$secret_file_name"-"$global_kube_ns"-"$global_kube_ctx" --namespace "$global_kube_ns" --key "$tls_key" --cert "$tls_certificate" --dry-run=client --output yaml)"
        secret_name="sealedtls"
        ;;
    "env")
        secret_file_name=$(basename "${opaque_file%.*}")
        secret_content="$(kubectl create secret generic "$secret_file_name"-"$global_kube_ns"-"$global_kube_ctx" --namespace "$global_kube_ns" --dry-run=client --output yaml --from-env-file ${opaque_file})"
        secret_name="sealedsecret"
        ;;
    *)  echo "err: \"${command}\" command not found."
        print_color "[33m" "=> use 'help' command to see available commands and options"
        exit 1
        ;;
esac

secret_name+=".$secret_file_name.$global_kube_ns.$global_kube_ctx.yaml"
seal_secret "$secret_content" "$secret_name"

print_color "[37m" "secret sealed";
print_color "[32m" "  => $secret_name"

print_color "[34m" "---";
print_color "[34m" "Au revoir 🚀 !";
exit 0
