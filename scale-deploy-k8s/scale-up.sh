#!/bin/bash
#
# @title       Scale Up Deploy
# @description Script de scale up de deployments no Kubernetes. Que ira ser executado as 07:00 de seg a sex.
# @author      Danilo de Souza Lopes 
# @licence     Copyright (C) All Rights Reserved
#
# @requires    bash v4+, crie o diretorio log no mesmo diretorio do script.
# @version     2.2
# @crontab     05 10 * * 1-5 /home/ssm-user/k8s-scale-programs/scale-up.sh >/dev/null 2>&1

applicationName=$(basename $BASH_SOURCE)
log_directory=("/var/log/k8s-scale-programs")
day=$(date +"%F"_"%k:%M")

exec > >(tee -a $log_directory/$applicationName-${day}.log)

declare -a namespaces=("hml")
declare -a deploysAtTime=5

checkLogDirectory() {
    for dir in ${log_directory}; do
        if [ -d $dir ]; then
            continue
        else
            mkdir $dir
        fi
    done
}

validateKubeconfig(){
    if [ -z $KUBECONFIG ]; then
        echo "Assumindo o kubeconfig:"
        KUBECONFIG="/home/ssm-user/my_kubeconfig_eks-unihs1001-vg"

        echo $KUBECONFIG
        echo ""

    else
        echo "Assumindo o kubeconfig: $KUBECONFIG, setado via variavel de ambiente."
        KUBECONFIG=$KUBECONFIG
        echo ""
    fi
}

validateWorkerNode(){
    getNodes=($(kubectl get nodes --kubeconfig=$KUBECONFIG | grep -v NAME | awk '{ print $2 }'))

    if [ ${#getNodes[@]} -eq 0 ]; then
        echo "Nenhum node disponivel"
        return 1
    fi

    declare -a arrOfNodeStatus=()
    for node in ${getNodes[@]}; do
        arrOfNodeStatus+=($(echo $node | cut -d "=" -f 2))
    done

    declare -a unhealthNodes=0
    for status in ${arrOfNodeStatus[@]}; do
        if [ $status != "Ready" ]; then
            let unhealthNodes++
        fi

        # if var is set and is empty
        if [ $unhealthNodes -eq 0 ] ; then
            echo "Todo os nodes estão Ready"
            echo ""
            return 0
        else
            echo "Um dos worker nodes esta com o status diferente de Ready"
            echo ""
            return 1
        fi
    done
}

validateDeploy(){
    replicaCount=$(kubectl get deploy $1 -n $2 --kubeconfig=$KUBECONFIG | grep -v NAME | awk '{ print $2 }')

    if [ "$replicaCount" == "1/1" ]; then
        return 0
    else
        return 1
    fi
}

scaleDeploy(){
    kubectl scale deploy $1 -n $2 --replicas=1 --kubeconfig=$KUBECONFIG
}

main(){
    # while the nodes doesnt have status ready, check it.
    validateWorkerNode
    while [ $? -eq 1 ]; do
        validateWorkerNode
        sleep 10
    done

    for ns in ${namespaces[@]}; do
        declare -a arrOfDeploy=()
        declare -a arrOfDeployToScale=()

        # increasing the array with replica count of the deploy"
        for deploy in $(kubectl -n $ns get deployment -o name --kubeconfig=$KUBECONFIG); do
            arrOfDeploy+=($deploy)
        done

        loopControl=0
        for deploy in ${arrOfDeploy[@]}; do
            arrOfDeployToScale+=($deploy)
            let loopControl++

            if [ $loopControl -ge $deploysAtTime ]; then
                for deploysToScale in ${arrOfDeployToScale[@]}; do
                    deploy=$(echo $deploysToScale | cut -d '=' -f 1 | cut -d '/' -f 2)
                    scaleDeploy $deploy $ns
                done

                for deployToCheck in ${arrOfDeployToScale[@]}; do
                    deploy=$(echo $deployToCheck | cut -d '=' -f 1 | cut -d '/' -f 2)

                    echo "Aguardando o deploy $deploy ficar com o status ready"
                    validateDeploy $deploy $ns
                    while [ $? -eq 1 ]; do
                        validateDeploy $deploy $ns
                    done

                    echo "O deploy $deploy está com o status available"
                    loopControl=0
                    arrOfDeployToScale=()
                done
            fi
        done
    done
}

cleanFiles() {
    find $log_directory -mtime +7 -type f -delete
}

checkLogDirectory
validateKubeconfig
main
cleanFiles
