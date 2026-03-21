#!/bin/bash

START_TIME=$(date +%s)
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD

mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE

# check the cart has root priveleges or not
if [ $USERID -ne 0 ]
then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
    exit 1 #give other than 0 upto 127
else
    echo "You are running with root access" | tee -a $LOG_FILE
fi

echo -e "Please enter Root password to setup"
read -s MYSQL_ROOT_PASSWORD

# validate functions takes input as exit status, what command they tried to install
VALIDATE(){
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}

dnf install maven -y
VALIDATE $? "maven installing"

id roboshop
if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
    VALIDATE $? "Creating roboshop system user"
else
    echo -e "System user roboshop already created ... $Y SKIPPING $N"
fi

mkdir -p /app 
VALIDATE $? "Creating app directory"

curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip 
VALIDATE $? "Downloading shipping"

rm -rf /app/*
cd /app 
unzip /tmp/shipping.zip &>>$LOG_FILE
VALIDATE $? "unzipping user"


mvn clean package
VALIDATE $? "clean package in maven"

mv target/shipping-1.0.jar shipping.jar
VALIDATE $? "Moving  shipping.jar"

cp $SCRIPT_DIR/shipping.service /etc/systemd/system/shipping.service

systemctl daemon-reload
VALIDATE $? "Sytem daemon reloading"

systemctl enable shipping 
systemctl start shipping
VALIDATE $? "Starting shipping"

dnf install mysql -y 
VALIDATE $? "Installing mysql"

mysql -h mysql.kimidi.site -uroot -p$MYSQL_ROOT_PASSWORD< /app/db/schema.sql -e 'use cities'
if [ $? -ne 0 ]
then
   mysql -h mysql.kimidi.site -uroot -pMYSQL_ROOT_PASSWORD < /app/db/schema.sql
   mysql -h mysql.kimidi.site -uroot -pMYSQL_ROOT_PASSWORD < /app/db/app-user.sql 
   mysql -h mysql.kimidi.site -uroot -pMYSQL_ROOT_PASSWORD < /app/db/master-data.sql
else
   echo -e "Data is already loaded into MYSQL ... $Y SKIPPING $N"
fi

systemctl restart shipping
VALIDATE $? "restarting shipping"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME ))

echo -e "Script exection completed successfully, $Y time taken: $TOTAL_TIME seconds $N" | tee -a $LOG_FILE

