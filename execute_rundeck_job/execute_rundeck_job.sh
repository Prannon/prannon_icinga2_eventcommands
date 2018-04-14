#!/bin/bash

###GET OPTIONS
get_options() {
        #read the options from the user
        while getopts :h:s:t:a:x:u:j: opt; do
                case "${opt}" in
                        h )
                                hostname="${OPTARG}"
                                ;;
                        s )
                                service_state="${OPTARG}"
                                ;;
                        t )
                                service_state_type="${OPTARG}"
                                ;;
                        a )
                                check_attempt="${OPTARG}"
                                ;;
                        x )
                                auth_token="${OPTARG}"
                                ;;
                        u )
                                rundeck_url="${OPTARG}"
                                ;;
                        j )
                                rundeck_job_uuid="${OPTARG}"
                                ;;
                        p ) 
                                rundeck_project="${OPTARG}"
                esac
        done
        shift $((OPTIND -1))
}

###DETERMINE IF RUNDECK JOB IS ALREADY RUNNING ON THIS HOST
function check_if_already_running() {
        #define vars for function
        local host_we_care_about="${1}" #$hostname
        local auth="${2}" #$auth_token
        local rundeck="${3}" #$rundeck_url
        local job_we_care_about="${4}" #$rundeck_job_uuid
        local project="${5}" #$rundeck_project$
        local running_jobs=$(curl -H "Accept: application/json" -H "X-Rundeck-Auth-Token: ${auth}" "${rundeck}/api/14/project/${project}/executions/running" | jq .)

        #look through all running jobs
        for i in $(seq 0 $(echo ${running_jobs} | jq '.executions|length')); do
                local job_uuid=$(echo "${running_jobs}" | jq .executions[${i}].job.id)
                local job_id=$(echo "${running_jobs}" | jq .executions[${i}].id)

                #if running job uuid is what we care about, then check the node/nodes it's running against
                if [[ "${job_uuid}" =~  ${job_we_care_about} ]]; then

                        local target_nodes=$(curl -H "Accept: application/json" -H "X-Rundeck-Auth-Token: ${auth}" "${rundeck}/api/10/execution/${job_id}/state" | jq .targetNodes[])
                        local our_host_is_there=$(grep "${host_we_care_about}" <<< "${target_nodes}")

                        #exit if the job is running against the node generating the alert
                        if [[ $our_host_is_there ]]; then
                                exit 1
                        fi
                fi
        done
}

###DETERMINE IF WE'RE ON AN ALLOWED CHECK STATE
function check_if_allowed_check_state() {
        #define vars for function
        local state="${1}" #$service_state
        local attempt="${2}" #$check_attempt
        local state_type="${3}" #$service_state_type
        local attempt_regx="(1|3|5|7|9)$" #eventcommand only executes on these check attempts
        local state_regx="(CRITICAL)$" #eventcommand only executes on these check states

        #don't run if check state is something other than critical
        if ! [[ "${state}" =~ ${state_regx} ]]; then
                exit 2
        fi

        #don't run if attempt is something other than regex, but always run if state type is HARD
        if ! [[ "${attempt}" =~ ${attempt_regx} ]]; then
                if ! [[ "${state_type}" =~ "HARD" ]]; then
                        exit 3
                fi
        fi
}

###EXECUTE RUNDECK API CALL
function execute_api_call() {
        #define vars for function
        local auth="${1}" #$auth_token
        local host="${2}" #$hostname
        local url="${3}" #$rundeck_url
        local uuid="${4}" #$rundeck_job_uuid

        #make api call to rundeck
        curl -s -X POST -H "X-Rundeck-Auth-Token:${auth}" --data-urlencode "filter=name:${host}" "${url}/api/1/job/${uuid}/run"
}

###MAIN EXECUTION
get_options "${@}"
check_if_already_running "${hostname}" "${auth_token}" "${rundeck_url}" "${rundeck_job_uuid}" "${rundeck_project}"
check_if_allowed_check_state "${service_state}" "${check_attempt}" "${service_state_type}"
execute_api_call "${auth_token}" "${hostname}" "${rundeck_url}" "${rundeck_job_uuid}"
