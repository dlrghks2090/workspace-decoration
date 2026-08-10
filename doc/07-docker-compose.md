# 07. Docker Compose

> 보고서 대응: [17-1 ~ 17-3 보너스 과제](../README.md)

---

## 1. Compose가 해결하는 문제

보고서 10번에서 컨테이너를 이렇게 띄웠다.

```bash
docker run -d -p 8081:80 --name my-app my-web:v1
```

문제는 이 명령이 **어디에도 기록되지 않는다**는 점이다.

- 인자를 하나라도 빠뜨리면 다르게 동작하는데 그 사실을 아무도 모른다
- 다른 사람에게 "이렇게 실행하세요"라고 전달할 방법이 채팅밖에 없다
- 서비스가 2개, 3개로 늘면 명령이 감당이 안 된다

Compose는 이 실행 설정을 **파일로 고정**한다.

```yaml
services:
  web:
    build: .
    image: my-web:v1
    ports:
      - "8081:80"
```

```bash
docker compose up -d
```

### 이것이 "문서화된 실행 설정"의 의미

| 항목 | `docker run` | Compose |
| :--- | :--- | :--- |
| 실행 방법의 소재 | 사람의 기억, 채팅 기록 | 저장소의 파일 |
| 버전 관리 | 불가 | `git diff` 로 변경 추적 |
| 코드 리뷰 | 불가 | PR에서 리뷰 가능 |
| 재현 | 명령을 정확히 다시 쳐야 함 | `docker compose up` 한 줄 |
| 다중 서비스 | 명령 여러 개 + 순서 관리 | 파일 하나 |

**실행 방법이 개인의 기억에서 저장소의 자산으로 바뀐다.** 이게 핵심이다.

---

## 2. docker run 과의 1:1 대응

보고서 17-1의 표다. 새 문법을 배우는 게 아니라 이미 아는 것을 옮겨 적는 것뿐이다.

| `docker run` 인자 | Compose 키 |
| :--- | :--- |
| `docker build -t my-web:v1 .` | `build: .` + `image: my-web:v1` |
| `-p 8081:80` | `ports: ["8081:80"]` |
| `-e NGINX_PORT=8080` | `environment:` |
| `-v my-vol:/data` | `volumes:` |
| `-d` | `up -d` |
| `--name my-app` | `container_name:` (보통 생략) |
| `--network mynet` | `networks:` (자동 생성됨) |
| `--restart unless-stopped` | `restart: unless-stopped` |

---

## 3. 파일 구조

보고서에서 쓴 실제 파일이다.

```yaml
services:
  # 웹 서버: 저장소 루트의 Dockerfile 을 그대로 빌드해 사용한다.
  web:
    build: .
    image: my-web:v1
    ports:
      - "${HOST_PORT}:${NGINX_PORT}"
    environment:
      NGINX_PORT: ${NGINX_PORT}
      APP_MODE: ${APP_MODE}

  # 보조 서비스: 컨테이너 간 통신 확인용.
  client:
    image: curlimages/curl:latest
    depends_on:
      - web
    command: ["sh", "-c", "sleep 3; curl -s http://web:${NGINX_PORT}/"]
```

### 최상위 키

| 키 | 용도 |
| :--- | :--- |
| `services:` | 컨테이너 정의 (필수) |
| `volumes:` | 이름 있는 볼륨 선언 |
| `networks:` | 커스텀 네트워크 선언 (보통 자동 생성으로 충분) |

> **`version:` 키는 쓰지 않는다.** Compose v1 시절 유물로, v2에서는 폐기됐다. 넣으면 경고가 뜬다.

### build vs image

```yaml
web:
  build: .              # Dockerfile로 빌드
  image: my-web:v1      # 빌드 결과에 이 태그를 붙임
```

| 조합 | 동작 |
| :--- | :--- |
| `image:` 만 | 레지스트리에서 받아 실행 |
| `build:` 만 | 빌드해서 자동 생성 이름으로 |
| 둘 다 | 빌드한 뒤 지정한 태그를 붙임 (권장) |

빌드 옵션을 더 주려면:

```yaml
build:
  context: .
  dockerfile: Dockerfile.dev
  args:
    BUILD_VERSION: "1.0"
```

---

## 4. 컨테이너 이름과 프로젝트

보고서 17-1에서 `container_name` 을 일부러 생략했다. Compose가 자동으로 짓는다.

```
workspace-decoration-web-1
└────────┬────────┘ └┬┘ └┬┘
      프로젝트명    서비스  번호
```

프로젝트명 기본값은 **디렉토리 이름**이다. 바꾸려면:

```bash
docker compose -p myproject up -d
# 또는 .env 에 COMPOSE_PROJECT_NAME=myproject
```

### 왜 자동 명명이 나은가

`container_name: my-app` 을 고정하면 **이름 충돌**이 생긴다. 이미 `my-app` 이 있으면 실패한다. 또 같은 Compose 파일로 여러 인스턴스를 띄울 수 없다.

자동 명명이면 프로젝트명이 다르므로 충돌하지 않는다. 보고서에서 10번의 `docker run --name my-app` 과 Compose를 함께 써야 했기에 이 선택이 실용적이었다.

---

## 5. 서비스 디스커버리 — 핵심 기능

Compose는 프로젝트마다 **전용 네트워크**를 자동으로 만든다.

```bash
docker network ls | grep workspace
# 3a67505907f1   workspace-decoration_default   bridge    local
```

이 네트워크 안에서는 **서비스명이 곧 호스트명**이다.

```yaml
client:
  command: ["sh", "-c", "curl -s http://web:8080/"]
  #                              └─ 서비스명 web 이 DNS로 해석됨
```

```bash
docker compose logs client
# client-1  | <h1>hello, world!</h1>
```

### 이 한 줄이 증명하는 세 가지

보고서 17-2에서 정리한 내용이다.

1. **컨테이너 간 통신이 된다**
2. **서비스명이 DNS로 해석된다** (IP를 몰라도 됨)
3. **빌드한 이미지가 실제로 index.html을 서빙한다**

### IP를 쓰면 안 되는 이유

컨테이너 IP는 재시작할 때마다 바뀐다.

```
❌ http://172.18.0.3:8080     ← 재시작하면 깨짐
✅ http://web:8080            ← 항상 동작
```

### 포트 매핑이 필요 없다는 점

`client` 에는 `ports:` 가 전혀 없는데도 `web` 에 접속했다. [05번 문서](05-port-mapping-network.md)에서 다룬 내용이 여기서 실증된다.

```bash
docker compose logs web
# web-1 | 172.18.0.3 - - [...] "GET / ..." "curl/8.21.0"   ← client 컨테이너 (직통)
# web-1 | 172.18.0.1 - - [...] "GET / ..." "curl/8.7.1"    ← 호스트 (매핑 경유)
```

---

## 6. depends_on 의 함정

```yaml
client:
  depends_on:
    - web
```

**`depends_on` 은 "먼저 시작"만 보장하지 "준비 완료"를 보장하지 않는다.**

```
web 컨테이너 시작됨  ←  depends_on 이 보장하는 것
        ↓
nginx 프로세스 기동 중...
        ↓
실제로 요청을 받을 수 있음  ←  보장하지 않음
```

그래서 보고서의 client에 `sleep 3` 이 들어 있다.

```yaml
command: ["sh", "-c", "sleep 3; curl -s http://web:${NGINX_PORT}/"]
#                      └─ web 이 준비될 때까지 잠깐 기다림
```

### 제대로 하려면 — healthcheck

```yaml
services:
  web:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 5s
      timeout: 3s
      retries: 5

  client:
    depends_on:
      web:
        condition: service_healthy    # 건강해질 때까지 대기
```

실무에서 DB와 앱을 함께 띄울 때 반드시 마주치는 문제다. `sleep` 은 학습용 임시방편이고, 운영에서는 healthcheck나 애플리케이션 레벨의 재시도를 쓴다.

---

## 7. 운영 명령어

보고서 17-3의 내용이다.

### up — 실행

```bash
docker compose up            # 포그라운드 (로그가 화면에)
docker compose up -d         # 백그라운드
docker compose up -d --build # 이미지를 다시 빌드하고 실행
docker compose up -d web     # 특정 서비스만
```

`up` 은 **똑똑하다.** 이미 떠 있고 설정이 안 바뀌었으면 그대로 두고, 바뀐 서비스만 재생성한다.

```
 Container workspace-decoration-web-1  Recreated    ← 설정이 바뀜
 Container workspace-decoration-web-1  Started
```

### ps — 상태 확인

```bash
docker compose ps       # 실행 중인 것만
docker compose ps -a    # 종료된 것까지
```

보고서 17-3의 주의사항: `client` 는 curl 후 즉시 종료되므로 `ps` 에 안 보인다. `-a` 를 써야 한다.

```bash
docker compose ps
# NAME                         SERVICE   STATUS
# workspace-decoration-web-1   web       Up 8 seconds
#                                        ← client 가 없음

docker compose ps -a
# workspace-decoration-client-1   client   Exited (0) 5 seconds ago
# workspace-decoration-web-1      web      Up 8 seconds
```

### logs — 로그 확인

```bash
docker compose logs                  # 전체
docker compose logs web              # 특정 서비스
docker compose logs -f web           # 실시간 추적
docker compose logs --tail 5 web     # 마지막 5줄
docker compose logs --no-log-prefix client   # 서비스명 접두어 제거
```

### down — 종료

```bash
docker compose down        # 컨테이너 + 네트워크 삭제
docker compose down -v     # 볼륨까지 삭제 ⚠️
```

| 명령 | 컨테이너 | 네트워크 | 볼륨 |
| :--- | :--- | :--- | :--- |
| `stop` | 중지만 (남아 있음) | 유지 | 유지 |
| `down` | 삭제 | 삭제 | **유지** |
| `down -v` | 삭제 | 삭제 | **삭제** |

### 기타 유용한 명령

```bash
docker compose config          # .env 치환 결과 확인 (문법 검증도 됨)
docker compose exec web bash   # 실행 중인 컨테이너에 진입
docker compose restart web     # 재시작
docker compose build           # 빌드만
docker compose pull            # 이미지만 받기
```

**`docker compose config` 는 디버깅에 매우 유용하다.** 변수가 실제로 어떤 값으로 치환되는지 보여준다.

```bash
docker compose config
# services:
#   client:
#     command: [sh, -c, "sleep 3; curl -s http://web:8080/"]
#   web:
#     environment:
#       NGINX_PORT: "8080"
#     ports:
#       - target: 8080
#         published: "8081"
```

---

## 8. 상태 확인 루틴

보고서 17-3에서 정리한 실무 루틴이다.

```
1. docker compose ps -a
   → 무엇이 떠 있고 무엇이 죽었는지

2. docker compose logs <서비스>
   → 죽었다면 왜 죽었는지

3. docker compose up -d
   → 설정을 고쳤으면 재기동 (바뀐 서비스만 재생성됨)

4. docker compose up -d --build
   → 이미지 자체를 고쳤으면 재빌드까지
```

3번과 4번의 구분이 중요하다. **소스나 Dockerfile을 고쳤는데 `--build` 없이 `up` 하면 변경이 반영되지 않는다.**

---

## 9. 직접 해보기

```bash
mkdir ~/Desktop/compose-practice && cd ~/Desktop/compose-practice

echo '<h1>compose test</h1>' > index.html

cat > Dockerfile <<'EOF'
FROM nginx:latest
COPY index.html /usr/share/nginx/html/index.html
EOF

cat > docker-compose.yml <<'EOF'
services:
  web:
    build: .
    image: composetest:v1
    ports:
      - "9090:80"

  client:
    image: curlimages/curl:latest
    depends_on:
      - web
    command: ["sh", "-c", "sleep 3; curl -s http://web/"]
EOF

# 1. 설정 확인 (실행 전 문법 검증)
docker compose config

# 2. 실행
docker compose up -d

# 3. 상태 확인 — client 는 안 보인다
docker compose ps
docker compose ps -a          # 여기서는 보인다

# 4. 컨테이너 간 통신 증거
docker compose logs client
# client-1  | <h1>compose test</h1>

# 5. 호스트에서 접속
curl -s localhost:9090

# 6. 네트워크 확인
docker network ls | grep compose-practice

# 7. 서비스명 DNS 해석 확인
docker compose exec web getent hosts web

# 8. 소스 변경 후 재빌드 실험
echo '<h1>changed</h1>' > index.html
docker compose up -d              # --build 없음
curl -s localhost:9090            # 여전히 옛날 내용
docker compose up -d --build      # 재빌드
curl -s localhost:9090            # changed

# 9. 정리
docker compose down
docker rmi composetest:v1
cd ~/Desktop && rm -r compose-practice
```

**확인 문제**

1. `docker compose ps` 에 client가 안 보이는 이유는?
2. 8번에서 `--build` 없이는 왜 반영이 안 되나?
3. client에 `ports:` 가 없는데 어떻게 web에 접속하나?

<details>
<summary>답</summary>

1. curl 실행 후 즉시 종료되기 때문. `ps` 는 실행 중인 것만 보여준다. `ps -a` 를 써야 한다.
2. `up` 은 기존 이미지를 재사용한다. Dockerfile이나 COPY 대상 파일이 바뀌어도 자동으로 다시 빌드하지 않는다. `--build` 를 명시해야 한다.
3. 같은 Compose 네트워크 안에 있어서 서비스명 `web` 이 DNS로 해석되고, 컨테이너 포트로 직접 통신한다. 포트 매핑은 호스트 경계를 넘을 때만 필요하다.
</details>

---

## 10. 자주 하는 실수

| 실수 | 증상 | 해결 |
| :--- | :--- | :--- |
| `version:` 키 사용 | 경고 발생 | v2에서는 제거 |
| `--build` 없이 `up` | 변경 미반영 | 이미지 수정 시 `--build` |
| `depends_on` 을 준비 완료로 오해 | 간헐적 연결 실패 | healthcheck + `condition` |
| `ps` 만 보고 판단 | 종료된 서비스를 놓침 | `ps -a` |
| `down -v` 습관 | 볼륨 소실 | 평소엔 `down` |
| 컨테이너 간 통신에 `localhost` | 연결 실패 | 서비스명 사용 |
| 컨테이너 간 통신에 호스트 포트 | 연결 실패 | 컨테이너 포트 사용 |
| 들여쓰기에 탭 사용 | YAML 파싱 에러 | 스페이스만 사용 |

> **YAML 주의**: 탭 문자를 허용하지 않는다. 들여쓰기는 반드시 스페이스로 한다. `docker compose config` 로 문법을 미리 검증하는 습관이 좋다.

---

## 11. 예상 질문과 답변 포인트

평가 루브릭 **항목 5 보너스 1~3**(Compose 기초·멀티 컨테이너·운영 명령어)이 이 문서에서 나온다. 보너스는 "했다"가 아니라 **"배움 포인트를 설명할 수 있는가"** 를 본다.

---

### A. 루브릭 직결 문항

#### A-1. `docker run` 대신 Compose를 쓰면 무엇이 좋은가? (보너스 1의 배움 포인트)

**⚡ 답변 — 문제 상황부터 말한다**

> 10번에서는 `docker run -d -p 8081:80 --name my-app my-web:v1` 이라는 명령을 **사람이 기억하고 매번 정확히 입력**해야 했습니다. 인자를 하나라도 빠뜨리면 다르게 동작하는데, 그 사실이 어디에도 기록되지 않습니다.
>
> Compose로 옮기면 같은 내용이 파일로 남습니다. 그래서 ① **저장소에 커밋**되어 버전 관리·코드 리뷰 대상이 되고 ② 다른 사람이 **`docker compose up` 한 줄**로 동일 환경을 재현하며 ③ 무엇이 바뀌었는지 **`git diff` 로 드러납니다.**
>
> 한 문장으로 정리하면, **실행 방법이 개인의 기억에서 저장소의 자산으로 바뀌는 것**이 핵심입니다.

**1:1 대응을 보여주면 설득력이 올라간다**

| `docker run` 인자 | Compose 키 |
| :--- | :--- |
| `docker build -t my-web:v1 .` | `build: .` + `image: my-web:v1` |
| `-p 8081:80` | `ports:` |
| `-e NGINX_PORT=8080` | `environment:` |
| `-d` | `up -d` |
| `--name my-app` | `container_name:` (보통 생략) |

> 새 문법을 배우는 게 아니라 **이미 아는 것을 옮겨 적는 것**뿐입니다.

**📄 근거**: 보고서 **17-1** (대응표 + 실행 로그)

---

#### A-2. 컨테이너 간 통신은 어떻게 이루어지나? (보너스 2의 배움 포인트)

**⚡ 30초 답변**

> Compose가 프로젝트마다 **전용 브리지 네트워크**를 만들고, 그 안에 **서비스명을 DNS 이름으로 등록**합니다. 그래서 IP를 몰라도 `http://web:8080` 처럼 서비스명으로 접속할 수 있습니다.
>
> 컨테이너 IP는 재시작할 때마다 바뀌어서 하드코딩하면 곧 깨지지만, 서비스명은 안정적입니다.

**증거 한 줄이 세 가지를 동시에 증명한다**

```bash
docker compose logs client
# client-1  | <h1>hello, world!</h1>
```

> 이 한 줄로 ① 컨테이너 간 통신이 되고 ② 서비스명 `web` 이 DNS로 해석되고 ③ 빌드한 이미지가 실제로 `index.html` 을 서빙한다는 게 전부 증명됩니다.

**포트 매핑이 필요 없다는 점을 반드시 짚는다**

> `client` 에는 `ports:` 가 전혀 없는데도 접속에 성공했습니다. 로그의 출처 IP를 보면 차이가 드러납니다.
>
> ```
> 172.18.0.3  ← client 컨테이너 (직통)
> 172.18.0.1  ← 호스트 게이트웨이 (매핑 경유)
> ```
>
> **포트 매핑은 호스트 경계를 넘을 때만 필요합니다.**

**📄 근거**: 보고서 **17-2** + **8번**(액세스 로그)

---

#### A-3. Compose 운영 명령어와 상태 확인 루틴은? (보너스 3의 배움 포인트)

**⚡ 답변 — 루틴으로 정리해 말한다**

> 명령을 나열하기보다 **순서**로 답합니다.
>
> 1. **`docker compose ps -a`** — 무엇이 떠 있고 무엇이 죽었는지
> 2. **`docker compose logs <서비스>`** — 죽었다면 왜 죽었는지
> 3. **`docker compose up -d`** — 설정을 고쳤으면 재기동 (바뀐 서비스만 재생성됨)
> 4. **`docker compose up -d --build`** — 이미지 자체를 고쳤으면 재빌드까지
>
> 3번과 4번의 구분이 중요합니다. **소스나 Dockerfile을 고쳤는데 `--build` 없이 `up` 하면 변경이 반영되지 않습니다.**

**두 가지 함정을 덧붙인다**

> 첫째, `ps` 는 **실행 중인 것만** 보여줍니다. `client` 처럼 작업 후 끝나는 서비스는 `-a` 를 붙여야 보입니다.
>
> 둘째, `down` 과 `down -v` 의 차이입니다.

| 명령 | 컨테이너 | 네트워크 | 볼륨 |
| :--- | :--- | :--- | :--- |
| `stop` | 중지만 | 유지 | 유지 |
| `down` | 삭제 | 삭제 | **유지** |
| `down -v` | 삭제 | 삭제 | **삭제** ⚠️ |

**📄 근거**: 보고서 **17-3**

---

### B. 따라붙기 쉬운 후속 질문

#### B-1. `depends_on` 을 걸었는데 연결이 실패한다.

> **`depends_on` 은 "먼저 시작"만 보장하지 "준비 완료"를 보장하지 않습니다.** 컨테이너는 떴지만 내부 프로세스가 아직 요청을 받을 준비가 안 된 상태입니다.
>
> ```
> web 컨테이너 시작됨      ← depends_on 이 보장하는 것
>        ↓
> nginx 프로세스 기동 중...
>        ↓
> 실제로 요청을 받을 수 있음  ← 보장하지 않음
> ```
>
> 실습에서는 학습용이라 `sleep 3` 으로 우회했습니다. 제대로 하려면 healthcheck를 정의하고 `condition: service_healthy` 를 씁니다.
>
> ```yaml
> web:
>   healthcheck:
>     test: ["CMD", "curl", "-f", "http://localhost:8080/"]
>     interval: 5s
>     retries: 5
> client:
>   depends_on:
>     web:
>       condition: service_healthy
> ```
>
> DB와 앱을 함께 띄울 때 반드시 마주치는 문제입니다.

---

#### B-2. `docker compose ps` 에 서비스가 안 보입니다.

> `ps` 는 **실행 중인 컨테이너만** 보여줍니다. 작업 후 종료되는 서비스는 `docker compose ps -a` 로 봐야 합니다.
>
> 실습의 `client` 가 그 예입니다. curl 한 번 하고 끝나므로 `ps` 에는 안 나오지만 `ps -a` 에는 `Exited (0)` 로 나옵니다.

---

#### B-3. 코드를 고쳤는데 반영이 안 됩니다.

> `docker compose up -d` 는 **기존 이미지를 재사용**합니다. Dockerfile이나 `COPY` 대상 파일이 바뀌어도 자동으로 재빌드하지 않습니다.
>
> ```bash
> docker compose up -d --build
> ```
>
> 이게 Compose에서 가장 자주 나오는 혼란입니다. **설정(`.env`, `ports`) 변경은 `up -d` 로 충분하지만, 이미지 내용 변경은 `--build` 가 필요합니다.**

---

#### B-4. `container_name` 을 왜 안 썼나?

> Compose가 `프로젝트명-서비스명-번호` 로 자동 명명하게 뒀습니다. 두 가지 이유입니다.
>
> 첫째, **이름 충돌 회피**입니다. `container_name: my-app` 을 고정하면 10번 실습에서 만든 `my-app` 과 부딪힙니다. 실제로 그 문제가 있어서 생략했습니다.
>
> 둘째, 같은 Compose 파일로 **여러 인스턴스**를 띄울 수 없게 됩니다. 프로젝트명이 다르면 자동 명명은 충돌하지 않습니다.

---

#### B-5. `version:` 키는 왜 없나?

> Compose v1 시절의 유물로 **v2에서는 폐기**됐습니다. 넣으면 경고가 뜹니다. 요즘 문서나 블로그에 `version: "3.8"` 이 남아 있는 경우가 많은데 지금은 쓰지 않습니다.

---

#### B-6. `docker-compose` 와 `docker compose` 의 차이는?

> 하이픈이 있는 `docker-compose` 는 **v1**(Python으로 만든 별도 바이너리), 공백인 `docker compose` 는 **v2**(Go로 만든 Docker CLI 플러그인)입니다.
>
> v1은 지원이 끝났으므로 **v2를 씁니다.** 실습 환경에는 레거시 바이너리도 남아 있지만 보고서는 v2로 통일했습니다.

---

#### B-7. `build` 와 `image` 를 함께 쓰면 어떻게 되나?

```yaml
web:
  build: .              # Dockerfile로 빌드하고
  image: my-web:v1      # 그 결과에 이 태그를 붙임
```

| 조합 | 동작 |
| :--- | :--- |
| `image:` 만 | 레지스트리에서 받아 실행 |
| `build:` 만 | 빌드해서 자동 생성 이름으로 |
| 둘 다 | 빌드 후 지정한 태그 부여 (권장) |

> 둘 다 쓰면 빌드 결과에 의미 있는 이름이 붙어 `docker images` 에서 찾기 쉽습니다.

---

#### B-8. Compose 파일 문법이 맞는지 미리 확인하려면?

```bash
docker compose config
```

> **실행 전 문법 검증 + 변수 치환 결과 확인**을 동시에 해 줍니다. `.env` 값이 실제로 어떻게 들어가는지 보여주므로 디버깅에 매우 유용합니다.
>
> YAML은 **탭 문자를 허용하지 않습니다.** 들여쓰기를 탭으로 하면 파싱 에러가 나는데, 이 명령으로 미리 잡을 수 있습니다.

---

### C. 실전 시나리오

#### C-1. "Compose로 띄웠는데 서비스가 죽습니다."

```bash
docker compose ps -a                  # ① 어떤 서비스가 어떤 상태로 죽었나
docker compose logs <서비스>          # ② 왜 죽었나
docker compose config                 # ③ 설정이 의도대로 치환됐나
docker compose up -d --build          # ④ 이미지 문제면 재빌드
```

> ①에서 Exit code가 `0`이면 에러가 아니라 **할 일을 하고 정상 종료**한 것입니다. `client` 처럼 일회성 작업 서비스가 여기 해당합니다.

---

#### C-2. "다른 사람이 클론했는데 실행이 안 됩니다."

> 십중팔구 **`.env` 가 없는 경우**입니다. `.gitignore` 대상이라 클론 직후에는 존재하지 않습니다.
>
> ```bash
> cp .env.example .env
> docker compose up -d
> ```
>
> 그래서 보고서 12번의 재현 절차에 이 단계를 명시적으로 포함시켰습니다. 빠뜨리면 변수 미정의로 실패합니다.

---

#### C-3. "서비스 이름으로 접속이 안 됩니다."

> 세 가지를 확인합니다.
>
> 1. **같은 네트워크에 있나** — 다른 Compose 프로젝트면 네트워크가 다르다
> 2. **호스트 포트를 쓰고 있진 않나** — `web:8081`(호스트 포트)이 아니라 `web:8080`(컨테이너 포트)이어야 한다
> 3. **`localhost` 를 쓰고 있진 않나** — 컨테이너 안에서 `localhost` 는 자기 자신이다

```bash
docker compose exec client getent hosts web    # DNS 해석 확인
docker network ls | grep <프로젝트명>          # 네트워크 존재 확인
```

---

### D. 한 줄 요약 (외울 것)

| 개념 | 한 줄 |
| :--- | :--- |
| Compose의 가치 | 실행 방법이 **기억 → 저장소 자산**으로 |
| 서비스 디스커버리 | 전용 네트워크 + 서비스명 DNS 등록 |
| 컨테이너 간 통신 | 포트 매핑 불필요, **컨테이너 포트** 사용 |
| `depends_on` | 시작 순서만, 준비 완료는 healthcheck |
| `ps` vs `ps -a` | 종료된 서비스는 `-a` 로만 보임 |
| `up` vs `up --build` | 이미지 변경은 `--build` 필수 |
| `down` vs `down -v` | `-v` 는 볼륨까지 삭제 ⚠️ |

---

**이전 문서** → [06. 볼륨과 데이터 영속성](06-volumes-persistence.md)
**다음 문서** → [08. 환경 변수와 설정 분리](08-environment-variables.md)
