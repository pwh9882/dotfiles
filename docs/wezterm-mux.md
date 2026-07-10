# WezTerm MUX(원격 세션 영속) 세팅 가이드

## 목표

로컬 WezTerm을 껐다 켜도, **원격 서버의 탭/패널/셸 세션이 유지**되도록 `wezterm-mux-server`를 **서버에서 상시 실행**하고, 로컬은 거기에 **재접속**한다.

---

## 빠른 요약 (TL;DR)

1. **서버**에 WezTerm 설치 → 유저 서비스로 `wezterm-mux-server` 상시 실행
2. **로컬** `~/.config/wezterm/machine/local.lua`에서 `ssh_domains` 정의(`multiplexing='WezTerm'`)
3. 접속: `wezterm connect SSHMUX:<host>`
4. 재부팅/재로그인 후에도 `wezterm connect …`만으로 기존 세션 재첨부

---

## 서버 설정

### 0) 전제

* 서버 쪽에도 **WezTerm 설치** 필요 (`wezterm-mux-server` 바이너리 있어야 함)
* 사용자 단위 systemd 사용 가능(보통 OK)

```bash
which wezterm-mux-server
# 예: /usr/bin/wezterm-mux-server
```

### 1) 유닛 파일

`~/.config/systemd/user/wezterm-mux.service`

```ini
[Unit]
Description=WezTerm Multiplexer (wezterm-mux-server)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/wezterm-mux-server
Restart=on-failure

[Install]
WantedBy=default.target
```

> `ExecStart` 경로는 `which` 결과에 맞춰 수정.

### 2) 적용 + 자동시작

```bash
systemctl --user daemon-reload
loginctl enable-linger "$USER"                    # 로그아웃 후에도 유저 systemd 유지
systemctl --user enable --now wezterm-mux.service # 부팅/로그인 시 자동 기동
```

### 3) 확인

```bash
systemctl --user status wezterm-mux.service
ss -xlp | grep wezterm
# 소켓: /run/user/$(id -u)/wezterm/sock
```

---

## 로컬(클라이언트) 설정

### 1) SSH 설정(선택)

`~/.ssh/config`

```sshconfig
Host build-host
  HostName build-host.example
  User developer
  Port 22
```

### 2) WezTerm 설정

`~/.config/wezterm/machine/local.lua`

```lua
return {
  ssh_domains = {
    {
      name = 'build-host',
      remote_address = 'build-host', -- ssh config Host alias
      username = 'developer',
      multiplexing = 'WezTerm',      -- 원격 mux에 연결
      -- remote_wezterm_path = '/usr/bin/wezterm', -- PATH 밖이면 지정
    },
  },
}
```

공개 저장소에는 주소, 사용자명, identity path를 넣지 않습니다. [`machine/local.example.lua`](../.config/wezterm/machine/local.example.lua)를 복사한 뒤 이 머신에서만 필요한 값을 gitignored `local.lua`에 추가합니다.

### 3) 접속/재접속

```bash
wezterm connect SSHMUX:build-host  # SSHMUX: 프리픽스가 “원격 mux” 의미
```

---

## 동작 개념(헷갈리기 쉬운 점)

* **로컬 설정이 적용되는 것(UI/키)**: 폰트/색상/탭바/키바인딩/분할 등 “보이는 것과 조작감”.
* **원격 설정이 적용되는 것(프로세스/셸)**: 새 탭/패널에서 실행되는 프로그램(default shell), default_cwd, launch_menu 항목의 경로 해석 등 **실행 환경**.
  → launch_menu에 명시한 경로/명령은 **원격 기준**으로 존재해야 함.

---

## 트러블슈팅

### A. `enable` 실패: `Access denied` 또는 `…wants/… does not exist`

원인: 디렉터리/소유권 꼬임 또는 wants 디렉터리 없음.

```bash
mkdir -p ~/.config/systemd/user/default.target.wants
chown -R "$USER:$USER" ~/.config/systemd ~/.config/systemd/user
systemctl --user daemon-reload
systemctl --user enable --now wezterm-mux.service
```

여전히 실패하면 **수동 심볼릭 링크**로 enable과 동일 효과:

```bash
ln -sf ../wezterm-mux.service \
  ~/.config/systemd/user/default.target.wants/wezterm-mux.service
systemctl --user daemon-reload
systemctl --user restart wezterm-mux.service
systemctl --user is-enabled wezterm-mux.service   # enabled면 OK
```

### B. 같은 소켓에 **프로세스가 2개** 리슨(중복 기동)

원인: 예전에 수동 `--daemonize`로 띄운 mux가 남아 있음.
정리 순서:

```bash
systemctl --user stop wezterm-mux.service
pkill -f wezterm-mux-server || true       # -f: 전체 커맨드라인 매칭
rm -f "$XDG_RUNTIME_DIR/wezterm/sock"     # 오래된 소켓 제거
systemctl --user start wezterm-mux.service
# 리슨 PID = status의 Main PID인지 확인
systemctl --user status wezterm-mux.service
ss -xlp | grep wezterm
```

### C. `pkill -x wezterm-mux-server`가 안 먹음

리눅스 comm 이름 15자 제한으로 `wezterm-mux-ser`로 잘려 저장됨.
→ `pkill -x wezterm-mux-ser` 또는 **`pkill -f wezterm-mux-server`** 사용.

### D. `sudo systemctl --user …`에서 `No medium found`

root에는 해당 유저의 **user DBus**가 없음.
→ **절대 `sudo systemctl --user` 쓰지 말 것.** 항상 일반 유저로 실행.

### E. 연결해도 세션이 안 이어짐 / 바로 끊김

* 로컬 접속이 **SSHMUX:** 프리픽스를 쓰는지 확인. (`wezterm connect SSHMUX:<host-alias>`)
* 원격 mux가 **실행 중**인지 확인(`systemctl --user status …` / 소켓 파일 확인).
* 로컬/원격 **WezTerm 버전 차이**가 크면 문제 될 수 있음 → 가급적 동일/근접 버전.
* `remote_wezterm_path`가 필요한 환경이면 지정.

### F. `enable`은 됐는데 부팅 후 안 떠요

* `loginctl show-user "$USER" -p Linger` → `Linger=yes`인지 확인.
* 홈/유닛 디렉터리 소유권/퍼미션 확인:

  ```bash
  ls -ld ~/.config/systemd ~/.config/systemd/user ~/.config/systemd/user/default.target.wants
  ```

### G. 소켓 경로/권한

* 기본: `/run/user/$(id -u)/wezterm/sock`
* 없거나 권한 문제로 붙지 못하면 소켓 제거 후 서비스 재기동:

  ```bash
  rm -f "$XDG_RUNTIME_DIR/wezterm/sock"
  systemctl --user restart wezterm-mux.service
  ```

---

## 유용한 확인/운영 커맨드

```bash
# 서비스 상태/로그
systemctl --user status wezterm-mux.service
journalctl --user -u wezterm-mux.service -n 200 --no-pager

# 리슨 소켓/프로세스
ss -xlp | grep wezterm
ls -l "$XDG_RUNTIME_DIR/wezterm/sock"

# 유저 systemd/linger
loginctl show-user "$USER" -p State -p Linger

# 현재 떠있는 mux 프로세스 확인
ps -eo pid,cmd | grep -v grep | grep wezterm-mux

# WezTerm CLI(원격 탭/창 관리)
wezterm cli list
wezterm cli kill-pane --pane-id <ID>    # 또는 kill-tab / kill-window
```

---

## 재접속 검증(손쉬운 테스트)

```bash
wezterm connect SSHMUX:build-host
echo $WEZTERM_PANE        # Pane ID 기록
# 로컬 WezTerm 완전 종료
wezterm connect SSHMUX:build-host
echo $WEZTERM_PANE        # 값이 같으면 같은 세션
```

---

## 참고 메모

* 로컬 설정(폰트/색/키)은 **클라이언트(UI)**에 적용, 원격 실행(default shell/경로)은 **서버** 설정/환경을 따름.
* 여러 서버를 쓰면 `ssh_domains`에 여러 항목을 추가하면 된다.
* `wezterm.default_ssh_domains()`를 쓰면 `~/.ssh/config` 기반으로 도메인을 자동 생성할 수 있다(선호에 따라 선택).
