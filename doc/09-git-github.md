# 09. Git과 GitHub

> 보고서 대응: [13번 Git 설정 및 GitHub 연동](../README.md), 18번 .gitignore

---

## 1. Git과 GitHub은 다르다

| | Git | GitHub |
| :--- | :--- | :--- |
| 정체 | 버전 관리 **프로그램** | Git 저장소 **호스팅 서비스** |
| 위치 | 내 컴퓨터에 설치 | 웹사이트 |
| 인터넷 | 없어도 동작 | 필요 |
| 대안 | Mercurial, SVN | GitLab, Bitbucket |

Git 없이 GitHub을 쓸 수 없지만, GitHub 없이 Git은 쓸 수 있다. 혼자 로컬에서 버전 관리만 해도 된다.

---

## 2. Git이 관리하는 3개 영역

이 그림을 이해하면 Git 명령의 절반이 설명된다.

```
작업 디렉토리          스테이징 영역           저장소
(Working Directory)   (Staging Area)      (Repository)
                                          
  파일 수정   ──add──►   커밋 대기   ──commit──►  이력에 기록
                                                     │
                                                     │ push
                                                     ▼
                                              원격 저장소(GitHub)
```

| 영역 | 설명 | 확인 명령 |
| :--- | :--- | :--- |
| 작업 디렉토리 | 실제 파일이 있는 곳 | `ls` |
| 스테이징 영역 | 다음 커밋에 포함할 것들을 모아두는 대기실 | `git diff --cached` |
| 저장소 | 커밋 이력이 쌓인 곳 (`.git/`) | `git log` |

### 왜 스테이징이라는 중간 단계가 있나

파일 10개를 고쳤는데 그중 3개만 "버그 수정" 커밋에 넣고 싶을 때가 있다. 스테이징 영역이 있어서 **커밋 단위를 의미 있게 나눌 수 있다.**

```bash
git add src/auth.js src/login.js    # 인증 관련만
git commit -m "Fix: 로그인 실패 처리"

git add README.md                   # 문서는 따로
git commit -m "Docs: 사용법 추가"
```

보고서에서도 이 방식을 썼다. 신규 파일 5개와 README 수정을 별도 커밋으로 나눴다.

---

## 3. 상태 확인 — `git status`

가장 자주 쓰는 명령이다.

```bash
git status --short
#  M README.md              ← Modified: 수정됨, 스테이징 안 됨
# ?? .env.example           ← Untracked: Git이 모르는 새 파일
# A  Dockerfile             ← Added: 스테이징됨
```

### 상태 기호

```
XY  파일명
│└─ 작업 디렉토리 상태
└── 스테이징 영역 상태
```

| 기호 | 의미 |
| :--- | :--- |
| `??` | Untracked (Git이 추적하지 않는 새 파일) |
| ` M` | 수정됐지만 스테이징 안 됨 |
| `M ` | 수정되고 스테이징됨 |
| `A ` | 새로 추가되고 스테이징됨 |
| `D ` | 삭제됨 |

### 파일의 생애

```
  Untracked ──git add──► Staged ──git commit──► Tracked(변경 없음)
      ▲                                              │
      │                                              │ 파일 수정
      │ git rm --cached                              ▼
      └──────────────────────────────────────── Modified
```

---

## 4. 기본 워크플로

```bash
# 1. 저장소 초기화 (새 프로젝트)
git init

# 2. 사용자 정보 설정 (최초 1회)
git config --global user.name "Kim IkHwan"
git config --global user.email "you@example.com"

# 3. 변경 확인
git status
git diff                    # 스테이징 안 된 변경
git diff --cached           # 스테이징된 변경

# 4. 스테이징
git add README.md           # 특정 파일
git add .                   # 현재 디렉토리 전부
git add -p                  # 변경 덩어리 단위로 선택

# 5. 커밋
git commit -m "Feat: 기능 추가"

# 6. 이력 확인
git log --oneline
git log --oneline --graph --all

# 7. 원격에 반영
git push origin main
```

### `--global` 과 로컬 설정

```bash
git config --global user.email "personal@gmail.com"   # 모든 저장소
git config user.email "work@company.com"              # 이 저장소만
```

회사 프로젝트와 개인 프로젝트의 이메일을 다르게 할 때 쓴다. 로컬 설정이 전역보다 우선한다.

```bash
git config --list | grep user
# user.name=Kim IkHwan
# user.email=you@example.com
```

---

## 5. 커밋 메시지 작성법

보고서가 따른 규칙이다.

```
Feat: README.md 파일 생성 및 초안 작성
└─┬─┘ └──────────────┬──────────────┘
 타입              설명
```

### 타입 접두어

| 타입 | 용도 |
| :--- | :--- |
| `Feat` | 새 기능 |
| `Fix` | 버그 수정 |
| `Docs` | 문서 |
| `Style` | 포맷팅 (동작 변화 없음) |
| `Refactor` | 리팩터링 |
| `Test` | 테스트 |
| `Chore` | 빌드·설정 등 잡무 |

### 좋은 커밋 메시지

```
Feat: Docker 이미지 빌드 및 Compose 실행 환경 구성

- Dockerfile: nginx:latest 기반 커스텀 이미지
- docker-compose.yml: web + client 2개 서비스 정의
- .gitignore: .env 및 시스템 파일 업로드 차단
```

| 원칙 | 설명 |
| :--- | :--- |
| 제목은 50자 이내 | 한눈에 읽히도록 |
| 제목과 본문 사이 빈 줄 | Git이 제목/본문을 구분하는 방식 |
| **무엇을** 보다 **왜** | 코드를 보면 무엇인지는 알 수 있다 |
| 한 커밋에 한 가지 | 나중에 되돌리기 쉬워진다 |

### 나쁜 예

```
수정
asdf
버그 픽스
최종본_진짜최종
```

3개월 뒤의 나 자신이 읽는다고 생각하면 된다.

---

## 6. `.gitignore`

버전 관리할 필요가 없거나 하면 안 되는 파일을 제외한다.

```gitignore
# macOS 시스템 파일
.DS_Store

# 로컬 환경 변수 (실제 값은 커밋하지 않는다)
.env

# 에디터 설정
.vscode/
.idea/

# 의존성 (package.json 으로 복원 가능)
node_modules/

# 빌드 산출물
dist/
build/
```

### 무엇을 제외하나

| 분류 | 예 | 이유 |
| :--- | :--- | :--- |
| 비밀 | `.env`, `*.pem`, `id_rsa` | 유출 위험 |
| 생성물 | `node_modules/`, `dist/` | 소스에서 다시 만들 수 있음 |
| 개인 설정 | `.vscode/`, `.idea/` | 사람마다 다름 |
| OS 파일 | `.DS_Store`, `Thumbs.db` | 무의미 |

### 패턴 문법

```gitignore
*.log            # 확장자가 log인 모든 파일
build/           # build 디렉토리 전체
/config.json     # 루트의 config.json만 (하위 디렉토리 것은 제외 안 함)
!important.log   # 앞의 규칙에서 예외 (부정)
doc/**/*.tmp     # doc 아래 모든 깊이의 .tmp
```

### 동작 검증

```bash
git check-ignore -v .env
# .gitignore:6:.env	.env
#  └─ 파일    └행 └규칙   └대상

git status --short
# ?? .env.example      ← .env 는 목록에 없음 = 제외 성공
```

### ⚠️ 가장 중요한 함정

**`.gitignore` 는 이미 추적 중인 파일에는 효과가 없다.**

```bash
git add .env          # 실수로 커밋
git commit -m "..."
echo ".env" >> .gitignore   # 이제 추가해도
git status            # 여전히 추적됨
```

해결:

```bash
git rm --cached .env         # 추적만 중단 (파일은 남음)
git commit -m "Chore: .env 추적 제외"
```

**이미 푸시했다면 커밋 이력에 영원히 남는다.** `git log -p` 로 누구나 옛 내용을 볼 수 있다. 이 경우:

1. 해당 비밀번호·키를 **즉시 교체**한다 (가장 중요)
2. 필요하면 `git filter-repo` 등으로 이력을 재작성한다 (협업 중이면 매우 번거롭다)

---

## 7. 원격 저장소

```bash
git remote -v
# origin	https://github.com/user/repo.git (fetch)
# origin	https://github.com/user/repo.git (push)
```

`origin` 은 원격 저장소의 **별명**이다. 관례적인 이름일 뿐 특별한 의미는 없다.

### 주요 명령

```bash
git remote add origin <URL>       # 원격 추가
git remote set-url origin <URL>   # URL 변경
git remote remove origin          # 제거

git push origin main              # 로컬 → 원격
git fetch origin                  # 원격 → 로컬 (병합 안 함)
git pull origin main              # fetch + merge
git clone <URL>                   # 통째로 복제
```

### fetch vs pull

```
fetch:  원격 내용을 가져오기만 함. 내 작업에 영향 없음
pull:   가져온 뒤 현재 브랜치에 자동 병합 (= fetch + merge)
```

충돌이 걱정되면 `fetch` 로 먼저 확인하고 병합하는 게 안전하다.

### 추적 브랜치

```bash
git branch -vv
# * main 34fe843 [origin/main] Feat: README.md 파일 생성 및 초안 작성
#                └──────┬────┘
#                  추적 중인 원격 브랜치
```

`[origin/main]` 표시는 로컬 `main` 이 원격 `origin/main` 과 연결됐다는 뜻이다. 그래서 `git push` 만 쳐도 어디로 보낼지 안다.

```bash
git status -sb | head -1
# ## main...origin/main              ← 동기화됨
# ## main...origin/main [ahead 2]    ← 푸시할 커밋 2개
# ## main...origin/main [behind 1]   ← 받아올 커밋 1개
```

---

## 8. HTTPS vs SSH

원격 URL은 두 형식이 있다.

```
HTTPS:  https://github.com/user/repo.git
SSH:    git@github.com:user/repo.git
```

| 항목 | HTTPS | SSH |
| :--- | :--- | :--- |
| 인증 | 토큰(PAT) 입력 | 키 쌍 |
| 매번 인증 | 필요 (캐시 가능) | 불필요 |
| 방화벽 | 대부분 통과 | 22번 포트가 막힌 곳 있음 |
| 설정 난이도 | 쉬움 | 초기 설정 필요 |

전환:

```bash
git remote set-url origin git@github.com:user/repo.git
git remote -v      # 확인
```

자세한 내용은 [10번 문서](10-ssh-authentication.md)에서 다룬다.

---

## 9. 브랜치 기초

보고서에서는 `main` 하나만 썼지만, 협업에서는 브랜치가 필수다.

```bash
git branch                    # 목록
git branch feature/login      # 생성
git switch feature/login      # 이동 (구버전: git checkout)
git switch -c feature/login   # 생성 + 이동

git merge feature/login       # 현재 브랜치에 병합
git branch -d feature/login   # 삭제
```

### 왜 브랜치를 쓰나

```
main       ●───●───●───────────●  ← 항상 동작하는 상태 유지
                    \         /
feature             ●───●───●     ← 실험은 여기서
```

`main` 을 망가뜨리지 않고 작업할 수 있고, 여러 사람이 서로 다른 브랜치에서 동시에 일할 수 있다.

---

## 10. 되돌리기

```bash
# 작업 디렉토리의 수정 취소 (⚠️ 복구 불가)
git restore README.md
git checkout -- README.md      # 구버전 문법

# 스테이징만 취소 (수정은 유지)
git restore --staged README.md

# 마지막 커밋 메시지 수정
git commit --amend -m "새 메시지"

# 마지막 커밋 취소 (변경은 작업 디렉토리에 유지)
git reset --soft HEAD~1

# 마지막 커밋 완전 취소 (⚠️ 변경도 삭제)
git reset --hard HEAD~1

# 특정 커밋 내용을 되돌리는 새 커밋 생성 (안전, 이력 보존)
git revert <커밋해시>
```

### reset vs revert

| | reset | revert |
| :--- | :--- | :--- |
| 방식 | 이력을 지움 | 되돌리는 새 커밋 추가 |
| 이력 | 사라짐 | 남음 |
| 푸시 후 사용 | ❌ 위험 | ✅ 안전 |

**이미 푸시한 커밋은 `revert` 를 쓴다.** `reset` 후 강제 푸시하면 동료의 이력이 깨진다.

### 실수했을 때 최후의 보루

```bash
git reflog
# HEAD가 거쳐온 모든 위치가 기록되어 있다
# 여기서 해시를 찾아 git reset --hard <해시> 로 복구 가능
```

`reset --hard` 로 날린 커밋도 대개 여기서 살릴 수 있다.

---

## 11. 직접 해보기

```bash
mkdir ~/Desktop/git-practice && cd ~/Desktop/git-practice

# 1. 초기화
git init
git config user.name "Test User"
git config user.email "test@example.com"

# 2. 파일 생성 및 상태 확인
echo "# 연습" > README.md
echo "SECRET=1234" > .env
git status --short
# ?? .env
# ?? README.md

# 3. .gitignore 로 .env 제외
echo ".env" > .gitignore
git status --short
# ?? .gitignore
# ?? README.md          ← .env 사라짐
git check-ignore -v .env

# 4. 첫 커밋
git add README.md .gitignore
git commit -m "Docs: 초기 문서 및 gitignore 추가"
git log --oneline

# 5. 수정 후 3개 영역 관찰
echo "내용 추가" >> README.md
git status --short          #  M README.md
git diff                    # 변경 내용 (스테이징 전)
git add README.md
git status --short          # M  README.md
git diff                    # 비어 있음
git diff --cached           # 여기에 보임
git commit -m "Docs: 내용 보강"

# 6. .gitignore 함정 재현
echo "TOKEN=abc" > secret.txt
git add secret.txt
git commit -m "실수로 커밋"
echo "secret.txt" >> .gitignore
git status --short          # 여전히 추적 중 (아무것도 안 나옴)
git rm --cached secret.txt  # 추적 중단
git commit -m "Chore: secret.txt 추적 제외"
git status --short          # ?? 로 바뀜 → 이제 제외됨

# 7. 되돌리기 실습
echo "실수한 내용" >> README.md
git restore README.md       # 수정 취소
cat README.md               # 원래대로

# 8. 이력 확인
git log --oneline --graph

# 9. 정리
cd ~/Desktop && rm -rf git-practice
```

**확인 문제**

1. `git add` 를 왜 거치나? 바로 커밋하면 안 되나?
2. `.env` 를 커밋한 뒤 `.gitignore` 에 추가했다. 안전해졌나?
3. 이미 푸시한 커밋을 되돌릴 때 `reset` 과 `revert` 중 무엇을 쓰나?

<details>
<summary>답</summary>

1. 커밋 단위를 의미 있게 나누기 위해서다. 여러 파일을 고쳤을 때 관련된 것끼리 묶어 별도 커밋으로 만들면 이력을 읽기 쉽고 되돌리기도 쉽다. (`git commit -a` 로 추적 중인 파일은 건너뛸 수 있긴 하다.)
2. 아니다. 커밋 이력에 내용이 남아 있어 누구나 조회할 수 있다. `git rm --cached` 로 추적을 끊어야 하고, 푸시까지 했다면 해당 비밀을 즉시 교체해야 한다.
3. `revert`. `reset` 은 이력을 지우므로 강제 푸시가 필요하고, 동료의 로컬 이력과 어긋나 문제를 일으킨다.
</details>

---

## 12. 자주 하는 실수

| 실수 | 결과 | 해결 |
| :--- | :--- | :--- |
| `.env`·키 파일 커밋 | 비밀 유출, 이력에 영구 | `.gitignore` 먼저 작성 |
| 커밋 후 `.gitignore` 추가로 해결 시도 | 계속 추적됨 | `git rm --cached` |
| `git add .` 남발 | 의도치 않은 파일 포함 | `git status` 로 먼저 확인 |
| 커밋 메시지 "수정", "asdf" | 나중에 이력을 못 읽음 | 타입 접두어 + 왜 |
| 한 커밋에 여러 작업 | 되돌리기 어려움 | 작업 단위로 분리 |
| 푸시 후 `reset --hard` + 강제 푸시 | 동료 이력 파괴 | `revert` |
| `node_modules/` 커밋 | 저장소 비대화 | `.gitignore` |

---

## 13. 예상 질문과 답변 포인트

평가 루브릭 **항목 1-9**(Git 설정 및 GitHub 연동 확인)가 이 문서에서 나온다. 증거를 보여주는 항목이지만, 개념 질문이 따라붙기 쉽다.

---

### A. 루브릭 직결 문항

#### A-1. Git 설정 및 GitHub 연동이 확인되는가?

**⚡ 30초 답변**

> 보고서 13번에 있습니다. `git config --list` 로 사용자 정보를, `git remote -v` 로 원격 저장소를, `git branch -vv` 로 로컬 `main` 이 `origin/main` 을 추적한다는 것을 확인했습니다. `git log --oneline` 으로 커밋 이력도 남겼습니다.
>
> 이후 보너스 5에서 원격을 HTTPS에서 SSH로 전환했고, 그 과정은 17-5에 있습니다.

**💻 실연**

```bash
git config --list | grep -E "^user\.|^remote\."
git remote -v
git branch -vv        # [origin/main] 추적 표시
git log --oneline -5
git status -sb | head -1
```

**꼬리질문 대비**
- *"13번은 HTTPS인데 지금은 SSH다. 왜 다른가?"* → 13번은 그 시점의 실제 기록이고, 17-5에서 전환했다. 시점이 다른 실제 출력이라 고치지 않고 그대로 뒀으며 17-5에 전환 사실을 명시했다.

**📄 근거**: 보고서 **13번** + **17-5**

---

### B. 따라붙기 쉬운 후속 질문

#### B-1. Git의 3개 영역을 설명하라.

```
작업 디렉토리 ──add──► 스테이징 영역 ──commit──► 저장소 ──push──► 원격
(실제 파일)          (커밋 대기실)         (이력)
```

| 영역 | 설명 | 확인 명령 |
| :--- | :--- | :--- |
| 작업 디렉토리 | 실제 파일이 있는 곳 | `git diff` |
| 스테이징 영역 | 다음 커밋에 넣을 것들의 대기실 | `git diff --cached` |
| 저장소 | 커밋 이력 (`.git/`) | `git log` |

> **스테이징이 왜 있나**를 묻는 게 진짜 질문입니다. 파일 10개를 고쳤는데 그중 3개만 "버그 수정" 커밋에 넣고 싶을 때가 있기 때문입니다. 중간 단계가 있어서 **커밋 단위를 의미 있게 나눌 수 있습니다.**
>
> 실습에서도 신규 파일 5개와 README 수정을 별도 커밋으로 나눴습니다.

---

#### B-2. `.gitignore` 에 추가했는데 왜 계속 추적되나?

> **`.gitignore` 는 아직 추적되지 않는 파일에만 적용됩니다.** 이미 한 번 `git add` 된 파일은 인덱스에 등록돼 있어 무시 규칙이 적용되지 않습니다.
>
> ```bash
> git rm --cached .env         # 추적만 중단 (파일은 남음)
> git commit -m "Chore: .env 추적 제외"
> ```
>
> 그리고 **이미 커밋·푸시했다면 이력에 내용이 남습니다.** `git log -p` 로 누구나 옛 내용을 볼 수 있습니다. 이 경우 가장 먼저 할 일은 이력 정리가 아니라 **해당 비밀번호·키를 즉시 교체**하는 것입니다.

이 순서가 중요하다. 이력 재작성은 협업 중이면 매우 번거롭고, 그 사이에도 비밀은 계속 유효하다.

---

#### B-3. `git fetch` 와 `git pull` 의 차이는?

> `fetch` 는 원격 내용을 **가져오기만** 하고 내 브랜치는 건드리지 않습니다. `pull` 은 `fetch` 후 자동으로 병합합니다(`pull` = `fetch` + `merge`).
>
> 충돌이 예상되면 `fetch` 로 먼저 상태를 확인하고 병합하는 편이 안전합니다.

---

#### B-4. 커밋 메시지를 어떻게 쓰나?

```
Feat: README.md 파일 생성 및 초안 작성
└─┬─┘ └──────────────┬──────────────┘
 타입              설명
```

| 타입 | 용도 |
| :--- | :--- |
| `Feat` | 새 기능 |
| `Fix` | 버그 수정 |
| `Docs` | 문서 |
| `Refactor` | 리팩터링 |
| `Chore` | 빌드·설정 등 잡무 |

> 원칙은 네 가지입니다. **제목 50자 이내**, **제목과 본문 사이 빈 줄**, **무엇보다 왜**(코드를 보면 무엇인지는 알 수 있으므로), **한 커밋에 한 가지**(되돌리기 쉬워집니다).
>
> 판단 기준은 **3개월 뒤의 내가 읽는다고 생각하는 것**입니다.

---

#### B-5. `origin` 은 무슨 뜻인가?

> 원격 저장소의 **별명**입니다. 관례적인 이름일 뿐 특별한 의미는 없습니다. `git clone` 할 때 자동으로 붙는 기본 이름이고, 원하면 다른 이름을 쓰거나 여러 원격을 등록할 수도 있습니다.

---

#### B-6. `git branch -vv` 의 `[origin/main]` 은?

```bash
git branch -vv
# * main 34fe843 [origin/main] Feat: README.md 파일 생성 및 초안 작성
```

> 로컬 `main` 이 원격 `origin/main` 을 **추적(tracking)** 한다는 표시입니다. 그래서 `git push` 만 쳐도 어디로 보낼지 압니다.
>
> `git status -sb` 로 동기화 상태도 볼 수 있습니다.
>
> ```
> ## main...origin/main              ← 동기화됨
> ## main...origin/main [ahead 2]    ← 푸시할 커밋 2개
> ## main...origin/main [behind 1]   ← 받아올 커밋 1개
> ```

---

#### B-7. 실수한 커밋을 되돌리려면?

| 상황 | 명령 | 비고 |
| :--- | :--- | :--- |
| 작업 디렉토리 수정 취소 | `git restore <파일>` | ⚠️ 복구 불가 |
| 스테이징만 취소 | `git restore --staged <파일>` | 수정은 유지 |
| 마지막 커밋 메시지 수정 | `git commit --amend` | 푸시 전에만 |
| 커밋 취소 (변경 유지) | `git reset --soft HEAD~1` | |
| 커밋 완전 취소 | `git reset --hard HEAD~1` | ⚠️ 변경도 삭제 |
| 되돌리는 새 커밋 생성 | `git revert <해시>` | 안전, 이력 보존 |

> **이미 푸시한 커밋은 `revert` 를 씁니다.** `reset` 은 이력을 지우므로 강제 푸시가 필요하고, 동료의 로컬 이력과 어긋나 문제를 일으킵니다.
>
> 그리고 `reset --hard` 로 날린 것도 대개 **`git reflog`** 로 살릴 수 있습니다. HEAD가 거쳐온 위치가 전부 기록되어 있습니다.

---

#### B-8. Git과 GitHub은 뭐가 다른가?

| | Git | GitHub |
| :--- | :--- | :--- |
| 정체 | 버전 관리 **프로그램** | Git 저장소 **호스팅 서비스** |
| 위치 | 내 컴퓨터에 설치 | 웹사이트 |
| 인터넷 | 없어도 동작 | 필요 |

> Git 없이 GitHub을 쓸 수 없지만, **GitHub 없이 Git은 쓸 수 있습니다.** 혼자 로컬에서 버전 관리만 해도 됩니다.

---

### C. 실전 시나리오

#### C-1. "푸시가 거부됩니다."

```
! [rejected]  main -> main (fetch first)
```

> 원격에 내가 모르는 커밋이 있다는 뜻입니다.
>
> ```bash
> git fetch origin           # 먼저 확인
> git log --oneline origin/main   # 무엇이 추가됐나
> git pull origin main       # 병합
> git push origin main
> ```
>
> **`--force` 는 마지막 수단입니다.** 원격 이력을 덮어쓰므로 남의 작업이 사라질 수 있습니다.

---

#### C-2. "비밀 파일을 커밋해 버렸습니다."

> 순서가 중요합니다.
>
> 1. **비밀을 즉시 교체한다** (가장 먼저 — 이력 정리보다 우선)
> 2. `git rm --cached <파일>` 로 추적 중단
> 3. `.gitignore` 에 추가
> 4. 필요하면 이력 재작성 (협업 중이면 팀과 협의)
>
> 1번을 미루고 이력 정리부터 하면, 그 사이에도 유출된 자격 증명은 계속 유효합니다.

---

#### C-3. "커밋 전에 무엇이 들어가는지 확인하려면?"

```bash
git status --short          # 상태 한눈에
git diff                    # 스테이징 안 된 변경
git diff --cached           # 스테이징된 변경 (= 커밋될 내용)
git check-ignore -v .env    # 제외되는지 확인
```

> `git add .` 을 습관적으로 쓰면 의도치 않은 파일이 섞입니다. **커밋 전 `git diff --cached` 로 한 번 훑는 습관**이 사고를 크게 줄입니다.

---

### D. 한 줄 요약 (외울 것)

| 개념 | 한 줄 |
| :--- | :--- |
| 3개 영역 | 작업 디렉토리 → 스테이징 → 저장소 |
| 스테이징의 존재 이유 | 커밋 단위를 의미 있게 나누려고 |
| `.gitignore` 한계 | **이미 추적 중인 파일엔 무효** |
| 비밀 커밋 사고 | 이력 정리보다 **비밀 교체가 먼저** |
| `fetch` vs `pull` | `pull` = `fetch` + `merge` |
| 푸시 후 되돌리기 | `reset` 아니라 `revert` |
| 최후의 보루 | `git reflog` |

---

**이전 문서** → [08. 환경 변수와 설정 분리](08-environment-variables.md)
**다음 문서** → [10. SSH 인증](10-ssh-authentication.md)
