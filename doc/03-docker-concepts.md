# 03. 이미지와 컨테이너

> 보고서 대응: [7~9번 Docker 설치·운영·실행](../README.md), 14-1 이미지와 컨테이너의 차이

---

## 1. Docker가 해결하는 문제

"내 컴퓨터에서는 되는데요"라는 말이 나오는 이유는 실행 환경이 다르기 때문이다. OS 버전, 설치된 라이브러리, 환경 변수, 포트 사용 현황이 사람마다 다르다.

Docker는 **애플리케이션과 그것이 필요로 하는 환경을 통째로 포장**해서 어디서든 같게 동작하게 만든다.

### 가상머신(VM)과의 차이

```
   가상머신(VM)                      컨테이너
┌─────────────────┐            ┌─────────────────┐
│  앱 A   │  앱 B  │            │  앱 A   │  앱 B  │
├────────┼────────┤            ├────────┴────────┤
│ 게스트   │ 게스트  │            │  Docker Engine  │
│  OS    │  OS    │            ├─────────────────┤
├────────┴────────┤            │     호스트 OS    │
│   하이퍼바이저     │            ├─────────────────┤
├─────────────────┤            │      하드웨어     │
│    호스트 OS      │            └─────────────────┘
└─────────────────┘
  OS를 통째로 복제           커널을 공유, 프로세스만 격리
  무겁고 느림 (GB, 분)       가볍고 빠름 (MB, 초)
```

컨테이너는 **호스트의 커널을 공유**하고 프로세스 수준에서만 격리한다. 그래서 가볍다.

### "호스트"가 무엇인지부터 정해야 한다

이 문장은 macOS에서 곧바로 헷갈린다. macOS에는 리눅스 커널이 없는데 리눅스 컨테이너가 돌아가기 때문이다. 그렇다고 컨테이너가 macOS 커널을 쓰는 것도 아니다.

모순처럼 보이지만 아니다. **"호스트"라는 말이 두 층을 가리킬 수 있어서 생기는 혼동이다.**

여기서 호스트란 **컨테이너 런타임(Docker 데몬)이 도는 머신**을 뜻한다. 그래서 환경에 따라 층이 달라진다.

| | Linux | macOS / Windows |
| :--- | :--- | :--- |
| 물리 머신 | 내 PC | 내 Mac |
| 컨테이너의 **호스트** | **내 PC** (같음) | **Docker Desktop이 띄운 리눅스 VM** |
| 공유되는 커널 | 내 PC의 리눅스 커널 | **VM의 리눅스 커널** |

Linux에서는 두 층이 하나로 겹쳐서 구분할 일이 없다. macOS에서는 갈라진다. macOS에 리눅스 커널이 없으니 Docker Desktop이 경량 리눅스 VM을 하나 돌리고, **컨테이너는 그 VM 안에서 실행된다.** 컨테이너 입장에서 호스트는 macOS가 아니라 그 VM이다.

즉 규칙("호스트 커널을 공유한다")은 그대로다. 무엇이 호스트인지가 한 층 옮겨갈 뿐이다.

### 실측으로 확인하기

세 곳의 커널을 나란히 찍어 보면 분명해진다.

```bash
uname -s -r                          # ① macOS 자신
# Darwin 25.5.0

docker run --rm ubuntu uname -s -r   # ② ubuntu 컨테이너 안
# Linux 6.10.11-linuxkit

docker run --rm nginx uname -s -r    # ③ nginx(debian) 컨테이너 안
# Linux 6.10.11-linuxkit

docker info --format '{{.KernelVersion}}'   # ④ Docker 데몬이 보고하는 커널
# 6.10.11-linuxkit
```

여기서 네 가지가 한 번에 읽힌다.

1. **컨테이너는 macOS 커널을 쓰지 않는다.** `Darwin` 과 `Linux` 는 아예 다른 커널이다.
2. **②③④가 모두 `6.10.11-linuxkit` 으로 같다.** 이것이 곧 "커널을 공유한다"의 실체다. 서로 다른 두 컨테이너가 같은 커널 하나를 함께 쓰고 있다.
3. 그 커널은 **Docker 데몬이 도는 곳의 커널**이다(④와 일치). 데몬은 VM 안에 있으므로 그 커널이 VM의 커널이다.
4. 이름의 `linuxkit` 이 정체를 드러낸다. LinuxKit은 **Docker Desktop이 VM을 만들 때 쓰는 경량 리눅스**다. Ubuntu의 커널도 Debian의 커널도 아니다.

### 그러면 컨테이너 안의 `Ubuntu 26.04` 는 무엇인가

보고서 9번에서 ubuntu 컨테이너에 진입했을 때 `Ubuntu 26.04 LTS` 가 떴다. 커널은 리눅스킷인데 왜 우분투라고 나올까.

**리눅스 배포판은 "커널 + 유저랜드"인데, 컨테이너 이미지에는 유저랜드만 들어 있기 때문이다.**

```bash
docker run --rm ubuntu sh -c 'grep PRETTY_NAME /etc/os-release'
# PRETTY_NAME="Ubuntu 26.04 LTS"

docker run --rm nginx sh -c 'grep PRETTY_NAME /etc/os-release'
# PRETTY_NAME="Debian GNU/Linux 13 (trixie)"
```

두 컨테이너가 서로 다른 배포판이라고 말하지만, 앞에서 봤듯 **커널은 둘 다 `6.10.11-linuxkit` 으로 같다.**

| 구성 요소 | 어디서 오는가 |
| :--- | :--- |
| `/etc/os-release`, `apt`, `bash`, 라이브러리 | **이미지** (배포판마다 다름) |
| 커널 (시스템 콜, 스케줄러, 파일시스템, 네트워크 스택) | **호스트 하나를 공유** (모든 컨테이너가 동일) |

`/etc/os-release` 는 그냥 텍스트 파일이다. 배포판이 자기 이름을 적어둔 것일 뿐, 커널이 무엇인지와는 무관하다. **커널을 알고 싶으면 `uname -r` 을 봐야 한다.**

이 구조에서 두 가지가 따라 나온다.

- **이미지가 가벼운 이유**: 커널을 담지 않아도 되니 수십~수백 MB로 끝난다. VM 이미지가 GB 단위인 것과 대비된다.
- **리눅스 컨테이너가 macOS에서 그냥은 못 도는 이유**: 이미지 안의 프로그램은 리눅스 시스템 콜을 호출하는데 Darwin 커널은 그걸 모른다. 그래서 리눅스 커널을 가진 VM이 반드시 하나 필요하다.

### `uname` — 커널에 직접 묻는 명령

위에서 계속 쓴 명령이라 따로 정리한다. 이름은 `unix name` 의 줄임말이고, **실행 중인 커널에 질의**한다. `/etc/os-release` 처럼 누가 적어둔 파일을 읽는 게 아니라서 속일 수 없다.

```bash
uname -s -r
# Darwin 25.5.0
#   └┬─┘ └┬┘
#    │    └── release  — 커널 버전
#    └─────── system   — 커널 이름
```

#### 왜 두 옵션을 함께 쓰나

`-s` 는 옵션을 아예 안 줬을 때의 기본값이라, 단독으로는 쓸 일이 없다. `-r` 과 묶을 때 의미가 생긴다.

```bash
uname          # Darwin          ← -s 와 같다
uname -r       # 25.5.0          ← 무슨 OS인지 알 수 없다
uname -s -r    # Darwin 25.5.0   ← 이름이 붙어야 판단이 된다
```

커널을 비교할 때 이게 중요하다. 컨테이너에서 `Linux 6.10.11-linuxkit`, macOS에서 `Darwin 25.5.0` 이 나오면 **버전이 아니라 커널 종류부터 다르다**는 게 한눈에 보인다.

#### `-r` 은 커널 버전이지 OS 제품 버전이 아니다

혼동하기 쉬운 지점이다. macOS에서는 두 숫자가 어긋나 있다.

| 무엇 | 명령 | 값 |
| :--- | :--- | :--- |
| macOS 제품 버전 | `sw_vers -productVersion` | `26.5.2` |
| **Darwin 커널 버전** | **`uname -r`** | **`25.5.0`** |

보고서 2번의 실행 환경에 적힌 `macOS 26.5.2` 는 `sw_vers` 기준이다. `uname -r` 로는 다른 값이 나온다.

리눅스에서는 `6.10.11-linuxkit` 처럼 `주.부.패치-접미어` 형태다. **접미어가 빌드 주체를 드러내서**, `linuxkit` 이면 Docker Desktop의 VM 커널이라는 걸 알 수 있다.

#### 옵션 목록

잘못된 플래그를 주면 macOS가 목록을 알려준다.

```bash
uname -Z
# uname: illegal option -- Z
# usage: uname [-amnoprsv]
```

| 옵션 | 이름 | macOS 출력 |
| :--- | :--- | :--- |
| `-s` | system name | `Darwin` |
| `-r` | release | `25.5.0` |
| `-m` | machine | `arm64` |
| `-p` | processor | `arm` |
| `-n` | nodename | 호스트명 |
| `-o` | operating system | `Darwin` (리눅스는 `GNU/Linux`) |
| `-v` | version | 빌드 날짜까지 포함한 긴 문자열 |
| `-a` | all | 전부 |

`-v` 에는 커널의 실제 이름이 드러난다. Darwin 커널은 XNU다.

```bash
uname -v
# Darwin Kernel Version 25.5.0: Tue Jun  9 22:28:29 PDT 2026; root:xnu-12377.121.10~1/RELEASE_ARM64_T6030
```

#### 플래그 순서는 출력 순서를 바꾸지 않는다

```bash
uname -s -r    # Darwin 25.5.0
uname -sr      # Darwin 25.5.0
uname -r -s    # Darwin 25.5.0   ← 뒤집어도 Darwin 이 먼저
```

출력은 `-a` 가 정한 고정 순서(`s n r v m`)를 따른다. 옵션 순서가 결과를 바꾸는 `ls` 같은 명령과 다른 점이다.

#### `-a` 는 보고서에 그대로 붙이지 않는다

`-a` 에는 `-n`(호스트명)이 딸려 온다. macOS 기본 호스트명은 계정 이름을 따라가서 **실명이 그대로 들어가는 경우가 많다.**

```bash
uname -a
# Darwin ****-MacBookPro.local 25.5.0 Darwin Kernel Version 25.5.0: ... arm64
#        └──────────┬─────────┘
#                   └── 실명이 들어갈 수 있는 자리
```

그래서 문서에는 `-a` 대신 **필요한 것만 골라 쓴다.** 위에서 `uname -s -r` 을 쓴 데는 이 이유도 있다 (보고서 18번 마스킹 규칙과 같은 맥락).

#### macOS(BSD)와 Linux(GNU)의 차이

| | macOS (BSD) | Linux (GNU) |
| :--- | :--- | :--- |
| `-o` | `Darwin` | `GNU/Linux` |
| `-i` | **없음** | 있음 (대개 `unknown`) |
| 긴 옵션 (`--kernel-release`) | **없음** | 있음 |

`-s`, `-r`, `-m`, `-a` 는 양쪽 같으므로 스크립트에서는 이것들만 쓰는 게 안전하다. `stat` 만큼 갈리지는 않지만 차이는 있다.

### 보고서 7번의 출력이 이 구조를 보여준다

```
Client:  OS/Arch: darwin/arm64    ← 명령을 치는 쪽 = macOS
Server:  OS/Arch: linux/arm64     ← 데몬과 컨테이너가 도는 쪽 = VM 안의 리눅스
```

같은 머신에서 친 한 명령의 출력인데 OS가 둘로 갈린다. **CLI는 macOS에, 데몬은 리눅스 VM에** 있다는 뜻이다. 컨테이너는 후자에서 돈다.

> 정리하면 macOS에서의 층은 이렇다.
>
> ```
> 컨테이너 (Ubuntu 유저랜드)  ← /etc/os-release 가 "Ubuntu" 라고 말하는 층
>      ↕ 시스템 콜
> 리눅스 VM 커널 6.10.11-linuxkit   ← 실제로 공유되는 커널. 컨테이너의 "호스트"
>      ↕ 가상화 (Virtualization.framework)
> macOS Darwin 25.5.0              ← 물리 머신. 컨테이너와 직접 닿지 않는다
> ```
>
> Linux에서는 가운데 층이 없어 `컨테이너 → 호스트 커널` 두 층으로 끝난다.

---

## 2. 클라이언트 – 데몬 구조

Docker는 하나의 프로그램이 아니라 **두 부분**으로 나뉜다.

```
  docker CLI  ──(요청)──►  Docker 데몬(dockerd)  ──►  컨테이너
  (클라이언트)              (실제 일하는 쪽)
```

이 구조를 알아야 보고서 15-1의 에러를 이해할 수 있다.

```bash
docker --version
# Docker version 27.3.1, build ce12230     ← CLI는 살아 있음

docker info
# Cannot connect to the Docker daemon at unix:///Users/kim/.docker/run/docker.sock.
# Is the docker daemon running?            ← 데몬이 죽어 있음
```

**`docker --version` 이 나온다고 Docker를 쓸 수 있는 게 아니다.** 버전 출력은 CLI 혼자 할 수 있지만, 실제 작업은 데몬이 한다.

### 함정 — `docker --version` 과 `docker version` 은 다른 명령이다

하이픈 두 개 차이인데 동작이 완전히 다르다. **이걸 같은 명령으로 알고 있으면 위 설명이 이해되지 않는다.**

| | `docker --version` | `docker version` |
| :--- | :--- | :--- |
| 출력 | **한 줄** | Client 블록 + **Server 블록** |
| 데몬에 접속하는가 | **안 한다** | **한다** |
| 데몬이 꺼져 있으면 | 그대로 성공 | Client만 찍고 실패 |

직접 확인해 보면 분명하다. 가짜 소켓을 물려 데몬이 없는 상황을 만든 것이다.

```bash
DOCKER_HOST=unix:///tmp/nonexistent.sock docker --version
# Docker version 27.3.1, build ce12230     ← 성공. 종료코드 0
```

```bash
DOCKER_HOST=unix:///tmp/nonexistent.sock docker version
#  Version:           27.3.1
#  OS/Arch:           darwin/arm64          ← Client 까지만 나오고
# Cannot connect to the Docker daemon at unix:///tmp/nonexistent.sock.
#                                          ← Server 자리에서 끊긴다. 종료코드 1
```

`--version` 은 자기 버전 문자열을 찍고 끝난다. 데몬이 있든 없든 결과가 같으니 **동작 가능 여부의 근거가 될 수 없다.**

### 데몬 확인은 "데몬에 질의하는 명령"이면 된다

`docker info` 만 되는 게 아니다. **`docker version` 도 데몬에 질의하므로 `Server:` 섹션이 나왔다는 것 자체가 데몬 응답의 증거다.**

| 확인 대상 | 쓸 수 있는 명령 | 실패하면 |
| :--- | :--- | :--- |
| CLI 설치 | `docker --version` | Docker 미설치 |
| **데몬 동작** | **`docker version`** (Server 블록 확인) 또는 **`docker info`** | 앱이 꺼져 있음 (macOS는 `open -a Docker`) |

둘 중 무엇을 쓸지는 필요한 정보량으로 정한다.

- `docker version` — 클라이언트/서버 버전과 아키텍처. **가볍고, 분리 구조가 눈에 보인다.**
- `docker info` — 컨테이너 수, 스토리지 드라이버, 커널 버전 등 수십 줄. 상세 진단용.

보고서 7번이 `docker version` 을 쓰는 이유가 이것이다. `Server: Docker Desktop ...` 한 줄로 데몬 응답과 클라이언트/서버 분리를 동시에 보여주므로, 별도 명령을 하나 더 칠 필요가 없다.

---

## 3. 이미지 — 빌드 산출물

**이미지는 "실행 환경의 스냅샷"이다.** 읽기 전용이고, 변경할 수 없다.

### 레이어 구조

이미지는 **여러 층(layer)이 쌓인 형태**다. Dockerfile의 각 명령이 한 층을 만든다.

```
┌──────────────────────────────────┐
│ COPY default.conf.template ...   │  ← 층 3 (우리가 추가)
├──────────────────────────────────┤
│ COPY index.html ...              │  ← 층 2 (우리가 추가)
├──────────────────────────────────┤
│ nginx:latest (여러 층으로 구성)  │  ← 층 1 (베이스)
└──────────────────────────────────┘
              모두 읽기 전용
```

보고서 10번의 빌드 로그가 이 구조를 그대로 보여준다.

```
#5 [1/3] FROM docker.io/library/nginx:latest    ← 베이스
#7 [2/3] COPY index.html ...                    ← 층 추가
#8 [3/3] COPY default.conf.template ...         ← 층 추가
```

### 레이어가 주는 이점

1. **저장 공간 절약** — 여러 이미지가 같은 베이스를 쓰면 그 층을 공유한다.
2. **전송 효율** — `docker pull` 시 이미 있는 층은 받지 않는다.
3. **빌드 캐시** — 바뀌지 않은 층은 다시 만들지 않는다.

캐시 동작은 같은 Dockerfile로 두 번 빌드해 보면 바로 드러난다. 아래는 `index.html` 은 그대로 두고 `default.conf.template` 만 한 줄 고친 뒤의 **2차 빌드** 로그다.

```
#5 [1/3] FROM docker.io/library/nginx:latest@sha256:640dee81b9ada...
#5 DONE 0.0s
#6 [2/3] COPY index.html /usr/share/nginx/html/index.html
#6 CACHED                                        ← 안 바뀌어서 재사용
#7 [3/3] COPY default.conf.template /etc/nginx/templates/default.conf.template
#7 DONE 0.0s                                     ← 바뀌어서 다시 실행
```

바뀐 레이어부터 그 뒤가 다시 실행되고, 앞쪽은 재사용된다. 자세한 순서 전략은 [04. Dockerfile](04-dockerfile.md)의 레이어 캐시 절에 있다.

> 이 로그는 캐시 동작을 보이려고 따로 재현한 것이다. 보고서 17-4는 **재빌드 없이** 환경 변수만으로 포트를 바꾸는 시연이라 빌드 로그가 없다.

### 이미지 식별

```bash
docker images
# REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
# nginx        latest    640dee81b9ad   10 hours ago   256MB
# my-web       v1        46b70910e1e1   2 minutes ago  256MB
```

| 항목 | 의미 |
| :--- | :--- |
| REPOSITORY | 이미지 이름 |
| TAG | 버전 라벨. 생략하면 `latest` |
| IMAGE ID | 내용 기반 해시. 내용이 같으면 ID도 같다 |

> **`latest` 함정**: `latest` 는 "최신"이라는 뜻이 아니라 그냥 **태그를 생략했을 때의 기본 이름**이다. 언제 갱신되는지 보장이 없으므로, 실제 운영에서는 `nginx:1.27` 처럼 버전을 고정하는 게 안전하다.

---

## 4. 컨테이너 — 실행 인스턴스

**컨테이너는 이미지 위에 얇은 쓰기 레이어를 하나 얹은 것**이다.

```
┌──────────────────────────────────┐
│      쓰기 가능 레이어             │  ← 컨테이너마다 하나씩, 삭제 시 사라짐
├══════════════════════════════════┤
│      이미지 (읽기 전용)           │  ← 모든 컨테이너가 공유
└──────────────────────────────────┘
```

### Copy-on-Write

컨테이너 안에서 파일을 수정하면 어떻게 될까? 이미지는 읽기 전용인데?

```
1. 읽기만 하면        → 이미지 층에서 그대로 읽는다
2. 수정하려고 하면    → 그 파일을 쓰기 레이어로 복사한 뒤 수정한다
3. 이후 읽으면        → 쓰기 레이어의 것이 보인다 (이미지 것을 가림)
```

이것을 **Copy-on-Write(CoW)** 라고 한다. 덕분에 이미지 하나로 컨테이너 수십 개를 띄워도 디스크를 거의 안 쓴다.

### 이미지 1 : 컨테이너 N

보고서 10번에서 실제로 확인했다. 같은 `my-web:v1` 이미지로 두 컨테이너를 띄웠다.

```bash
docker run -d -p 8081:80 --name my-app  my-web:v1
docker run -d -p 8082:80 --name my-app2 my-web:v1

docker ps
# NAMES     PORTS                  STATUS
# my-app2   0.0.0.0:8082->80/tcp   Up 2 seconds
# my-app    0.0.0.0:8081->80/tcp   Up 17 seconds
```

---

## 5. 이미지 vs 컨테이너 — 세 관점 정리

보고서 14-1의 핵심 표다.

| 관점 | 이미지 | 컨테이너 |
| :--- | :--- | :--- |
| **빌드** | `docker build` 의 결과물. 불변 스냅샷 | 빌드하지 않는다. 이미지에서 생성될 뿐 |
| **실행** | 그 자체로는 실행되지 않는다 | `docker run` 이 만든 실행 인스턴스 |
| **변경** | 바꾸려면 다시 빌드 (새 ID 생성) | 변경은 쓰기 레이어에만, 원본 이미지는 그대로 |

### 비유

```
이미지   =  붕어빵 틀 / 설계도 / 클래스(class)
컨테이너 =  붕어빵     / 건물   / 인스턴스(instance)
```

틀 하나로 붕어빵 여러 개를 찍고, 붕어빵을 먹어도 틀은 그대로다.

---

## 6. 컨테이너 생명주기

```
    docker create          docker start
 이미지 ──────────► created ──────────► running
                                          │
                        docker stop       │
                    ┌─────────────────────┘
                    ▼
                 exited ──── docker start ────► running
                    │
                    │ docker rm
                    ▼
                  삭제됨 (쓰기 레이어도 함께 소멸)
```

`docker run` = `create` + `start` 를 한 번에 하는 명령이다.

### 컨테이너의 수명 = PID 1의 수명

**이것이 가장 중요한 개념 중 하나다.** 컨테이너는 "켜 두는 상자"가 아니라 **프로세스를 감싼 것**이다. 메인 프로세스가 끝나면 컨테이너도 끝난다.

보고서 16번에서 실제로 막혔던 지점이다.

```bash
docker run --name test ubuntu sh -c "echo hello > /tmp/a.txt"
# echo가 즉시 끝나므로 컨테이너도 즉시 종료

docker exec test cat /tmp/a.txt
# Error response from daemon: container ... is not running
#                             └─ 종료된 컨테이너에는 exec 할 수 없다
```

해결은 프로세스를 살려두는 것이다.

```bash
docker run -d --name test ubuntu sleep 300   # 300초간 살아 있음
docker exec test sh -c "echo hello > /tmp/a.txt"
docker exec test cat /tmp/a.txt
# hello
```

`nginx` 이미지가 계속 떠 있는 이유도 같다. nginx 프로세스가 종료되지 않고 계속 돌기 때문이다.

---

## 7. 기본 명령어

### 이미지 관련

```bash
docker pull nginx              # 레지스트리에서 받기
docker images                  # 목록
docker rmi nginx               # 삭제 (remove image)
docker build -t my-web:v1 .    # Dockerfile로 빌드
```

### 컨테이너 관련

```bash
docker run nginx               # 실행 (포그라운드)
docker run -d nginx            # 백그라운드 실행 (detached)
docker run -it ubuntu bash     # 대화형 실행 (interactive + tty)

docker ps                      # 실행 중인 것만
docker ps -a                   # 종료된 것까지 전부

docker logs my-app             # 로그 보기
docker logs -f my-app          # 실시간 추적

docker exec my-app ls /        # 실행 중인 컨테이너에서 명령 실행
docker exec -it my-app bash    # 실행 중인 컨테이너에 진입

docker stop my-app             # 중지
docker rm my-app               # 삭제
docker rm -f my-app            # 강제 삭제 (중지 + 삭제)
```

### 자주 쓰는 옵션

| 옵션 | 의미 | 예시 |
| :--- | :--- | :--- |
| `-d` | 백그라운드 | `docker run -d nginx` |
| `-it` | 대화형 터미널 | `docker run -it ubuntu bash` |
| `--name` | 이름 지정 | `--name my-app` |
| `--rm` | 종료 시 자동 삭제 | 일회성 실행에 유용 |
| `-p` | 포트 매핑 | `-p 8081:80` |
| `-v` | 볼륨 마운트 | `-v my-vol:/data` |
| `-e` | 환경 변수 | `-e NGINX_PORT=8080` |

### `--name` 을 안 주면

보고서 8번에서 나온 `jolly_elgamal` 이 그 예다. Docker가 형용사+과학자 이름 조합으로 임의 명명한다. 나중에 찾기 어려우므로 계속 쓸 컨테이너는 이름을 주는 게 좋다.

---

## 8. 직접 해보기

```bash
# 1. 데몬 확인 (Server 블록이 나오면 데몬이 응답한 것)
docker version

# 2. hello-world — 가장 작은 이미지로 동작 확인
docker run hello-world

# 3. 이미지가 없으면 자동으로 받아온다
docker images | grep hello-world

# 4. ubuntu 컨테이너에 진입해 보기
docker run -it --name ubuntu-test ubuntu /bin/bash
# 컨테이너 안에서:
#   cat /etc/os-release    ← 호스트와 다른 OS
#   whoami                 ← root
#   ls /                   ← 독립된 파일시스템
#   exit

# 5. 종료된 컨테이너 확인
docker ps          # 안 보임
docker ps -a       # 보임 (Exited 상태)

# 6. 컨테이너 수명 실험
docker run -d --name alive ubuntu sleep 60
docker ps                                  # 살아 있음
docker exec alive echo "안에서 실행"
sleep 65
docker ps                                  # 사라짐 (sleep 끝남)
docker ps -a                               # Exited로 남아 있음

# 7. 정리
docker rm -f ubuntu-test alive
docker ps -a
```

**확인 문제**

1. 같은 이미지로 컨테이너 3개를 띄우면 디스크를 3배 쓰는가?
2. 컨테이너 안에서 `apt install` 로 패키지를 깔았다. 컨테이너를 지우고 같은 이미지로 새로 띄우면 그 패키지가 있는가?
3. `docker run ubuntu` 를 하면 왜 즉시 종료되는가?

<details>
<summary>답</summary>

1. 아니다. 이미지 층은 공유되고 컨테이너마다 얇은 쓰기 레이어만 추가된다.
2. 없다. 설치 내용은 그 컨테이너의 쓰기 레이어에만 있었고 삭제와 함께 사라졌다. 영구히 남기려면 Dockerfile에 `RUN apt install` 을 써서 이미지에 굽거나, 볼륨을 쓴다.
3. ubuntu 이미지의 기본 명령이 `bash` 인데, `-it` 없이 실행하면 입력이 없어 bash가 즉시 끝난다. 컨테이너 수명 = PID 1의 수명이므로 컨테이너도 종료된다.
</details>

---

## 9. 자주 하는 실수

| 실수 | 증상 | 해결 |
| :--- | :--- | :--- |
| `docker --version` 만 보고 준비됐다고 판단 | 이후 명령이 전부 실패 | `docker version` 의 `Server:` 또는 `docker info` 로 데몬 확인 |
| `docker --version` 과 `docker version` 을 같은 명령으로 앎 | 데몬 확인을 했다고 착각 | 하이픈 없는 쪽만 데몬에 질의한다 |
| 종료된 컨테이너에 `exec` | `is not running` | `docker start` 하거나 장기 실행 프로세스로 띄운다 |
| `docker ps` 만 보고 컨테이너가 없다고 판단 | 이름 충돌 발생 | `docker ps -a` 로 종료된 것까지 확인 |
| 컨테이너 안에서 설정 변경 후 재생성 | 변경분 소실 | Dockerfile에 반영하거나 볼륨 사용 |
| `latest` 태그를 운영에 사용 | 어느 날 갑자기 동작이 달라짐 | 버전 명시 (`nginx:1.27`) |

---

## 10. 예상 질문과 답변 포인트

평가 루브릭 **항목 3-1**(이미지와 컨테이너의 차이)과 **항목 1-3**(Docker 동작 가능 상태)이 이 문서에서 나온다.

---

### A. 루브릭 직결 문항

#### A-1. 이미지와 컨테이너의 차이를 "빌드/실행/변경" 관점에서 구분해 설명할 수 있는가?

**⚡ 답변 — 세 관점을 순서대로 짚는다**

> **빌드 관점**에서 이미지는 `docker build` 의 산출물이고, 읽기 전용 레이어가 쌓인 불변 스냅샷입니다. 컨테이너는 빌드되지 않고 이미지에서 생성될 뿐입니다.
>
> **실행 관점**에서 이미지는 그 자체로 실행되지 않습니다. `docker run` 이 이미지 위에 **쓰기 가능 레이어**를 얹어 만든 실행 인스턴스가 컨테이너입니다.
>
> **변경 관점**에서 이미지를 바꾸려면 다시 빌드해야 하고 새 ID가 생깁니다. 컨테이너에서 일어난 변경은 쓰기 레이어에만 쌓이고 원본 이미지는 그대로입니다. 그래서 이미지 하나로 컨테이너 여러 개를 띄울 수 있습니다.

**실습 근거를 반드시 붙인다**

> 실습에서 `my-web:v1` 이미지 하나로 `my-app` 과 `my-app2` 를 동시에 띄운 것이 **이미지 1 : 컨테이너 N** 관계의 증거입니다. 그리고 11번 대조 실험에서 컨테이너에 만든 파일이 삭제와 함께 사라진 것이 **"변경은 컨테이너 레이어에만 남는다"** 의 증거입니다.

**보조 — 비유가 필요하면**

```
이미지   =  붕어빵 틀 / 설계도 / 클래스(class)
컨테이너 =  붕어빵     / 건물   / 인스턴스(instance)
```

> 틀 하나로 붕어빵 여러 개를 찍고, 붕어빵을 먹어도 틀은 그대로입니다.

**📄 근거**: 보고서 **14-1** (3관점 표) + **10번**(1:N) + **11번**(변경 소실)

---

#### A-2. `docker --version` 이 출력되고, Docker가 동작 가능한 상태인가?

**⚡ 30초 답변**

> 이 질문은 두 가지를 묻고 있습니다. **`docker --version` 만으로는 동작 가능 여부를 알 수 없습니다.** Docker는 CLI와 데몬이 분리된 구조라, 버전 출력은 CLI 혼자 할 수 있지만 실제 작업은 데몬이 합니다.
>
> 그래서 보고서 7번에서는 `docker version` 까지 확인했습니다. 이 명령은 Client 정보를 찍은 뒤 **데몬에 질의해** Server 섹션을 채우므로, `Server: Docker Desktop ...` 이 출력됐다는 것 자체가 데몬이 응답했다는 증거입니다. 실습 중 CLI는 정상인데 데몬이 꺼져 있어 실패한 사례를 15-1에 기록했습니다.

| 확인 대상 | 명령 | 실패하면 |
| :--- | :--- | :--- |
| CLI 설치 | `docker --version` | Docker 미설치 |
| 데몬 동작 | `docker version` 의 `Server:` 블록 (또는 `docker info`) | 앱이 꺼져 있음 |

**따라붙을 질문**

- *"`docker info` 로 해야 하는 것 아닌가?"* → `docker info` 도 됩니다. 데몬에 질의하는 명령이면 무엇이든 증거가 됩니다. `docker version` 을 쓴 이유는 **데몬 응답과 클라이언트/서버 분리를 한 번에** 보여주기 때문입니다. `docker info` 는 수십 줄이라 상세 진단에 씁니다.
- *"`docker --version` 과 `docker version` 이 다른 명령인가?"* → 다릅니다. 하이픈 있는 쪽은 **데몬에 접속하지 않아** 데몬이 꺼져 있어도 종료코드 0으로 성공합니다. 그래서 동작 가능 여부의 근거가 못 됩니다.

**📄 근거**: 보고서 **7번** + **15-1**

---

### B. 따라붙기 쉬운 후속 질문

#### B-1. 같은 이미지로 컨테이너 3개를 띄우면 디스크를 3배 쓰나?

> 아닙니다. **이미지 레이어는 공유**되고 컨테이너마다 얇은 쓰기 레이어만 추가됩니다.
>
> **Copy-on-Write** 방식이라 파일을 읽기만 하면 이미지 층에서 그대로 읽고, 수정할 때만 그 파일을 쓰기 레이어로 복사한 뒤 고칩니다. 그래서 256MB 이미지로 컨테이너 10개를 띄워도 디스크는 256MB + 변경분 정도만 씁니다.

---

#### B-2. 컨테이너 안에서 `apt install` 로 패키지를 깔았다. 컨테이너를 지우면?

> 사라집니다. 설치 내용이 그 컨테이너의 쓰기 레이어에만 있었기 때문입니다. 같은 이미지로 새 컨테이너를 띄우면 언제나 깨끗한 초기 상태로 시작합니다.
>
> 영구히 남기려면 두 가지 중 하나입니다. **패키지라면** Dockerfile에 `RUN apt install` 을 써서 이미지에 굽고, **데이터라면** 볼륨을 씁니다.

---

#### B-3. 컨테이너가 자꾸 바로 종료된다. 왜인가?

> **컨테이너의 수명은 PID 1 프로세스의 수명과 같습니다.** 메인 프로세스가 끝나면 컨테이너도 끝납니다. 컨테이너는 "켜 두는 상자"가 아니라 **프로세스를 격리해 감싼 것**입니다.
>
> 실습에서 실제로 겪었습니다. `docker run --name test ubuntu sh -c "echo hello > /tmp/a.txt"` 는 echo가 즉시 끝나므로 컨테이너도 곧바로 종료되고, 그 뒤 `docker exec` 를 하면 `is not running` 이 납니다. `sleep 300` 처럼 오래 도는 프로세스로 바꿔서 해결했습니다.
>
> nginx 컨테이너가 계속 떠 있는 이유도 같습니다. nginx 프로세스가 종료되지 않고 계속 돌기 때문입니다.

**📄 근거**: 보고서 **16번 회고**

---

#### B-4. `docker run ubuntu` 는 왜 즉시 끝나나?

> ubuntu 이미지의 기본 명령이 `bash` 인데, `-it` 없이 실행하면 입력이 연결되지 않아 bash가 할 일이 없어 즉시 종료됩니다. 컨테이너 수명 = PID 1 수명이므로 컨테이너도 끝납니다.
>
> `docker ps -a` 로 보면 Exit code가 `0`(정상 종료)입니다. 에러가 아니라 **할 일을 다 하고 끝난 것**이라는 신호입니다.

---

#### B-5. VM과 컨테이너의 차이는?

> VM은 게스트 OS를 통째로 올려 하이퍼바이저 위에서 돌리므로 무겁습니다(GB 단위, 부팅 수 분). 컨테이너는 **호스트 커널을 공유**하고 프로세스 수준에서만 격리하므로 가볍습니다(MB 단위, 기동 수 초).
>
> 대신 커널을 공유하므로 **격리 수준은 VM보다 낮습니다.** 커널 취약점이 있으면 컨테이너 경계를 넘을 수 있어서, 신뢰할 수 없는 코드를 돌릴 때는 VM이 더 안전합니다.

---

#### B-6. macOS에서 리눅스 컨테이너가 어떻게 도나?

> macOS에는 리눅스 커널이 없어서 **Docker Desktop이 경량 리눅스 VM을 하나 돌립니다.** 컨테이너는 그 VM의 커널을 공유합니다.
>
> `docker version` 출력이 이 구조를 보여줍니다.
>
> ```
> Client:  OS/Arch: darwin/arm64    ← 명령을 치는 쪽 = macOS
> Server:  OS/Arch: linux/arm64     ← 컨테이너가 도는 쪽 = 리눅스
> ```
>
> 그래서 macOS에서는 `systemctl status docker` 같은 systemd 명령이 통하지 않습니다.
>
> **"컨테이너는 호스트 커널을 공유한다면서 macOS 커널을 쓰는 것이냐"** 고 되물으면 이렇게 답합니다. 규칙은 그대로이고, **호스트가 macOS가 아니라 그 리눅스 VM**입니다. 컨테이너 입장에서 자신을 실행해 주는 머신이 VM이기 때문입니다. Linux에서는 물리 머신과 호스트가 겹쳐서 구분할 일이 없지만 macOS에서는 한 층 갈라집니다.
>
> 커널을 직접 찍어 보면 분명합니다.
>
> ```bash
> uname -r                                   # Darwin 25.5.0      (macOS)
> docker run --rm ubuntu uname -r            # 6.10.11-linuxkit
> docker run --rm nginx  uname -r            # 6.10.11-linuxkit
> docker info --format '{{.KernelVersion}}'  # 6.10.11-linuxkit
> ```
>
> 서로 다른 두 컨테이너와 데몬이 **모두 같은 커널 하나**를 가리키고, macOS의 Darwin과는 다릅니다. 이름의 `linuxkit` 이 Docker Desktop의 VM 커널이라는 표시입니다.
>
> 이어서 *"그럼 컨테이너 안의 `Ubuntu 26.04` 는 뭐냐"* 고 물으면 **배포판 = 커널 + 유저랜드인데 이미지에는 유저랜드만 들어 있다**고 답합니다. `/etc/os-release` 는 배포판이 자기 이름을 적어둔 텍스트 파일일 뿐이라, 커널을 알려면 `uname -r` 을 봐야 합니다. 위에서 ubuntu와 nginx(debian)가 서로 다른 배포판을 표시하면서 커널은 같았던 것이 그 증거입니다.

---

#### B-7. 이미지 태그 `latest` 는 최신 버전인가?

> 아닙니다. **태그를 생략했을 때의 기본 이름**일 뿐입니다. 자동으로 갱신된다는 보장도, 실제로 최신이라는 보장도 없습니다.
>
> 운영에서는 `nginx:1.27` 처럼 버전을 고정해야 합니다. `latest` 를 쓰면 어느 날 베이스 이미지가 바뀌어 동작이 달라져도 원인을 찾기 어렵습니다.

---

#### B-8. `docker stop` 과 `docker rm` 의 차이는?

> `stop` 은 프로세스를 멈출 뿐 **컨테이너와 쓰기 레이어는 남습니다.** `docker start` 로 다시 켜면 그 안의 파일도 그대로입니다.
>
> `rm` 이 실제 삭제이고, 이때 쓰기 레이어의 데이터가 사라집니다. 데이터가 없어지는 시점은 `stop` 이 아니라 `rm` 입니다.

---

### C. 실전 시나리오

#### C-1. "Docker 명령이 전부 실패합니다."

> CLI와 데몬을 분리해서 확인합니다.
>
> ```bash
> docker --version    # 성공 → CLI는 정상 (데몬에 접속하지 않는 명령)
> docker version      # Client 만 나오고 실패 → 데몬 문제
> open -a Docker      # macOS 기동
> ```
>
> 두 명령의 결과가 갈리는 지점이 문제의 경계입니다. 앞쪽은 CLI 혼자 처리하고 뒤쪽은 데몬에 질의하므로, **뒤쪽만 실패하면 범인은 데몬**입니다. 실습에서 실제로 이 방식으로 원인을 특정했습니다.

---

#### C-2. "컨테이너가 죽었습니다. 원인을 어떻게 찾나요?"

```bash
docker ps -a                    # Exit code 확인
docker logs <이름>              # 왜 죽었는지
docker inspect <이름> --format '{{.State.ExitCode}} {{.State.Error}}'
```

| Exit code | 의미 |
| :--- | :--- |
| 0 | 정상 종료 — 명령이 끝난 것. 컨테이너 수명 문제 |
| 1 | 애플리케이션 에러 |
| 125 | Docker 데몬 오류 |
| 126 | 명령을 실행할 수 없음 (권한 등) |
| 127 | 명령을 찾을 수 없음 (경로 오타) |
| 137 | 강제 종료 (OOM 등) |

> **0이면 에러가 아닙니다.** 할 일을 다 하고 끝난 것이므로 "왜 계속 안 도는가"가 아니라 "무슨 프로세스를 돌리려 했는가"를 봐야 합니다.

---

### D. 한 줄 요약 (외울 것)

| 개념 | 한 줄 |
| :--- | :--- |
| 이미지 | 빌드 산출물, 읽기 전용, 불변 |
| 컨테이너 | 이미지 + 쓰기 레이어, 실행 인스턴스 |
| 관계 | 이미지 1 : 컨테이너 N |
| 디스크 | 레이어 공유 + Copy-on-Write |
| 컨테이너 수명 | **PID 1 프로세스의 수명** |
| 데이터 소멸 시점 | `stop` 이 아니라 `rm` |
| 동작 확인 | `--version` 은 CLI, `info` 는 데몬 |

---

**이전 문서** → [02. 파일 권한](02-file-permissions.md)
**다음 문서** → [04. Dockerfile](04-dockerfile.md)
