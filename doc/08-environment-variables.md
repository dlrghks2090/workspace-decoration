# 08. 환경 변수와 설정 분리

> 보고서 대응: [17-4 환경 변수 활용](../README.md), 4번 디렉토리 설계 기준

---

## 1. 왜 설정을 분리하는가

포트 번호를 코드나 이미지 안에 하드코딩하면 이런 일이 생긴다.

```
개발 환경   포트 8080  →  이미지 A 빌드
스테이징    포트 9000  →  이미지 B 빌드
운영        포트 80    →  이미지 C 빌드
```

**같은 코드인데 이미지가 3개**다. 테스트한 이미지와 운영에 올라가는 이미지가 다르므로, "개발에서는 됐는데"가 다시 발생한다.

설정을 밖으로 빼면:

```
이미지 1개  +  개발용 설정   →  개발 환경
           +  운영용 설정   →  운영 환경
```

**테스트한 그 이미지 그대로 운영에 올라간다.** 이것이 12-factor app의 "Config" 원칙이다.

---

## 2. 환경 변수를 주입하는 경로

Docker에서 환경 변수를 넣는 방법은 여러 가지다.

| 방법 | 문법 | 시점 |
| :--- | :--- | :--- |
| Dockerfile `ENV` | `ENV NGINX_PORT=80` | 이미지에 기본값으로 구움 |
| `docker run -e` | `-e NGINX_PORT=8080` | 실행 시 |
| `--env-file` | `--env-file .env` | 실행 시 (파일에서) |
| Compose `environment:` | `NGINX_PORT: 8080` | 실행 시 |
| Compose `env_file:` | `env_file: .env` | 실행 시 (파일에서) |
| 셸 환경 변수 | `export NGINX_PORT=8080` | Compose 파일 치환에 사용 |

### 우선순위 (뒤가 이김)

```
1. Dockerfile ENV              ← 가장 약함 (기본값)
2. Compose env_file
3. Compose environment
4. docker run -e / 셸 환경 변수  ← 가장 강함
```

보고서의 설계가 이 구조를 그대로 쓴다.

```dockerfile
# Dockerfile — 기본값
ENV NGINX_PORT=80
```

```yaml
# docker-compose.yml — 덮어쓰기
environment:
  NGINX_PORT: ${NGINX_PORT}    # .env 에서 8080
```

**기본값이 왜 필요한가?** `docker run` 만으로 실행할 때(보고서 10번) 변수가 비어 있으면 nginx 설정이 `listen ;` 이 되어 기동에 실패한다. Dockerfile의 `ENV NGINX_PORT=80` 이 그 안전망이다.

---

## 3. `.env` 파일 — 두 가지 역할 구분

여기가 가장 헷갈리는 부분이다. Compose에서 `.env` 는 **두 가지 다른 일**을 한다.

### 역할 A — Compose 파일 자체의 변수 치환

```yaml
ports:
  - "${HOST_PORT}:${NGINX_PORT}"    # ← .env 값으로 치환됨
```

Compose가 파일을 읽을 때 `${...}` 를 `.env` 값으로 바꾼다. **이건 컨테이너와 무관하다.** YAML 파일을 만들 때 쓰는 것이다.

### 역할 B — 컨테이너 안의 환경 변수

```yaml
environment:
  NGINX_PORT: ${NGINX_PORT}    # ← 컨테이너 안에 전달됨
```

`environment:` 에 명시해야 컨테이너 안에서 `echo $NGINX_PORT` 로 보인다.

### 실험으로 확인

```yaml
services:
  web:
    image: nginx
    ports:
      - "${HOST_PORT}:80"      # 역할 A만 사용
```

이 경우 `.env` 에 `HOST_PORT=8081` 이 있어도 **컨테이너 안에는 `HOST_PORT` 가 없다.** 포트 매핑에만 쓰였을 뿐이다.

보고서 17-4에서 두 역할을 모두 확인했다.

```bash
# 역할 A 확인 — Compose 파일 치환 결과
docker compose config
# ports:
#   - target: 8080
#     published: "8081"      ← .env 값이 들어감

# 역할 B 확인 — 컨테이너 안의 변수
docker compose exec web env | grep -E "NGINX_PORT|APP_MODE"
# APP_MODE=production
# NGINX_PORT=8080
```

---

## 4. `.env` 와 `.env.example` 분리

보고서가 채택한 방식이다.

```
.env.example   →  커밋한다   (설정의 "구조"를 공유)
.env           →  커밋 안 함 (실제 "값"은 각자)
```

```gitignore
# .gitignore
.env
```

### 왜 이렇게 하나

`.env` 에는 보통 DB 비밀번호, API 키 같은 비밀이 들어간다. 이게 저장소에 올라가면:

- 저장소 접근 권한이 있는 모두가 운영 비밀번호를 본다
- **커밋 이력에 영원히 남는다.** 나중에 지워도 `git log` 로 복구 가능하다
- 공개 저장소면 자동 스캐너가 몇 분 안에 찾아낸다

`.env.example` 은 어떤 변수가 필요한지 알려주는 명세다.

```bash
# .env.example
HOST_PORT=8081
NGINX_PORT=8080
APP_MODE=production
```

### 그래서 클론 후 첫 단계가 이것이다

```bash
cp .env.example .env
docker compose up -d
```

이 단계를 빠뜨리면 Compose가 변수를 못 찾아 실패한다. 보고서 13번의 재현 절차에 이 줄이 들어 있는 이유다.

### 검증

```bash
git check-ignore -v .env
# .gitignore:6:.env	.env      ← 실제로 제외됨

git status --short
# ?? .env.example              ← .env 는 안 보임
```

> **주의**: `.gitignore` 는 **이미 추적 중인 파일에는 효과가 없다.** 실수로 커밋한 뒤에 `.gitignore` 에 추가해도 계속 추적된다. `git rm --cached .env` 로 추적을 끊어야 하고, 이미 푸시했다면 **비밀은 유출된 것으로 간주하고 교체**해야 한다.

---

## 5. nginx 템플릿 실습 분석

보고서 17-4의 핵심 시연을 단계별로 뜯어본다.

### 구조

```
default.conf.template          (템플릿, ${NGINX_PORT} 포함)
        ↓ Dockerfile COPY
/etc/nginx/templates/default.conf.template   (이미지 안)
        ↓ 컨테이너 기동 시 envsubst
/etc/nginx/conf.d/default.conf               (치환 완료)
        ↓
nginx 가 이 설정으로 기동
```

### 템플릿

```nginx
server {
    # 아래 리슨 포트는 컨테이너 기동 시 환경 변수 값으로 치환된다.
    listen       ${NGINX_PORT};
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html;
    }
}
```

### 결과 확인

```bash
docker compose exec web cat /etc/nginx/conf.d/default.conf
# server {
#     # 아래 리슨 포트는 컨테이너 기동 시 환경 변수 값으로 치환된다.
#     listen       8080;        ← 치환됨
```

### 핵심 시연 — 재빌드 없이 포트 변경

```bash
# 변경 전
grep NGINX_PORT .env                    # NGINX_PORT=8080
docker compose exec web cat /etc/nginx/conf.d/default.conf | grep listen
#     listen       8080;
docker compose ps --format "table {{.Service}}\t{{.Ports}}"
# web       80/tcp, 0.0.0.0:8081->8080/tcp

# .env 에서 NGINX_PORT 만 8090으로 수정 후
docker compose up -d                    # --build 없음!

# 변경 후
docker compose exec web cat /etc/nginx/conf.d/default.conf | grep listen
#     listen       8090;                ← 바뀌었다
docker compose ps --format "table {{.Service}}\t{{.Ports}}"
# web       80/tcp, 0.0.0.0:8081->8090/tcp

curl -sI localhost:8081 | head -1
# HTTP/1.1 200 OK                       ← 호스트 접속 주소는 그대로

docker images my-web --format "{{.Repository}}:{{.Tag}} {{.CreatedSince}}"
# my-web:v1 2 minutes ago               ← 재빌드 안 됨
```

### 여기서 배울 점

**내부 구성이 바뀌었는데 사용자에게 보이는 인터페이스는 그대로다.**

```
사용자가 접속하는 주소:  localhost:8081     (변화 없음)
컨테이너 내부 리슨 포트:  8080 → 8090       (변경됨)
이미지:                  재빌드 없음
```

이것이 설정과 코드를 분리했을 때 얻는 실질적 이득이다.

---

## 6. envsubst의 동작 범위 — 보고서 15-4 사례

`envsubst` 는 **단순 텍스트 치환기**다. nginx 설정 문법을 이해하지 못한다.

### 무엇이 잘못됐나

처음 템플릿에 이렇게 썼다.

```nginx
# ${NGINX_PORT} 는 컨테이너 기동 시 환경 변수 값으로 치환된다.
listen ${NGINX_PORT};
```

결과물:

```nginx
# 8080 는 컨테이너 기동 시 환경 변수 값으로 치환된다.    ← 주석이 깨짐
listen 8080;
```

주석 안의 `${NGINX_PORT}` 도 치환 대상이었다.

### 왜 이런 일이

```
envsubst 는 파일을 텍스트로만 본다.
"이건 주석이니 건너뛰자" 같은 판단을 하지 않는다.
${...} 패턴이 보이면 무조건 바꾼다.
```

### 교훈

**템플릿을 다룰 때는 입력이 아니라 출력을 검증한다.**

```bash
docker compose exec web cat /etc/nginx/conf.d/default.conf
```

템플릿 원본만 봐서는 문제가 안 보인다. 렌더링된 결과를 열어봐야 보인다.

### nginx 이미지의 envsubst 특성

`envsubst` 를 인자 없이 쓰면 **모든** 환경 변수를 치환한다. nginx 설정에는 `$host`, `$uri`, `$remote_addr` 같은 자체 변수가 흔하므로, 그대로 두면 설정이 깨질 수 있다. 그래서 nginx 이미지의 스크립트는 **치환할 변수 목록을 명시적으로 넘긴다.**

```bash
# 20-envsubst-on-templates.sh 내부 동작 (요약)
defined_envs=$(printf '${%s} ' $(awk 'END { for (name in ENVIRON) print name }' </dev/null))
envsubst "$defined_envs" < template > output
```

목록은 **현재 정의된 환경 변수 전부**다. 실제로 어떻게 걸러지는지 확인해 보면:

```bash
export NGINX_PORT=8080
echo 'A=${NGINX_PORT}  B=$NGINX_PORT  C=$host  D=$remote_addr' | envsubst '${NGINX_PORT}'
# A=8080  B=8080  C=$host  D=$remote_addr
```

여기서 두 가지를 읽어야 한다.

**① `$host` 가 살아남은 이유는 형태가 아니라 이름 때문이다.** `${}` 를 안 써서가 아니다. 위 출력의 `B=8080` 을 보면 중괄호 없는 `$NGINX_PORT` 도 똑같이 치환됐다. `$host` 가 무사한 건 **`host` 라는 이름의 환경 변수가 없어서** 목록에 안 들어갔기 때문이다.

**② 뒤집으면 위험이 보인다.** `host` 나 `uri` 라는 환경 변수를 만들면 nginx의 `$host`, `$uri` 가 치환돼 설정이 깨진다. 환경 변수 이름에 `NGINX_PORT` 처럼 접두어를 붙이는 관습에는 이런 이유도 있다.

> 스크립트는 `NGINX_ENVSUBST_FILTER` 환경 변수도 지원한다. 값을 주면 그 정규식에 맞는 이름만 목록에 넣으므로, 치환 대상을 더 좁힐 수 있다.

---

## 7. 비밀 관리 — 환경 변수의 한계

환경 변수는 편리하지만 **비밀 보관에는 취약**하다.

```bash
docker inspect my-app | grep -A5 '"Env"'
# "Env": [
#     "DB_PASSWORD=supersecret",     ← 누구나 볼 수 있다
# ]
```

| 문제 | 설명 |
| :--- | :--- |
| `docker inspect` 로 노출 | 컨테이너 접근 권한만 있으면 조회 가능 |
| 로그에 찍힐 위험 | 에러 로그가 환경 변수를 덤프하는 경우 |
| 자식 프로세스에 상속 | 의도치 않은 전파 |
| Dockerfile `ENV` 는 이미지에 영구 | 이미지를 받은 누구나 조회 가능 |

### 대안

| 방법 | 용도 |
| :--- | :--- |
| Docker secrets | Swarm/Compose에서 파일로 마운트 |
| 클라우드 secret 관리 | AWS Secrets Manager, GCP Secret Manager 등 |
| 파일 마운트 | 비밀을 파일로 두고 볼륨 마운트, 권한 `600` |

**학습·개발 단계에서는 `.env` + `.gitignore` 로 충분하다.** 다만 "환경 변수는 완전한 비밀 보관 수단이 아니다"라는 점은 알고 있어야 한다.

---

## 8. 직접 해보기

```bash
mkdir ~/Desktop/env-practice && cd ~/Desktop/env-practice

echo '<h1>env test</h1>' > index.html

cat > default.conf.template <<'EOF'
server {
    listen       ${NGINX_PORT};
    server_name  localhost;
    location / {
        root   /usr/share/nginx/html;
        index  index.html;
    }
}
EOF

cat > Dockerfile <<'EOF'
FROM nginx:latest
ENV NGINX_PORT=80
COPY index.html /usr/share/nginx/html/index.html
COPY default.conf.template /etc/nginx/templates/default.conf.template
EOF

cat > docker-compose.yml <<'EOF'
services:
  web:
    build: .
    image: envtest:v1
    ports:
      - "${HOST_PORT}:${NGINX_PORT}"
    environment:
      NGINX_PORT: ${NGINX_PORT}
      APP_MODE: ${APP_MODE}
EOF

cat > .env.example <<'EOF'
HOST_PORT=9091
NGINX_PORT=8080
APP_MODE=development
EOF

echo ".env" > .gitignore

# 1. .env 없이 실행하면 실패한다
docker compose config           # 경고 발생

# 2. 예시에서 복사
cp .env.example .env

# 3. 치환 결과 확인
docker compose config | grep -A3 ports

# 4. 실행
docker compose up -d
curl -s localhost:9091

# 5. 컨테이너 안의 환경 변수 확인
docker compose exec web env | grep -E "NGINX_PORT|APP_MODE"

# 6. 치환된 설정 파일 확인
docker compose exec web cat /etc/nginx/conf.d/default.conf

# 7. 핵심 실험 — 재빌드 없이 내부 포트 변경
sed -i '' 's/NGINX_PORT=8080/NGINX_PORT=8090/' .env
docker compose up -d                      # --build 없음
docker compose exec web cat /etc/nginx/conf.d/default.conf | grep listen
# listen       8090;                       ← 바뀜
curl -sI localhost:9091 | head -1
# HTTP/1.1 200 OK                          ← 접속 주소는 그대로

# 8. Dockerfile 기본값 확인 — Compose 없이 실행
docker run -d -p 9092:80 --name envtest-default envtest:v1
curl -s localhost:9092                     # ENV 기본값 80으로 동작

# 9. 정리
docker compose down
docker rm -f envtest-default
docker rmi envtest:v1
cd ~/Desktop && rm -r env-practice
```

**확인 문제**

1. `.env` 에 `HOST_PORT=8081` 이 있고 Compose의 `environment:` 에는 없다. 컨테이너 안에서 `echo $HOST_PORT` 는?
2. Dockerfile의 `ENV NGINX_PORT=80` 을 지우면 `docker run` 실행 시 무슨 일이?
3. `.env` 를 실수로 커밋한 뒤 `.gitignore` 에 추가했다. 해결되나?

<details>
<summary>답</summary>

1. 비어 있다. `.env` 는 Compose 파일의 `${}` 치환에만 쓰였고, 컨테이너에 전달되려면 `environment:` 에 명시해야 한다.
2. `NGINX_PORT` 가 비어서 템플릿이 `listen ;` 로 치환되고 nginx가 설정 오류로 기동에 실패한다.
3. 해결되지 않는다. `.gitignore` 는 추적되지 않는 파일에만 적용된다. `git rm --cached .env` 로 추적을 끊어야 하고, 이미 푸시했다면 커밋 이력에 남아 있으므로 비밀을 교체해야 한다.
</details>

---

## 9. 자주 하는 실수

| 실수 | 결과 | 해결 |
| :--- | :--- | :--- |
| `.env` 커밋 | 비밀 유출, 이력에 영구 기록 | `.gitignore` + `.env.example` |
| `.env` 만 있고 예시 없음 | 남이 클론하면 실행 불가 | `.env.example` 커밋 |
| `.env` 값이 컨테이너에 자동 전달된다고 오해 | 변수가 비어 있음 | `environment:` 에 명시 |
| Dockerfile `ENV` 에 비밀 저장 | 이미지 받은 누구나 조회 | 실행 시 주입 |
| 템플릿 주석에 변수 표기 | 결과물 문장 깨짐 | 주석에서 `${}` 제거 |
| 템플릿 원본만 확인 | 치환 문제를 못 잡음 | 컨테이너 안의 결과물 확인 |
| 커밋 후 `.gitignore` 추가로 해결 시도 | 계속 추적됨 | `git rm --cached` |

---

## 10. 예상 질문과 답변 포인트

평가 루브릭 **항목 5 보너스 4**(환경 변수 활용)와 **항목 2-2**(포트/볼륨 재현 가능성)가 이 문서에서 나온다.

---

### A. 루브릭 직결 문항

#### A-1. 설정과 코드를 왜 분리하나? (보너스 4의 배움 포인트)

**⚡ 답변 — 분리하지 않으면 생기는 문제부터**

> 포트 같은 설정을 이미지에 굽으면 **환경마다 다른 이미지**를 만들어야 합니다.
>
> ```
> 개발 8080 → 이미지 A
> 스테이징 9000 → 이미지 B
> 운영 80 → 이미지 C
> ```
>
> 같은 코드인데 이미지가 3개입니다. **테스트한 이미지와 운영에 올라가는 이미지가 다르므로** "개발에서는 됐는데"가 다시 발생합니다.
>
> 설정을 밖으로 빼면 이미지 하나로 모든 환경을 커버하고, **테스트한 그 이미지가 그대로 운영에 올라갑니다.**

**실습으로 증명한 부분을 반드시 붙인다**

> 실습에서 `.env` 의 `NGINX_PORT` 만 8080에서 8090으로 바꾸고 **`--build` 없이** 재기동했습니다.
>
> ```
> 변경 전:  listen 8080;   /  0.0.0.0:8081->8080/tcp
> 변경 후:  listen 8090;   /  0.0.0.0:8081->8090/tcp
> curl -sI localhost:8081  →  HTTP/1.1 200 OK
> ```
>
> 이미지 생성 시각이 그대로인 것으로 재빌드가 없었음을 확인했습니다.
>
> **핵심은 내부 구성이 바뀌었는데 사용자가 접속하는 주소(`localhost:8081`)는 그대로**라는 점입니다. 외부 인터페이스는 유지한 채 내부만 교체한 셈입니다.

**📄 근거**: 보고서 **17-4** (변경 전후 출력 + 재빌드 없음 증거)

---

#### A-2. 포트/볼륨 설정을 어떤 방식으로 재현 가능하게 정리했나? (항목 2-2)

**⚡ 30초 답변**

> 보고서 13번에 표와 명령 시퀀스로 고정했습니다.
>
> **포트는 호스트와 컨테이너를 분리해 표로** 정리했습니다. `docker run` 방식은 호스트 8081 → 컨테이너 80, Compose 방식은 `.env` 의 `HOST_PORT` / `NGINX_PORT` 가 결정합니다. 분리한 이유는 호스트 포트가 점유됐을 때 **컨테이너 쪽은 그대로 두고 호스트 포트만 바꾸면 되기** 때문입니다.
>
> **볼륨은 이름 있는 볼륨**을 썼습니다. 호스트 경로에 의존하지 않아 다른 머신에서도 같은 명령이 동작하고, 명시적으로 이름을 줘야 추적·백업이 가능합니다.
>
> 그리고 **클론부터 정리까지 복사-실행 가능한 명령 시퀀스**를 한 블록으로 제공했습니다. `.env` 가 커밋되지 않으므로 `cp .env.example .env` 단계를 명시적으로 포함시켰습니다.

**📄 근거**: 보고서 **13번**

---

### B. 따라붙기 쉬운 후속 질문

#### B-1. `.env` 를 커밋하지 않는 이유는?

> 실제 값에는 **비밀번호나 API 키**가 들어가기 쉽습니다. 한번 커밋하면 **이력에 영구히 남아** 나중에 파일을 지워도 `git log -p` 로 복구할 수 있습니다. 공개 저장소면 자동 스캐너가 몇 분 안에 찾아냅니다.
>
> 대신 `.env.example` 로 **어떤 변수가 필요한지 구조만** 공유하고 값은 각자 로컬에 둡니다. 설정의 구조는 공유하되 값은 분리하는 방식입니다.

```bash
git check-ignore -v .env     # 실제로 제외되는지 검증
```

---

#### B-2. `.env` 에 있는 값이 컨테이너 안에서 안 보입니다.

> **`.env` 는 Compose에서 두 가지 다른 일을 합니다.** 이걸 구분하지 못하면 반드시 걸립니다.

| 역할 | 쓰임 | 컨테이너 안에서 보이나 |
| :--- | :--- | :--- |
| **A. Compose 파일 치환** | `ports: "${HOST_PORT}:80"` | ❌ |
| **B. 컨테이너 환경 변수** | `environment: FOO: ${FOO}` | ✅ |

> `.env` 에 `HOST_PORT=8081` 이 있어도, `environment:` 에 명시하지 않으면 **컨테이너 안에는 그 변수가 없습니다.** 포트 매핑을 만드는 데만 쓰였을 뿐입니다.
>
> 실습에서 두 역할을 모두 확인했습니다. `docker compose config` 로 치환 결과(A)를, `docker compose exec web env` 로 컨테이너 안 변수(B)를 봤습니다.

---

#### B-3. 환경 변수의 우선순위는?

```
Dockerfile ENV          ← 가장 약함 (기본값)
  ↓
Compose env_file
  ↓
Compose environment
  ↓
docker run -e / 셸 환경 변수   ← 가장 강함
```

> 뒤에 오는 것이 앞을 덮어씁니다.

---

#### B-4. Dockerfile에 `ENV NGINX_PORT=80` 을 왜 넣었나?

> **안전망입니다.** Compose 없이 `docker run` 만으로 실행할 때(보고서 10번) 변수가 비어 있으면 nginx 설정이 `listen ;` 으로 치환되어 **기동에 실패**합니다.
>
> 기본값이 있으면 아무 설정 없이도 동작하고, 필요하면 Compose가 덮어씁니다. 이게 우선순위 구조를 활용하는 전형적인 패턴입니다.

---

#### B-5. nginx 템플릿은 어떻게 동작하나?

```
default.conf.template
        ↓ Dockerfile COPY
/etc/nginx/templates/default.conf.template
        ↓ 컨테이너 기동 시 envsubst
/etc/nginx/conf.d/default.conf     ← 치환 완료
```

> nginx 공식 이미지는 기동 시 `/etc/nginx/templates/*.template` 을 `envsubst` 로 치환해 `/etc/nginx/conf.d/` 로 출력합니다. **이 경로가 아니면 그 기능이 동작하지 않습니다.**
>
> 덕분에 이미지를 다시 빌드하지 않고 환경 변수만으로 리슨 포트를 바꿀 수 있습니다.

---

#### B-6. envsubst가 주석까지 바꿔 버렸습니다.

> `envsubst` 는 **nginx 설정 문법을 이해하는 도구가 아니라 단순 텍스트 치환기**입니다. `${...}` 패턴이 보이면 주석이든 아니든 무조건 바꿉니다.
>
> 실습에서 실제로 겪었습니다.
>
> ```nginx
> # 작성한 것:  # ${NGINX_PORT} 는 ... 치환된다
> # 결과물:     # 8080 는 ... 치환된다          ← 문장이 깨짐
> ```
>
> 조치는 주석에서 변수 표기를 빼는 것이었고, 교훈은 **템플릿은 입력이 아니라 출력을 검증해야 한다**는 것입니다. 원본만 봐서는 안 보입니다.

**📄 근거**: 보고서 **15-4** + **16번 회고**

---

#### B-7. 환경 변수에 비밀번호를 넣어도 되나?

> 편리하지만 **완전한 비밀 보관 수단은 아닙니다.**
>
> ```bash
> docker inspect my-app | grep -A5 '"Env"'
> # "DB_PASSWORD=supersecret"     ← 조회 가능
> ```

| 문제 | 설명 |
| :--- | :--- |
| `docker inspect` 노출 | 컨테이너 접근 권한만 있으면 조회 가능 |
| 로그 유출 | 에러 로그가 환경 변수를 덤프하는 경우 |
| 자식 프로세스 상속 | 의도치 않은 전파 |
| Dockerfile `ENV` | 이미지에 영구 기록 — 받은 누구나 조회 |

> 대안은 Docker secrets, 클라우드 secret 관리 서비스, 권한 `600` 파일 마운트 등입니다. **학습·개발 단계에서는 `.env` + `.gitignore` 로 충분하지만, 한계는 알고 있어야 합니다.**

---

#### B-8. `.env` 를 실수로 커밋했습니다. `.gitignore` 에 추가하면 되나?

> **해결되지 않습니다.** `.gitignore` 는 아직 추적되지 않는 파일에만 적용됩니다. 이미 `git add` 된 파일은 계속 추적됩니다.
>
> ```bash
> git rm --cached .env
> git commit -m "Chore: .env 추적 제외"
> ```
>
> 그리고 **이미 푸시했다면 커밋 이력에 내용이 남습니다.** 이 경우 가장 먼저 할 일은 이력 정리가 아니라 **해당 비밀번호·키를 즉시 교체**하는 것입니다. 유출된 것으로 간주해야 합니다.

---

### C. 실전 시나리오

#### C-1. "Compose가 변수를 못 찾는다고 합니다."

```
WARN[0000] The "HOST_PORT" variable is not set. Defaulting to a blank string.
```

> 순서대로 확인합니다.
>
> 1. **`.env` 파일이 있나** — 클론 직후엔 없다. `cp .env.example .env`
> 2. **파일 위치가 맞나** — `docker-compose.yml` 과 **같은 디렉토리**에 있어야 한다
> 3. **변수 이름 오타** — `docker compose config` 로 치환 결과 확인
> 4. **다른 디렉토리에서 실행했나** — Compose는 실행 위치 기준으로 `.env` 를 찾는다

---

#### C-2. "설정을 바꿨는데 반영이 안 됩니다."

> **무엇을 바꿨는지에 따라 필요한 명령이 다릅니다.**

| 바꾼 것 | 필요한 명령 |
| :--- | :--- |
| `.env` 값 | `docker compose up -d` |
| `docker-compose.yml` | `docker compose up -d` |
| Dockerfile, `COPY` 대상 파일 | `docker compose up -d --build` |

> 설정만 바꿨으면 재빌드가 필요 없고, **이미지 내용을 바꿨으면 `--build` 가 필수**입니다. 이 구분을 못 하면 "분명 고쳤는데 그대로"라는 상황을 만납니다.

---

#### C-3. "치환이 제대로 됐는지 확인하려면?"

```bash
docker compose config                                    # ① Compose 파일 치환 결과
docker compose exec web env | grep NGINX_PORT            # ② 컨테이너 안 변수
docker compose exec web cat /etc/nginx/conf.d/default.conf  # ③ 최종 설정 파일
```

> ①②③ 세 지점을 각각 봐야 합니다. ①은 됐는데 ②가 안 되면 `environment:` 누락이고, ②는 됐는데 ③이 이상하면 템플릿 문제입니다.
>
> **원본이 아니라 결과물을 보는 것**이 핵심입니다.

---

### D. 한 줄 요약 (외울 것)

| 개념 | 한 줄 |
| :--- | :--- |
| 왜 분리하나 | 이미지 하나로 모든 환경, **테스트한 이미지가 그대로 배포** |
| `.env` 두 역할 | Compose 치환(A) ≠ 컨테이너 변수(B) |
| 컨테이너에 넣으려면 | `environment:` 에 **명시**해야 함 |
| 우선순위 | Dockerfile ENV < env_file < environment < `-e` |
| Dockerfile ENV | 아무 설정 없이도 돌게 하는 **안전망** |
| envsubst | 문법을 모르는 **텍스트 치환기** — 주석도 바꾼다 |
| 검증 | 입력이 아니라 **출력**을 본다 |
| `.env` 커밋 사고 | `.gitignore` 추가로는 해결 안 됨 → 비밀 교체 |

---

**이전 문서** → [07. Docker Compose](07-docker-compose.md)
**다음 문서** → [09. Git과 GitHub](09-git-github.md)
