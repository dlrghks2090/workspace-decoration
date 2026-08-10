# 10. SSH 인증

> 보고서 대응: [17-5 GitHub SSH 키 설정](../README.md), 15-5 공개키 형식 오류

---

## 1. 공개키 암호 방식의 원리

SSH 인증의 핵심은 **비대칭 암호(asymmetric cryptography)** 다. 열쇠가 두 개 있고, 역할이 다르다.

```
┌─────────────────┐              ┌─────────────────┐
│    개인키       │              │    공개키       │
│ id_ed25519      │  수학적으로   │ id_ed25519.pub  │
│                 │◄──── 쌍 ────►│                 │
│ 절대 공개 금지  │              │ 마음껏 배포 OK  │
│ 내 컴퓨터에만   │              │ GitHub에 등록   │
└─────────────────┘              └─────────────────┘
```

### 자물쇠 비유

- **공개키 = 자물쇠**. 복사해서 여기저기 달아도 된다. GitHub에 등록하는 게 "GitHub 문에 내 자물쇠를 다는 것"이다.
- **개인키 = 열쇠**. 이것만 있으면 그 자물쇠를 열 수 있다. 절대 남에게 주면 안 된다.

**공개키로는 개인키를 알아낼 수 없다.** 이게 비대칭 암호의 수학적 보장이다.

### 인증 과정

비밀번호처럼 개인키를 서버에 보내지 **않는다.**

```
1. 클라이언트:  "저 로그인할게요"
2. 서버:        "그럼 이 무작위 값에 서명해 보세요"  ← 챌린지
3. 클라이언트:  개인키로 서명해서 전송              ← 개인키는 로컬을 안 떠남
4. 서버:        등록된 공개키로 서명을 검증
5. 서버:        "확인됐습니다"
```

**개인키가 네트워크를 절대 지나가지 않는다.** 이것이 HTTPS 토큰 방식과의 근본적 차이다. 토큰은 매번 서버에 제시하므로 중간에서 가로채면 그대로 도용된다.

---

## 2. 키 생성

```bash
ssh-keygen -t ed25519 -C "you@example.com"
```

| 옵션 | 의미 |
| :--- | :--- |
| `-t ed25519` | 키 알고리즘 |
| `-C "..."` | 주석 (보통 이메일, 키 구분용) |
| `-f 경로` | 저장 위치 지정 |
| `-N "암호"` | passphrase를 비대화형으로 지정 |

### 알고리즘 선택

| 알고리즘 | 키 길이 | 권장 |
| :--- | :--- | :--- |
| **ed25519** | 짧음 (~68자) | ✅ 현재 표준. 빠르고 안전 |
| RSA 4096 | 김 (~700자) | 구형 시스템 호환이 필요할 때 |
| DSA | - | ❌ 폐기됨 |

특별한 이유가 없으면 `ed25519` 를 쓴다.

### 생성 결과

```bash
ls -1 ~/.ssh
# id_ed25519        ← 개인키 (권한 600)
# id_ed25519.pub    ← 공개키 (권한 644)
# known_hosts       ← 접속했던 서버들의 지문
```

---

## 3. 파일 권한 — 왜 600인가

[02번 문서](02-file-permissions.md)의 권한 규칙이 여기서 실제로 강제된다.

```bash
stat -f "%Sp %OLp %N" ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
# -rw------- 600 /Users/kim/.ssh/id_ed25519
# -rw-r--r-- 644 /Users/kim/.ssh/id_ed25519.pub
```

| 파일 | 권한 | 이유 |
| :--- | :--- | :--- |
| 개인키 | `600` (소유자만 읽기·쓰기) | 남이 읽으면 계정을 탈취당함 |
| 공개키 | `644` (누구나 읽기) | 어차피 배포하는 값 |

### SSH는 권한을 검사한다

권한이 느슨하면 SSH가 **아예 사용을 거부한다.**

```bash
chmod 644 ~/.ssh/id_ed25519      # 일부러 느슨하게
ssh -T git@github.com
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# @    WARNING: UNPROTECTED PRIVATE KEY FILE!             @
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# Permissions 0644 for '.../id_ed25519' are too open.
# This private key will be ignored.

chmod 600 ~/.ssh/id_ed25519      # 복구
```

**보안 도구가 사용자의 실수를 막기 위해 권한을 강제하는 사례**다. `chmod` 를 배우는 실질적 이유이기도 하다.

권장 권한:

```bash
chmod 700 ~/.ssh                 # 디렉토리
chmod 600 ~/.ssh/id_ed25519      # 개인키
chmod 644 ~/.ssh/id_ed25519.pub  # 공개키
```

---

## 4. 공개키 등록 — 보고서 15-5의 함정

### 공개키의 실제 형태

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI(생략) you@example.com
└────┬────┘ └────────────┬────────────┘ └───────┬───────┘
  알고리즘            키 본문                  주석
```

**한 줄**이고, `ssh-` 로 시작한다.

### 지문(fingerprint)과 혼동하지 말 것

```bash
ssh-keygen -lf ~/.ssh/id_ed25519.pub
# 256 SHA256:McCE60hNY/KM/r+GbuS1N9ScwfZClRge96AnzP9xSo8 you@example.com (ED25519)
#     └──────────────────────┬──────────────────────────┘
#                          지문
```

| | 공개키 | 지문 |
| :--- | :--- | :--- |
| 정체 | 실제 키 데이터 | 공개키를 해시한 **요약값** |
| 형태 | `ssh-ed25519 AAAA...` | `SHA256:McCE...` |
| 용도 | **등록용** | **대조·확인용** |
| 되돌리기 | - | 지문에서 키를 복원 불가 |

보고서 15-5에서 발생한 오류가 이 혼동 때문이었다.

```
Key is invalid. You must supply a key in OpenSSH public key format
```

지문을 등록 필드에 붙여넣으면 GitHub이 형식 오류로 거부한다. 지문은 "이 키가 내가 아는 그 키가 맞는지" 확인할 때 쓰는 값이지 키 자체가 아니다.

### 진단 순서

```bash
# ① 파일 자체가 유효한지
ssh-keygen -lf ~/.ssh/id_ed25519.pub
# 지문이 나오면 파일은 정상

# ② 한 줄인지, ssh- 로 시작하는지
wc -l < ~/.ssh/id_ed25519.pub        # 1
cut -d' ' -f1 < ~/.ssh/id_ed25519.pub # ssh-ed25519

# ③ 붙여넣을 내용을 클립보드에 정확히 담기
pbcopy < ~/.ssh/id_ed25519.pub       # macOS
# xclip -sel clip < ~/.ssh/id_ed25519.pub    # Linux

# ④ 클립보드 검증
pbpaste | cut -d' ' -f1              # ssh-ed25519 가 나와야 정상
```

### GitHub 등록 화면

| 필드 | 입력 |
| :--- | :--- |
| Title | 아무 이름 (예: `MacBook - work`) |
| Key type | `Authentication Key` |
| Key | `ssh-ed25519 AAAA...` 한 줄 전체 |

Title과 Key 칸을 바꿔 넣는 것도 같은 오류의 흔한 원인이다.

---

## 5. 인증 확인

```bash
ssh -T git@github.com
# Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

### 종료 코드가 1인데 성공?

```bash
ssh -T git@github.com; echo "exit: $?"
# Hi username! You've successfully authenticated, ...
# exit: 1
```

**정상이다.** GitHub은 셸 접속을 제공하지 않으므로 인증 후 세션을 끊는다. 판단 기준은 종료 코드가 아니라 `successfully authenticated` 메시지다.

### 실패할 때

```bash
ssh -T git@github.com
# git@github.com: Permission denied (publickey).
```

원인이 두 가지라 구분이 필요하다.

| 원인 | 확인 방법 |
| :--- | :--- |
| GitHub에 키 미등록 | 아래 참조 |
| passphrase 걸린 키가 agent에 없음 | `ssh-add -l` |

**구분하는 법:**

```bash
# 개인키에 passphrase가 있는지 확인
ssh-keygen -y -P "" -f ~/.ssh/id_ed25519 > /dev/null 2>&1 \
  && echo "passphrase 없음 → 미등록이 원인" \
  || echo "passphrase 있음 → agent 문제일 수 있음"

# 어떤 키를 제시했는지 상세 확인
ssh -v -T git@github.com 2>&1 | grep -i "offering\|denied"
# debug1: Offering public key: /Users/kim/.ssh/id_ed25519 ED25519 SHA256:McCE...
# git@github.com: Permission denied (publickey).
#   → 키를 제시했는데 거부됨 = 서버에 등록 안 됨
```

---

## 6. 원격 저장소 SSH 전환

```bash
# 전환 전
git remote -v
# origin	https://github.com/user/repo.git (fetch)
# origin	https://github.com/user/repo.git (push)

# 전환
git remote set-url origin git@github.com:user/repo.git

# 전환 후
git remote -v
# origin	git@github.com:user/repo.git (fetch)
# origin	git@github.com:user/repo.git (push)
```

### URL 형식 차이

```
HTTPS:  https://github.com/user/repo.git
SSH:    git@github.com:user/repo.git
        └┬┘ └────┬───┘│└───┬───┘
       사용자   호스트  :  경로
```

SSH 형식은 호스트 뒤가 `/` 가 아니라 `:` 다. 자주 틀리는 부분이다.

### 푸시 없이 검증하기

커밋이 없어도 전송 계층을 확인할 수 있다.

```bash
git ls-remote origin
# 34fe8435622a73b667ba56ec0e19e96a536fdd60	HEAD
# 34fe8435622a73b667ba56ec0e19e96a536fdd60	refs/heads/main

git fetch origin
git status -sb | head -1
# ## main...origin/main
```

자격 증명을 묻지 않고 원격 참조를 읽어 왔다면 SSH 인증이 동작하는 것이다.

---

## 7. passphrase

개인키 파일 자체를 **암호화**하는 비밀번호다.

```
passphrase 없음:  개인키 파일 = 즉시 사용 가능
passphrase 있음:  개인키 파일 + passphrase = 사용 가능
```

파일이 유출돼도 passphrase를 모르면 쓸 수 없다. **자물쇠를 하나 더 다는 것**이다.

### 설정·변경

```bash
ssh-keygen -p -f ~/.ssh/id_ed25519
# Enter old passphrase:        (없으면 그냥 Enter)
# Enter new passphrase:        (입력해도 화면에 안 보임 — 정상)
# Enter same passphrase again:
# Your identification has been saved with the new passphrase.
```

**공개키는 바뀌지 않는다.** 파일 내용이 암호화될 뿐이므로 GitHub 재등록이 필요 없다. 지문도 그대로다.

### 설정 여부 확인

```bash
ssh-keygen -y -P "" -f ~/.ssh/id_ed25519 > /dev/null 2>&1 \
  && echo "passphrase 없음" || echo "passphrase 있음"
```

파일이 다시 쓰였는지도 단서가 된다.

```bash
stat -f "%Sm %N" -t "%Y-%m-%d %H:%M:%S" ~/.ssh/id_ed25519
# 수정 시각이 생성 시각 그대로면 passphrase 변경이 실행되지 않은 것
```

### ssh-agent — 매번 안 묻게 하기

passphrase를 걸면 매번 물어본다. `ssh-agent` 가 메모리에 들고 있어 준다.

```bash
ssh-add -l                                    # 로드된 키 목록
ssh-add ~/.ssh/id_ed25519                     # 추가
ssh-add --apple-use-keychain ~/.ssh/id_ed25519  # macOS 키체인에 영구 저장
```

macOS는 키체인에 넣어두면 재부팅 후에도 자동으로 불러온다.

```
~/.ssh/config 설정 예:

Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
```

### 걸어야 하나?

| 상황 | 권장 |
| :--- | :--- |
| 공용 PC | **필수** |
| 운영 서버 접근 키 | **필수** |
| 조직 저장소 접근 키 | **필수** |
| 개인 노트북 + 개인 학습 저장소 | 선택 (위험 인지하에) |

보고서 17-5에서 걸지 않기로 하되 **위험을 명시**한 이유가 이것이다. 모르고 안 하는 것과 알고 선택하는 것은 다르다.

---

## 8. known_hosts — 서버를 확인하는 쪽

지금까지는 "서버가 나를 확인"하는 이야기였다. 반대 방향도 있다.

```bash
ssh -T git@github.com
# The authenticity of host 'github.com' can't be established.
# ED25519 key fingerprint is SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU.
# Are you sure you want to continue connecting (yes/no)?
```

이건 **내가 접속하려는 서버가 진짜 GitHub인지** 묻는 것이다. `yes` 하면 지문이 `~/.ssh/known_hosts` 에 저장되고, 다음부터는 안 묻는다.

만약 나중에 지문이 바뀌면 경고가 뜬다.

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

서버를 재설치했을 수도 있지만 **중간자 공격(MITM)일 수도 있다.** 무작정 지우지 말고 확인해야 한다. GitHub의 공식 지문은 문서에 공개돼 있다.

```bash
ssh-keygen -F github.com          # 등록 여부 확인
ssh-keygen -R github.com          # 항목 제거 (확인 후에만)
```

---

## 9. 직접 해보기

```bash
# ⚠️ 기존 키가 있다면 덮어쓰지 않도록 다른 이름으로 실습한다

# 1. 연습용 키 생성 (passphrase 없이)
ssh-keygen -t ed25519 -C "practice@example.com" -f ~/.ssh/practice_key -N ""

# 2. 생성된 파일과 권한 확인
ls -l ~/.ssh/practice_key*
stat -f "%Sp %OLp %N" ~/.ssh/practice_key ~/.ssh/practice_key.pub

# 3. 공개키와 지문의 차이 관찰
echo "--- 공개키 (등록용) ---"
cat ~/.ssh/practice_key.pub
echo "--- 지문 (대조용) ---"
ssh-keygen -lf ~/.ssh/practice_key.pub

# 4. passphrase 걸기
ssh-keygen -p -f ~/.ssh/practice_key
# (아무 값이나 입력)

# 5. passphrase 설정 확인
ssh-keygen -y -P "" -f ~/.ssh/practice_key > /dev/null 2>&1 \
  && echo "passphrase 없음" || echo "passphrase 있음"

# 6. 공개키가 바뀌지 않았는지 확인 (지문 비교)
ssh-keygen -lf ~/.ssh/practice_key.pub
# 3번과 같은 지문이어야 한다

# 7. 권한 검사 동작 확인
chmod 644 ~/.ssh/practice_key
ssh -i ~/.ssh/practice_key -o BatchMode=yes -T git@github.com 2>&1 | head -5
# UNPROTECTED PRIVATE KEY FILE 경고
chmod 600 ~/.ssh/practice_key

# 8. 정리
rm ~/.ssh/practice_key ~/.ssh/practice_key.pub
```

**확인 문제**

1. 공개키를 GitHub에 등록했다. 누군가 그 공개키를 훔치면 내 계정에 접근할 수 있나?
2. passphrase를 걸면 GitHub에 키를 다시 등록해야 하나?
3. `ssh -T git@github.com` 이 종료 코드 1을 반환했다. 실패인가?

<details>
<summary>답</summary>

1. 없다. 공개키는 자물쇠에 해당하며 공개돼도 안전하다. 접근하려면 개인키가 필요하고, 공개키에서 개인키를 역산할 수 없다.
2. 필요 없다. passphrase는 개인키 파일을 암호화할 뿐 공개키는 그대로다. 지문도 변하지 않는다.
3. 아니다. GitHub은 셸 접속을 제공하지 않아 인증 성공 후에도 세션을 끊는다. `successfully authenticated` 메시지가 성공 여부의 기준이다.
</details>

---

## 10. 자주 하는 실수

| 실수 | 결과 | 해결 |
| :--- | :--- | :--- |
| 지문을 등록 필드에 붙여넣기 | `Key is invalid` | 공개키 원문(`ssh-ed25519 AAAA...`) |
| 개인키를 등록·공유 | **계정 탈취 위험** | 절대 금지, 유출 시 즉시 폐기·재발급 |
| 개인키를 저장소에 커밋 | 유출 | `.gitignore` 에 `id_*` 추가 |
| 개인키 권한 644 | SSH가 사용 거부 | `chmod 600` |
| SSH URL에 `/` 사용 | 접속 실패 | `git@github.com:user/repo.git` (콜론) |
| 종료 코드 1을 실패로 오해 | 불필요한 재시도 | 메시지로 판단 |
| passphrase 설정 시 Enter만 | 설정 안 됨 | 값을 실제로 입력 |
| `known_hosts` 경고를 무시하고 삭제 | MITM 공격 가능성 무시 | 지문을 공식 문서와 대조 |

---

## 11. 예상 질문과 답변 포인트

평가 루브릭 **항목 5 보너스 5**(GitHub SSH 키 설정)가 이 문서에서 나온다. 배움 포인트가 "인증 방식 차이와 보안 습관"이므로 **원리와 판단 근거**를 함께 말해야 한다.

---

### A. 루브릭 직결 문항

#### A-1. HTTPS와 SSH 인증의 차이는? (보너스 5의 배움 포인트)

**⚡ 답변 — 자격 증명이 어디로 가는지로 구분한다**

> **HTTPS는 토큰이나 비밀번호를 매 요청마다 서버에 제시**합니다. 자격 증명이 네트워크를 지나가고, 유출되면 그대로 도용됩니다.
>
> **SSH는 키 쌍 기반**입니다. 서버가 보낸 무작위 값(챌린지)에 개인키로 서명해 응답하고, 서버는 등록된 공개키로 그 서명을 검증합니다. **개인키는 로컬을 절대 벗어나지 않습니다.** 이게 근본적인 차이입니다.

**인증 과정을 물으면**

```
1. 클라이언트:  "로그인할게요"
2. 서버:        "이 무작위 값에 서명해 보세요"     ← 챌린지
3. 클라이언트:  개인키로 서명해서 전송             ← 개인키는 전송되지 않음
4. 서버:        등록된 공개키로 서명 검증
5. 서버:        "확인됐습니다"
```

| 항목 | HTTPS | SSH |
| :--- | :--- | :--- |
| 인증 수단 | 비밀번호 / PAT 토큰 | 공개키·개인키 쌍 |
| 자격 증명 전달 | 매 요청마다 서버에 제시 | 서명만 전송, 개인키는 로컬 |
| 유출 시 | 토큰 그대로 도용 가능 | passphrase 있으면 파일만으론 사용 불가 |
| 폐기 | 토큰 재발급 | GitHub에서 공개키만 삭제 |

**실제로 확인한 것을 붙인다**

> 전환 후 `git ls-remote` 와 `git fetch` 가 **자격 증명을 묻지 않고** 동작했습니다. HTTPS였다면 토큰을 요구했을 지점입니다.

**📄 근거**: 보고서 **17-5**

---

#### A-2. SSH 키를 어떻게 설정했나?

**⚡ 30초 답변 — 6단계로**

> `ed25519` 로 키를 생성하고 → 지문으로 확인하고 → 공개키를 GitHub에 등록하고 → `ssh -T` 로 인증을 확인하고 → `git remote set-url` 로 HTTPS에서 SSH로 전환하고 → `git ls-remote` 로 실제 통신까지 검증했습니다. 이 저장소는 실제로 SSH로 푸시했습니다.
>
> 등록 과정에서 `Key is invalid` 오류를 겪었는데, 원인은 공개키 원문 대신 **지문**을 붙여넣은 것이었습니다. 15-5에 진단 과정을 기록했습니다.

**꼬리질문 대비**
- *"왜 ed25519인가?"* → 현재 표준이다. RSA 4096보다 키가 짧으면서(약 68자 vs 700자) 안전하고 빠르다. 구형 시스템 호환이 필요할 때만 RSA를 쓴다.
- *"`ssh -T` 가 종료 코드 1을 반환하는데 실패인가?"* → 정상이다. GitHub은 셸 접속을 제공하지 않아 인증 성공 후에도 세션을 끊는다. 판단 기준은 종료 코드가 아니라 `successfully authenticated` 메시지다.

---

### B. 따라붙기 쉬운 후속 질문

#### B-1. 공개키를 남에게 줘도 되나?

> 됩니다. **공개키는 자물쇠**에 해당합니다. 복사해서 여기저기 달아도 되고, GitHub에 등록하는 게 "GitHub 문에 내 자물쇠를 다는 것"입니다.
>
> 여기서 개인키를 역산하는 것은 **계산적으로 불가능**합니다. 그게 비대칭 암호의 수학적 보장입니다.
>
> 반대로 **개인키는 열쇠**라 절대 공유하면 안 되고, 유출되면 즉시 폐기하고 새로 만들어야 합니다.

---

#### B-2. 개인키 파일 권한이 600이어야 하는 이유는?

> 같은 시스템의 다른 사용자가 개인키를 읽으면 **내 계정을 사칭**할 수 있기 때문입니다.
>
> SSH는 이를 방지하려고 **권한을 직접 검사**하며, 그룹이나 기타에 권한이 조금이라도 열려 있으면 경고와 함께 **키 사용을 아예 거부**합니다.
>
> ```
> @    WARNING: UNPROTECTED PRIVATE KEY FILE!             @
> Permissions 0644 for '.../id_ed25519' are too open.
> This private key will be ignored.
> ```
>
> **권한 숫자 규칙이 실제 보안 도구에서 강제되는 대표 사례**입니다. 실습에서 `stat` 으로 확인했더니 개인키는 `600`, 공개키는 `644` 로 갈렸습니다. 공개키는 어차피 배포하는 값이라 열어둬도 되기 때문입니다.

[02번 문서](02-file-permissions.md)의 권한 규칙과 직접 연결되는 부분이다.

---

#### B-3. passphrase는 왜 거나?

> **개인키 파일 자체를 암호화**합니다.
>
> ```
> passphrase 없음:  개인키 파일 = 즉시 사용 가능
> passphrase 있음:  개인키 파일 + passphrase = 사용 가능
> ```
>
> 노트북 분실이나 파일 유출 시 passphrase를 모르면 쓸 수 없습니다. **자물쇠를 하나 더 다는 것**입니다.
>
> **공개키는 바뀌지 않으므로 서버 재등록이 필요 없습니다.** 지문도 그대로입니다. 매번 입력하는 불편은 `ssh-agent` 나 OS 키체인으로 해결합니다.

---

#### B-4. 이 키에는 왜 passphrase를 걸지 않았나?

> **의도적인 선택입니다.** 개인 노트북에서 혼자 쓰는 학습용 저장소이고, 유출 시 피해 범위가 이 공개 저장소 하나로 한정된다고 판단해 편의를 택했습니다.
>
> 다만 **위험이 없다는 뜻이 아니라 알고 감수한 것**입니다. 현재 개인키가 평문으로 저장돼 있어 파일만 유출돼도 즉시 사용 가능한 상태이고, 파일 권한 `600` 으로 보완하고 있습니다.
>
> 공용 PC를 쓰거나, 운영 서버 접근 권한이 걸린 키이거나, 조직 저장소에 접근하는 키라면 **반드시 걸어야 합니다.** 보고서 17-5에 이 판단 근거를 명시했습니다.

이 문항은 "안 했다"가 아니라 "알고 선택했다"로 답하는 게 핵심이다. 모르고 안 한 것과 구분된다.

---

#### B-5. 공개키와 지문의 차이는?

| | 공개키 | 지문(fingerprint) |
| :--- | :--- | :--- |
| 정체 | 실제 키 데이터 | 공개키를 해시한 **요약값** |
| 형태 | `ssh-ed25519 AAAA...` | `SHA256:McCE...` |
| 용도 | **등록용** | **대조·확인용** |
| 되돌리기 | — | 지문에서 키 복원 불가 |

> 실습에서 이 둘을 혼동해 `Key is invalid` 오류를 냈습니다. 지문은 "이 키가 내가 아는 그 키가 맞는지" 확인할 때 쓰는 값이지 키 자체가 아닙니다.

---

#### B-6. `ssh -T git@github.com` 이 종료 코드 1인데 성공인가?

> **정상입니다.** GitHub은 셸 접속을 제공하지 않으므로 인증에 성공해도 세션을 바로 끊습니다.
>
> ```
> Hi username! You've successfully authenticated, but GitHub does not provide shell access.
> ```
>
> 판단 기준은 종료 코드가 아니라 **`successfully authenticated` 메시지**입니다.

---

#### B-7. `known_hosts` 는 무엇인가?

> 지금까지는 "서버가 나를 확인"하는 이야기였는데, 이건 **반대 방향**입니다. 내가 접속하려는 서버가 진짜 GitHub인지 확인하는 용도입니다.
>
> 처음 접속하면 서버 지문을 보여주며 물어보고, `yes` 하면 `~/.ssh/known_hosts` 에 저장됩니다. 다음부터는 안 묻습니다.
>
> 나중에 지문이 바뀌면 경고가 뜨는데, 서버 재설치일 수도 있지만 **중간자 공격(MITM)일 수도 있습니다.** 무작정 지우지 말고 공식 문서의 지문과 대조해야 합니다.

---

#### B-8. SSH URL 형식이 왜 다른가?

```
HTTPS:  https://github.com/user/repo.git
SSH:    git@github.com:user/repo.git
        └┬┘ └────┬───┘│└───┬───┘
       사용자   호스트  :  경로
```

> SSH 형식은 호스트 뒤가 `/` 가 아니라 **`:`** 입니다. 자주 틀리는 부분입니다.

---

### C. 실전 시나리오

#### C-1. "`Permission denied (publickey)` 가 납니다."

> 원인이 두 가지라 **먼저 구분**해야 합니다.
>
> ```bash
> # passphrase 유무 확인
> ssh-keygen -y -P "" -f ~/.ssh/id_ed25519 > /dev/null 2>&1 \
>   && echo "passphrase 없음 → 미등록이 원인" \
>   || echo "passphrase 있음 → agent 문제일 수 있음"
>
> # 어떤 키를 제시했는지 상세 확인
> ssh -v -T git@github.com 2>&1 | grep -i "offering\|denied"
> ```
>
> `Offering public key: ...` 다음에 `denied` 가 나오면 **키를 제시했는데 서버가 모르는 키**라는 뜻이므로 GitHub 등록 문제입니다. passphrase가 걸려 있고 agent가 비어 있으면 `ssh-add` 로 해결합니다.

실습에서 실제로 이 순서로 원인을 특정했다.

---

#### C-2. "GitHub이 `Key is invalid` 라고 합니다."

> 세 단계로 확인합니다.
>
> ```bash
> ssh-keygen -lf ~/.ssh/id_ed25519.pub     # ① 파일이 유효한가 (지문이 나오면 정상)
> cut -d' ' -f1 < ~/.ssh/id_ed25519.pub    # ② ssh- 로 시작하는가
> pbcopy < ~/.ssh/id_ed25519.pub           # ③ 원문을 정확히 복사
> ```
>
> ①이 정상인데 오류가 나면 **붙여넣은 내용이 공개키가 아닌** 것입니다. 지문을 붙여넣었거나, Title 칸과 Key 칸이 바뀐 경우가 대부분입니다.

---

#### C-3. "매번 passphrase를 물어봅니다."

```bash
ssh-add ~/.ssh/id_ed25519                       # 현재 세션에만
ssh-add --apple-use-keychain ~/.ssh/id_ed25519  # macOS 키체인에 영구 저장
```

`~/.ssh/config` 에 넣어두면 자동으로 처리된다.

```
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
```

---

### D. 한 줄 요약 (외울 것)

| 개념 | 한 줄 |
| :--- | :--- |
| 공개키 / 개인키 | 자물쇠 / 열쇠 |
| SSH의 핵심 | **개인키가 네트워크를 지나가지 않는다** |
| HTTPS와 차이 | 토큰은 매번 제시, SSH는 서명만 전송 |
| 공개키 공유 | 안전 (개인키 역산 불가) |
| 개인키 권한 | `600` 아니면 SSH가 **거부** |
| passphrase | 개인키 파일 암호화, 공개키는 안 바뀜 |
| 지문 | 등록용 아님, **대조용** |
| `ssh -T` exit 1 | 정상 (메시지로 판단) |

---

**이전 문서** → [09. Git과 GitHub](09-git-github.md)
**다음 문서** → [11. 트러블슈팅 방법론](11-troubleshooting.md)
