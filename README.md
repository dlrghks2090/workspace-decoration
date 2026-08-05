# 🚀 개발 워크스테이션 구축 및 Docker/Git 실습 최종 보고서

## 1. 프로젝트 개요
- **미션 목표**: 터미널 환경 설정, Docker 컨테이너 운영, 커스텀 이미지 제작 및 Git/GitHub 연동 과정을 문서화하여 표준 개발 워크스테이션 구축을 완료함.
- **기록 원칙**: 본 보고서의 모든 명령어 출력은 실제 실행 결과를 그대로 옮긴 것이다. 개인정보에 해당하는 이메일과 홈 디렉토리 경로만 `****` 로 마스킹했다 (18번 섹션 참고).

---

## 2. 실행 환경

| 항목 | 상세 내용 |
| :--- | :--- |
| **OS** | macOS 26.5.2 (Build 25F84) |
| **Shell** | zsh (`/bin/zsh`) |
| **Docker** | Client 27.3.1 (build ce12230) / Server Docker Desktop 4.35.1 (173168) |
| **Docker Compose** | v2.29.7-desktop.1 |
| **Git** | 2.45.2 |
| **아키텍처** | Client `darwin/arm64` / Server `linux/arm64` |

---

## 3. 수행 항목 체크리스트
- [x] **터미널**: 기본 조작 및 파일 생성·이동·복사·삭제 완료
- [x] **권한**: 파일/디렉토리 권한 변경 및 전후 비교 기록 완료
- [x] **Docker 설치**: 버전 확인 및 데몬 상태 점검 완료
- [x] **Docker 운영**: 이미지/컨테이너 목록 확인, 로그 확인, 정리 완료
- [x] **컨테이너 실습**: hello-world 및 ubuntu 내부 진입 실습 완료
- [x] **Dockerfile**: 커스텀 이미지 빌드 및 컨테이너 실행 성공
- [x] **포트 매핑**: 호스트 포트 연결 및 서비스 접속 증거 확보
- [x] **볼륨 영속성**: 컨테이너 삭제 후 데이터 유지 검증 완료 (대조 실험 포함)
- [x] **Git/GitHub**: 사용자 정보 설정 및 GitHub 저장소 연동 완료
- [x] **보너스 1~2**: Docker Compose 단일/멀티 컨테이너 실행 및 통신 확인 완료
- [x] **보너스 3**: Compose 운영 명령어(`up`/`down`/`ps`/`logs`) 습득 완료
- [x] **보너스 4**: 환경 변수 주입으로 리슨 포트 전환 검증 완료
- [x] **보너스 5**: GitHub SSH 키 생성·등록 및 SSH 원격 전환 완료
- [x] **보안**: 민감 정보 마스킹 및 개인정보 보호 준수 완료

---

## 4. 프로젝트 디렉토리 구조 및 설계 기준
> **수행 내용**: 저장소 구조를 정하고 그 기준을 문서화

- **디렉토리 구조**

      workspace-decoration/
      ├── Dockerfile               # 커스텀 이미지 빌드 정의
      ├── default.conf.template    # nginx 설정 템플릿 (환경 변수 치환용)
      ├── docker-compose.yml       # 다중 서비스 실행 정의
      ├── .env.example             # 환경 변수 예시 (커밋 대상)
      ├── .env                     # 실제 환경 변수 (gitignore 대상)
      ├── .gitignore
      ├── index.html               # 서비스할 정적 페이지
      └── README.md                # 본 보고서

**구성 기준 세 가지**

1. **빌드에 필요한 파일은 저장소 루트에 평평하게 둔다.**
   `docker build .` 의 빌드 컨텍스트가 곧 저장소 루트가 되므로, Dockerfile 안에서 `COPY index.html ...` 처럼 짧은 상대 경로만 쓰면 된다. 하위 디렉토리로 나누면 `COPY src/index.html ...` 처럼 경로가 길어지고, 빌드 컨텍스트를 바꿀 때마다 Dockerfile을 함께 고쳐야 한다. 파일이 8개뿐인 규모에서는 계층을 만드는 비용이 이득보다 크다고 판단했다.

2. **실습 산출물은 저장소 밖에 격리한다.**
   터미널·권한 실습에서 만든 파일은 `~/Desktop/kan` 에서 작업하고 실습 후 삭제했다. 저장소 안에서 작업하면 실습용 임시 파일이 `git status` 에 섞여 실제 산출물과 구분되지 않는다.

3. **설정과 코드를 분리한다.**
   포트 같은 실행 설정은 `.env` 로 빼고, 저장소에는 `.env.example` 만 커밋한다. 덕분에 이미지를 다시 빌드하지 않고 설정만 바꿔 동작을 바꿀 수 있으며(17-4 참고), 실제 값이 저장소에 올라가지 않는다.

---

## 5. 터미널 조작 로그 기록
> **수행 내용**: 위치 확인, 디렉토리 생성/이동, 파일 생성/확인/복사/이동/삭제

- **현재 위치 확인**

      $ pwd
      /Users/****/Desktop

- **디렉토리 생성 및 확인**

      $ mkdir kan
      $ ls -d kan
      kan

- **디렉토리 이동**

      $ cd kan
      $ pwd
      /Users/****/Desktop/kan

- **파일 생성**

      $ echo "Terminal Practice" > memo.txt
      $ ls
      memo.txt

- **파일 내용 확인**

      $ cat memo.txt
      Terminal Practice

- **파일 복사**

      $ cp memo.txt backup.txt
      $ ls
      backup.txt
      memo.txt

- **파일 이름 변경 (mv)**

      $ mv memo.txt notes.txt
      $ ls
      backup.txt
      notes.txt

- **파일을 다른 디렉토리로 이동 (mv)**

      $ mkdir archive
      $ mv notes.txt archive/
      $ ls archive
      notes.txt

- **파일 삭제**

      $ rm backup.txt
      $ ls
      archive

- **디렉토리 이름 변경 (mv)**

      $ ls
      archive
      note.txt
      workspace

      $ mv archive archive-old
      $ ls
      archive-old
      note.txt
      workspace

  > 위 목록의 `note.txt` 와 `workspace` 는 6번 권한 실습에서 만든 파일이다. 이 단계를 권한 실습 이후에 수행했기 때문에 함께 보인다.

- **디렉토리 삭제 (rm -r)**

      $ rm -r archive-old
      $ ls
      note.txt
      workspace

- **실습 디렉토리 전체 정리**

      $ cd ~/Desktop
      $ rm -r kan
      $ ls -d kan
      ls: kan: No such file or directory

> `mv` 는 같은 디렉토리 안에서 쓰면 이름 변경, 다른 디렉토리를 대상으로 쓰면 이동으로 동작하며, 파일과 디렉토리 모두에 같은 방식으로 적용된다. 네 경우를 모두 기록했다.
>
> 디렉토리 삭제에는 `-r`(recursive) 옵션이 필요하다. `rm` 만 쓰면 디렉토리는 지워지지 않는데, 내부에 파일이 남아 있을 수 있어 실수로 통째로 지우는 것을 막기 위한 안전장치다.

---

## 6. 권한 실습 및 증거 기록
> **수행 내용**: 파일/디렉토리 권한 변경 전후를 `ls -l` 로 실측

- **변경 전 상태 확인**

      $ ls -l note.txt
      -rw-r--r--@ 1 ****  staff  20 Aug  5 19:23 note.txt

      $ ls -ld workspace
      drwxr-xr-x@ 2 ****  staff  64 Aug  5 19:23 workspace

- **권한 변경**

      $ chmod 600 note.txt
      $ chmod 700 workspace

- **변경 후 상태 확인**

      $ ls -l note.txt
      -rw-------@ 1 ****  staff  20 Aug  5 19:23 note.txt

      $ ls -ld workspace
      drwx------@ 2 ****  staff  64 Aug  5 19:23 workspace

- **숫자 표기와 문자 표기 대조**

      $ stat -f "%Sp %OLp %N" note.txt workspace
      -rw------- 600 note.txt
      drwx------ 700 workspace

| 대상 | 변경 전 | 변경 후 | 의미 |
| :--- | :--- | :--- | :--- |
| `note.txt` | `-rw-r--r--` (644) | `-rw-------` (600) | 소유자만 읽기/쓰기, 그룹·기타 접근 차단 |
| `workspace` | `drwxr-xr-x` (755) | `drwx------` (700) | 소유자만 진입·조회 가능 |

> 권한 숫자가 결정되는 규칙은 14번 섹션에서 설명한다.

---

## 7. Docker 설치 및 기본 점검
> **수행 내용**: 버전 확인 및 데몬 동작 상태 점검

- **Docker 버전 확인**

      $ docker --version
      Docker version 27.3.1, build ce12230

- **Docker 상세 버전 확인 (클라이언트/서버 분리 확인)**

      $ docker version
      Client:
       Version:           27.3.1
       API version:       1.47
       Go version:        go1.22.7
       Git commit:        ce12230
       Built:             Fri Sep 20 11:38:18 2024
       OS/Arch:           darwin/arm64
       Context:           desktop-linux

      Server: Docker Desktop 4.35.1 (173168)
       Engine:
        Version:          27.3.1
        API version:      1.47 (minimum version 1.24)
        Go version:       go1.22.7
        Git commit:       41ca978
        Built:            Fri Sep 20 11:41:19 2024
        OS/Arch:          linux/arm64
        Experimental:     false
       containerd:
        Version:          1.7.21
       runc:
        Version:          1.1.13

- **Docker 데몬 동작 확인**

      $ docker info | grep "Server Version"
       Server Version: 27.3.1

> **macOS 기준 참고**: 이 환경은 macOS이므로 데몬 상태 확인에 `systemctl status docker` 를 쓰지 않는다. `systemctl` 은 systemd 기반 Linux 전용 명령이며, macOS에서는 Docker Desktop 앱이 리눅스 VM 안의 데몬을 관리한다. 위 `docker version` 출력에서 Client는 `darwin/arm64`, Server는 `linux/arm64` 로 갈리는 것이 그 증거다. 데몬 기동 여부는 `docker info` 의 응답 성공 자체로 확인한다.

---

## 8. Docker 기본 운영
> **수행 내용**: 이미지 다운로드, 목록 확인, 로그 확인, 컨테이너 정리

- **이미지 다운로드**

      $ docker pull nginx
      Using default tag: latest
      latest: Pulling from library/nginx
      69bf5e21f36b: Pull complete
      65d501c82b02: Pull complete
      f3dc69d0d185: Pull complete
      1b7200988f19: Pull complete
      b4878adb81c5: Pull complete
      6f707990432e: Pull complete
      5a965c79b807: Pull complete
      Digest: sha256:640dee81b9ada2bf929ae17c2c7e88930f244216aa6418306226ce9bdc3271e6
      Status: Downloaded newer image for nginx:latest
      docker.io/library/nginx:latest

- **이미지 목록 확인**

      $ docker images
      REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
      nginx        latest    640dee81b9ad   10 hours ago   256MB

- **컨테이너 로그 확인**

      $ docker logs my-app
      /docker-entrypoint.sh: Configuration complete; ready for start up
      2026/08/05 10:26:33 [notice] 1#1: using the "epoll" event method
      2026/08/05 10:26:33 [notice] 1#1: nginx/1.31.3
      2026/08/05 10:26:33 [notice] 1#1: OS: Linux 6.10.11-linuxkit
      2026/08/05 10:26:33 [notice] 1#1: start worker processes
      172.17.0.1 - - [05/Aug/2026:10:26:35 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/8.7.1" "-"
      172.17.0.1 - - [05/Aug/2026:10:26:35 +0000] "GET / HTTP/1.1" 200 23 "-" "curl/8.7.1" "-"

> 로그 마지막 두 줄은 10번 섹션에서 `curl` 로 접속했을 때 남은 액세스 로그다. 요청이 실제로 컨테이너까지 도달했다는 증거가 된다.

- **정리 전 전체 컨테이너 목록**

      $ docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
      NAMES             IMAGE         STATUS
      my-app2           my-web:v1     Up About a minute
      my-app            my-web:v1     Up About a minute
      ubuntu-practice   ubuntu        Exited (0) About a minute ago
      jolly_elgamal     hello-world   Exited (0) About a minute ago

- **실행 중인 컨테이너 중지**

      $ docker stop my-app my-app2
      my-app
      my-app2

      $ docker ps -a --format "table {{.Names}}\t{{.Status}}"
      NAMES             STATUS
      my-app2           Exited (0) Less than a second ago
      my-app            Exited (0) Less than a second ago
      ubuntu-practice   Exited (0) About a minute ago
      jolly_elgamal     Exited (0) About a minute ago

- **컨테이너 삭제 및 정리 확인**

      $ docker rm my-app my-app2 ubuntu-practice
      my-app
      my-app2
      ubuntu-practice

      $ docker ps -a --format "table {{.Names}}\t{{.Status}}"
      NAMES           STATUS
      jolly_elgamal   Exited (0) About a minute ago

> `jolly_elgamal` 은 `--name` 을 주지 않고 실행한 hello-world 컨테이너에 Docker가 자동으로 붙인 이름이다. 이름을 지정하지 않으면 임의의 이름이 생기고, 종료된 컨테이너도 삭제 전까지 목록에 남는다는 것을 보여준다.

---

## 9. 컨테이너 실행 실습
> **수행 내용**: hello-world 동작 확인 및 ubuntu 컨테이너 내부 진입

- **hello-world 실행**

      $ docker run hello-world
      Unable to find image 'hello-world:latest' locally
      latest: Pulling from library/hello-world
      58dee6a49ef1: Pull complete
      Digest: sha256:7f4da0fc94bcece205a8c0b6f4d11c8196924654ffe5c4d1aa439b7f632048b2
      Status: Downloaded newer image for hello-world:latest

      Hello from Docker!
      This message shows that your installation appears to be working correctly.

      To generate this message, Docker took the following steps:
       1. The Docker client contacted the Docker daemon.
       2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
          (arm64v8)
       3. The Docker daemon created a new container from that image which runs the
          executable that produces the output you are currently reading.
       4. The Docker daemon streamed that output to the Docker client, which sent it
          to your terminal.

      To try something more ambitious, you can run an Ubuntu container with:
       $ docker run -it ubuntu bash

      Share images, automate workflows, and more with a free Docker ID:
       https://hub.docker.com/

      For more examples and ideas, visit:
       https://docs.docker.com/get-started/

> 로컬에 이미지가 없으면(`Unable to find image ... locally`) Docker가 자동으로 레지스트리에서 받아온 뒤 실행한다는 것을 확인했다.

- **ubuntu 컨테이너 내부 진입**

      $ docker run -it --name ubuntu-practice ubuntu /bin/bash
      Unable to find image 'ubuntu:latest' locally
      latest: Pulling from library/ubuntu
      Digest: sha256:678c6550cc43645e08669028bc177f50be4e7c5b8cca677067b1914d4afc7a03
      Status: Downloaded newer image for ubuntu:latest

      root@b60f67dd4331:/# cat /etc/os-release
      PRETTY_NAME="Ubuntu 26.04 LTS"
      NAME="Ubuntu"
      VERSION_ID="26.04"
      VERSION="26.04 LTS (Resolute Raccoon)"
      VERSION_CODENAME=resolute
      ID=ubuntu
      ID_LIKE=debian
      UBUNTU_CODENAME=resolute

      root@b60f67dd4331:/# whoami
      root

      root@b60f67dd4331:/# pwd
      /

      root@b60f67dd4331:/# ls /
      bin   dev  home  media  opt   root  sbin  sys  usr
      boot  etc  lib   mnt    proc  run   srv   tmp  var

      root@b60f67dd4331:/# exit
      exit

> 호스트는 macOS인데 컨테이너 안은 Ubuntu 26.04이고 프롬프트가 `root@<컨테이너ID>` 로 바뀐다. 컨테이너가 호스트와 분리된 독립 파일시스템·사용자 공간을 갖는다는 것을 직접 확인한 부분이다.

---

## 10. 커스텀 Dockerfile 제작 및 포트 매핑
> **수행 내용**: 이미지 빌드, 컨테이너 실행, 접속 검증 (베이스: nginx:latest)

- **작성한 Dockerfile**

      FROM nginx:latest

      # 환경 변수 기본값. Compose 나 docker run -e 로 덮어쓸 수 있다.
      ENV NGINX_PORT=80
      ENV APP_MODE=development

      # 빌드 컨텍스트가 저장소 루트이므로 상대 경로로 참조한다.
      COPY index.html /usr/share/nginx/html/index.html

      # nginx 공식 이미지는 기동 시 /etc/nginx/templates/*.template 을
      # envsubst 로 치환해 /etc/nginx/conf.d/ 로 출력한다.
      COPY default.conf.template /etc/nginx/templates/default.conf.template

      EXPOSE ${NGINX_PORT}

- **커스텀 이미지 빌드**

      $ docker build -t my-web:v1 .
      #1 [internal] load build definition from Dockerfile
      #1 transferring dockerfile: 898B done
      #1 DONE 0.0s
      #5 [1/3] FROM docker.io/library/nginx:latest@sha256:640dee81b9ada...
      #5 DONE 1.5s
      #7 [2/3] COPY index.html /usr/share/nginx/html/index.html
      #7 DONE 0.0s
      #8 [3/3] COPY default.conf.template /etc/nginx/templates/default.conf.template
      #8 DONE 0.0s
      #9 exporting to image
      #9 naming to docker.io/library/my-web:v1 done
      #9 DONE 0.1s

      $ docker images my-web
      REPOSITORY   TAG       IMAGE ID       CREATED                  SIZE
      my-web       v1        46b70910e1e1   Less than a second ago   256MB

- **컨테이너 실행 (포트 매핑)**

      $ docker run -d -p 8081:80 --name my-app my-web:v1
      f87abce4cd5ec82d56b1967b66436cdcb26194324e136811cbbc57538ccff047

      $ docker ps
      CONTAINER ID   IMAGE       COMMAND                  STATUS         PORTS                  NAMES
      f87abce4cd5e   my-web:v1   "/docker-entrypoint.…"   Up 2 seconds   0.0.0.0:8081->80/tcp   my-app

- **포트 접속 검증 (응답 헤더)**

      $ curl -sI localhost:8081
      HTTP/1.1 200 OK
      Server: nginx/1.31.3
      Date: Wed, 05 Aug 2026 10:26:48 GMT
      Content-Type: text/html
      Content-Length: 23
      Last-Modified: Wed, 05 Aug 2026 09:46:12 GMT
      Connection: keep-alive
      ETag: "6a730664-17"
      Accept-Ranges: bytes

- **포트 접속 검증 (응답 본문)**

      $ curl -s localhost:8081
      <h1>hello, world!</h1>

> 응답 본문이 저장소의 `index.html` 내용과 일치한다. 이는 `COPY index.html ...` 이 실제로 이미지에 반영됐고, 기본 nginx 페이지가 아니라 우리가 만든 페이지가 서빙되고 있다는 증거다.

---

## 11. Docker 볼륨 영속성 검증
> **수행 내용**: 볼륨 생성 → 데이터 저장 → **컨테이너 삭제** → 데이터 유지 확인, 그리고 볼륨을 쓰지 않은 대조 실험

### 실험군: 볼륨에 저장

- **볼륨 생성**

      $ docker volume create my-vol
      my-vol

      $ docker volume ls | grep my-vol
      local     my-vol

- **볼륨에 데이터 저장**

      $ docker run --name vol-test -v my-vol:/data ubuntu sh -c "echo saved > /data/test.txt"

- **컨테이너 존재 확인**

      $ docker ps -a --filter name=vol-test --format "table {{.Names}}\t{{.Status}}"
      NAMES      STATUS
      vol-test   Exited (0) Less than a second ago

- **컨테이너 삭제**

      $ docker rm vol-test
      vol-test

      $ docker ps -a --filter name=vol-test --format "table {{.Names}}\t{{.Status}}"
      NAMES     STATUS

- **컨테이너 삭제 후 데이터 유지 확인**

      $ docker run --rm -v my-vol:/data ubuntu cat /data/test.txt
      saved

### 대조군: 볼륨 없이 컨테이너 쓰기 레이어에 저장

- **컨테이너 안에 파일 생성**

      $ docker run -d --name novol-test ubuntu sleep 300
      58f8ff0ddaeb0804d80cf3cec8cdab292ec75e6e725331710657d43d2be2eb62

      $ docker exec novol-test sh -c "echo lost > /tmp/test.txt"

- **같은 컨테이너 안에서는 데이터가 보인다**

      $ docker exec novol-test cat /tmp/test.txt
      lost

- **컨테이너를 삭제하면**

      $ docker rm -f novol-test
      novol-test

- **새 컨테이너에는 데이터가 없다**

      $ docker run --rm ubuntu cat /tmp/test.txt
      cat: /tmp/test.txt: No such file or directory

- **반면 볼륨에 저장한 데이터는 여전히 살아 있다**

      $ docker run --rm -v my-vol:/data ubuntu cat /data/test.txt
      saved

| 저장 위치 | 컨테이너 실행 중 | 컨테이너 삭제 후 |
| :--- | :--- | :--- |
| 컨테이너 쓰기 레이어 (`/tmp`) | `lost` | **소실** (`No such file or directory`) |
| 이름 있는 볼륨 (`my-vol:/data`) | `saved` | **유지** (`saved`) |

> 같은 이미지, 같은 명령인데 저장 위치만 다르다. 데이터가 사라지는 원인이 "컨테이너 삭제" 자체가 아니라 "어디에 썼는가"에 있다는 것을 보여준다.

---

## 12. 재현 절차 (포트/볼륨)
> **수행 내용**: 제3자가 동일한 결과를 재현할 수 있도록 설정을 표와 명령 시퀀스로 고정

### 포트 매핑 규칙

| 실행 방식 | 호스트 포트 | 컨테이너 포트 | 결정 위치 |
| :--- | :--- | :--- | :--- |
| `docker run` (10번) | 8081 | 80 | `-p 8081:80` 인자, 컨테이너 포트는 Dockerfile의 `ENV NGINX_PORT=80` |
| Compose (17번) | 8081 | 8080 | `.env` 의 `HOST_PORT` / `NGINX_PORT` |

호스트 포트와 컨테이너 포트를 분리해 둔 이유는, 호스트 포트가 이미 점유됐을 때 **컨테이너 쪽은 그대로 두고 호스트 포트만 바꾸면 되기 때문**이다 (15번 트러블슈팅 2번 사례).

### 볼륨 규칙

| 항목 | 값 | 이유 |
| :--- | :--- | :--- |
| 볼륨 종류 | 이름 있는 볼륨(named volume) | 호스트 경로에 의존하지 않아 다른 머신에서도 같은 명령이 동작한다 |
| 볼륨 이름 | `my-vol` | 명시적으로 만들어야 `docker volume ls` 로 추적·백업이 가능하다 |
| 마운트 경로 | `/data` | 컨테이너 내부의 고정 경로로 통일 |

### 전체 재현 명령 시퀀스

      # 1. 저장소 준비
      $ git clone https://github.com/dlrghks2090/workspace-decoration.git
      $ cd workspace-decoration

      # 2. 환경 변수 준비 (.env 는 저장소에 없으므로 예시에서 복사)
      $ cp .env.example .env

      # 3. 단일 컨테이너로 실행
      $ docker build -t my-web:v1 .
      $ docker run -d -p 8081:80 --name my-app my-web:v1
      $ curl -s localhost:8081          # → <h1>hello, world!</h1>

      # 4. 볼륨 영속성 확인
      $ docker volume create my-vol
      $ docker run --name vol-test -v my-vol:/data ubuntu sh -c "echo saved > /data/test.txt"
      $ docker rm vol-test
      $ docker run --rm -v my-vol:/data ubuntu cat /data/test.txt   # → saved

      # 5. Compose 로 실행 (보너스)
      $ docker compose up -d
      $ docker compose logs client      # → <h1>hello, world!</h1>

      # 6. 정리
      $ docker compose down
      $ docker rm -f my-app
      $ docker volume rm my-vol

---

## 13. Git 설정 및 GitHub 연동
> **수행 내용**: 사용자 정보 및 원격 저장소 확인

- **Git 사용자 정보 확인**

      $ git config --list | grep -E "^user\.|^remote\."
      user.name=Kim IkHwan
      user.email=****@gmail.com
      remote.origin.url=https://github.com/dlrghks2090/workspace-decoration.git
      remote.origin.fetch=+refs/heads/*:refs/remotes/origin/*

- **GitHub 원격 저장소 확인**

      $ git remote -v
      origin	https://github.com/dlrghks2090/workspace-decoration.git (fetch)
      origin	https://github.com/dlrghks2090/workspace-decoration.git (push)

- **브랜치와 원격 추적 상태 확인**

      $ git branch -vv
      * main 34fe843 [origin/main] Feat: README.md 파일 생성 및 초안 작성

- **커밋 이력 확인**

      $ git log --oneline
      34fe843 Feat: README.md 파일 생성 및 초안 작성
      2c4445a Feat: 프로젝트 생성 및 READEME.md 초안 작성
      f482988 Initial commit

> `[origin/main]` 표시는 로컬 `main` 브랜치가 원격 `origin/main` 을 추적하도록 연동됐다는 뜻이다.

---

## 14. 핵심 기술 원리

### 14-1. 이미지와 컨테이너의 차이 (빌드 / 실행 / 변경 관점)

| 관점 | 이미지 | 컨테이너 |
| :--- | :--- | :--- |
| **빌드** | `docker build` 의 결과물. 읽기 전용 레이어가 쌓인 불변 스냅샷 | 빌드하지 않는다. 이미지를 재료로 만들어질 뿐 |
| **실행** | 그 자체로는 실행되지 않는다 | `docker run` 이 이미지 위에 **쓰기 가능 레이어**를 얹어 만든 실행 인스턴스 |
| **변경** | 변경하려면 다시 빌드해야 한다 (새 이미지 ID 생성) | 실행 중 변경은 쓰기 레이어에만 쌓이고, 원본 이미지는 그대로다 |

**실습 근거**: 11번 대조 실험에서 `novol-test` 컨테이너에 만든 `/tmp/test.txt` 는 컨테이너를 지우자 함께 사라졌지만, 같은 `ubuntu` 이미지로 새 컨테이너를 띄우면 언제나 깨끗한 초기 상태로 시작했다. 변경이 이미지가 아니라 컨테이너 레이어에 쌓였다는 직접적인 증거다.

또한 10번에서 `my-web:v1` 이미지 하나로 `my-app`, `my-app2` 두 컨테이너를 동시에 띄웠다. **이미지 1개 : 컨테이너 N개** 관계가 성립한다.

### 14-2. 컨테이너 내부 포트로 직접 접속할 수 없는 이유와 포트 매핑이 필요한 이유

**접속할 수 없는 이유**: 컨테이너는 자체 네트워크 네임스페이스를 가지며 호스트와 분리된 사설 IP를 부여받는다. 호스트 입장에서 `localhost:80` 은 호스트 자신의 80번 포트일 뿐, 컨테이너의 80번 포트가 아니다. 둘은 애초에 다른 네트워크 공간에 있다.

**실습 근거**: 8번의 nginx 액세스 로그에서 접속 출처 IP가 갈린다.

      172.18.0.3 - - [...] "GET / HTTP/1.1" 200 23 "-" "curl/8.21.0"    ← 같은 네트워크의 client 컨테이너
      172.18.0.1 - - [...] "GET / HTTP/1.1" 200 23 "-" "curl/8.7.1"     ← 호스트(게이트웨이)를 거쳐 들어온 요청

컨테이너끼리는 `172.18.0.x` 대역에서 직접 통신하지만, 호스트에서 온 요청은 게이트웨이(`172.18.0.1`)를 통과해 들어온다. 실제로 17-2에서 `client` 컨테이너는 **호스트 포트 매핑 없이** `http://web:8080` 으로 접속에 성공했다. 즉 포트 매핑은 컨테이너 간 통신에는 필요 없고, **호스트 ↔ 컨테이너 경계를 넘을 때만** 필요하다.

**필요한 이유 세 가지**
1. **격리 유지**: 컨테이너의 모든 포트를 자동 공개하면 격리의 의미가 없다. 공개할 포트를 명시적으로 고르게 한다.
2. **포트 충돌 회피**: 여러 컨테이너가 모두 내부 80번을 쓰더라도 호스트 포트만 8081, 8082로 달리 주면 공존할 수 있다 (10번에서 실제로 그렇게 했다).
3. **이식성**: 컨테이너 내부 포트는 이미지에 고정하고 호스트 포트만 환경에 맞춰 바꾸면, 같은 이미지를 어느 서버에서든 쓸 수 있다.

### 14-3. 절대 경로와 상대 경로의 선택 기준

| 상황 | 선택 | 이유 |
| :--- | :--- | :--- |
| Dockerfile의 `COPY index.html ...` | **상대 경로** | 빌드 컨텍스트 기준으로 해석된다. 저장소를 어디에 클론하든 동작해야 하므로 절대 경로를 쓰면 안 된다 |
| `docker build .` 의 빌드 컨텍스트 | **상대 경로** | 현재 위치 기준. 저장소 루트에서 실행한다는 규약과 함께 쓴다 |
| 볼륨 마운트 `-v my-vol:/data` | **절대 경로** | 컨테이너 내부 경로는 반드시 `/` 로 시작하는 절대 경로여야 한다 |
| 스크립트·스케줄러(cron)에서의 파일 참조 | **절대 경로** | 실행 시점의 작업 디렉토리를 예측할 수 없다 |

**판단 기준 한 줄 요약**: *실행 위치가 달라져도 같은 대상을 가리켜야 하면 절대 경로, 프로젝트를 통째로 옮겨도 따라와야 하면 상대 경로.*

**실습 근거**: 4번 섹션에서 빌드 파일을 저장소 루트에 평평하게 둔 것도 이 기준 때문이다. `COPY index.html ...` 이라는 짧은 상대 경로가 클론 위치와 무관하게 항상 동작한다.

### 14-4. 파일 권한 숫자 표기가 결정되는 규칙

**1단계 — 각 권한에 값을 부여한다**

| 권한 | 문자 | 값 |
| :--- | :--- | :--- |
| 읽기 (read) | `r` | 4 |
| 쓰기 (write) | `w` | 2 |
| 실행 (execute) | `x` | 1 |

**2단계 — 대상별로 합산해 세 자리를 만든다**  순서는 **소유자(user) → 그룹(group) → 기타(others)** 다.

      755  →  rwx  r-x  r-x
             ^^^  ^^^  ^^^
             4+2+1  4+0+1  4+0+1
             소유자  그룹   기타

**실습에 적용한 값**

| 숫자 | 문자 표기 | 계산 | 의미 |
| :--- | :--- | :--- | :--- |
| 644 | `rw-r--r--` | 4+2 / 4 / 4 | 소유자 읽기·쓰기, 나머지는 읽기만 (일반 파일 기본값) |
| 600 | `rw-------` | 4+2 / 0 / 0 | 소유자만 읽기·쓰기 (6번 실습의 `note.txt`) |
| 755 | `rwxr-xr-x` | 4+2+1 / 4+1 / 4+1 | 소유자만 수정, 나머지는 진입·조회 (디렉토리 기본값) |
| 700 | `rwx------` | 4+2+1 / 0 / 0 | 소유자만 진입·조회 (6번 실습의 `workspace`) |

**주의할 점**: 디렉토리에서 `x` 는 "실행"이 아니라 **진입(cd) 권한**이다. 디렉토리에 `r` 만 있고 `x` 가 없으면 이름 목록은 볼 수 있어도 안으로 들어가거나 내부 파일의 정보를 읽을 수 없다. 그래서 디렉토리 권한은 보통 `755`·`700` 처럼 `x` 를 포함한 형태로 준다.

---

## 15. 트러블슈팅
> 각 사례를 **가설 → 확인 → 조치 → 결과** 순으로 기록

### 15-1. Docker 명령이 데몬에 연결되지 않음

- **현상**

      $ docker info
      Cannot connect to the Docker daemon at unix:///Users/****/.docker/run/docker.sock.
      Is the docker daemon running?

- **가설**: `docker --version` 은 정상 출력됐으므로 CLI 설치 문제는 아니다. CLI와 데몬이 분리된 구조이므로 데몬 쪽만 죽어 있을 것이다.
- **확인**: `docker --version` 은 `27.3.1` 을 반환하는데 `docker info` 만 실패한다 → 클라이언트는 살아 있고 서버가 없다는 뜻.
- **조치**: Docker Desktop 앱을 기동한다.

      $ open -a Docker

- **결과**

      $ docker info | grep "Server Version"
       Server Version: 27.3.1

- **배운 점**: `docker --version` 이 동작한다고 Docker가 쓸 수 있는 상태인 것은 아니다. CLI 설치 확인과 데몬 동작 확인은 별개이며, 데몬 확인은 `docker info` 로 해야 한다.

### 15-2. 호스트 포트가 이미 사용 중이라 포트 매핑 실패

- **현상**: 8081 포트를 쓰는 `my-app` 이 떠 있는 상태에서 같은 포트로 두 번째 컨테이너를 실행

      $ docker run -d -p 8081:80 --name my-app2 my-web:v1
      8553c743c5dc07fa27038fb69df60c1b8dac8af44b8de755a5f9280fa63000d4
      docker: Error response from daemon: driver failed programming external connectivity
      on endpoint my-app2: Bind for 0.0.0.0:8081 failed: port is already allocated.

- **진단 순서**
  1. **에러 메시지부터 읽는다** — `Bind for 0.0.0.0:8081 failed` 이므로 문제는 컨테이너 내부가 아니라 **호스트 포트 8081** 이다.
  2. **누가 점유 중인지 확인한다**

         $ lsof -i :8081
         COMMAND     PID  USER   FD   TYPE  NODE NAME
         com.docke 90928 ****  171u  IPv6   TCP *:sunproxyadmin (LISTEN)

  3. **Docker 컨테이너인지 확인한다** — `docker ps` 로 8081을 쓰는 컨테이너(`my-app`)를 특정한다.
  4. **선택한다** — 기존 컨테이너가 필요하면 호스트 포트를 바꾸고, 필요 없으면 정리한다.

- **조치**: 컨테이너 포트(80)는 그대로 두고 **호스트 포트만** 8082로 변경

      $ docker rm my-app2
      $ docker run -d -p 8082:80 --name my-app2 my-web:v1
      b64e36d567051ac00086ad093ae5c117de7147e12c20856370e8066ba6f8d1ef

- **결과**: 두 컨테이너가 서로 다른 호스트 포트로 공존

      $ docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
      NAMES     PORTS                  STATUS
      my-app2   0.0.0.0:8082->80/tcp   Up 2 seconds
      my-app    0.0.0.0:8081->80/tcp   Up 17 seconds

      $ curl -sI localhost:8082 | head -1
      HTTP/1.1 200 OK

- **배운 점**: 실패한 컨테이너도 생성은 되므로(위 출력의 컨테이너 ID) 재시도 전에 `docker rm` 으로 지워야 이름 충돌이 생기지 않는다. 그리고 고쳐야 할 것은 이미지나 컨테이너 포트가 아니라 **호스트 포트 하나**다.

### 15-3. 컨테이너 삭제 후 데이터가 사라짐

- **현상**: 11번 대조 실험에서 컨테이너 삭제 후 `cat: /tmp/test.txt: No such file or directory`
- **가설**: 파일을 컨테이너의 쓰기 레이어에 썼기 때문에 컨테이너 수명과 함께 사라졌을 것이다.
- **확인**: 같은 조건에서 저장 위치만 볼륨(`my-vol:/data`)으로 바꿔 재실험 → 컨테이너를 지워도 `saved` 가 그대로 남았다.
- **조치 및 대안 비교**

| 대안 | 방식 | 적합한 상황 | 유의점 |
| :--- | :--- | :--- | :--- |
| **이름 있는 볼륨** | `-v my-vol:/data` | DB 데이터 등 운영 데이터 (이번 실습에서 채택) | 호스트 경로가 드러나지 않아 이식성이 좋다 |
| **바인드 마운트** | `-v $(pwd)/data:/data` | 개발 중 소스 실시간 반영 | 호스트 경로에 의존해 다른 머신에서 깨질 수 있다 |
| **정기 백업** | `docker run --rm -v my-vol:/data -v $(pwd):/backup ubuntu tar cvf /backup/backup.tar /data` | 볼륨 자체의 유실 대비 | 볼륨만으로는 실수로 `docker volume rm` 하면 끝이다 |

- **배운 점**: `docker compose down` 은 컨테이너와 네트워크만 지우지만 **`docker compose down -v` 는 볼륨까지 지운다.** 영속성이 필요한 환경에서 `-v` 를 습관적으로 붙이면 안 된다.

### 15-4. envsubst가 주석 안의 변수까지 치환함

- **현상**: `default.conf.template` 에 `# ${NGINX_PORT} 는 ... 치환된다` 라는 주석을 달았는데, 컨테이너 안의 결과 파일에서 주석이 `# 8080 는 ... 치환된다` 로 바뀌어 의미가 깨졌다.
- **가설**: nginx 엔트리포인트의 envsubst는 파일을 문법적으로 해석하지 않고 텍스트 전체를 치환하므로, 주석도 예외가 아닐 것이다.
- **확인**: 컨테이너 안의 실제 결과 파일을 직접 확인

      $ docker compose exec web cat /etc/nginx/conf.d/default.conf
      server {
          # 8080 는 컨테이너 기동 시 환경 변수 값으로 치환된다.
          listen       8080;

- **조치**: 주석에서 변수 표기를 빼고 "아래 리슨 포트는 ~" 처럼 서술형으로 바꿨다.
- **배운 점**: 템플릿 파일의 주석은 치환 대상에서 제외되지 않는다. 설명용 주석에 변수명을 그대로 쓰면 결과물에서 문장이 깨진다.

### 15-5. GitHub이 SSH 공개키를 형식 오류로 거부함

- **현상**: 생성한 키를 GitHub에 등록하려 하자 다음 오류가 반환됐다.

      Key is invalid. You must supply a key in OpenSSH public key format

- **가설 1 — 키 파일 자체가 손상됐을 것이다.** 확인해 보니 아니었다.

      $ ssh-keygen -lf ~/.ssh/id_ed25519.pub
      256 SHA256:McCE60hNY/KM/r+GbuS1N9ScwfZClRge96AnzP9xSo8 ****@gmail.com (ED25519)

      $ wc -l < ~/.ssh/id_ed25519.pub
             1
      $ cut -d' ' -f1 < ~/.ssh/id_ed25519.pub
      ssh-ed25519

  `ssh-keygen -lf` 가 지문을 정상 출력했다. 파일은 1줄짜리 유효한 OpenSSH 공개키다. 따라서 파일 문제가 아니다.

- **가설 2 — 붙여넣은 내용이 공개키가 아니었을 것이다.** 실제 원인이었다. 등록 필드에 공개키 원문 대신 **지문(`SHA256:...`)** 을 붙여넣었다. 지문은 공개키를 해시한 요약값이라 키 자체로 쓸 수 없다.

- **조치**: 공개키 원문을 다시 복사해 등록했다.

      $ pbcopy < ~/.ssh/id_ed25519.pub
      $ pbpaste | cut -d' ' -f1
      ssh-ed25519

- **결과**: 등록 후 인증 성공 (17-5 참고)

      $ ssh -T git@github.com
      Hi dlrghks2090! You've successfully authenticated, but GitHub does not provide shell access.

- **배운 점**: 공개키와 지문은 용도가 다르다. 지문은 "이 키가 내가 아는 그 키가 맞는지" **대조**할 때 쓰고, 등록에는 `ssh-ed25519 AAAA...` 로 시작하는 원문 한 줄을 쓴다. 같은 오류가 났을 때 점검 순서는 ① `ssh-keygen -lf` 로 파일 유효성 확인 → ② 붙여넣은 값이 `ssh-` 로 시작하는지 확인 → ③ Title 칸과 Key 칸이 바뀌지 않았는지 확인이다.

### 15-6. [Linux 환경 참고] Docker 권한 거부

이번 실습 환경은 macOS라 발생하지 않았으나, Linux에서 자주 만나는 문제라 참고로 기록한다.

- **현상**: `permission denied while trying to connect to the Docker daemon socket`
- **원인**: Linux에서 Docker 소켓은 `docker` 그룹 소유이며, 해당 그룹에 속하지 않은 사용자는 접근할 수 없다.
- **조치**

      $ sudo usermod -aG docker $USER

  이후 로그아웃/로그인 또는 `newgrp docker` 로 그룹 변경을 적용한다.
- **macOS와의 차이**: macOS의 Docker Desktop은 사용자 홈 아래(`~/.docker/run/docker.sock`)에 소켓을 두므로 이 문제가 발생하지 않는다. 15-1처럼 "데몬이 꺼져 있음"이 훨씬 흔한 원인이다.

---

## 16. 미션 회고

### 가장 어려웠던 지점: 환경 변수 치환의 동작 범위를 잘못 예상한 것

포트를 환경 변수로 바꾸는 과제(보너스 4)에서 nginx 템플릿에 설명 주석을 달았는데, 결과 파일에서 주석 문장이 깨졌다.

- **가설**: 처음에는 "설정 파일의 주석은 파서가 무시하니 치환 대상도 아닐 것"이라고 생각했다.
- **확인**: `docker compose exec web cat /etc/nginx/conf.d/default.conf` 로 컨테이너 안의 **결과물**을 직접 열어 보니 주석까지 치환돼 있었다. 템플릿 원본이 아니라 렌더링된 결과를 봐야 문제가 보였다.
- **조치**: 주석에서 변수 표기를 제거했다.
- **근거와 교훈**: envsubst는 nginx 설정 문법을 이해하는 도구가 아니라 단순 텍스트 치환기다. "설정 파일이니 파서가 알아서 하겠지"라는 추측이 틀렸다. **템플릿을 다룰 때는 입력이 아니라 출력을 검증해야 한다**는 것이 이번 미션에서 가장 크게 배운 점이다.

### 두 번째로 막혔던 지점: 종료된 컨테이너에 `docker exec` 가 붙지 않음

볼륨 대조 실험을 짤 때 `docker run --name novol-test ubuntu sh -c "echo lost > /tmp/test.txt"` 로 파일을 만든 뒤 `docker exec` 로 확인하려 했으나 실패했다.

      Error response from daemon: container 88b72e13f017... is not running

- **가설**: 컨테이너가 이미 종료 상태라 `exec` 가 붙을 프로세스가 없을 것이다.
- **확인**: `docker ps -a` 에서 해당 컨테이너가 `Exited (0)` 상태임을 확인했다. `sh -c "echo ..."` 는 즉시 끝나는 명령이라 컨테이너도 곧바로 종료된다.
- **조치**: `docker run -d --name novol-test ubuntu sleep 300` 으로 컨테이너를 살려 둔 뒤 `docker exec` 로 파일을 쓰고 읽도록 실험을 재설계했다.
- **교훈**: 컨테이너의 수명은 **PID 1 프로세스의 수명과 같다.** 컨테이너는 "켜 두는 상자"가 아니라 "프로세스를 감싼 것"이라는 점을 실감했다.

### 종합

기능을 돌리는 것보다 **왜 그렇게 동작하는지 확인하는 절차**를 만드는 게 어려웠다. 특히 11번 대조 실험처럼 "되는 경우"와 "안 되는 경우"를 나란히 실행해 보니, 데이터 소실의 원인이 컨테이너 삭제가 아니라 저장 위치라는 것이 한눈에 보였다. 앞으로도 결과만 기록하지 않고 대조군을 함께 남기려 한다.

---

## 17. 보너스 과제

### 17-1. Docker Compose 기초
> **수행 내용**: 단일 서비스를 Compose로 실행

- **작성한 docker-compose.yml (web 서비스 부분)**

      services:
        web:
          build: .
          image: my-web:v1
          ports:
            - "${HOST_PORT}:${NGINX_PORT}"
          environment:
            NGINX_PORT: ${NGINX_PORT}
            APP_MODE: ${APP_MODE}

- **10번의 `docker run` 과 1:1 대응**

| `docker run` 인자 (10번) | Compose 키 | 역할 |
| :--- | :--- | :--- |
| `docker build -t my-web:v1 .` | `build: .` + `image: my-web:v1` | 빌드와 태깅 |
| `-p 8081:80` | `ports: - "${HOST_PORT}:${NGINX_PORT}"` | 포트 매핑 |
| `-e NGINX_PORT=...` | `environment:` | 환경 변수 주입 |
| `-d` | `up -d` | 백그라운드 실행 |
| `--name my-app` | (생략) | Compose가 `프로젝트명-서비스명-번호` 로 자동 명명 |

- **실행 및 접속 확인**

      $ docker compose up -d
       Network workspace-decoration_default  Created
       Container workspace-decoration-web-1  Started

      $ curl -s localhost:8081
      <h1>hello, world!</h1>

- **배움 포인트 — 왜 "문서화된 실행 설정"인가**
  10번에서는 `docker run -d -p 8081:80 --name my-app my-web:v1` 이라는 명령을 **사람이 기억하고 매번 정확히 입력**해야 했다. 인자를 하나라도 빠뜨리면 다르게 동작하는데, 그 사실이 어디에도 기록되지 않는다. Compose로 옮기면 같은 내용이 파일로 남아 ① 저장소에 커밋되어 버전 관리·코드 리뷰 대상이 되고, ② 다른 사람이 `docker compose up` 한 줄로 동일한 환경을 재현할 수 있으며, ③ 무엇이 바뀌었는지 `git diff` 로 드러난다. 실행 방법이 개인의 기억에서 저장소의 자산으로 바뀌는 것이 핵심이다.

### 17-2. Docker Compose 멀티 컨테이너
> **수행 내용**: 웹 서버 + 보조 서비스 2개를 함께 실행하고 컨테이너 간 통신 확인

- **client 서비스 정의**

      client:
        image: curlimages/curl:latest
        depends_on:
          - web
        command: ["sh", "-c", "sleep 3; curl -s http://web:${NGINX_PORT}/"]

- **두 서비스 동시 실행**

      $ docker compose up -d
       Network workspace-decoration_default    Created
       Container workspace-decoration-web-1    Started
       Container workspace-decoration-client-1 Started

      $ docker compose ps -a
      NAME                            IMAGE                    SERVICE   STATUS
      workspace-decoration-client-1   curlimages/curl:latest   client    Exited (0) 5 seconds ago
      workspace-decoration-web-1      my-web:v1                web       Up 8 seconds

- **컨테이너 간 통신 확인 (핵심 증거)**

      $ docker compose logs client
      client-1  | <h1>hello, world!</h1>

- **전용 네트워크 생성 확인**

      $ docker network ls | grep workspace
      3a67505907f1   workspace-decoration_default   bridge    local

- **web 쪽에서 본 접속 출처**

      $ docker compose logs --tail 5 web
      web-1  | 172.18.0.3 - - [...] "GET / HTTP/1.1" 200 23 "-" "curl/8.21.0" "-"
      web-1  | 172.18.0.1 - - [...] "GET / HTTP/1.1" 200 23 "-" "curl/8.7.1" "-"

- **배움 포인트 — 네트워크와 서비스 디스커버리**
  `client` 는 IP를 전혀 모르는 채 `http://web:8080` 이라는 **서비스 이름**으로 접속했고 성공했다. Compose가 프로젝트 전용 브리지 네트워크(`workspace-decoration_default`)를 만들고, 그 안에 서비스명을 DNS 이름으로 등록해 주기 때문이다. 컨테이너 IP는 재시작할 때마다 바뀌므로 IP를 하드코딩하면 곧 깨지지만, 서비스명은 안정적이다.

  또 하나 중요한 점: **`client` 는 호스트 포트 매핑이 전혀 없는데도 `web` 에 접속했다.** 위 로그에서 `172.18.0.3`(client 컨테이너)과 `172.18.0.1`(호스트 게이트웨이)로 출처가 갈리는 것이 그 증거다. 포트 매핑(`-p`)은 컨테이너끼리 통신할 때가 아니라 **호스트에서 컨테이너로 들어갈 때만** 필요하다 (14-2 참고).

### 17-3. Compose 운영 명령어 습득
> **수행 내용**: `up` / `ps` / `logs` / `down` 으로 실행·상태·로그·종료 관리

- **실행 (up)**

      $ docker compose up -d
       Container workspace-decoration-web-1  Started
       Container workspace-decoration-client-1  Started

- **상태 확인 (ps)**

      $ docker compose ps
      NAME                         IMAGE       SERVICE   STATUS         PORTS
      workspace-decoration-web-1   my-web:v1   web       Up 8 seconds   80/tcp, 0.0.0.0:8081->8080/tcp

  > 종료된 컨테이너는 `ps` 에 보이지 않는다. `client` 처럼 작업 후 끝나는 서비스를 보려면 `docker compose ps -a` 를 써야 한다.

- **로그 확인 (logs)**

      $ docker compose logs client
      client-1  | <h1>hello, world!</h1>

      $ docker compose logs --tail 5 web
      web-1  | 2026/08/05 10:29:19 [notice] 1#1: start worker process 46
      web-1  | 172.18.0.3 - - [...] "GET / HTTP/1.1" 200 23 "-" "curl/8.21.0" "-"

- **종료 (down)**

      $ docker compose down
       Container workspace-decoration-client-1  Removed
       Container workspace-decoration-web-1  Removed
       Network workspace-decoration_default  Removed

- **종료 후 상태 확인**

      $ docker compose ps -a
      NAME      IMAGE     COMMAND   SERVICE   CREATED   STATUS    PORTS

      $ docker network ls | grep workspace
      (출력 없음 — 네트워크도 함께 삭제됨)

      $ curl -sI --max-time 3 localhost:8081
      (접속 불가 - 컨테이너 종료됨)

- **`down` 과 `down -v` 의 차이 (주의)**

| 명령 | 컨테이너 | 네트워크 | 볼륨 |
| :--- | :--- | :--- | :--- |
| `docker compose down` | 삭제 | 삭제 | **유지** |
| `docker compose down -v` | 삭제 | 삭제 | **삭제** |

  11번에서 확인했듯 볼륨은 데이터의 마지막 보루다. `-v` 를 습관적으로 붙이면 영속 데이터가 통째로 날아간다.

- **배움 포인트 — 상태 확인 루틴**
  1. `docker compose ps -a` 로 **무엇이 떠 있고 무엇이 죽었는지** 먼저 본다.
  2. 죽어 있다면 `docker compose logs <서비스>` 로 **왜 죽었는지** 확인한다.
  3. 설정을 고쳤으면 `docker compose up -d` 로 재기동한다 (바뀐 서비스만 재생성된다).
  4. 이미지 자체를 고쳤으면 `--build` 를 붙인다.

### 17-4. 환경 변수 활용
> **수행 내용**: 환경 변수를 주입해 이미지 재빌드 없이 서버 리슨 포트를 변경

- **템플릿 파일 (default.conf.template)**

      server {
          # 아래 리슨 포트는 컨테이너 기동 시 환경 변수 값으로 치환된다.
          listen       ${NGINX_PORT};
          server_name  localhost;

          location / {
              root   /usr/share/nginx/html;
              index  index.html;
          }
      }

- **환경 변수 파일 (.env.example → .env)**

      HOST_PORT=8081
      NGINX_PORT=8080
      APP_MODE=production

- **Compose가 .env 를 읽어 치환한 결과**

      $ docker compose config
      services:
        client:
          command: [sh, -c, "sleep 3; curl -s http://web:8080/"]
        web:
          environment:
            APP_MODE: production
            NGINX_PORT: "8080"
          ports:
            - target: 8080
              published: "8081"

- **컨테이너 안에 실제로 주입됐는지 확인**

      $ docker compose exec web env | grep -E "NGINX_PORT|APP_MODE"
      APP_MODE=production
      NGINX_PORT=8080

- **템플릿이 치환된 결과 확인**

      $ docker compose exec web cat /etc/nginx/conf.d/default.conf
      server {
          # 아래 리슨 포트는 컨테이너 기동 시 환경 변수 값으로 치환된다.
          listen       8080;
          server_name  localhost;

          location / {
              root   /usr/share/nginx/html;
              index  index.html;
          }
      }

- **핵심 시연: 이미지를 다시 빌드하지 않고 리슨 포트 변경**

  변경 전

      $ grep NGINX_PORT .env
      NGINX_PORT=8080

      $ docker compose exec web cat /etc/nginx/conf.d/default.conf | grep listen
          listen       8080;

      $ docker compose ps --format "table {{.Service}}\t{{.Ports}}"
      SERVICE   PORTS
      web       80/tcp, 0.0.0.0:8081->8080/tcp

  `.env` 의 `NGINX_PORT` 만 8090으로 수정한 뒤 재기동 (`--build` 없음)

      $ docker compose up -d
       Container workspace-decoration-web-1  Recreated
       Container workspace-decoration-web-1  Started

  변경 후

      $ docker compose exec web cat /etc/nginx/conf.d/default.conf | grep listen
          listen       8090;

      $ docker compose ps --format "table {{.Service}}\t{{.Ports}}"
      SERVICE   PORTS
      web       80/tcp, 0.0.0.0:8081->8090/tcp

      $ curl -sI localhost:8081 | head -1
      HTTP/1.1 200 OK

  이미지는 다시 빌드되지 않았다.

      $ docker images my-web --format "{{.Repository}}:{{.Tag}} 생성시각={{.CreatedSince}}"
      my-web:v1 생성시각=2 minutes ago

- **배움 포인트 — 설정과 코드의 분리**
  포트 번호를 이미지 안에 하드코딩했다면 포트를 바꿀 때마다 재빌드가 필요했을 것이다. 설정을 환경 변수로 빼면 **같은 이미지 하나로 개발·스테이징·운영 환경을 모두 커버**할 수 있다. 위 시연에서 컨테이너 내부 리슨 포트가 8080→8090으로 바뀌었는데도 호스트 접속 주소(`localhost:8081`)는 그대로였다는 점이 이를 잘 보여준다. 사용자에게 보이는 인터페이스는 유지한 채 내부 구성만 교체한 셈이다.

  또한 실제 값이 담긴 `.env` 는 `.gitignore` 로 제외하고 `.env.example` 만 커밋했다. 설정의 **구조**는 공유하되 **값**은 각자 환경에 두는 방식이다.

### 17-5. GitHub SSH 키 설정
> **수행 내용**: HTTPS 대신 SSH로 푸시가 가능하도록 키 등록 및 동작 확인

- **1. 키 생성** (개인키는 로컬에만 두고 절대 저장소에 올리지 않는다)

      $ ssh-keygen -t ed25519 -C "****@gmail.com"

      $ ls -1 ~/.ssh
      id_ed25519
      id_ed25519.pub
      known_hosts

- **2. 생성된 키 확인 (지문만 기록)**

      $ ssh-keygen -lf ~/.ssh/id_ed25519.pub
      256 SHA256:McCE60hNY/KM/r+GbuS1N9ScwfZClRge96AnzP9xSo8 ****@gmail.com (ED25519)

- **3. 공개키 복사 후 GitHub에 등록** — https://github.com/settings/keys 의 **New SSH key**

      $ pbcopy < ~/.ssh/id_ed25519.pub

  등록할 내용은 `ssh-ed25519 AAAA...` 로 시작하는 **한 줄 전체**다. 이 단계에서 형식 오류를 만났고, 원인과 해결은 15-5에 기록했다.

- **4. 인증 확인**

      $ ssh -T git@github.com
      Hi dlrghks2090! You've successfully authenticated, but GitHub does not provide shell access.

  > 종료 코드는 `1` 이지만 정상이다. GitHub은 셸 접속을 제공하지 않으므로 인증에 성공해도 세션이 바로 끊긴다. 판단 기준은 종료 코드가 아니라 `successfully authenticated` 메시지다.

- **5. 원격 저장소를 SSH로 전환**

      $ git remote -v
      origin	https://github.com/dlrghks2090/workspace-decoration.git (fetch)
      origin	https://github.com/dlrghks2090/workspace-decoration.git (push)

      $ git remote set-url origin git@github.com:dlrghks2090/workspace-decoration.git

      $ git remote -v
      origin	git@github.com:dlrghks2090/workspace-decoration.git (fetch)
      origin	git@github.com:dlrghks2090/workspace-decoration.git (push)

- **6. SSH 경로로 실제 원격 통신 검증**

      $ git ls-remote origin
      34fe8435622a73b667ba56ec0e19e96a536fdd60	HEAD
      34fe8435622a73b667ba56ec0e19e96a536fdd60	refs/heads/main

      $ git fetch origin
      $ git status -sb | head -1
      ## main...origin/main

  > 자격 증명을 묻지 않고 원격 저장소의 참조를 그대로 읽어 왔다. HTTPS였다면 토큰을 요구했을 지점이다. 13번 섹션의 `git remote -v` 출력이 HTTPS인 것은 그 시점의 실제 상태이며, 이 단계에서 SSH로 전환했다.

- **배움 포인트 — 인증 방식의 차이와 보안 습관**

| 항목 | HTTPS | SSH |
| :--- | :--- | :--- |
| 인증 수단 | 계정 비밀번호 또는 Personal Access Token | 공개키/개인키 쌍 |
| 자격 증명 전달 | 요청할 때마다 토큰을 서버에 제시 | 개인키는 로컬을 벗어나지 않고, 서명으로만 증명 |
| 유출 시 위험 | 토큰이 유출되면 그대로 도용 가능 | 개인키에 passphrase를 걸면 파일만으로는 사용 불가 |
| 폐기 방법 | 토큰 재발급 | GitHub에서 해당 공개키만 삭제 |

  **보고서 기재 원칙**: 개인키(`id_ed25519`)는 어떤 경우에도 기록하지 않는다. 공개키도 전문 대신 지문(`ssh-keygen -lf`)만 남긴다.

  **현재 키의 한계 (개선 예정)**: 이번에 생성한 키는 passphrase를 걸지 않았다. 따라서 위 표의 "개인키에 passphrase를 걸면 파일만으로는 사용 불가"라는 이점은 지금 이 키에는 적용되지 않으며, `~/.ssh/id_ed25519` 파일이 유출되면 그대로 사용될 수 있는 상태다. 키를 다시 만들 필요 없이 아래 명령으로 passphrase를 추가할 수 있고, 공개키는 변하지 않으므로 GitHub 재등록도 필요 없다.

      $ ssh-keygen -p -f ~/.ssh/id_ed25519

---

## 18. 보안 및 개인정보 보호

### 적용한 마스킹 규칙

| 대상 | 처리 | 예시 |
| :--- | :--- | :--- |
| 이메일 주소 | 계정 부분 마스킹 | `user.email=****@gmail.com` |
| 홈 디렉토리 경로 | 계정명 마스킹 | `/Users/****/Desktop` |
| `ls -l` / `lsof` 의 소유자 열 | 계정명 마스킹 | `-rw------- 1 **** staff` |
| GitHub 사용자명·저장소 URL | 유지 | 공개 저장소 주소라 비공개 정보가 아님 |
| SSH 개인키 | **기재 금지** | 파일 자체를 저장소에 두지 않음 |

### .gitignore 로 차단한 항목

      # macOS 시스템 파일
      .DS_Store

      # 로컬 환경 변수 파일 (실제 값은 커밋하지 않는다)
      # 저장소에는 .env.example 만 커밋한다.
      .env

      # 에디터/IDE 설정
      .vscode/
      .idea/

- **차단 동작 검증**

      $ git check-ignore -v .env
      .gitignore:6:.env	.env

      $ git status --short
      ?? .env.example
      ?? .gitignore
      ?? Dockerfile
      ?? default.conf.template
      ?? docker-compose.yml

  `.env` 는 실제로 존재하지만 `git status` 의 추적 대상에 나타나지 않는다. 설정 구조를 공유하는 `.env.example` 만 커밋 대상이 된다.

### 체크리스트
- [x] 로그 내 이메일·홈 경로 등 개인 식별 정보 마스킹 처리 완료
- [x] `.gitignore` 파일 생성 및 `.env`·시스템 파일 업로드 차단 검증 완료
- [x] 실제 설정 값(`.env`)과 예시(`.env.example`) 분리 완료
- [x] SSH 개인키를 저장소·문서 어디에도 기재하지 않음
