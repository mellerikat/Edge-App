#!/bin/

# Check for the correct number of arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: ./install_edgeapp.sh <app_name> <package_path> <config_file>"
    exit 1
fi

APP_NAME=$1
PACKAGE_PATH=$2
CONFIG_FILE=$3



# Step 1: Read env:type from the configuration file
ENV_TYPE=$(awk '/env:/ { f=1 } f && /type:/ { print $2; exit }' $CONFIG_FILE)

# Step 2: Branch depending on env:

# Check if insecure_ip key exists and its value is not empty in the config file
INSECURE_IP_EXISTS=$(awk '/conductor:/ { f=1 } f && /insecure_ip:/ { if ($2) print "exists"; else print "empty"; exit }' $CONFIG_FILE)

# Step 2: Branch depending on env:type and insecure_ip existence
#if [ "$ENV_TYPE" == "linux" ]; then
if [ "$ENV_TYPE" == "linux" ] && [ "$INSECURE_IP_EXISTS" != "exists" ]; then
    # Prompt for AWS credentials if not already set in environment variables
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        echo "Please enter AWS credentials"
        read -p 'AWS Access Key: ' AWS_ACCESS_KEY_ID
        read -sp 'AWS Secret Access Key: ' AWS_SECRET_ACCESS_KEY
        echo
    fi

    # Perform AWS login using actual AWS CLI commands
    echo "Configuring AWS CLI ..."
    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
    aws configure set default.region ap-northeast-2

    # Save credentials as environment variables to a file
    echo "export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> ~/.aws_credentials.sh
    echo "export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> ~/.aws_credentials.sh

    if [ -f ~/.aws_credentials.sh ]; then
        source ~/.aws_credentials.sh
    else
        echo "AWS credentials file not found."
        exit 1
    fi

    # Read ECR information from the configuration file
    ECR_IMAGE_HOST=$(awk '/ecr:/ { f=1 } f && /image_host:/ { print $2; exit }' $CONFIG_FILE)

    # Log in to AWS ECR
    echo "Logging in to AWS ECR ..."
    aws ecr get-login-password --region ap-northeast-2 | sudo docker login --username AWS --password-stdin $ECR_IMAGE_HOST

    if [ $? -ne 0 ]; then
        echo "AWS ECR login failed"
        exit 1
    else
        echo "AWS ECR login successful"
    fi

elif [ "$ENV_TYPE" == "linux" ] && [ "$INSECURE_IP_EXISTS" == "exists" ]; then
    echo "Deploying to on-premise environment"
    INSECURE_IP=$(awk '/conductor:/ { f=1 } f && /insecure_ip:/ { print $2; exit }' $CONFIG_FILE)
    DAEMON_FILE="/.docker/daemon.json"
    username="edgeapp"

    echo $username | docker login $INSECURE_IP --username $username --password-stdin
    login_status=$?

    # 로그인 성공 여부 확인
    if [ $login_status -ne 0 ]; then
        echo "Docker 레지스트리 로그인 실패."
        echo " /etc/docker/daemon.json에 insecure registry에 $INSECURE_IP 가 잘들어가있는지 확인하시오 "
        exit 1
    else
        echo "$INSECURE_IP login successful"
    fi

fi

# Step 3: Modify host_path in the configuration file to use $HOME
sed -i -e "s|host_path: .*|host_path: $HOME|" $CONFIG_FILE
echo "Updated host_path in $CONFIG_FILE to $HOME"

# Step 4: Get the updated host_path, data_input_path, and data_output_path values
host_path=$HOME
DATA_INPUT_PATH=$(awk '/appinfo:/ { f=1 } f && /data_input_path:/ { print $2; exit }' $CONFIG_FILE)
DATA_OUTPUT_PATH=$(awk '/appinfo:/ { f=1 } f && /data_output_path:/ { print $2; exit }' $CONFIG_FILE)


create_dirs_if_not_exist() {
    local relative_path="$1"
    local path="$HOME/$relative_path"
    IFS='/' read -ra ADDR <<< "$path"
    local dir=""

    for i in "${ADDR[@]}"; do
        if [ -n "$i" ]; then
            dir="$dir/$i"
            if [ ! -d "$dir" ]; then
                echo "Creating directory: $dir"
                sudo mkdir -p "$dir"
            fi
        fi
    done
}

# If type is linux or linux-on-premise, set chmod 777 for data paths
if [ "$ENV_TYPE" == "linux" ]; then

    FULL_INPUT_PATH="edgeapp/$APP_NAME/$DATA_INPUT_PATH"
    FULL_OUTPUT_PATH="edgeapp/$APP_NAME/$DATA_OUTPUT_PATH"

    create_dirs_if_not_exist "$FULL_INPUT_PATH"
    create_dirs_if_not_exist "$FULL_OUTPUT_PATH"

    if [ -d "$HOME/$FULL_INPUT_PATH" ]; then
        sudo chmod 770 "$HOME/$FULL_INPUT_PATH"
        echo "Set chmod 770 for $HOME/$FULL_INPUT_PATH"
    else
        echo "Data input path $HOME/$FULL_INPUT_PATH does not exist"
    fi

    if [ -d "$HOME/$FULL_OUTPUT_PATH" ]; then
        sudo chmod 777 "$HOME/$FULL_OUTPUT_PATH"
        echo "Set chmod 777 for $HOME/$FULL_OUTPUT_PATH"
    else
        echo "Data output path $HOME/$FULL_OUTPUT_PATH does not exist"
    fi

fi

# Step 5: Install EdgeApp using Helm with the provided configuration file
helm upgrade -i $APP_NAME $PACKAGE_PATH -f $CONFIG_FILE
#helm template $APP_NAME $PACKAGE_PATH -f $CONFIG_FILE


# Step 6: Print user information from the configuration file
echo "User Information:"
echo "EdgeApp Name: $APP_NAME"
echo "Input/Output Addresses:"
awk '
/appinfo:/ { f=1 }
f {
    if ($1 == "data_input_path:") { print "Data Input Path: " $2 }
    if ($1 == "data_output_path:") { print "Data Output Path: " $2 }
    if ($1 == "Note:") { print "Note: " $2; exit }
}
' $CONFIG_FILE
