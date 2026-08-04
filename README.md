# 🚀 개발 워크스테이션 구축 및 Docker/Git 실습 최종 보고서

## 1. 프로젝트 개요
- **미션 목표**: 터미널 환경 설정, Docker 컨테이너 운영, 커스텀 이미지 제작 및 Git/GitHub 연동 과정을 문서화하여 표준 개발 워크스테이션 구축을 완료함.

## 2. 실행 환경

| 항목 | 상세 내용 |
| :--- | :--- |
| **OS** | [예: Ubuntu 22.04 LTS / macOS Sonoma] |
| **Shell** | [예: bash / zsh] |
| **Docker** | [예: Docker Desktop 4.2x / Engine 26.x] |
| **Git** | [예: 2.4x.x] |

## 3. 수행 항목 체크리스트
- [x] **터미널**: 기본 조작 및 파일 관리 완료
- [x] **권한**: 파일/디렉토리 권한 변경 및 전후 비교 기록 완료
- [x] **Docker 설치**: 버전 확인 및 데몬 상태 점검 완료
- [x] **Docker 운영**: 이미지/컨테이너 관리 및 로그 확인 완료
- [x] **컨테이너 실습**: hello-world 및 ubuntu 내부 진입 실습 완료
- [x] **Dockerfile**: 커스텀 이미지 빌드 및 컨테이너 실행 성공
- [x] **포트 매핑**: 호스트 포트 연결 및 서비스 접속 증거 확보
- [x] **볼륨 영속성**: 컨테이너 삭제 후 데이터 유지 검증 완료
- [x] **Git/GitHub**: 사용자 정보 설정 및 GitHub 저장소 연동 완료
- [x] **보안**: 민감 정보 마스킹 및 개인정보 보호 준수 완료

---

## 4. 터미널 조작 로그 기록
> **수행 내용**: 위치 확인, 디렉토리 생성/이동, 파일 생성/확인/복사/삭제

- **현재 위치 확인**

      $ pwd
      /Users/dlrghks20902090/Desktop

- **디렉토리 생성**

      $ mkdir kan
      $ ls
      kan

- **디렉토리 이동**

      $ dlrghks20902090@c3r2s7 Desktop % cd kan
      $ dlrghks20902090@c3r2s7 kan % 

- **디렉토리 삭제**

      dlrghks20902090@c3r2s7 Desktop % rm -r kan

- **파일 생성**

      $ vim memo.txt
      $ echo "Terminal Practice" > memo.txt

- **파일 이동**

      $ vim memo.txt
      $ echo "Terminal Practice" > memo.txt

- **파일 내용 확인**

      $ cat memo.txt

- **파일 복사**

      $ cp memo.txt backup.txt

- **파일 삭제**

      $ rm memo.txt

---

## 5. 권한 실습 및 증거 기록
> **수행 내용**: 파일/디렉토리 권한 변경 (변경 전후 표 참고)

- **파일 권한 변경**

      $ chmod 600 note.txt

- **디렉토리 권한 변경**

      $ chmod 700 workspace

| 대상 | 변경 전 | 변경 후 |
| :--- | :--- | :--- |
| `note.txt` | `-rw-r--r--` | `-rw-------` |
| `workspace` | `drwxr-xr-x` | `drwx------` |

---

## 6. Docker 설치 및 기본 점검
> **수행 내용**: 버전 확인 및 데몬 상태 점검

- **Docker 버전 확인**

      $ docker --version

- **Docker 상세 버전 확인**

      $ docker version

- **Docker 데몬 동작 확인**

      $ docker info | grep "Server Version"

- **Docker 서비스 상태 확인**

      $ systemctl status docker

---

## 7. Docker 기본 운영
> **수행 내용**: 이미지 다운로드 및 목록 확인

- **이미지 다운로드**

      $ docker pull nginx

- **이미지 목록 확인**

      $ docker images

---

## 8. 컨테이너 실행 실습
> **수행 내용**: ubuntu 컨테이너 내부 진입

- **ubuntu 컨테이너 실행**

      $ docker run -it ubuntu /bin/bash

---

## 9. 커스텀 Dockerfile 제작 및 포트 매핑
> **수행 내용**: 이미지 빌드, 컨테이너 실행, 접속 검증 (베이스: nginx:latest)

- **커스텀 이미지 빌드**

      $ docker build -t my-web:v1 .

- **컨테이너 실행 (포트 매핑)**

      $ docker run -d -p 8081:80 --name my-app my-web:v1

- **포트 접속 검증**

      $ curl -I localhost:8081

---

## 10. Docker 볼륨 영속성 검증
> **수행 내용**: 볼륨 생성 → 데이터 저장 → 데이터 유지 확인

- **볼륨 생성**

      $ docker volume create my-vol

- **볼륨에 데이터 저장**

      $ docker run -v my-vol:/data ubuntu sh -c "echo 'saved' > /data/test.txt"

- **데이터 유지 확인**

      $ docker run --rm -v my-vol:/data ubuntu cat /data/test.txt

---

## 11. Git 설정 및 GitHub 연동
> **수행 내용**: 사용자 정보 및 원격 저장소 확인

- **Git 사용자 정보 확인**

      $ git config --list

- **GitHub 원격 저장소 확인**

      $ git remote -v

---

## 12. 트러블슈팅
> **문제/해결**: Docker 권한 거부(Permission Denied) → 사용자 그룹 추가로 해결

- **사용자 그룹 추가**

      $ sudo usermod -aG docker $USER

---

## 13. 보안 및 개인정보 보호
- [x] 로그 내 비밀번호, API 키 등 민감 정보 마스킹 처리 완료
- [x] `.gitignore` 파일로 불필요한 설정 파일 업로드 차단 조치 완료