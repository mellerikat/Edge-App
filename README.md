# For Cloud

## **목차**

1. [**Edgeapp Infra Login**](#edgeapp-infra)
2. [**Helm 설치**](#Helm-install)
3. [**Edgeapp Helm Chart 다운로드 및 인프라 정보 작성**](#edgeapp-helmchart-install)
4. [**Edgeapp 설치/삭제/업데이트**](#edgeapp-management)
5. [**Edge conductor 상에서 확인 후 사용**](#edgeapp-cond)   <br />

---


### **1. Edgeapp Infra Login**
<a id="markdown-edgeapp-infra" name="edgeapp-infra"></a>

- *Edgeapp* infra의 자원들을 이용하기 위해 key 계정의 확보가 필수 입니다 (클라우드 관리자에게 Key를 문의해 주세요)
 
- awscli, curl, kubectl 사전 설치 
    ```bash        
        sudo apt-get install awscli
        sudo apt-get install curl
        sudo curl -LO https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    ```

- AWS ECR 로그인 
    ```bash
        aws configure set aws_access_key_id {"AWS Access Key"}
        aws configure set aws_secret_access_key  {"AWS Secret Access Key"} 
        aws configure set default.region  {"region"}
        aws ecr get-login-password --region {region}| sudo docker login --username AWS --password-stdin {AWS Account ID}.dkr.ecr.{region}.amazonaws.com 
    ```


### **2. Helm 설치**
<a id="markdown-Helm-install" name="Helm-install"></a>
- helm 설치
    ```bash
    sudo snap install helm --classic
    ```


### **3. Edgeapp Helm Chart 다운로드 및 환경구성**
<a id="markdown-edgeapp-helmchart-install" name="edgeapp-helmchart-install"></a>

- Edgeapp Helm chart 설치
    ```bash
    git clone https://github.com/mellerikat/Edge-App.git
    ```

- Edgeapp 환경 구성(최초 1회 )


    ```bash 
        helm install init ./setup-pacakge/edgeapp-setup-[버전정보].tgz-f [namespace_setting_file] -n {namespace}
    ```

    (ex)
    ```bash
        helm install init ./setup-pacakge/edgeapp-setup-1.0.0.tgz -f example/aws-setup-for-each-namespace.yaml -n edge-app
    ```
- 환경에 따라 맞는 하나의 예제파일을 선택해서 수정후 -f 옵션 뒤에  넣는다 
    - example/aws-setup-for-each-namespace.yaml
    - example/gcp-setup-for-each-namespace.yaml
    - example/wsl-setup-for-each-namespace.yaml

- 저장소, Rolebind 등 Edgeapp이 동작위한 환경 설정을 위한 파일
        (aws 예시)
    ```bash
    # aws-setup-for-each-namespace.yaml
    global:
      is_aws: True #aws환경인 경우 True
      cluster_set: True #저장소 setting 최초 세팅이라면 True

    env:
      namespace: edge-app #k8s namespace 
      serviceaccount: edge-app #k8s service account
      
    pv:
      pv_enable: True #저장소를 사용할것이라면 True
      volumeHandle: {"storage name"} #할당받은 저장소 이름을 적는다 
    ```


### **4. Edgeapp 설치/삭제/업데이트**
<a id="markdown-edgeapp-management" name="edgeapp-management"></a>
 - #### 1. Edgeapp 설치

    ```bash
    helm install [edgeapp이름] ./edgeapp-package/edgeapp-manifest-[버전정보].tgz -f example/aws-edgeapp.yaml -n {namespace}
    ```
    (ex)
    ```bash
    helm install edgeapp-1 ./edgeapp-package/edgeapp-manifest-3.4.0.tgz -f example/aws-edgeapp-1.yaml -n edge-app
    helm install edgeapp-2 ./edgeapp-package/edgeapp-manifest-3.4.0.tgz -f example/aws-edgeapp-2.yaml -n edge-app
    ```

    -  환경에 따라 맞는 하나의 예제파일을 선택해서 수정후 -f 옵션 뒤에  넣는다 
        - example/aws-edgeapp.yaml
        - example/gcp-edgeapp.yaml
        - example/wsl-edgeapp.yaml

    - Edgeapp 사용자/인프라 정보를 저장하는 파일
    ```bash
        # mellerikat-dev
        env:
            type: aws #설치환경
            cluster: eks-an2-meerkat-dev-eks-master #설치 클러스터
            edgeapp_node: ng-an2-meerkat-ws-edge-app-t3-medium #엣지앱노드
            alo_node: ng-an2-edgeapp-meerkat-standard #추론 노드
            alo_memory: 6500Mi #추론 메모리
            storage: s3-an2-meerkat-dev-meerkat #저장소
            #ECR이미지 주소
            controller_image_address: 339713051385.dkr.ecr.ap-northeast-2.amazonaws.com/ecr-repo-an2-meerkat-dev/edgeapp/amd/controller:[버전명]
            iomanager_image_address: 339713051385.dkr.ecr.ap-northeast-2.amazonaws.com/ecr-repo-an2-meerkat-dev/edgeapp/amd/iomanager:[버전명]
            redis_image_address: 339713051385.dkr.ecr.ap-northeast-2.amazonaws.com/ecr-repo-an2-meerkat-dev/edgeapp/amd/redis:v7.2.3
            namespace: edge-app #k8s namespace
            serviceaccount: edge-app #k8s service account

        pv:
            pv_enable: True #log 저장여부

        conductor:#edge conductor 정보
            host: edgecond.meerkat-dev.com
            http_protocol: https
            port: 443
            wsprotocol: wss

        appinfo:
            data_input_path: edgeapp_test/input #추론 이미지 입력장소
            data_ouput_path: edgeapp_test/output #추론 결과 저장장소
            data_input_policy: copy #'move','copy' #입력이미지 정책
            data_save_policy: add_utc #'overwrite','add_utc','add_date' #이미지 저장정책
            enable_result_to_edgecond: True #edge conductor로 결과 전송 여부
            Note: aws-test-edgeapp #기타 참고 사항
    ```


- #### 4.Edgeapp 삭제 
    ```bash
    helm uninstall [edgeapp이름]
    ```
    (ex)
    ```bash
    helm uninstall example1
    helm uninstall example2
    ```
 - #### 5.Helm 설정정보 업데이트 

    ```bash
    helm upgrade [edgeapp이름] ./edgeapp-package/edgeapp-manifest-[버전명].tgz -n {namespace}
    ```

- #### 6. Alo삭제 
    ```bash
    kubectl delete pod [alo pod 이름] -n {namespace}
    ```

### **5. Edge conductor 상에서 확인 후 사용**
<a id="markdown-edgeapp-cond" name="edgeapp-cond"></a>

- 엣지 컨덕터상에서 사용자가 설치한 엣지가 보이는지 확인한다 
    - ex) **\{edgetest\}**  -> \{serail-number}**\{edgetest\}**
