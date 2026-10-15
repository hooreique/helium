# Helium flake

[Helium 0.19.3.1](https://github.com/imputnet/helium-linux/releases/tag/0.19.3.1)의
공식 Linux 바이너리를 NixOS + GNOME + Wayland용으로 패키징한 Nix flake입니다.
`x86_64-linux`만 지원하며,
입력은 `nixpkgs` 하나입니다. `flake-utils`, `flake-parts`를 사용하지 않습니다.

## 사용법

```sh
nix build
nix run .
nix run . -- --version
nix flake check
```

`nix build`의 실행 파일은 `./result/bin/helium`입니다. 인자는
`nix run . -- <인자>`로 전달할 수 있습니다.

사용자 프로필에 설치하려면 다음 명령을 실행합니다. 데스크톱 메뉴 항목과 아이콘도 포함됩니다.

```sh
nix profile install .#helium
```

다른 flake에서는 이 저장소를 입력으로 추가한 뒤
`inputs.helium.packages.x86_64-linux.default`를 NixOS의 `environment.systemPackages`
또는 Home Manager의 `home.packages`에 넣으면 됩니다.

## 구성

- `flake.nix`: `packages`와 `apps`의 `default` / `helium`, 패키지 빌드 check를 제공합니다.
- `package.nix`: 고정된 SHA-256으로 tarball을 받고, ELF 인터프리터와 라이브러리 경로를
  패치합니다. GTK 4 통합, 오디오, Wayland, 그래픽 관련 런타임 라이브러리를 연결합니다.
  Qt 통합은 제외하며, X11 라이브러리는 바이너리가 직접 링크하는 항목을 유지합니다.
  샌드박스 기본 설정을 유지하며, 설치 검증 단계에서 버전 출력을 확인합니다.
- `flake.lock`: 사용할 `nixpkgs` 리비전을 고정합니다.

릴리스를 갱신할 때는 `package.nix`의 `version`과 `src.hash`, flake 설명 및 이 문서의
버전을 함께 수정합니다. 새 tarball의 해시는 `nix store prefetch-file --json <URL>`로
확인할 수 있습니다. 변경 파일을 `git add`한 후 `nix build`와 `nix flake check`로 검증합니다.
