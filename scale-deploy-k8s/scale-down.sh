#!/bin/bash
#
# @title       K8S Scale Down Deploy
# @description Script de scale down de deployments no Kubernetes. Que ira ser executado as 18:50 de seg a sex.
# @author      Danilo de Souza Lopes 
# @licence     Copyright (C) All Rights Reserved
#
# @requires    bash v4+, crie o diretorio log no mesmo diretorio do script.
# @version     2.0
# @crontab     55 21 * * 1-5 /home/ssm-user/k8s-scale-programs/scale-down.sh

applicationName=$(basename $BASH_SOURCE)
log_directory=("/var/log/k8s-scale-programs")
day=$(date +"%F"_"%k:%M")

exec > >(tee -a $log_directory/$applicationName-${day}.log)

declare -a namespaces=("hml")

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

main(){
    for ns in ${namespaces[@]}; do
        declare -a arrOfDeploy=()

        # increasing arrOfDeploy array with replica count of the deploys"
        for deploy in $(kubectl -n $ns get deployment -o name --kubeconfig=$KUBECONFIG); do
            arrOfDeploy+=($deploy)
        done

        for applications in ${arrOfDeploy[@]}; do
            # getting deploy name.
            deploy=$(echo $applications | cut -d '=' -f 1 | cut -d '/' -f 2)

            kubectl -n $ns scale deploy $deploy --replicas=0 --kubeconfig=$KUBECONFIG
            if [ $? != 0 ]; then
                echo ""
                echo "Nao foi possivel zerar a replica do deploy $deploy"
                echo ""
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
