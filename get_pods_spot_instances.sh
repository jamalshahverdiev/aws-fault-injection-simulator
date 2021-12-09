#!/usr/bin/env bash

if [[ $# != 1 ]]; then echo "Usage: ./$(basename $0) autoscaling_name"; exit 111; fi
spot_node_group_name=$1
export AWS_PROFILE=default

get_instances_inside_spot_asg() {
    asg_name=$1
    all_instances=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name ${asg_name} | jq '.AutoScalingGroups[].Instances[]')
    echo ${all_instances} | jq -r 'select(.LifecycleState=="InService")|.InstanceId'
}

collect_eks_nodes(){
    instance_ids=$(get_instances_inside_spot_asg ${spot_node_group_name})
    instance_object=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" | jq '.Reservations[].Instances[]')
    for instance_id in $instance_ids; do
        instance_private_ip=$(echo ${instance_object} | jq -r 'select(.InstanceId=="'${instance_id}'")|.PrivateIpAddress')
        # echo "Instance ID: ${instance_id} | Instance private IP: ${instance_private_ip}"
        kubectl get nodes -o wide --no-headers | grep -w ${instance_private_ip} | awk '{ print $1 }'
    done
}

get_pods_in_spot_nodes(){
    eks_node_names=$(collect_eks_nodes)
    for node_name in ${eks_node_names}; do
        kubectl get pods -n fischeck -o wide | grep ${node_name} | awk '{ print $1 }'
    done
}

get_pods_in_spot_nodes 
# collect_eks_nodes

##### Test HTTP response code of POD after signal termination handler comes
# kubectl exec -it some_of_pod_name_with_curl_installed -n kube-system bash
# for count in `seq 1000000`; do sleep 0.5; curl -o /dev/null -s -w "%{http_code}\n" http://fischeck.fischeck.svc.cluster.local:8080; done

