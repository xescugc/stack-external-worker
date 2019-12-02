#!/usr/bin/env bash

if test -z "$BASH_VERSION"; then
  echo "Please run this script using bash, not sh or any other shell." >&2
  exit 1
fi

# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against
# the problem described in this blog post:
#   https://www.seancassidy.me/dont-pipe-to-your-shell.html
#   https://www.idontplaydarts.com/2016/04/detecting-curl-pipe-bash-server-side/
_() {
    set -euo pipefail

    DEBUG=${DEBUG:-0}
    STACK_BRANCH=${STACK_BRANCH:-"master"}
    VAR_LIB_DEVICE=${VAR_LIB_DEVICE:-""}
    CLOUD_PROVIDER=${CLOUD_PROVIDER:-""}

    # For backward compatibility with older deployments
    PROJECT=${PROJECT:-"cycloid-ci-workers"}
    ROLE="${ROLE:-"workers"}"
    ENV="${ENV:-"prod"}"
    STACK_NAME="${STACK_NAME:-$PROJECT}"

    cloud_signal_status() {
        local status="$1"
        if [[ ${CLOUD_PROVIDER} == "aws" ]]; then
            aws cloudformation signal-resource --stack-name ${STACK_NAME} --logical-resource-id WorkersGroup --unique-id ${AWS_UNIQUE_ID} --region ${AWS_DEFAULT_REGION} --status ${status^^}
        elif [[ ${CLOUD_PROVIDER} == "gcp" ]]; then
            gcloud beta runtime-config configs variables set "${status,,}/worker" ${status,,} --config-name ${RUNTIMECONFIG_NAME}-runtimeconfig
        fi
    }

    finish() {
        if [[ $? -eq 0 ]]; then
            echo "[startup.sh] SUCCESS"
            cloud_signal_status SUCCESS
        else
            set +e
            echo "[startup.sh] FAILURE"
            echo "[startup.sh] waiting 1min for debug purpose, create a /tmp/keeprunning file to prevent halting the instance"
            sleep 60
            if [[ -f "/tmp/keeprunning" ]]; then
                echo "[startup.sh] keeprunning"
                cloud_signal_status SUCCESS
            else
                echo "[startup.sh] halting"
                cloud_signal_status FAILURE
                halt -p
            fi
        fi
    }
    trap finish EXIT

    usage() {
        echo "Usage: $SCRIPT_NAME [-d] [-b BRANCH_NAME] [<cloud_provider>]" >&2
        echo "The <cloud_provider> argument is optional, it can be either `aws`, `azure` or `gcp`." >&2
        echo '' >&2
        echo '  -d           Debug mode.' >&2
        echo '  -b           Branch to use for the external-worker stack (default: master).' >&2
        exit 1
    }

    handle_args() {
        SCRIPT_NAME=$1
        shift

        while getopts ":deiup:" opt; do
            case $opt in
            d)
                DEBUG=1
                ;;
            b)
                STACK_BRANCH="${OPTARG}"
                ;;
            *)
                usage
                ;;
            esac
        done

        # Pass positional parameters through
        shift "$((OPTIND - 1))"

        if [[ $# -eq 1 ]] && [[ ! $1 =~ ^- ]]; then
            CLOUD_PROVIDER="$1"
        elif [[ $# -ne 0 ]]; then
            usage
        fi
    }

    handle_envvars() {
        [[ -z "${SCHEDULER_API_ADDRESS}" ]] && echo "error: SCHEDULER_API_ADDRESS envvar must be set." >&2
        [[ -z "${SCHEDULER_HOST}" ]] && echo "error: SCHEDULER_HOST envvar must be set." >&2
        [[ -z "${SCHEDULER_PORT}" ]] && echo "error: SCHEDULER_PORT envvar must be set." >&2
        [[ -z "${TSA_PUBLIC_KEY}" ]] && echo "error: TSA_PUBLIC_KEY envvar must be set." >&2
        [[ -z "${WORKER_KEY}" ]] && echo "error: WORKER_KEY envvar must be set." >&2
        [[ -z "${TEAM_ID}" ]] && echo "error: TEAM_ID envvar must be set." >&2
        [[ -z "${PROJECT}" ]] && echo "error: PROJECT envvar must be set." >&2
        [[ -z "${ENV}" ]] && echo "error: ENV envvar must be set." >&2
        [[ -z "${ROLE}" ]] && echo "error: ROLE envvar must be set." >&2

        if [[ "${CLOUD_PROVIDER}" == "gcp" ]]; then
            [[ -z "${RUNTIMECONFIG_NAME}" ]] && echo "error: RUNTIMECONFIG_NAME envvar must be set." >&2
        fi

        if [[ -z "${VAR_LIB_DEVICE}" ]]; then
            if [[ "${CLOUD_PROVIDER}" == "gcp" ]]; then
                VAR_LIB_DEVICE="/dev/disk/by-id/google-data-volume"
            elif [[ "${CLOUD_PROVIDER}" == "aws" ]]; then
                VAR_LIB_DEVICE="/dev/xvdf"
            elif [[ "${CLOUD_PROVIDER}" == "azure" ]]; then
                VAR_LIB_DEVICE="/dev/disk/azure/scsi1/lun0"
            else
                VAR_LIB_DEVICE="/dev/sda"
            fi
        fi

        if [[ ${DEBUG} == "true" ]]; then
            DEBUG=1
        else
            DEBUG=0
        fi
    }

    handle_args "$@"
    handle_envvars

    echo "### starting setup of cycloid worker"
    apt-get update
    apt-get install -y --no-install-recommends git python-setuptools curl jq

    if command -v easy_install >/dev/null 2>&1; then
        easy_install pip
    else
        apt-get install -y --no-install-recommends python-pip
    fi
    pip install -U cryptography
    pip install ansible==2.7

    if [[ "${CLOUD_PROVIDER}" == "aws" ]]; then
        pip install awscli

        # Be able to use paris region (https://github.com/boto/boto/issues/3783)
        pip install --upgrade boto
        echo '[Boto]
use_endpoint_heuristics = True' > /etc/boto.cfg

        export AWS_DEFAULT_REGION=$(curl -sL http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
        export AWS_UNIQUE_ID=$(curl -L http://169.254.169.254/latest/meta-data/instance-id)
    fi

    cd /opt/
    git clone -b ${STACK_BRANCH} https://github.com/cycloid-community-catalog/stack-external-worker
    cd stack-external-worker/ansible

    export HOME=/root
    export VERSION=${VERSION:-$(curl -sL "${SCHEDULER_API_ADDRESS}/api/v1/info" | jq -r '.version')}

    cat >> "${ENV}-worker.yml" <<EOF
concourse_version: "${VERSION}"
concourse_tsa_port: "$SCHEDULER_PORT"
concourse_tsa_host: "$SCHEDULER_HOST"
concourse_tsa_public_key: "$TSA_PUBLIC_KEY"
concourse_tsa_worker_key_base64: "$WORKER_KEY"
concourse_tsa_worker_key: "{{ concourse_tsa_worker_key_base64 | b64decode}}"
concourse_worker_team: "$TEAM_ID"
nvme_mapping_run: true
var_lib_device: ${VAR_LIB_DEVICE}
EOF

    ansible-galaxy install -r requirements.yml --force --roles-path=/etc/ansible/roles

    echo "Run packer.yml"
    ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 ansible-playbook -e role=${ROLE} -e env=${ENV} -e project=${PROJECT} --connection local packer.yml

    echo "Run external-worker.yml build steps"
    ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 ansible-playbook -e role=${ROLE} -e env=${ENV} -e project=${PROJECT} --connection local external-worker.yml --diff --skip-tags deploy,notforbuild

    echo "Run /home/admin/first-boot.yml"
    ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 ansible-playbook -e role=${ROLE} -e env=${ENV} -e project=${PROJECT} --connection local /home/admin/first-boot.yml --diff

    echo "Run external-worker.yml boot steps"
    ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 ansible-playbook -e role=${ROLE} -e env=${ENV} -e project=${PROJECT} --connection local external-worker.yml --diff --tags runatboot,notforbuild

    sleep 60 && systemctl status concourse-worker
}

# Now that we know the whole script has downloaded, run it.
_ "$0" "$@"
