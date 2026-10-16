# Helium flake

[Helium](https://github.com/imputnet/helium-linux)의 공식 Linux 바이너리를
NixOS + GNOME + Wayland용으로 패키징한 Nix flake입니다. `x86_64-linux`를 지원합니다.

## Getting started

Nix flakes가 활성화된 환경에서 저장소 루트에서 실행합니다.

```sh
nix run .
```

```sh
nix run . -- --version          # 실행 인자 전달
nix build                      # ./result/bin/helium 빌드
nix profile install .#helium    # 사용자 프로필에 설치
nix run .#helium-spoofdpium      # 프록시와 함께 실행
```

Home Manager에서는 `inputs.helium.homeManagerModules.default`를 모듈 목록에 추가하고
`programs.helium.enable = true;`로 활성화합니다.
프록시도 사용하려면 `programs.helium.proxy.enable = true;`를 설정합니다.

개발 및 유지보수는 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.
