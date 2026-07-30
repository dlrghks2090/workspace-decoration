# 🛠️ Mission: 개발 워크스테이션 구축 및 환경 자동화

본 프로젝트는 리눅스 터미널 조작, 권한 관리, Docker를 이용한 컨테이너화, 그리고 Git을 통한 버전 관리 환경을 구축하는 과정을 기록한 기술 문서입니다.

---

## 1. 실행 환경 (Environment)
| 항목 | 상세 내용 |
| :--- | :--- |
| **OS** | [예: Ubuntu 22.04 LTS / macOS Sonoma] |
| **Shell** | [예: bash / zsh] |
| **Docker** | [예: Docker Desktop 4.2x / Engine 26.x] |
| **Git** | [예: 2.4x.x] |

---

## 2. 수행 체크리스트 (Checklist)
- [x] 터미널 기본 조작 및 폴더 구조 설계
- [x] 파일 및 디렉토리 권한 설정 (chmod)
- [x] Docker 설치 및 데몬 상태 점검
- [x] `hello-world` 및 `ubuntu` 이미지 실행 테스트
- [x] 커스텀 `Dockerfile` 작성 및 이미지 빌드
- [x] 포트 매핑(Port Mapping)을 통한 외부 접속 검증 (2회 이상)
- [x] Docker 볼륨(Volume)을 활용한 데이터 영속성 증명
- [x] 로컬 Git 설정 및 GitHub 원격 저장소 연동

---

## 3. 핵심 개념 자기 설명 (Self-Explanation)
1. **절대 경로 vs 상대 경로**: 
   - 절대 경로는 루트(`/`)부터 시작하는 고유 주소이며, 상대 경로는 현재 위치(`.`)를 기준으로 한 경로입니다.
2. **파일 권한 (755 vs 644)**: 
   - 755는 소유자에게 모든 권한을, 644는 소유자에게만 쓰기 권한을 부여합니다.
3. **Docker 이미지 vs 컨테이너**: 
   - 이미지는 실행 파일/설정의 묶음(설계도)이고, 컨테이너는 이를 실행한 상태(실체)입니다.
4. **포트 매핑의 필요성**: 
   - 격리된 컨테이너 내부 네트워크 포트를 호스트 PC의 포트와 연결하여 외부 접속을 허용합니다.
5. **Docker 볼륨의 역할**: 
   - 컨테이너 삭제 시 사라지는 데이터를 호스트 저장소나 별도 볼륨에 저장하여 영구 보존합니다.
6. **Git과 GitHub의 차이**: 
   - Git은 로컬 버전 관리 도구이며, GitHub은 이를 공유하고 협업하는 원격 플랫폼입니다.

---

## 4. 수행 로그 및 증거 (Execution Logs)

### 4.1 터미널 조작 및 권한 설정
```bash
# 1. 작업 디렉토리 생성 및 이동
$ mkdir -p ~/codyssey/workstation && cd ~/codyssey/workstation

# 2. 파일 생성 및 권한 변경 (644 -> 755)
$ touch script.sh
$ ls -l script.sh
-rw-r--r-- 1 user user 0 May 20 10:00 script.sh

$ chmod 755 script.sh
$ ls -l script.sh
-rwxr-xr-x 1 user user 0 May 20 10:00 script.sh

```

### 4.2 Docker 실습 및 커스텀 이미지 빌드
[Dockerfile]
```bash
FROM nginx:alpine
LABEL maintainer="yourname <email@example.com>"
# 기본 인덱스 페이지 교체
COPY ./html/index.html /usr/share/nginx/html/index.html
EXPOSE 80
```

[빌드 및 실행 로그]
```bash
# 이미지 빌드
$ docker build -t my-web-app:1.0 .

# 1차 실행 (8080 포트)
$ docker run -d -p 8080:80 --name web-1 my-web-app:1.0

# 2차 실행 (8081 포트)
$ docker run -d -p 8081:80 --name web-2 my-web-app:1.0

# 컨테이너 상태 확인
$ docker ps
```

📸 증거 스크린샷 (브라우저 접속)
Browser Access
(주소창의 localhost:8080과 응답 화면이 포함되어야 함)

### 4.3 볼륨 영속성 검증

# 1. 볼륨 생성 및 데이터 쓰기
```bash
$ docker volume create my-data
$ docker run -it --rm -v my-data:/app ubuntu sh -c "echo 'Hello Docker' > /app/test.txt"
```

# 2. 컨테이너 삭제 후 새 컨테이너에서 데이터 확인
```bash
$ docker run -it --rm -v my-data:/app ubuntu cat /app/test.txt
Hello Docker
```
---

## 5. Git & GitHub 설정
# Git 사용자 설정 (이메일 마스킹 처리)
```bash
$ git config --global user.name "YourName"
$ git config --global user.email "y***@example.com"
```

# 원격 저장소 연결 확인
```bash
$ git remote -v
origin  https://github.com/YourID/workstation-mission.git (fetch)
origin  https://github.com/YourID/workstation-mission.git (push)
```

---

## 6. 트러블슈팅 및 회고
이슈: Docker 빌드 중 COPY 명령에서 경로 오류 발생.
원인: Dockerfile이 위치한 경로가 아닌 상위 경로에서 빌드를 시도함.
해결: 빌드 컨텍스트 위치를 .으로 정확히 지정하여 해결함.
회고: 이번 미션을 통해 인프라의 기본인 터미널과 컨테이너 환경의 중요성을 깨달았습니다. 특히 볼륨을 통한 데이터 보존 방식이 인상적이었습니다.


### 💡 작성 가이드 (튜터의 팁)
1.  **이미지 경로**: `screenshots`라는 폴더를 만들고 그 안에 캡처본을 넣은 뒤, 위 마크다운 코드의 `./screenshots/파일명.png` 부분을 실제 파일명과 맞추세요.
2.  **마스킹**: `git config` 결과나 로그에 개인 정보(토큰, 실제 이메일 등)가 있다면 `***`로 가려주는 센스를 보여주세요.
3.  **가독성**: 코드 블록(```)을 사용하면 평가자가 명령어를 복사해서 테스트해보기 매우 편리합니다.

이 템플릿은 깔끔함과 전문성을 동시에 잡을 수 있도록 설계되었습니다. 실습 내용을 잘 채워 넣어 멋진 결과물 만드시길 바랍니다! 🚀