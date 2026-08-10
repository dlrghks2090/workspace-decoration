# 04. Dockerfile

> 보고서 대응: [10번 커스텀 Dockerfile 제작](../README.md)

---

## 1. Dockerfile이란

**이미지를 만드는 레시피**다. 텍스트 파일에 명령을 순서대로 적으면 Docker가 위에서부터 실행해 이미지를 만든다.

보고서에서 실제로 쓴 Dockerfile이다.

```dockerfile
FROM nginx:latest

ENV NGINX_PORT=80
ENV APP_MODE=development

COPY index.html /usr/share/nginx/html/index.html
COPY default.conf.template /etc/nginx/templates/default.conf.template

EXPOSE ${NGINX_PORT}
```

이 7줄이 하는 일:

```
1. nginx 공식 이미지를 바탕으로 시작한다
2. 환경 변수 기본값을 심는다
3. 내 HTML 파일을 nginx가 서빙하는 위치에 복사한다
4. 설정 템플릿을 nginx가 읽는 위치에 복사한다
5. 이 이미지는 이 포트를 쓴다고 문서화한다
```

---

## 2. 핵심 명령어

### FROM — 출발점

```dockerfile
FROM nginx:latest
FROM ubuntu:24.04
FROM node:20-alpine
```

모든 Dockerfile은 `FROM` 으로 시작한다. 맨바닥부터 만들 일은 거의 없고, 이미 잘 만들어진 이미지 위에 얹는다.

> **`alpine` 태그**: Alpine Linux 기반의 초경량 버전이다. `node:20` 이 1GB라면 `node:20-alpine` 은 150MB 수준이다. 다만 표준 C 라이브러리가 달라(musl vs glibc) 일부 패키지가 안 돌 수 있다.

### COPY — 파일 복사

호스트의 파일을 이미지 안으로 넣는 명령이다. Dockerfile에서 가장 자주 쓰이면서 **가장 함정이 많은** 명령이기도 하다.

```dockerfile
COPY index.html /usr/share/nginx/html/index.html
#    └─ 출발지(빌드 컨텍스트)   └─ 도착지(이미지 내부)
```

기본 문법은 두 가지 형태다.

```dockerfile
COPY <출발지>... <도착지>
COPY ["<출발지>", ..., "<도착지>"]    # 경로에 공백이 있을 때
```

---

#### ① 경로 규칙

| 위치 | 경로 종류 | 기준 |
| :--- | :--- | :--- |
| 출발지 | **상대 경로만** | 빌드 컨텍스트 루트 |
| 도착지 | 절대 경로 (권장) | 이미지 루트 `/` |
| 도착지 | 상대 경로 | 직전 `WORKDIR` |

**출발지에 절대 경로를 쓰면 안 된다.** `COPY /Users/kim/project/index.html ...` 은 다른 사람 컴퓨터에 그 경로가 없어 빌드가 깨진다. 애초에 출발지는 호스트 파일시스템 전체가 아니라 **빌드 컨텍스트 안**에서만 찾는다.

도착지에 상대 경로를 쓰면 `WORKDIR` 기준이 된다.

```dockerfile
WORKDIR /app
COPY main.py .          # → /app/main.py
COPY config/ ./conf/    # → /app/conf/
```

`WORKDIR` 없이 상대 경로를 쓰면 루트(`/`) 기준이 되는데, 의도가 불분명해지므로 **절대 경로나 `WORKDIR` + 상대 경로 중 하나로 통일**하는 게 좋다.

---

#### ② 디렉토리를 복사하면 디렉토리 자체는 안 간다 ⚠️

가장 많이 틀리는 부분이다. **출발지가 디렉토리면 그 디렉토리가 아니라 "내용물"이 복사된다.**

실제로 확인해 보자. 다음 구조를 만들고

```
src/
├── a.txt
└── nested/
    └── b.txt
```

이렇게 빌드하면

```dockerfile
FROM alpine
COPY src /dest
RUN ls -R /dest
```

결과는 이렇다.

```
#8 [3/3] RUN echo "--- /dest 내용 ---" && ls -R /dest
#8 0.100 --- /dest 내용 ---
#8 0.100 /dest:
#8 0.100 a.txt
#8 0.100 nested
#8 0.100
#8 0.100 /dest/nested:
#8 0.100 b.txt
```

`/dest/src/a.txt` 가 아니라 **`/dest/a.txt`** 다. `src` 라는 디렉토리 이름은 사라졌다.

| 쓴 것 | 기대하기 쉬운 결과 | 실제 결과 |
| :--- | :--- | :--- |
| `COPY src /dest` | `/dest/src/a.txt` | **`/dest/a.txt`** |

디렉토리 이름을 유지하고 싶으면 도착지에 명시한다.

```dockerfile
COPY src /dest/src        # → /dest/src/a.txt
```

> 하위 디렉토리(`nested/`)와 그 안의 파일은 재귀적으로 함께 복사된다. 사라지는 건 **최상위 디렉토리 이름 하나**뿐이다.

---

#### ③ 후행 슬래시(`/`)의 의미

도착지가 `/` 로 끝나면 **디렉토리**로, 아니면 **파일 이름**으로 해석된다.

```dockerfile
COPY index.html /usr/share/nginx/html/          # 디렉토리 안에 index.html 로
COPY index.html /usr/share/nginx/html/main.html # main.html 이라는 이름으로 저장
```

출발지가 여러 개면 **도착지는 반드시 디렉토리여야 한다.**

```dockerfile
COPY a.txt b.txt /dest/     # OK
COPY a.txt b.txt /dest      # 에러 (파일 2개를 파일 1개로 못 넣는다)
```

---

#### ④ 여러 파일과 와일드카드

```dockerfile
COPY *.conf /etc/app/          # 확장자로 묶기
COPY src/ config/ /app/        # 여러 디렉토리 (각각의 내용물이 /app/ 에 합쳐짐)
```

와일드카드는 셸이 아니라 Go의 패턴 매칭 규칙을 쓴다. `**` 같은 재귀 글롭은 지원하지 않으므로 디렉토리 전체를 넣고 싶으면 디렉토리를 통째로 지정한다.

---

#### ⑤ 빌드 컨텍스트 경계를 넘을 수 없다

```dockerfile
COPY ../secret.txt /            # 에러
```

```
forbidden path outside the build context
```

빌드 컨텍스트 밖의 파일은 애초에 데몬에 전송되지 않으므로 접근할 방법이 없다. 이건 버그가 아니라 **의도된 보안 경계**다. 빌드가 호스트 파일시스템을 마음대로 읽을 수 있으면 위험하기 때문이다.

필요하다면 컨텍스트를 상위로 올린다.

```bash
docker build -f docker/Dockerfile .    # 컨텍스트는 현재 디렉토리, Dockerfile만 하위에서
```

자세한 내용은 아래 **3. 빌드 컨텍스트** 절에서 다룬다.

---

#### ⑥ 소유권과 권한

복사된 파일은 기본적으로 **`root:root` 소유**가 된다. 컨테이너를 비root 사용자로 돌린다면 문제가 될 수 있다.

```dockerfile
COPY --chown=1000:1000 app/ /app/       # UID:GID 로 지정
COPY --chown=node:node  app/ /app/      # 이름으로 지정 (이미지에 그 계정이 있어야 함)
COPY --chmod=644 config.ini /etc/       # 권한을 명시적으로 지정
```

| 플래그 | 용도 |
| :--- | :--- |
| `--chown` | 소유자·그룹 지정 |
| `--chmod` | 권한 비트 지정 (BuildKit 필요, 요즘 Docker는 기본 활성) |

`--chmod` 를 안 쓰면 원본 파일의 권한이 대체로 그대로 따라온다. 실행 스크립트를 넣을 때 호스트에서 실행 권한이 없으면 컨테이너에서도 없으므로, `--chmod=755` 를 명시하거나 `RUN chmod +x` 를 따로 하는 편이 안전하다.

권한 숫자 규칙은 [02번 문서](02-file-permissions.md)를 참고한다.

---

#### ⑦ 다른 스테이지에서 가져오기 (`--from`)

멀티스테이지 빌드에서 앞 단계의 산출물만 뽑아올 때 쓴다.

```dockerfile
FROM golang:1.22 AS builder
WORKDIR /src
COPY . .
RUN go build -o app

FROM alpine
COPY --from=builder /src/app /usr/local/bin/app    # 빌드 결과물만 가져옴
```

컴파일러와 소스는 최종 이미지에 안 들어가므로 크기가 크게 줄어든다. 다른 이미지에서 직접 가져올 수도 있다.

```dockerfile
COPY --from=nginx:latest /etc/nginx/nginx.conf /tmp/
```

---

#### ⑧ COPY는 캐시를 깨뜨리는 지점이다

Docker는 `COPY` 대상 파일의 **내용 체크섬**으로 캐시 재사용 여부를 판단한다. 파일이 1바이트라도 바뀌면 그 레이어와 **그 뒤의 모든 레이어**가 다시 실행된다.

보고서 17-4의 재빌드 로그가 이걸 보여준다.

```
#6 [web 2/3] COPY index.html ...                #6 CACHED   ← 안 바뀜 → 재사용
#7 [web 3/3] COPY default.conf.template ...     #7 DONE     ← 바뀜 → 다시 실행
```

그래서 **자주 바뀌는 파일을 늦게 COPY** 하는 게 빌드 속도에 유리하다. 자세한 순서 전략은 아래 **4. 레이어 캐시** 절에 있다.

---

#### ⑨ .dockerignore 로 제외하기

`.gitignore` 와 같은 문법으로, 빌드 컨텍스트에서 제외할 것을 적는다.

```
node_modules/
.git/
*.log
.env
```

효과가 세 가지다.

1. **전송량 감소** — 컨텍스트가 데몬으로 전송되므로 빌드가 빨라진다
2. **캐시 안정성** — 제외된 파일이 바뀌어도 캐시가 깨지지 않는다
3. **사고 방지** — `COPY . .` 을 썼을 때 `.env` 나 `.git` 이 이미지에 들어가는 것을 막는다

3번이 특히 중요하다. `COPY . .` 로 통째로 복사하면 **비밀 파일이 이미지에 구워진다.** 이미지를 받은 누구나 꺼내 볼 수 있고, 나중에 파일을 지워도 이전 레이어에는 남는다.

---

#### ⑩ COPY vs ADD

```dockerfile
COPY app.tar.gz /tmp/     # 파일을 그대로 복사
ADD  app.tar.gz /tmp/     # 로컬 tar 파일이면 자동으로 압축을 푼다
ADD  https://... /tmp/    # URL에서 다운로드 (단, 원격 tar는 안 풀림)
```

| | COPY | ADD |
| :--- | :--- | :--- |
| 로컬 파일 복사 | ✅ | ✅ |
| tar 자동 해제 | ❌ | ✅ (로컬 파일만) |
| URL 다운로드 | ❌ | ✅ |
| 동작 예측 가능성 | 높음 | 낮음 |

`ADD` 는 "이게 tar인가?"를 판단해 동작이 달라지므로 의도치 않은 결과를 부른다. **특별한 이유가 없으면 `COPY` 를 쓴다**는 게 공식 권장이다. 원격 파일이 필요하면 `RUN curl ... && ...` 이 더 명시적이고, 한 레이어에서 받고 지울 수 있어 이미지도 작아진다.

---

#### ⑪ 실습 Dockerfile 분석

보고서에서 쓴 [`Dockerfile`](../Dockerfile)의 COPY 두 줄이다.

```dockerfile
COPY index.html /usr/share/nginx/html/index.html
COPY default.conf.template /etc/nginx/templates/default.conf.template
```

| 항목 | 선택 | 이유 |
| :--- | :--- | :--- |
| 출발지 | 상대 경로 (`index.html`) | 빌드 컨텍스트가 저장소 루트. 클론 위치와 무관하게 동작 |
| 도착지 | 절대 경로 | 이미지 내부 경로. nginx가 읽는 위치가 정해져 있음 |
| 파일명 명시 | `.../index.html` 까지 | 디렉토리로 끝내도 되지만 결과가 명확해짐 |
| 두 줄로 분리 | 목적지가 다름 | 하나는 서빙 대상, 하나는 설정 템플릿 |

**두 번째 줄이 보너스 4의 핵심이다.** `/etc/nginx/templates/` 에 넣으면 nginx 공식 이미지가 기동 시 `envsubst` 로 환경 변수를 치환해 `/etc/nginx/conf.d/` 로 출력한다. 이 경로가 아니면 그 기능이 동작하지 않는다.

또 이 파일 배치가 보고서 4번의 디렉토리 설계 기준과 이어진다. 빌드 파일을 저장소 루트에 평평하게 뒀기 때문에 `COPY index.html` 이라는 짧은 상대 경로가 가능했다.

---

#### ⑫ 자주 만나는 에러

| 에러 메시지 | 원인 | 해결 |
| :--- | :--- | :--- |
| `"/index.html": not found` | 컨텍스트에 파일이 없음 (경로 오타, `.dockerignore` 로 제외됨) | 경로 확인, `.dockerignore` 점검 |
| `forbidden path outside the build context` | `../` 로 컨텍스트 밖 참조 | 컨텍스트를 상위로 올리고 `-f` 로 Dockerfile 지정 |
| `when using COPY with more than one source file, the destination must be a directory` | 소스 여러 개인데 도착지가 파일 | 도착지를 `/` 로 끝내기 |
| 복사했는데 컨테이너에 없음 | 디렉토리 내용물만 복사되는 규칙을 오해 | `COPY src /dest/src` 로 명시 |
| 실행 권한이 없다 | 원본에 실행 권한이 없었음 | `--chmod=755` 또는 `RUN chmod +x` |

`not found` 가 났을 때 가장 먼저 확인할 것은 **컨텍스트에 실제로 그 파일이 있는가**다.

```bash
ls -a                        # 컨텍스트 루트에 파일이 있나
cat .dockerignore            # 제외되고 있진 않나
docker build --no-cache .    # 캐시 때문에 헷갈리는 경우 배제
```

### RUN — 빌드 중 명령 실행

```dockerfile
RUN apt-get update && apt-get install -y curl
RUN mkdir -p /app/data
```

**이미지를 만드는 시점**에 실행된다. 컨테이너 실행 시점이 아니다.

각 `RUN` 은 새 레이어를 만든다. 그래서 이렇게 쓰면 레이어가 3개 생긴다.

```dockerfile
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*
```

`&&` 로 묶으면 1개다. 이미지가 작아진다.

```dockerfile
RUN apt-get update \
    && apt-get install -y curl \
    && rm -rf /var/lib/apt/lists/*
```

> **왜 크기가 줄어드나?** 레이어는 삭제를 "지웠다는 기록"으로 표현할 뿐, 앞 레이어의 실제 데이터는 이미지에 남는다. 같은 레이어 안에서 만들고 지워야 처음부터 없던 게 된다.

### ENV — 환경 변수

```dockerfile
ENV NGINX_PORT=80
ENV APP_MODE=development
```

**이미지에 굽는 기본값**이다. 컨테이너 실행 시 `-e` 나 Compose의 `environment:` 로 덮어쓸 수 있다.

보고서의 Dockerfile이 `ENV NGINX_PORT=80` 을 둔 이유가 여기 있다.

```
Dockerfile의 ENV        →  기본값 80  (docker run 만 하면 이 값)
Compose의 environment   →  8080으로 덮어씀
```

기본값이 없으면 `docker run` 시 변수가 비어 있어 nginx 설정이 `listen ;` 이 되어 깨진다.

#### ENV vs ARG

```dockerfile
ARG BUILD_VERSION=1.0     # 빌드 시점에만 존재. 컨테이너에 안 남음
ENV APP_VERSION=1.0       # 컨테이너 실행 중에도 남음
```

비밀번호 같은 것을 `ENV` 로 넣으면 `docker inspect` 로 누구나 볼 수 있다. 비밀은 실행 시 주입하거나 secret 관리 도구를 쓴다.

### WORKDIR — 작업 디렉토리

```dockerfile
WORKDIR /app
COPY . .          # /app 에 복사됨
RUN npm install   # /app 에서 실행됨
```

`cd` 를 대신한다. `RUN cd /app` 은 그 줄에서만 유효하고 다음 줄에서 원위치되므로 소용없다. `WORKDIR` 을 써야 한다.

### EXPOSE — 문서화

```dockerfile
EXPOSE 80
```

**포트를 여는 명령이 아니다.** "이 이미지는 이 포트를 씁니다"라고 적어두는 메모에 가깝다. 실제 공개는 `docker run -p` 나 Compose의 `ports:` 가 한다.

```bash
# EXPOSE 80 이 있어도 이것만으로는 호스트에서 접속 불가
docker run -d my-web:v1

# -p 를 줘야 실제로 열린다
docker run -d -p 8081:80 my-web:v1
```

### CMD vs ENTRYPOINT — 실행 명령

```dockerfile
CMD ["nginx", "-g", "daemon off;"]
ENTRYPOINT ["nginx"]
```

| 명령 | 성격 | `docker run img 인자` 시 |
| :--- | :--- | :--- |
| `CMD` | 기본값 제안 | **대체된다** |
| `ENTRYPOINT` | 고정 실행 | 인자가 **뒤에 붙는다** |

```dockerfile
# CMD 만 있을 때
CMD ["echo", "hello"]
# docker run img            → echo hello
# docker run img ls         → ls          (대체됨)

# ENTRYPOINT + CMD 조합 (권장 패턴)
ENTRYPOINT ["echo"]
CMD ["hello"]
# docker run img            → echo hello
# docker run img world      → echo world  (CMD만 교체)
```

우리 Dockerfile에 `CMD` 가 없는 이유는, 베이스인 `nginx:latest` 가 이미 정의해 둔 것을 물려받기 때문이다.

---

## 3. 빌드 컨텍스트 — 자주 오해하는 개념

```bash
docker build -t my-web:v1 .
#                          └─ 이게 빌드 컨텍스트
```

마지막 `.` 은 "Dockerfile이 여기 있다"는 뜻이 아니라 **"이 디렉토리 전체를 데몬에게 보낸다"**는 뜻이다.

```
1. CLI가 . 아래 모든 파일을 압축해 데몬에 전송
2. 데몬이 Dockerfile을 읽고 실행
3. COPY 는 전송받은 파일 중에서 찾는다
```

### 여기서 나오는 두 가지 결과

**① 컨텍스트 밖의 파일은 COPY 할 수 없다**

```dockerfile
COPY ../secret.txt /app/    # 에러: 컨텍스트 밖
```

보안 장치다. 빌드가 임의의 호스트 파일을 가져가지 못하게 막는다.

**② 큰 파일이 있으면 빌드가 느려진다**

`node_modules` 나 `.git` 이 통째로 전송되면 수 초~수 분이 낭비된다. `.dockerignore` 로 제외한다.

```
# .dockerignore
.git
node_modules
*.log
README.md
```

보고서 10번의 빌드 로그에서 컨텍스트 크기를 볼 수 있다.

```
#4 [internal] load build context
#4 transferring context: 432B done      ← 432바이트만 전송됨
```

파일이 몇 개 없어서 432B다. `.git` 이 포함됐다면 훨씬 컸을 것이다.

### 디렉토리 구조 설계와의 연결

보고서 4번에서 "빌드에 필요한 파일은 저장소 루트에 평평하게 둔다"고 한 이유가 이것이다. 빌드 컨텍스트가 저장소 루트라면 `COPY index.html` 처럼 짧은 상대 경로로 끝난다. 하위 폴더로 나누면 `COPY src/index.html` 이 되고, 컨텍스트를 바꿀 때마다 Dockerfile도 고쳐야 한다.

---

## 4. 레이어 캐시 — 빌드를 빠르게

Docker는 각 명령의 결과를 캐시한다. **한 층이 바뀌면 그 아래는 전부 다시 만든다.**

```
층 1 (FROM)      캐시 사용
층 2 (COPY a)    캐시 사용
층 3 (COPY b)    ← 여기가 바뀌면
층 4 (RUN ...)   ← 여기부터 전부 재실행
```

### 순서가 성능을 좌우한다

```dockerfile
# 나쁜 예 — 소스가 바뀔 때마다 npm install 재실행
COPY . .
RUN npm install

# 좋은 예 — package.json 이 안 바뀌면 install 은 캐시
COPY package.json package-lock.json ./
RUN npm install
COPY . .
```

원칙: **자주 바뀌는 것을 뒤에 둔다.**

보고서 17-4의 재빌드에서 캐시가 동작한 실제 기록이다.

```
#6 [web 2/3] COPY index.html ...            CACHED    ← 안 바뀜
#7 [web 3/3] COPY default.conf.template ... DONE      ← 바뀌어서 재실행
```

---

## 5. nginx 이미지의 템플릿 기능

보고서 17-4에서 쓴 기능이라 따로 설명한다. 공식 nginx 이미지에는 특별한 동작이 내장돼 있다.

```
컨테이너 기동
   ↓
/docker-entrypoint.d/ 안의 스크립트들이 순서대로 실행
   ↓
20-envsubst-on-templates.sh 가
/etc/nginx/templates/*.template 을 읽어
환경 변수를 치환한 뒤
/etc/nginx/conf.d/ 로 출력          ← .template 확장자가 떨어진다
   ↓
nginx 시작
```

보고서 8번의 로그에서 실제로 확인된다.

```
20-envsubst-on-templates.sh: Running envsubst on
  /etc/nginx/templates/default.conf.template
  to /etc/nginx/conf.d/default.conf
```

그래서 Dockerfile이 파일을 `/etc/nginx/templates/` 에 넣는다.

```dockerfile
COPY default.conf.template /etc/nginx/templates/default.conf.template
```

### envsubst의 함정

`envsubst` 는 **단순 텍스트 치환기**다. nginx 설정 문법을 이해하지 못한다. 보고서 15-4에서 실제로 겪은 문제다.

```nginx
# 템플릿에 이렇게 썼더니
server {
    # ${NGINX_PORT} 는 환경 변수로 치환된다     ← 설명 주석
    listen ${NGINX_PORT};
}

# 결과물에서 주석까지 치환돼 문장이 깨졌다
server {
    # 8080 는 환경 변수로 치환된다
    listen 8080;
}
```

**교훈: 템플릿을 다룰 때는 입력이 아니라 출력을 검증한다.**

```bash
docker compose exec web cat /etc/nginx/conf.d/default.conf
```

---

## 6. 직접 해보기

```bash
mkdir ~/Desktop/dockerfile-practice && cd ~/Desktop/dockerfile-practice

# 1. 간단한 HTML
echo '<h1>My First Image</h1>' > index.html

# 2. Dockerfile 작성
cat > Dockerfile <<'EOF'
FROM nginx:latest
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
EOF

# 3. 빌드
docker build -t practice:v1 .

# 4. 실행하고 확인
docker run -d -p 9000:80 --name practice-app practice:v1
curl localhost:9000
# <h1>My First Image</h1>

# 5. 캐시 실험 — 다시 빌드하면 전부 CACHED
docker build -t practice:v1 .

# 6. HTML을 바꾸고 다시 빌드 — COPY부터 재실행
echo '<h1>Changed</h1>' > index.html
docker build -t practice:v1 .

# 7. 컨테이너를 새로 만들어야 반영된다
docker rm -f practice-app
docker run -d -p 9000:80 --name practice-app practice:v1
curl localhost:9000
# <h1>Changed</h1>

# 8. 정리
docker rm -f practice-app
docker rmi practice:v1
cd ~/Desktop && rm -r dockerfile-practice
```

**확인 문제**

1. 6번에서 다시 빌드했을 때 왜 전부 `CACHED` 인가?
2. 7번에서 컨테이너를 재생성하지 않으면 왜 옛날 내용이 나오나?
3. `EXPOSE 80` 만 있고 `-p` 를 안 주면 호스트에서 접속되나?

<details>
<summary>답</summary>

1. Dockerfile도 index.html도 바뀌지 않아 모든 층의 입력이 동일하므로 캐시가 유효하다.
2. 실행 중인 컨테이너는 **예전 이미지**로 만들어진 것이다. 이미지를 다시 빌드해도 이미 만들어진 컨테이너는 갱신되지 않는다.
3. 안 된다. `EXPOSE` 는 문서화일 뿐 실제 포트 공개는 `-p` 가 한다.
</details>

---

## 7. 자주 하는 실수

| 실수 | 증상 | 해결 |
| :--- | :--- | :--- |
| `COPY` 출발지에 절대 경로 | 다른 환경에서 빌드 실패 | 상대 경로 사용 |
| `COPY src /dest` 로 디렉토리 이름이 유지될 거라 기대 | `/dest/src/...` 가 아니라 `/dest/...` | `COPY src /dest/src` 로 명시 |
| 소스 여러 개인데 도착지가 파일 | `destination must be a directory` | 도착지를 `/` 로 끝내기 |
| `COPY ../file` 로 컨텍스트 밖 참조 | `forbidden path outside the build context` | 컨텍스트를 올리고 `-f` 로 Dockerfile 지정 |
| `COPY . .` 로 `.env`·`.git` 까지 복사 | 비밀이 이미지에 구워짐 | `.dockerignore` 에 제외 |
| 복사한 스크립트에 실행 권한 없음 | `permission denied` | `--chmod=755` 또는 `RUN chmod +x` |
| `RUN cd /app` 으로 디렉토리 이동 | 다음 줄에서 원위치 | `WORKDIR` 사용 |
| `COPY . .` 을 맨 앞에 | 매번 전체 재빌드 | 의존성 파일 먼저 복사 |
| `.dockerignore` 없음 | 빌드 느림, 이미지 비대 | `.git`, `node_modules` 제외 |
| `EXPOSE` 로 포트가 열린다고 오해 | 접속 불가 | `-p` 로 실제 매핑 |
| 이미지 재빌드 후 컨테이너 유지 | 변경 미반영 | 컨테이너 재생성 |
| `ENV` 에 비밀번호 저장 | `docker inspect` 로 노출 | 실행 시 주입 또는 secret 사용 |

---

## 8. 예상 질문과 답변 포인트

평가 루브릭 **항목 1-6**(Dockerfile로 이미지 빌드), **항목 3-3**(절대/상대 경로 선택), **항목 2-1**(디렉토리 구조 설계 기준)이 이 문서에서 나온다.

---

### A. 루브릭 직결 문항

#### A-1. Dockerfile로 이미지 빌드가 가능한가?

**⚡ 30초 답변**

> 저장소 루트에 Dockerfile이 있고, 보고서 10번에 빌드 로그가 있습니다. `nginx:latest` 를 베이스로 `index.html` 과 nginx 설정 템플릿을 `COPY` 하고, `ENV` 로 포트 기본값을 넣었습니다. `docker build -t my-web:v1 .` 로 빌드했고, 로그에서 **3개 레이어가 순서대로 쌓이는 것**을 확인할 수 있습니다.

```
#5 [1/3] FROM docker.io/library/nginx:latest    ← 베이스
#7 [2/3] COPY index.html ...                    ← 층 추가
#8 [3/3] COPY default.conf.template ...         ← 층 추가
#9 naming to docker.io/library/my-web:v1
```

**💻 실연**

```bash
cat Dockerfile
docker build -t my-web:v1 .
docker images my-web
```

**📄 근거**: 보고서 **10번** + 저장소의 [`Dockerfile`](../Dockerfile)

---

#### A-2. 절대 경로와 상대 경로를 어떤 상황에서 선택하나? (항목 3-3)

**⚡ 답변 — 기준 한 줄 + 실습 예시**

> 판단 기준은 **실행 위치가 달라져도 같은 대상을 가리켜야 하면 절대 경로, 프로젝트를 통째로 옮겨도 따라와야 하면 상대 경로**입니다.

| 상황 | 선택 | 이유 |
| :--- | :--- | :--- |
| `COPY index.html ...` | 상대 | 빌드 컨텍스트 기준. 클론 위치와 무관해야 함 |
| `docker build .` | 상대 | 현재 위치 기준 |
| `COPY ... /usr/share/nginx/html/` | 절대 | 이미지 내부 경로 |
| `-v my-vol:/data` | 절대 | 컨테이너 내부 경로 규칙 |

> **출발지에 절대 경로를 쓰면 제 컴퓨터에서만 빌드됩니다.** 저장소는 누가 어디에 클론할지 모르니까요. 반대로 이미지 내부 경로는 위치가 고정돼야 하므로 절대 경로입니다.

**📄 근거**: 보고서 **14-3**

---

#### A-3. 프로젝트 디렉토리 구조를 어떤 기준으로 구성했나? (항목 2-1, Dockerfile 관점)

**⚡ 답변**

> **빌드에 필요한 파일을 저장소 루트에 평평하게 뒀습니다.** `docker build .` 의 빌드 컨텍스트가 곧 저장소 루트가 되므로, Dockerfile에서 `COPY index.html` 처럼 짧은 상대 경로만 쓰면 됩니다.
>
> 하위 디렉토리로 나누면 `COPY src/index.html ...` 처럼 경로가 길어지고, 빌드 컨텍스트를 바꿀 때마다 Dockerfile도 함께 고쳐야 합니다. **파일이 8개뿐인 규모에서는 계층을 만드는 비용이 이득보다 크다**고 판단했습니다.

**꼬리질문 대비**
- *"규모가 커지면?"* → `src/`, `config/`, `docker/` 로 나눈다. 그때는 Compose에서 `build.context` 와 `dockerfile` 경로를 명시하게 된다.

**📄 근거**: 보고서 **4번**

---

### B. 따라붙기 쉬운 후속 질문

#### B-1. `docker build .` 의 점(`.`)은 무슨 의미인가?

> **빌드 컨텍스트**입니다. 그 디렉토리 전체가 Docker 데몬에 전송되고, `COPY` 는 **그 안에서만** 파일을 찾을 수 있습니다.
>
> 컨텍스트 밖의 파일(`../secret.txt`)은 복사할 수 없는데, 이건 버그가 아니라 **빌드가 임의의 호스트 파일에 접근하지 못하게 하는 보안 경계**입니다.
>
> 전송되는 양이므로 `.git` 이나 `node_modules` 가 들어 있으면 빌드가 느려집니다. `.dockerignore` 로 제외합니다.

---

#### B-2. `COPY src /dest` 를 하면 `/dest/src` 가 생기나?

> 아닙니다. 출발지가 디렉토리면 **디렉토리 자체가 아니라 내용물**이 복사됩니다.
>
> ```
> src/a.txt   →   /dest/a.txt      (O)
>                 /dest/src/a.txt  (X)
> ```
>
> 하위 디렉토리는 재귀적으로 따라오지만 **최상위 이름 하나만** 빠집니다. 이름을 유지하려면 `COPY src /dest/src` 로 도착지에 명시해야 합니다.

가장 많이 틀리는 지점이라 실제로 빌드해서 확인했다. (본문 ②번 참고)

---

#### B-3. `COPY` 한 파일의 소유자와 권한은?

> 기본적으로 **`root:root`** 소유가 됩니다. 비root 사용자로 컨테이너를 돌린다면 `--chown=uid:gid` 로 지정해야 합니다.
>
> 권한은 원본 파일의 모드가 대체로 따라옵니다. 그래서 **실행 스크립트인데 호스트에서 실행 권한이 없었다면 컨테이너에서도 없습니다.** `--chmod=755` 를 명시하거나 `RUN chmod +x` 를 따로 해 줍니다.

---

#### B-4. `COPY` 가 빌드 캐시에 어떤 영향을 주나?

> Docker는 복사 대상 파일의 **내용 체크섬**으로 캐시 재사용 여부를 판단합니다. 파일이 1바이트라도 바뀌면 그 레이어와 **그 뒤의 모든 레이어**가 다시 실행됩니다.
>
> 그래서 **자주 바뀌는 소스는 늦게, 잘 안 바뀌는 의존성 목록은 먼저** `COPY` 하는 것이 빌드 시간을 줄이는 기본 전략입니다.
>
> ```dockerfile
> COPY package.json .      # 자주 안 바뀜 → 먼저
> RUN npm install          # 캐시 재사용
> COPY . .                 # 자주 바뀜 → 나중
> ```

실습에서도 캐시 동작을 확인했다.

```
#6 [web 2/3] COPY index.html ...                #6 CACHED   ← 안 바뀜
#7 [web 3/3] COPY default.conf.template ...     #7 DONE     ← 바뀜
```

---

#### B-5. `COPY` 와 `ADD` 중 무엇을 쓰나?

> 기본은 **`COPY`** 입니다. `ADD` 는 tar 자동 해제와 URL 다운로드 같은 **암묵적 동작**이 있어 의도치 않은 결과를 만들기 쉽습니다. "이게 tar인가?"를 판단해 동작이 달라집니다.
>
> 원격 파일이 필요하면 `RUN curl` 이 더 명시적이고, 같은 레이어에서 받고 지울 수 있어 이미지도 작아집니다.

---

#### B-6. `EXPOSE` 와 `-p` 의 차이는?

> `EXPOSE` 는 **문서화 지시자**로, 실제로 포트를 열지 않습니다. "이 이미지는 이 포트를 쓴다"는 메타데이터일 뿐입니다.
>
> 호스트에서 접근 가능하게 만드는 것은 `docker run -p` 나 Compose의 `ports:` 입니다. 다만 `docker run -P`(대문자)를 쓰면 `EXPOSE` 된 포트를 임의의 호스트 포트에 자동 매핑해 줍니다.

---

#### B-7. `RUN`, `CMD`, `ENTRYPOINT` 의 차이는?

| 명령 | 실행 시점 | 용도 |
| :--- | :--- | :--- |
| `RUN` | **빌드 시** | 패키지 설치 등. 결과가 레이어로 굳는다 |
| `CMD` | **컨테이너 실행 시** | 기본 명령. `docker run` 인자로 덮어쓸 수 있다 |
| `ENTRYPOINT` | **컨테이너 실행 시** | 고정 실행 파일. 덮어쓰기 어렵다 |

> 자주 헷갈리는 건 `RUN` 과 `CMD` 입니다. `RUN` 은 **이미지를 만들 때** 한 번 실행되고, `CMD` 는 **컨테이너를 띄울 때마다** 실행됩니다.

---

#### B-8. `RUN cd /app` 이 왜 안 먹히나?

> 각 `RUN` 은 **별개의 셸에서 실행**됩니다. `cd` 는 그 셸에서만 유효하므로 다음 `RUN` 에서는 원래 위치로 돌아갑니다.
>
> ```dockerfile
> RUN cd /app          # 효과 없음
> RUN pwd              # /
>
> WORKDIR /app         # 이후 모든 명령에 적용
> RUN pwd              # /app
> ```
>
> `WORKDIR` 을 써야 합니다. 한 `RUN` 안에서라면 `cd /app && make` 처럼 `&&` 로 이어도 됩니다.

---

#### B-9. 이미지 크기를 줄이려면?

> 네 가지입니다.
>
> 1. **경량 베이스** — `-alpine`, `-slim` 계열
> 2. **`RUN` 을 `&&` 로 묶기** — 레이어 수를 줄인다
> 3. **같은 레이어에서 정리** — 캐시나 임시 파일을 다른 레이어에서 지우면 **앞 레이어에 데이터가 남아 크기가 안 줄어든다**
> 4. **멀티스테이지 빌드** — 컴파일러와 소스를 최종 이미지에서 제외
>
> 3번이 특히 중요합니다.
>
> ```dockerfile
> RUN apt-get update && apt-get install -y curl \
>     && rm -rf /var/lib/apt/lists/*      # 같은 레이어에서 지워야 효과
> ```

---

#### B-10. 왜 `ENV NGINX_PORT=80` 을 Dockerfile에 넣었나?

> **안전망입니다.** Compose 없이 `docker run` 만으로 실행할 때 변수가 비어 있으면 nginx 설정이 `listen ;` 으로 치환되어 기동에 실패합니다.
>
> 기본값이 있으면 아무 설정 없이도 동작하고, 필요하면 Compose가 덮어씁니다. 환경 변수 우선순위(Dockerfile `ENV` < Compose `environment` < `-e`)를 활용한 패턴입니다.

---

### C. 실전 시나리오

#### C-1. "`COPY` 가 파일을 못 찾습니다."

```
"/index.html": not found
```

> 순서대로 확인합니다.
>
> ```bash
> ls -a                        # ① 컨텍스트 루트에 파일이 있나
> cat .dockerignore            # ② 제외되고 있진 않나
> docker build --no-cache .    # ③ 캐시 때문에 헷갈리는 경우 배제
> ```
>
> `.dockerignore` 에 걸려 제외된 파일은 컨텍스트에 아예 안 들어가므로 "분명 파일이 있는데 없다고 한다"는 상황이 됩니다.

---

#### C-2. "빌드가 너무 느립니다."

> 두 방향으로 봅니다.
>
> **① 컨텍스트가 큰가** — 빌드 시작 시 `transferring context` 크기를 봅니다. `.git`, `node_modules` 가 들어가면 수백 MB가 전송됩니다. `.dockerignore` 로 제외합니다.
>
> **② 캐시가 안 먹는가** — `COPY . .` 이 앞에 있으면 파일 하나만 바뀌어도 그 뒤 전부 재실행됩니다. 의존성 파일을 먼저 복사하고 설치한 뒤, 소스를 나중에 복사하도록 순서를 바꿉니다.

---

#### C-3. "이미지를 고쳤는데 컨테이너에 반영이 안 됩니다."

> **기존 컨테이너는 옛 이미지로 만들어진 상태 그대로**입니다. 이미지를 다시 빌드해도 이미 돌고 있는 컨테이너는 바뀌지 않습니다.
>
> ```bash
> docker build -t my-web:v1 .
> docker rm -f my-app                      # 컨테이너 재생성 필요
> docker run -d -p 8081:80 --name my-app my-web:v1
>
> # Compose라면
> docker compose up -d --build
> ```

---

### D. 한 줄 요약 (외울 것)

| 개념 | 한 줄 |
| :--- | :--- |
| 빌드 컨텍스트 | `.` 이 전송 범위이자 `COPY` 의 탐색 범위 |
| 컨텍스트 밖 참조 | 불가 — 버그가 아니라 **보안 경계** |
| `COPY` 디렉토리 | 디렉토리 자체가 아니라 **내용물**만 |
| `COPY` 소유자 | 기본 `root:root`, `--chown` 으로 변경 |
| 캐시 | 자주 바뀌는 파일을 **늦게** COPY |
| `EXPOSE` | 문서화일 뿐, 실제 공개는 `-p` |
| `RUN` vs `CMD` | 빌드 시 vs 실행 시 |
| `RUN cd` | 효과 없음 → `WORKDIR` |
| 이미지 축소 | 정리는 **같은 레이어 안에서** |

---

**이전 문서** → [03. 이미지와 컨테이너](03-docker-concepts.md)
**다음 문서** → [05. 포트와 네트워크](05-port-mapping-network.md)
