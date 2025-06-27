#!/bin/bash

#실행 명령어 예시 : ./on_edgeapp.sh linux my-namespace

# 네임스페이스 이름을 지정 (기본값은 'default')
NAMESPACE=${2:-default}

# 입력받은 cronjob prefix
CRONJOB_PREFIX=$1

# 특정 Job 이름을 지정
JOB_NAME="on-job"
CRONJOB_NAME="${CRONJOB_PREFIX}-cronjob-on"

# CronJob으로부터 새로운 Job 생성
kubectl create job --from=cronjob/${CRONJOB_NAME} $JOB_NAME -n $NAMESPACE

# 완료된 특정 Job을 삭제하는 함수
delete_specific_completed_job() {
  echo "Waiting for job $JOB_NAME to complete..."
  
  kubectl wait --for=condition=Complete job/$JOB_NAME -n $NAMESPACE --timeout=600s
  JOB_STATUS=$(kubectl get job $JOB_NAME -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}')

  #Job이 완료되었는지 확인
  if [ "$JOB_STATUS" == "True" ]; then
    echo "Deleting completed job: $JOB_NAME in namespace $NAMESPACE"
    kubectl delete job $JOB_NAME -n $NAMESPACE
  else
    echo "Job $JOB_NAME is not completed or does not exist in namespace $NAMESPACE."
  fi
}

# 스크립트 실행
delete_specific_completed_job