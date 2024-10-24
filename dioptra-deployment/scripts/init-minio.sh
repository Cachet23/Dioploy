#!/usr/bin/env bash
# This Software (Dioptra) is being made available as a public service by the
# National Institute of Standards and Technology (NIST), an Agency of the United
# States Department of Commerce. This software was developed in part by employees of
# NIST and in part by NIST contractors. Copyright in portions of this software that
# were developed by NIST contractors has been licensed or assigned to NIST. Pursuant
# to Title 17 United States Code Section 105, works of NIST employees are not
# subject to copyright protection in the United States. However, NIST may hold
# international copyright in software created by its employees and domestic
# copyright (or licensing rights) in portions of software that were assigned or
# licensed to NIST. To the extent that NIST holds copyright in this software, it is
# being made available under the Creative Commons Attribution 4.0 International
# license (CC BY 4.0). The disclaimers of the CC BY 4.0 license apply to all parts
# of the software developed or licensed by NIST.
#
# ACCESS THE FULL CC BY 4.0 LICENSE HERE:
# https://creativecommons.org/licenses/by/4.0/legalcode

shopt -s extglob
set -euo pipefail ${DEBUG:+-x}

###########################################################################################
# Global parameters
###########################################################################################

INIT_REPOS_DIR="/init-repos"
LOGNAME="Init MinIO"
MINIO_ENDPOINT_ALIAS="minio"
SECRETS_DIR="/secrets"
S3_POLICY_DIR="/s3-policy"

MINIO_MLFLOW_TRACKING_USER=""
MINIO_MLFLOW_TRACKING_PASSWORD=""
MINIO_MLFLOW_TRACKING_POLICIES=""
MINIO_RESTAPI_USER=""
MINIO_RESTAPI_PASSWORD=""
MINIO_RESTAPI_POLICIES=""
MINIO_WORKER_USER=""
MINIO_WORKER_PASSWORD=""
MINIO_WORKER_POLICIES=""
MINIO_ROOT_USER=""
MINIO_ROOT_PASSWORD=""

# NOTE: Mutable global variable
policies_reduced=()

###########################################################################################
# Print the script help message
#
# Globals:
#   SCRIPT_CMDNAME
# Arguments:
#   Error messages to log, a string
# Returns:
#   None
###########################################################################################

print_help() {
  cat <<-HELPMESSAGE
		Utility that configures the MinIO accounts and policies.

		Usage: init-minio.sh [-h|--help]
		        -h, --help: Prints help
	HELPMESSAGE
}

###########################################################################################
# Print an error log message to stderr
#
# Globals:
#   LOGNAME
# Arguments:
#   Error messages to log, one or more strings
# Returns:
#   None
###########################################################################################

log_error() {
  echo "${LOGNAME}: ERROR -" "${@}" 1>&2
}

###########################################################################################
# Print an informational log message to stdout
#
# Globals:
#   LOGNAME
# Arguments:
#   Info messages to log, one or more strings
# Returns:
#   None
###########################################################################################

log_info() {
  echo "${LOGNAME}: INFO -" "${@}"
}

###########################################################################################
# Parse the script arguments
#
# Globals:
#   None
# Arguments:
#   Script arguments, an array
# Returns:
#   None
###########################################################################################

parse_args() {
  while (("${#}" > 0)); do
    case "${1}" in
      -h | --help)
        print_help
        exit 0
        ;;
      *)
        log_error "Unrecognized argument ${1}, exiting..."
        exit 1
        ;;
    esac
  done
}

###########################################################################################
# Load account credentials into environment variables
#
# Globals:
#   MINIO_MLFLOW_TRACKING_USER
#   MINIO_MLFLOW_TRACKING_PASSWORD
#   MINIO_MLFLOW_TRACKING_POLICIES
#   MINIO_RESTAPI_USER
#   MINIO_RESTAPI_PASSWORD
#   MINIO_RESTAPI_POLICIES
#   MINIO_WORKER_USER
#   MINIO_WORKER_PASSWORD
#   MINIO_WORKER_POLICIES
#   MINIO_ROOT_USER
#   MINIO_ROOT_PASSWORD
#   SECRETS_DIR
# Arguments:
#   None
# Returns:
#   None
###########################################################################################

load_account_creds() {
  while IFS="=" read -r key value; do
    case "${key}" in
      "MINIO_MLFLOW_TRACKING_USER") MINIO_MLFLOW_TRACKING_USER="$value" ;;
      "MINIO_MLFLOW_TRACKING_PASSWORD") MINIO_MLFLOW_TRACKING_PASSWORD="$value" ;;
      "MINIO_MLFLOW_TRACKING_POLICIES") MINIO_MLFLOW_TRACKING_POLICIES="$value" ;;
      "MINIO_RESTAPI_USER") MINIO_RESTAPI_USER="$value" ;;
      "MINIO_RESTAPI_PASSWORD") MINIO_RESTAPI_PASSWORD="$value" ;;
      "MINIO_RESTAPI_POLICIES") MINIO_RESTAPI_POLICIES="$value" ;;
      "MINIO_WORKER_USER") MINIO_WORKER_USER="$value" ;;
      "MINIO_WORKER_PASSWORD") MINIO_WORKER_PASSWORD="$value" ;;
      "MINIO_WORKER_POLICIES") MINIO_WORKER_POLICIES="$value" ;;
      "MINIO_ROOT_USER") MINIO_ROOT_USER="$value" ;;
      "MINIO_ROOT_PASSWORD") MINIO_ROOT_PASSWORD="$value" ;;
    esac
  done < "${SECRETS_DIR}/dioptra-deployment-minio-accounts.env"
}

###########################################################################################
# Configure alias for accessing the MinIO endpoint
#
# Globals:
#   MINIO_ENDPOINT_ALIAS
#   MINIO_ROOT_USER
#   MINIO_ROOT_PASSWORD
# Arguments:
#   None
# Returns:
#   None
###########################################################################################

set_minio_alias() {
  mc alias set \
    "${MINIO_ENDPOINT_ALIAS}" \
    "http://dioptra-deployment-minio:9000" \
    "${MINIO_ROOT_USER}" \
    "${MINIO_ROOT_PASSWORD}"
}

###########################################################################################
# Create the plugins, workflow, and mlflow-tracking buckets
#
# Globals:
#   MINIO_ENDPOINT_ALIAS
# Arguments:
#   None
# Returns:
#   None
###########################################################################################

create_buckets() {
  mc mb --p \
    "${MINIO_ENDPOINT_ALIAS}/plugins" \
    "${MINIO_ENDPOINT_ALIAS}/workflow" \
    "${MINIO_ENDPOINT_ALIAS}/mlflow-tracking"
}

###########################################################################################
# Create the MinIO accounts
#
# Globals:
#   MINIO_ENDPOINT_ALIAS
#   MINIO_MLFLOW_TRACKING_USER
#   MINIO_MLFLOW_TRACKING_PASSWORD
#   MINIO_RESTAPI_USER
#   MINIO_RESTAPI_PASSWORD
#   MINIO_WORKER_USER
#   MINIO_WORKER_PASSWORD
# Arguments:
#   None
# Returns:
#   None
###########################################################################################

create_minio_accounts() {
  mc admin user add \
    "${MINIO_ENDPOINT_ALIAS}" "${MINIO_MLFLOW_TRACKING_USER}" \
    "${MINIO_MLFLOW_TRACKING_PASSWORD}"

  mc admin user add \
    "${MINIO_ENDPOINT_ALIAS}" "${MINIO_RESTAPI_USER}" \
    "${MINIO_RESTAPI_PASSWORD}"

  mc admin user add \
    "${MINIO_ENDPOINT_ALIAS}" "${MINIO_WORKER_USER}" \
    "${MINIO_WORKER_PASSWORD}"
}

###########################################################################################
# Create MinIO access policies
#
# Globals:
#   MINIO_ENDPOINT_ALIAS
#   S3_POLICY_DIR
# Arguments:
#   None
# Returns:
#   None
###########################################################################################

create_minio_policies() {
  mc admin policy create \
    "${MINIO_ENDPOINT_ALIAS}" "builtin-plugins-readonly" "${S3_POLICY_DIR}/builtin-plugins-readonly-policy.json"

  mc admin policy create \
    "${MINIO_ENDPOINT_ALIAS}" "builtin-plugins-readwrite" "${S3_POLICY_DIR}/builtin-plugins-readwrite-policy.json"

  mc admin policy create \
    "${MINIO_ENDPOINT_ALIAS}" "custom-plugins-readonly" "${S3_POLICY_DIR}/custom-plugins-readonly-policy.json"

  mc admin policy create \
    "${MINIO_ENDPOINT_ALIAS}" "custom-plugins-readwrite" "${S3_POLICY_DIR}/custom-plugins-readwrite-policy.json"

  mc admin policy create \
    "${MINIO_ENDPOINT_ALIAS}" "dioptra-readonly" "${S3_POLICY_DIR}/dioptra-readonly-policy.json"

  mc admin policy create \
    "${MINIO_ENDPOINT_ALIAS}" "mlflow-tracking-readwrite" "${S3_POLICY_DIR}/mlflow-tracking-readwrite-policy.json"

  mc admin policy create \
    "${MINIO_ENDPOINT_ALIAS}" "plugins-readonly" "${S3_POLICY_DIR}/plugins-readonly-policy.json"

  mc admin policy create \
    "${MINIO_ENDPOINT_ALIAS}" "workflow-downloadonly" "${S3_POLICY_DIR}/workflow-downloadonly-policy.json"

  mc admin policy create \
    "${MINIO_ENDPOINT_ALIAS}" "workflow-uploadonly" "${S3_POLICY_DIR}/workflow-uploadonly-policy.json"
}

###########################################################################################
# Remove elements from a comma-separated list
#
# Globals:
#   LOGNAME
# Arguments:
#   Input list, a comma-separated string
#   Elements to match and delete, a comma-separated string
# Returns:
#   List with elements removed, a comma-separated string
###########################################################################################

remove_elements_from_comma_delimited() {
  local input_list="${1}"
  local elements_to_delete="${2}"
  local merged_list="$input_list,$elements_to_delete"
  local updated_list_newline_sep=$(echo "${merged_list//,/$'\n'}" | sort | uniq -u)
  local updated_list_comma_sep="${updated_list_newline_sep//$'\n'/,}"
  echo "${updated_list_comma_sep}"
}

###########################################################################################
# Set the policies to attach in global policies_reduced after deduplicating repeat policies
#
# Globals:
#   LOGNAME
#   policies_reduced
# Arguments:
#   The current list of policy to user mappings, an array
#   The target policies for a user
#   The target user
# Returns:
#   None
###########################################################################################

remove_repeat_policies() {
  local name=$1[@]
  local policies=$2
  local user=$3
  local lines=("${!name}")

  local found_policy=false
  local reading_users=false
  local select_policy=""

  # lines contains a policy -> user mapping
  for i in "${lines[@]}"; do
    # is this line of the input indicating a policy?
    if grep -q "  Policy: " <<<"$i"; then
      # since we found a new policy, do not search for users anymore
      found_policy=false
      reading_users=false
      select_policy=""
      # is this policy one of the ones we are trying to add?
      for policy in $(echo "${policies}" | sed -n 1'p' | tr ',' '\n'); do
        if [[ "  Policy: ${policy}" == $i ]]; then
          # the next few lines will be a list of users
          found_policy=true
          #save the policy so we know to remove it if necessary
          select_policy="${policy}"
        fi
      done
      continue # continue to next line of input
    fi

    if [ "${found_policy}" = true ]; then
      if [[ "    User Mappings:" == "$i" ]]; then
        # this indicates the start of a list of users
        reading_users=true
        continue # continue to next line of input
      fi
    fi

    if [ "${reading_users}" = true ] && [ "${found_policy}" = true ]; then
      if [[ $(echo "$i" | sed 's/^ *//g' | sed 's/ *$//g') == "$user" ]]; then
        # the user already has this policy! remove it from the list of policies
        policies=$(remove_elements_from_comma_delimited $policies $select_policy)
      fi
    fi
  done

  # policies should not be comma separated
  local policies_newline_sep=$(echo "$policies" | sed -e "s/,/\n/g")
  if [ ! -z "${policies_newline_sep}" ]; then
    IFS=$'\n' read -r -d '' -a policies_reduced < <( echo "${policies_newline_sep}" && printf '\0' )
  fi
}

###########################################################################################
# Attach MinIO policies to user accounts
#
# Globals:
#   MINIO_ENDPOINT_ALIAS
#   MINIO_MLFLOW_TRACKING_USER
#   MINIO_MLFLOW_TRACKING_POLICIES
#   MINIO_RESTAPI_USER
#   MINIO_RESTAPI_POLICIES
#   MINIO_WORKER_USER
#   MINIO_WORKER_POLICIES
# Arguments:
#   None
# Returns:
#   None
###########################################################################################

attach_minio_policies() {
  local attached_policies=()

  IFS=$'\n' read -r -d '' -a attached_policies < <( mc admin policy entities ${MINIO_ENDPOINT_ALIAS} && printf '\0' )

  remove_repeat_policies attached_policies \
    "${MINIO_MLFLOW_TRACKING_POLICIES}" "${MINIO_MLFLOW_TRACKING_USER}"

  if [[ ! -z "${policies_reduced[@]}" ]]; then
    mc admin policy attach \
      "${MINIO_ENDPOINT_ALIAS}" \
      "${policies_reduced[@]}" \
      --user="${MINIO_MLFLOW_TRACKING_USER}"
  fi

  remove_repeat_policies attached_policies \
    "${MINIO_RESTAPI_POLICIES}" "${MINIO_RESTAPI_USER}"

  if [[ ! -z "${policies_reduced[@]}" ]]; then
    mc admin policy attach \
      "${MINIO_ENDPOINT_ALIAS}" \
      "${policies_reduced[@]}" \
      --user="${MINIO_RESTAPI_USER}"
  fi

  remove_repeat_policies attached_policies \
    "${MINIO_WORKER_POLICIES}" "${MINIO_WORKER_USER}"

  if [[ ! -z "${policies_reduced[@]}" ]]; then
    mc admin policy attach \
      "${MINIO_ENDPOINT_ALIAS}" \
      "${policies_reduced[@]}" \
      --user="${MINIO_WORKER_USER}"
  fi
}

###########################################################################################
# The top-level function in the script
#
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
###########################################################################################

main() {
  parse_args "${@}"
  load_account_creds
  set_minio_alias
  create_buckets
  create_minio_accounts
  create_minio_policies
  attach_minio_policies
}

###########################################################################################
# Main script
###########################################################################################

main "${@}"
