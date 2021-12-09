#!/usr/bin/env bash

if [[ $# != 1 ]]; then echo "Usage: ./$(basename $0) autoscaling_group_name"; exit 76; fi
asg_name=$1
policy_files='''
Additional_FIS_Grants_use_EC2_Actions.json
Grant_FIS_use_EC2_Actions.json
Permission_to_perform_FIS.json
'''
fis_rolename='FIS_EKS_ROLE'
fis_rolejson_file='assume_fis_role.json'
fis_experiment_template_file='fis_template.json'
create_role_result=$(aws iam create-role --role-name ${fis_rolename} --assume-role-policy-document file://${fis_rolejson_file})
created_role_arn=$(echo ${create_role_result} | jq -r '.Role.Arn')
launch_template_name='eksctl-uv-iguazio-eks-east-nodegroup-memory-optimized-spot'
account_id=$(aws sts get-caller-identity | jq -r '.Account')
region=$(aws configure get region)
asg_instance_ids=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name ${asg_name} | jq -r '.AutoScalingGroups[].Instances[].InstanceId')
########## get_launchtemplate_names=$(aws ec2 describe-launch-templates | jq -r '.LaunchTemplates[].LaunchTemplateName' | grep -i spot)

prepare_instance_struct(){
    if [[ $# -lt 1 ]]; then echo "Usage: ./$(basename $0) instance_object"; exit 89; fi
    local instances=("$1")
    declare -a instance_array
    for instance in ${instances}; do instance_array+=('"'arn:aws:ec2:${region}:${account_id}:instance/${instance}'",'); done
    listed_instances=$(echo ${instance_array[@]} | sed 's/,$//') && instance_array=()
    echo ${listed_instances}
}

create_fis_template() {
    if [[ $# -lt 1 ]]; then echo "Usage: ./$(basename $0) source_json_file"; exit 90; fi
    source_json_file=$1
    temp_json='json_to_post.json'
    cp ${source_json_file} ${temp_json}
    structed_in_json_instances=$(prepare_instance_struct "${asg_instance_ids}")
    sed -i "s|replace_arn_of_role|${created_role_arn}|g;s|replace_instance_ids|${structed_in_json_instances}|g" ${temp_json}
    create_fis_temp_result=$(aws fis create-experiment-template --cli-input-json file://${temp_json}) && rm -rf ${temp_json} 
}

########## Done
if [[ -n ${created_role_arn} ]]; then
    for policy_file in ${policy_files}; do
        policy_name=$(echo ${policy_file} | awk -F '.' '{ print $1 }')
        policy_create_object=$(aws iam create-policy --policy-name ${policy_name} --policy-document file://${policy_file})
        policy_arn=$(echo ${policy_create_object} | jq -r '.Policy.Arn')
        if [[ -n ${policy_arn} ]]; then 
            aws iam attach-role-policy --policy-arn ${policy_arn} --role-name ${fis_rolename}
        fi
    done
    create_fis_template ${fis_experiment_template_file}
fi

# Look at the policies attached to ${fis_rolename} role
# aws iam list-attached-role-policies --role-name ${fis_rolename}