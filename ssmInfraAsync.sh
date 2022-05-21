#!/bin/zsh

# @Title infraProvision.sh
# @Description Script Para Provisionamento de Projetos Terraform System Manager
# @Author Danilo 
# @Licence Copyright (C) All Rights Reserved

# @Requirements zsh v5.8+
# @Version 2.2

environment=$1
option=$2

# Apenas se aplica quando ambiente for compartilhado
environmentShared=$2
optionShared=$3

declare -a accounts

function waitAndGetExitCodes(){
    childrenPIDs=("$@")
    EXIT_CODE=0
    for job in "${childrenPIDs[@]}"; do
        CODE=0
        wait $job || CODE=$?
        if [[ "$CODE" != "0" ]]; then
            echo "pid $job had a failed execution"
            EXIT_CODE=1
        else
            echo "pid $job had a successed execution"
        fi
   done
}

cmd(){
    case $3 in
        "destroy"|"apply")
            AWS_PROFILE=$1 terraform -chdir=$2 $3 -auto-approve > /dev/null 2>&1
        ;;
        *)
            AWS_PROFILE=$1 terraform -chdir=$2 $3 > /dev/null 2>&1
        ;;
    esac
}

patcher(){
    for account in ${accounts[@]}; do
        echo "Fazendo na conta: $account"
        childrenPIDs=()

        case $environment in
            "compartilhado")
                if [[ "environmentShared" == "prod" ]]; then
                    baseDir="$PWD/aws/ambientes/compartilhado/$environmentShared/$account/sa-east-1/recursos/ssm"
                    for window in $(ls $baseDir); do
                        dir="$baseDir/$window"
                        cmd $account $dir $optionShared &
                        childrenPIDs+=($!)
                        echo "$window provisioning has been issued as a background job, as pid: $!"
                    done
                else
                    baseDir="$PWD/aws/ambientes/compartilhado/$environmentShared/$account"
                    for region in $(ls $baseDir); do
                        dir="$baseDir/$region/recursos/ssm/all_instances"
                        cmd $account $dir $optionShared &
                        childrenPIDs+=($!)
                        echo "$region provisioning has been issued as a background job, as pid: $!"
                    done
                fi
            ;;
            "prod")
                baseDir="$PWD/aws/ambientes/$(echo $account |grep -o $environment)/$account/sa-east-1/recursos/ssm"
                for window in $(ls $baseDir); do
                    dir="$baseDir/$window"
                    if [[ $account == *"ficsa"* ]]; then
                        cmd "c6-ficsa-dev" $dir $option &
                        childrenPIDs+=($!)
                        echo "$window provisioning has been issued as a background job, as pid: $!"
                    elif [[ $account == *"shared"* ]]; then
                        cmd "c6-shared-corp" $dir $option &
                        childrenPIDs+=($!)
                        echo "$window provisioning has been issued as a background job, as pid: $!"
                    else
                        cmd $account $dir $option &
                        childrenPIDs+=($!)
                        echo "$window provisioning has been issued as a background job, as pid: $!"
                    fi
                done
            ;;
            *)
                baseDir="$PWD/aws/ambientes/$(echo $account |grep -o $environment)/$account"
                for region in $(ls $baseDir); do
                    dir="$baseDir/$region/recursos/ssm/all_instances"
                    cmd $account $dir $option &
                    childrenPIDs+=($!)
                    echo "$region provisioning has been issued as a background job, as pid: $!"
                done
            ;;
        esac
        waitAndGetExitCodes ${childrenPIDs[@]}
        childrenPIDs=()
    done
}

fetchAccounts(){
    if [[ $1 == "compartilhado" ]]; then
        for account in $(ls $PWD/aws/ambientes/compartilhado/$environmentShared); do
            accounts+=$account
        done
    elif [[ $1 == "dev" || $1 == "hom" || $1 == "prod" ]]; then
        for account in $(ls $PWD/aws/ambientes/$environment); do
            accounts+=$account
        done        
    fi
}

cleanDirs(){
    find $PWD -type d -name "*.terraform" |xargs rm -rf -
}

case ${environment} in
    *"dev"*)
        fetchAccounts $environment
        patcher
    ;;
    *"hom"*)
        fetchAccounts $environment
        patcher
    ;;
    *"prod"*)
        fetchAccounts $environment
        patcher
    ;;
    *"compartilhado"*)
        if [[ $option == "dev-hom" || $option == "prod" ]]; then
            fetchAccounts $environment
            patcher
        else
            echo "Para ambientes compartilhados use: zsh <script.sh> <dev-hom|prod> <init|plan|apply|destroy>"
            exit 1
        fi
    ;;
    *"clean"*)
        cleanDirs
    ;;
    *)
        echo -e "Uso: \n zsh <script.sh> <dev|hom|prod> <init|plan|apply|destroy> \n zsh <script.sh> clean (Deleta os diretorios .terraform) \n Ambientes Compartilhados: zsh <script.sh> \
compartilhado <dev-hom|prod> <init|plan|apply|destroy>"
        exit 1
    ;;
esac
