# 06. 볼륨과 데이터 영속성

> 보고서 대응: [11번 볼륨 영속성 검증](../README.md), 15-3 데이터 소실 대안

---

## 1. 문제 상황

컨테이너 안에서 만든 파일은 컨테이너를 지우면 **함께 사라진다.** 보고서 11번의 대조 실험이 이것을 정확히 보여준다.

```bash
# 컨테이너 안에 파일 생성
docker run -d --name novol-test ubuntu sleep 300
docker exec novol-test sh -c "echo lost > /tmp/test.txt"

# 같은 컨테이너 안에서는 보인다
docker exec novol-test cat /tmp/test.txt
# lost

# 컨테이너를 삭제하면
docker rm -f novol-test

# 새 컨테이너에는 없다
docker run --rm ubuntu cat /tmp/test.txt
# cat: /tmp/test.txt: No such file or directory
```

DB 컨테이너였다면 데이터가 통째로 날아간 것이다.

---

## 2. 왜 사라지나 — 쓰기 레이어

[03번 문서](03-docker-concepts.md)에서 본 구조를 다시 보자.

```
┌──────────────────────────────────┐
│      쓰기 가능 레이어             │  ← 컨테이너와 수명을 같이함
├══════════════════════════════════┤
│      이미지 (읽기 전용)           │  ← 영구
└──────────────────────────────────┘
```

컨테이너 안에서 파일을 만들거나 고치면 **전부 쓰기 레이어에 쌓인다.** 이 레이어는 컨테이너에 딸린 것이라 `docker rm` 하면 함께 삭제된다.

**핵심 통찰**: 데이터가 사라지는 원인은 "컨테이너 삭제"라는 행위 자체가 아니라 **"어디에 썼는가"** 다. 보고서 11번이 이걸 대조 실험으로 증명한 이유가 여기 있다.

| 저장 위치 | 컨테이너 실행 중 | 컨테이너 삭제 후 |
| :--- | :--- | :--- |
| 쓰기 레이어 (`/tmp`) | `lost` | **소실** |
| 볼륨 (`my-vol:/data`) | `saved` | **유지** |

같은 이미지, 같은 명령인데 결과가 갈린다.

---

## 3. 해결책 — 레이어 밖에 저장한다

Docker는 세 가지 방법을 제공한다.

```
┌──────────── 호스트 ────────────┐
│                                │
│  /var/lib/docker/volumes/  ←── 볼륨 (Docker가 관리)
│  /Users/kim/project/       ←── 바인드 마운트 (내가 지정)
│  (메모리)                  ←── tmpfs (휘발성)
│         │                      │
│         │ 마운트                │
│  ┌──────▼──────── 컨테이너 ───┐ │
│  │  /data                    │ │
│  └───────────────────────────┘ │
└────────────────────────────────┘
```

### 비교표

| 항목 | 볼륨 (named volume) | 바인드 마운트 | tmpfs |
| :--- | :--- | :--- | :--- |
| 위치 | Docker가 관리하는 영역 | 호스트의 특정 경로 | 메모리 |
| 지정 방식 | `-v my-vol:/data` | `-v $(pwd)/data:/data` | `--tmpfs /tmp` |
| 이식성 | 좋음 (호스트 경로 무관) | 나쁨 (경로가 있어야 함) | - |
| 호스트에서 직접 편집 | 불편 | 쉬움 | 불가 |
| 주 용도 | **운영 데이터** (DB 등) | **개발 중 소스 실시간 반영** | 비밀·임시 데이터 |

---

## 4. 볼륨 (named volume)

보고서 11번에서 채택한 방식이다.

### 기본 사용법

```bash
docker volume create my-vol          # 생성
docker volume ls                     # 목록
docker volume inspect my-vol         # 상세 (호스트 실제 경로 등)
docker volume rm my-vol              # 삭제
```

```bash
docker run -v my-vol:/data ubuntu sh -c "echo saved > /data/test.txt"
#           └──┬──┘ └─┬─┘
#              │      └─ 컨테이너 안의 마운트 지점 (절대 경로)
#              └──────── 볼륨 이름
```

### 영속성 증명 — 보고서 11번 전체 흐름

```bash
# 1. 볼륨 생성
docker volume create my-vol
# my-vol

# 2. 볼륨에 데이터 저장
docker run --name vol-test -v my-vol:/data ubuntu sh -c "echo saved > /data/test.txt"

# 3. 컨테이너가 존재하는지 확인
docker ps -a --filter name=vol-test --format "table {{.Names}}\t{{.Status}}"
# NAMES      STATUS
# vol-test   Exited (0) Less than a second ago

# 4. 컨테이너를 명시적으로 삭제
docker rm vol-test
# vol-test

# 5. 삭제됐는지 확인 (목록이 비어야 함)
docker ps -a --filter name=vol-test --format "table {{.Names}}\t{{.Status}}"
# NAMES     STATUS

# 6. 완전히 새로운 컨테이너로 데이터 확인
docker run --rm -v my-vol:/data ubuntu cat /data/test.txt
# saved     ← 살아남았다
```

> **4번 단계가 핵심이다.** 컨테이너를 명시적으로 지우지 않으면 "삭제 후에도 유지된다"는 것을 증명할 수 없다. 루브릭이 "컨테이너 삭제 후에도 유지되는가"를 묻는 이유다.

### 익명 볼륨

이름을 안 주면 Docker가 임의의 해시 이름을 붙인다.

```bash
docker run -v /data ubuntu     # 익명 볼륨 생성
docker volume ls
# local     8f3a2b1c...        ← 무엇에 쓰였는지 알 수 없음
```

추적·백업이 불가능해지므로 **이름을 주는 습관**을 들인다. 보고서 12번에서 "명시적으로 만들어야 `docker volume ls` 로 추적·백업이 가능하다"고 적은 이유다.

---

## 5. 바인드 마운트

호스트의 특정 폴더를 컨테이너에 연결한다.

```bash
docker run -v $(pwd)/html:/usr/share/nginx/html nginx
#           └────┬────┘
#             호스트 경로 (절대 경로여야 함)
```

### 개발할 때 유용한 이유

호스트에서 파일을 고치면 **컨테이너 안에서 즉시 반영된다.** 이미지를 다시 빌드할 필요가 없다.

```bash
mkdir html && echo '<h1>v1</h1>' > html/index.html
docker run -d -p 8080:80 -v $(pwd)/html:/usr/share/nginx/html nginx

curl -s localhost:8080          # <h1>v1</h1>
echo '<h1>v2</h1>' > html/index.html
curl -s localhost:8080          # <h1>v2</h1>   ← 재빌드 없이 바뀜
```

### 단점

- 호스트 경로에 의존해서 **다른 컴퓨터에서 깨진다**
- 상대 경로를 쓸 수 없어 `$(pwd)` 같은 표현이 필요하다
- 권한 문제가 생기기 쉽다 (호스트 UID와 컨테이너 UID 불일치)

**그래서 운영에는 볼륨, 개발에는 바인드 마운트**가 일반적인 선택이다.

### `-v` vs `--mount`

```bash
-v my-vol:/data
--mount source=my-vol,target=/data,type=volume
```

`--mount` 가 더 명시적이고 오타 시 에러를 낸다. `-v` 는 짧지만 존재하지 않는 호스트 경로를 주면 **조용히 디렉토리를 만들어 버려서** 실수를 못 잡는다.

---

## 6. 백업과 복원

볼륨은 컨테이너보다 오래 살지만 **영원하지는 않다.** 실수로 `docker volume rm` 하면 끝이다.

### 백업

```bash
docker run --rm \
  -v my-vol:/data \
  -v $(pwd):/backup \
  ubuntu tar cvf /backup/backup.tar /data
```

작동 원리:

```
1. 임시 컨테이너를 띄운다
2. 백업할 볼륨을 /data 로 마운트
3. 현재 디렉토리를 /backup 으로 바인드 마운트
4. /data 를 tar로 묶어 /backup 에 저장  → 호스트에 파일이 생김
5. --rm 이므로 작업 후 컨테이너 자동 삭제
```

### 복원

```bash
docker run --rm \
  -v my-vol:/data \
  -v $(pwd):/backup \
  ubuntu tar xvf /backup/backup.tar -C /
```

---

## 7. `docker compose down -v` 주의

보고서 17-3에서 경고한 내용이다.

| 명령 | 컨테이너 | 네트워크 | 볼륨 |
| :--- | :--- | :--- | :--- |
| `docker compose down` | 삭제 | 삭제 | **유지** |
| `docker compose down -v` | 삭제 | 삭제 | **삭제** |

`-v` 를 습관적으로 붙이면 DB 데이터가 통째로 날아간다. "정리할 때는 항상 -v" 같은 습관은 위험하다.

비슷하게 위험한 명령들:

```bash
docker volume prune          # 사용되지 않는 볼륨 전부 삭제
docker system prune -a       # 이미지·컨테이너·네트워크 전부 삭제
docker system prune -a --volumes   # 볼륨까지 (가장 위험)
```

---

## 8. 직접 해보기

```bash
# ===== 실험군: 볼륨 사용 =====
docker volume create test-vol
docker run --name keeper -v test-vol:/data ubuntu sh -c "echo 살아남음 > /data/a.txt"
docker rm keeper
docker run --rm -v test-vol:/data ubuntu cat /data/a.txt
# 살아남음

# ===== 대조군: 볼륨 미사용 =====
docker run -d --name loser ubuntu sleep 60
docker exec loser sh -c "echo 사라짐 > /tmp/a.txt"
docker exec loser cat /tmp/a.txt        # 사라짐 (아직 보임)
docker rm -f loser
docker run --rm ubuntu cat /tmp/a.txt
# cat: /tmp/a.txt: No such file or directory

# ===== 바인드 마운트 실시간 반영 =====
mkdir ~/Desktop/bind-test && cd ~/Desktop/bind-test
echo '<h1>v1</h1>' > index.html
docker run -d -p 8877:80 --name bindtest \
  -v $(pwd):/usr/share/nginx/html nginx
curl -s localhost:8877                  # <h1>v1</h1>
echo '<h1>v2</h1>' > index.html
curl -s localhost:8877                  # <h1>v2</h1>  ← 재빌드 없이 반영

# ===== 백업 실습 =====
docker run --rm -v test-vol:/data -v $(pwd):/backup \
  ubuntu tar cvf /backup/vol-backup.tar /data
ls -lh vol-backup.tar

# ===== 정리 =====
docker rm -f bindtest
docker volume rm test-vol
cd ~/Desktop && rm -r bind-test
```

**확인 문제**

1. 컨테이너를 `stop` 만 하고 `rm` 은 안 했다. `/tmp` 의 파일은 남아 있나?
2. 볼륨과 바인드 마운트 중 팀원과 공유하는 프로젝트에 적합한 것은?
3. `docker compose down` 과 `down -v` 의 차이는?

<details>
<summary>답</summary>

1. 남아 있다. 쓰기 레이어는 컨테이너가 존재하는 한 유지된다. `docker start` 로 다시 켜면 그대로 있다. 사라지는 시점은 `rm` 이다.
2. 볼륨. 바인드 마운트는 호스트 경로에 의존해서 다른 사람 컴퓨터에서 깨진다. 단, 소스 코드 실시간 반영이 목적이라면 개발 환경에서는 바인드 마운트를 쓰고 경로를 `$(pwd)` 같은 상대 표현으로 맞춘다.
3. `down` 은 컨테이너와 네트워크만, `down -v` 는 볼륨까지 삭제한다.
</details>

---

## 9. 자주 하는 실수

| 실수 | 결과 | 해결 |
| :--- | :--- | :--- |
| 컨테이너 안에서 DB 데이터 저장 | 컨테이너 삭제 시 전부 소실 | 볼륨 마운트 |
| 익명 볼륨 남발 | 어느 볼륨이 무엇인지 모름 | 이름 지정 |
| `down -v` 습관적 사용 | 데이터 소실 | 평소엔 `down` 만 |
| 볼륨만 믿고 백업 안 함 | `volume rm` 한 번에 끝 | 정기 tar 백업 |
| 바인드 마운트 경로 오타 | 빈 디렉토리가 생성돼 조용히 실패 | `--mount` 사용 시 에러로 잡힘 |
| 볼륨 마운트 지점에 상대 경로 | 에러 | 컨테이너 내부 경로는 절대 경로 |

---

## 10. 예상 질문과 답변 포인트

평가 루브릭 **항목 1-8**(볼륨 데이터가 컨테이너 삭제 후에도 유지되는가)과 **항목 4-2**(데이터 소실 방지 대안)가 이 문서에서 나온다. 4-2는 **경험 → 원인 → 대안** 순서로 답해야 하는 심층 인터뷰 문항이다.

---

### A. 루브릭 직결 문항

#### A-1. 컨테이너 삭제 후 데이터가 사라진 경험이 있다면, 방지 대안을 설명할 수 있는가?

**⚡ 답변 — 경험 → 원인 → 대안 순서로**

> **경험이 있습니다.** 11번 실습에서 컨테이너 안 `/tmp` 에 파일을 만들고 컨테이너를 지웠더니 `No such file or directory` 가 나왔습니다.
>
> **원인은 저장 위치입니다.** 컨테이너는 이미지 위에 쓰기 레이어를 얹은 구조인데, 이 레이어의 수명이 컨테이너와 같습니다. `/tmp` 에 쓴 건 쓰기 레이어에 쌓였고 `docker rm` 과 함께 사라진 겁니다.
>
> **중요한 건 원인이 "컨테이너 삭제"라는 행위가 아니라는 점입니다.** 그걸 확인하려고 대조 실험을 했습니다. 같은 이미지, 같은 명령인데 저장 위치만 볼륨으로 바꿨더니 컨테이너를 지워도 데이터가 남았습니다.

**대안 비교 — 세 가지를 나란히 놓는다**

| 대안 | 방식 | 적합한 상황 | 유의점 |
| :--- | :--- | :--- | :--- |
| **이름 있는 볼륨** | `-v my-vol:/data` | DB 등 운영 데이터 (이번에 채택) | 호스트 경로 비의존, 이식성 좋음 |
| **바인드 마운트** | `-v $(pwd)/data:/data` | 개발 중 소스 실시간 반영 | 호스트 경로 의존, 다른 머신에서 깨짐 |
| **정기 백업** | `tar` 로 볼륨 아카이브 | 볼륨 자체의 유실 대비 | 볼륨도 `volume rm` 하면 끝 |

> 이번엔 재현성이 중요해서 이름 있는 볼륨을 택했습니다. **다만 볼륨이 있다고 백업이 불필요한 건 아닙니다.** 실수로 `docker volume rm` 하면 그대로 사라지므로 백업은 별개 대비책입니다.

**마무리 — 실무 감각을 보여주는 한마디**

> 운영에서 특히 조심할 게 하나 있는데, **`docker compose down` 은 볼륨을 남기지만 `down -v` 는 볼륨까지 지웁니다.** 정리한다고 습관적으로 `-v` 를 붙이면 데이터가 통째로 날아갑니다.

**📄 근거**: 보고서 **11번**(대조 실험) + **15-3**(대안 비교표) + **17-3**(`down -v` 경고)

---

#### A-2. Docker 볼륨 데이터가 컨테이너 삭제 후에도 유지되는가?

**⚡ 30초 답변**

> 보고서 11번에서 증명했습니다. 볼륨 생성 → 데이터 저장 → **컨테이너를 명시적으로 `docker rm` 으로 삭제** → 삭제됐는지 목록으로 확인 → 완전히 새 컨테이너로 읽기 순으로 진행해 `saved` 가 그대로 나왔습니다.
>
> **삭제 단계를 명시적으로 넣은 이유**는, 그래야 "삭제 후에도 유지"가 증명되기 때문입니다. 컨테이너를 안 지우고 데이터가 남아 있다고 하면 아무것도 증명한 게 아닙니다.

**💻 실연**

```bash
docker volume create demo-vol
docker run --name vt -v demo-vol:/data ubuntu sh -c "echo saved > /data/t.txt"
docker rm vt                                    # 명시적 삭제
docker run --rm -v demo-vol:/data ubuntu cat /data/t.txt
# saved
docker volume rm demo-vol
```

**📄 근거**: 보고서 **11번** (실험군 + 대조군 + 비교표)

---

### B. 따라붙기 쉬운 후속 질문

#### B-1. 데이터가 사라지는 원인이 컨테이너 삭제인가?

> 정확히는 아닙니다. 원인은 **"어디에 썼는가"** 입니다. 같은 이미지·같은 명령이라도 볼륨에 쓰면 컨테이너를 지워도 남고, 쓰기 레이어에 쓰면 사라집니다. 삭제라는 행위가 아니라 저장 위치가 결정합니다.

| 저장 위치 | 컨테이너 실행 중 | 컨테이너 삭제 후 |
| :--- | :--- | :--- |
| 쓰기 레이어 (`/tmp`) | `lost` | **소실** |
| 볼륨 (`my-vol:/data`) | `saved` | **유지** |

> 이걸 확인하려고 **대조 실험**을 만들었습니다. 변수를 하나만 다르게 한 두 실험을 나란히 놓으면 인과가 드러납니다. 관찰만으로는 상관관계까지만 알 수 있습니다.

---

#### B-2. 볼륨과 바인드 마운트의 차이는?

| | 볼륨 | 바인드 마운트 |
| :--- | :--- | :--- |
| 저장 위치 | Docker가 관리하는 영역 | 호스트의 특정 경로 |
| 지정 | `-v my-vol:/data` | `-v $(pwd)/data:/data` |
| 이식성 | 좋음 | 나쁨 (경로가 있어야 함) |
| 호스트에서 편집 | 불편 | 쉬움 (실시간 반영) |
| 주 용도 | 운영 데이터 | 개발 중 소스 |

> 개발할 때 바인드 마운트가 편한 이유는 호스트에서 파일을 고치면 **재빌드 없이 즉시 반영**되기 때문입니다. 반대로 다른 사람 컴퓨터에는 그 경로가 없어 깨지므로 운영에는 부적합합니다.

---

#### B-3. 컨테이너를 `stop` 만 하고 `rm` 은 안 했다. `/tmp` 파일은 남아 있나?

> 남아 있습니다. 쓰기 레이어는 **컨테이너가 존재하는 한** 유지됩니다. `docker start` 로 다시 켜면 그대로 있습니다.
>
> 사라지는 시점은 `stop` 이 아니라 **`rm`** 입니다. 이 구분을 못 하면 "멈췄더니 데이터가 날아갔다"는 잘못된 결론을 냅니다.

---

#### B-4. 익명 볼륨은 무엇이고 왜 피하나?

```bash
docker run -v /data ubuntu     # 이름 없이 마운트 지점만 지정
docker volume ls
# local     8f3a2b1c4d5e...    ← 무엇에 쓰였는지 알 수 없음
```

> 이름을 안 주면 Docker가 임의의 해시 이름을 붙입니다. 나중에 **어느 볼륨이 무엇인지 알 수 없어 추적·백업이 불가능**해집니다. 정리하려 해도 지워도 되는 건지 판단할 수 없습니다.
>
> 그래서 보고서 12번에 "명시적으로 만들어야 `docker volume ls` 로 추적·백업이 가능하다"고 적었습니다.

---

#### B-5. `-v` 와 `--mount` 중 무엇을 쓰나?

```bash
-v my-vol:/data
--mount source=my-vol,target=/data,type=volume
```

> `--mount` 가 더 명시적이고 오타가 있으면 에러를 냅니다. `-v` 는 짧지만 **존재하지 않는 호스트 경로를 주면 조용히 빈 디렉토리를 만들어 버려서** 실수를 못 잡습니다.
>
> "분명 마운트했는데 파일이 없다"는 상황의 흔한 원인입니다.

---

#### B-6. 볼륨을 백업하려면?

```bash
docker run --rm \
  -v my-vol:/data \
  -v $(pwd):/backup \
  ubuntu tar cvf /backup/backup.tar /data
```

> 임시 컨테이너를 띄워 볼륨과 현재 디렉토리를 동시에 마운트하고, 볼륨 내용을 tar로 묶어 호스트에 떨어뜨립니다. `--rm` 이라 작업 후 컨테이너는 자동 삭제됩니다.
>
> 복원은 `tar xvf` 로 반대 방향입니다.

---

#### B-7. 볼륨이 실제로 호스트 어디에 저장되나?

```bash
docker volume inspect my-vol
```

> `Mountpoint` 에 경로가 나옵니다. 다만 **그 경로를 직접 건드리는 건 권장하지 않습니다.** Docker가 관리하는 영역이고, macOS나 Windows에서는 VM 안이라 호스트에서 직접 접근할 수도 없습니다.
>
> 호스트에서 직접 다뤄야 한다면 처음부터 바인드 마운트를 쓰는 게 맞습니다.

---

#### B-8. 여러 컨테이너가 같은 볼륨을 쓸 수 있나?

> 가능합니다. 여러 컨테이너에 같은 볼륨을 마운트하면 데이터를 공유합니다.
>
> 다만 **동시 쓰기는 주의해야 합니다.** Docker는 파일 잠금을 대신 처리해 주지 않으므로, DB처럼 자체 락 관리가 없는 프로그램이 같은 파일을 동시에 쓰면 데이터가 깨질 수 있습니다.

---

### C. 실전 시나리오

#### C-1. "마운트했는데 컨테이너 안에 파일이 없습니다."

> 순서대로 확인합니다.
>
> 1. **경로 오타** — `-v` 는 없는 호스트 경로를 주면 빈 디렉토리를 만들어 버린다. `--mount` 로 바꾸면 에러로 잡힌다
> 2. **마운트 지점이 기존 디렉토리를 덮었나** — 이미지에 있던 `/data` 위에 빈 볼륨을 마운트하면 원래 내용이 가려진다
> 3. **볼륨 이름 오타** — 오타 난 이름으로 **새 빈 볼륨이 생성**된다. `docker volume ls` 로 의도치 않은 볼륨이 있는지 확인

2번이 특히 헷갈린다. 마운트는 그 지점을 **가리는** 동작이라, 이미지에 있던 파일은 지워진 게 아니라 안 보이게 된 것뿐이다.

---

#### C-2. "디스크가 가득 찼습니다."

```bash
docker system df              # 무엇이 공간을 쓰는지
docker volume ls              # 볼륨 목록
docker volume prune           # 사용되지 않는 볼륨 삭제 ⚠️
```

> `prune` 계열은 위험합니다. **어떤 컨테이너도 참조하지 않는 볼륨을 전부 지우는데**, 잠시 컨테이너를 지워 둔 상태의 중요한 볼륨도 여기 해당합니다. 실행 전 `docker volume ls` 로 목록을 확인하고, 이름을 지어 두는 습관이 여기서 값을 합니다.

---

### D. 한 줄 요약 (외울 것)

| 개념 | 한 줄 |
| :--- | :--- |
| 소실 원인 | 삭제라는 행위가 아니라 **저장 위치** |
| 쓰기 레이어 수명 | 컨테이너와 동일 (`rm` 시점에 소멸) |
| 볼륨 | 운영 데이터, 이식성 좋음 |
| 바인드 마운트 | 개발 중 실시간 반영, 경로 의존 |
| 백업 | 볼륨이 있어도 **별개로 필요** |
| `down` vs `down -v` | `-v` 는 볼륨까지 삭제 ⚠️ |
| 증명 방법 | 컨테이너를 **명시적으로 삭제**해야 증명됨 |

---

**이전 문서** → [05. 포트와 네트워크](05-port-mapping-network.md)
**다음 문서** → [07. Docker Compose](07-docker-compose.md)
