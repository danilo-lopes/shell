if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Execute o comando com: source /caminho/para/o/script.sh"
    echo "Caso contrário a variável AWS_PROFILE não será exportada"
    exit 1
fi

# Dependency Check
for i in dialog ; do
    if [ ! -f `which $i` ] ; then
        DEPS="$i 
        $DEPS"
        echo ; echo 'You need to install the following software
        before you can continue:'
        echo "$DEPS"
        exit 1
    fi
done

# Hostname check
if [[ "$HOSTNAME" == "MacBook-Pro.local" ]] ; then
   AWS_CREDENTIALS_PATH="/Users/$USER/.aws/credentials"
else
   AWS_CREDENTIALS_PATH="/home/$USER/.aws/credentials"
fi

HEIGHT=$(expr $(tput lines) - 5) # Deixar umas 5 linhas de margem
WIDTH=45
CHOICE_HEIGHT=$HEIGHT
BACKTITLE="AWS CLI Profile Switch"
TITLE="Profiles"
MENU="Qual profile deseja exportar?"

OPTIONS=($(grep -iE "\[([a-z0-9._\-]+)\]" $AWS_CREDENTIALS_PATH | grep -oE '[a-z0-9._\-]+' | sort))

CHOICE=$(dialog --clear \
                --no-items \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear

export AWS_PROFILE="$CHOICE"
export AWS_SDK_LOAD_CONFIG=1

echo "Assumindo profile \"$CHOICE\""
