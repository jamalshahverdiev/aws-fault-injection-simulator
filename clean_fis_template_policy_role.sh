#!/usr/bin/env bash

policy_files='''
Additional_FIS_Grants_use_EC2_Actions.json
Grant_FIS_use_EC2_Actions.json
Permission_to_perform_FIS.json
'''
fis_template_name='Spot_EKS_FIS_Experiment'
fis_rolename='FIS_EKS_ROLE'
aws_iam_all_policies_object=$(aws iam list-policies | jq '.Policies[]')
get_fis_template_id=$(aws fis list-experiment-templates | jq -r 'select(.experimentTemplates[].tags.Name=="'${fis_template_name}'")|.experimentTemplates[].id')

delete_fis_result=$(aws fis delete-experiment-template --id ${get_fis_template_id})
if [[ $(echo ${delete_fis_result} | jq -r '.experimentTemplate.id') == ${get_fis_template_id} ]]; then
    for policy_name in ${policy_files}; do
        name=$(echo ${policy_name} | awk -F '.' '{ print $1 }')
        policy_arn=$(echo ${aws_iam_all_policies_object} | jq -r 'select(.PolicyName=="'${name}'")|.Arn')
        aws iam detach-role-policy --role-name ${fis_rolename} --policy-arn ${policy_arn}
        aws iam delete-policy --policy-arn ${policy_arn}
    done
    # get_instance_profile_name=$(aws iam list-instance-profiles-for-role --role-name ${fis_rolename} | jq -r '.InstanceProfiles[].InstanceProfileName')
    # aws iam remove-role-from-instance-profile --role-name ${fis_rolename} --instance-profile-name ${get_instance_profile_name}
    aws iam delete-role --role-name ${fis_rolename}
fi

# aws iam list-instance-profiles-for-role --role-name FIS_EKS_ROLE | jq -r '.InstanceProfiles[].Arn'
# aws ec2 describe-instances | jq -r '.Reservations[].Instances[].IamInstanceProfile.Arn'
