# 유지보수 가이드

## 코드 구성

- `flake.nix`: 패키지·앱·오버레이·Home Manager 모듈과 checks를 노출합니다.
  `overlays.default`는 소비자의 패키지 세트로 빌드하고, `overlays.pinned`는
  이 flake에 고정된 패키지를 사용합니다. 지원 플랫폼은 `x86_64-linux`입니다.
- `package.nix`: 공식 바이너리 다운로드, ELF 패치, 런타임 라이브러리와
  데스크톱 통합을 담당합니다. 소스에서 브라우저를 빌드하지 않습니다.
- `wrapped-package.nix`: 실행 인자와 선택적 프록시를 결합하고 데스크톱 실행 경로를 맞춥니다.
  프록시 런처는 `spoofdpium` 입력의 `package.nix`를 재사용합니다.
- `home-manager.nix`: `programs.helium` 옵션, 설치 패키지와 외부 확장 JSON을 정의합니다.
- `flake.lock`: `nixpkgs`, `spoofdpium`과 전이 입력의 리비전을 고정합니다.
- `tests.nix`, `tests-runtime.py`: 모듈 평가, 데스크톱 통합과 런처 동작을 검사합니다.

## 릴리스 및 입력 갱신

1. `package.nix`의 `version`과 `src.hash`, `flake.nix`의 버전 설명을 갱신합니다.
   해시는 새 릴리스의 tarball URL로 확인합니다.

   ```sh
   nix store prefetch-file --json <tarball-URL>
   ```

2. 의존성 갱신이 필요하면 대상 입력만 갱신하고 `flake.lock` 변경을 검토합니다.

   ```sh
   nix flake update nixpkgs
   nix flake update spoofdpium
   ```

3. 아래 검증을 실행합니다. `spoofdpium` 갱신 시 런처와 `spoofdpi`의 CLI 호환성도 확인합니다.

## 유지해야 할 동작

- GTK 4와 Wayland 통합, 그래픽·오디오 런타임 라이브러리를 유지합니다.
  바이너리가 직접 링크하는 X11 라이브러리도 필요합니다. Qt 통합은 제외하며
  기본 샌드박스 설정을 유지합니다.
- 터미널과 데스크톱 메뉴의 기본 실행·새 창·시크릿 창은 같은 래퍼를 사용해야 합니다.
  인자의 공백·빈 문자열·셸 문자를 보존하고, 새 창과 시크릿 인자를 유지합니다.
- Home Manager는 `${xdg.configHome}/net.imput.helium`을 프로필로 사용합니다.
  외부 확장 선언(`id`, `crxPath`, `version`)은 이 경로의 `External Extensions`에
  JSON으로 기록합니다. 프로필 인자를 바꾸면 확장 경로도 일치시켜야 합니다.
  `finalPackage`가 실제 설치되는 패키지입니다.
- 프록시 기본 포트는 `48202`, 잠금은 `$XDG_RUNTIME_DIR/spoofdpium-48202.lock`입니다.
  같은 포트의 실행은 프록시를 공유하며 최초 소유 브라우저가 종료되면 프록시도 정리됩니다.
  독립적인 프로필은 서로 다른 포트를 사용해야 합니다.
  시작 실패나 포트 충돌 시 브라우저를 실행하지 않아야 하며,
  사용자 지정 `spoofdpi`는 `--listen-addr`와 `--no-tui`를 지원해야 합니다.

## 검증

새 파일은 Git 추적에 추가해야 로컬 flake 검증에 포함됩니다. 커밋은 필요하지 않습니다.

```sh
git add <새-파일>
nix build . .#helium-spoofdpium --no-link
nix flake check
```

checks는 패키지 빌드, 모듈 기본값·사용자 설정·포트 검증·확장 JSON,
데스크톱 실행 경로와 한국어 리소스를 확인합니다. 런처 검사는 가짜 브라우저와
TCP 프록시로 인자 전달, 중복 실행, 종료·신호 정리, 시작 실패, 포트 충돌과
서로 다른 포트의 독립 실행을 검증합니다.

브라우저나 통합 동작을 변경했다면 실제 GNOME/Wayland 환경에서도 확인합니다.
터미널과 메뉴(새 창·시크릿 포함)에서 실행하고 `chrome://version`의 프로필·인자를 확인합니다.
프록시 사용 시 실제 네트워크 연결과 브라우저 종료 후 프록시 정리를 확인하고,
확장 관련 변경은 임시 프로필에서 설치·실행을 검증합니다.
