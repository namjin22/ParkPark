# 🎠 ParkPark

**꺼진 놀이공원에 다시 불을 켜는 Roblox 복구 타이쿤**

폐장한 놀이공원을 하나씩 고쳐 다시 손님을 맞는 게임입니다. 친구와 가볍게 둘러보고, 고장 난 놀이기구를 되살리고, 티켓을 모아 공원을 키우는 흐름을 만들고 있어요.

## 지금 만들고 있어요

첫 목표는 입구를 지나 회전목마를 고치고, 복구 보상으로 티켓을 받는 짧은 플레이입니다.

화면에 보이는 기본 파트와 임시 HUD는 동작을 확인하기 위한 graybox예요. 최종 디자인이 아니고, 회전목마와 입구는 별도의 아트 작업을 거칠 예정입니다.

`입구 정리 → 회전목마 수리 → 손님 맞이 → 티켓 모으기 → 공원 확장`

## 프로젝트 둘러보기

```text
src/
├── client/
│   ├── Bootstrap.client.luau
│   └── Controllers/HUDController.luau
├── server/
│   ├── Bootstrap.server.luau
│   └── Services/
│       ├── ParkBuilder.luau
│       ├── RideService.luau
│       └── EconomyService.luau
└── shared/Config/GameConfig.luau

docs/
├── GAME_DESIGN.md
├── ART_DIRECTION.md
└── ASSET_PLAN.md
```

## 실행 방법

### 준비물

- Roblox Studio
- [Rojo 7.7](https://rojo.space/)
- [Aftman](https://github.com/LPGhatguy/aftman) — 프로젝트에서 사용하는 도구 버전을 맞출 때 권장

### Studio에 연결하기

프로젝트 폴더에서 아래 명령을 실행하고, Roblox Studio에서 Rojo 플러그인으로 연결하세요.

```powershell
aftman install
rojo serve default.project.json
```

서버 코드는 `ServerScriptService/ParkReborn`, 클라이언트 코드는 `StarterPlayerScripts/ParkRebornClient`, 공용 설정은 `ReplicatedStorage/ParkRebornShared`에 연결됩니다.

### 변경 사항 확인하기

Windows PowerShell에서 다음을 실행합니다.

```powershell
.\verify.ps1
```

StyLua, Selene, Luau 타입 분석, Rojo sourcemap과 place build를 확인합니다. 실제 플레이와 화면 확인은 Roblox Studio에서 진행하세요.

## 설계 메모

- [게임 기획](docs/GAME_DESIGN.md)
- [아트 방향](docs/ART_DIRECTION.md) — 동화책 같은 놀이공원과 모바일 화면 기준
- [에셋 계획](docs/ASSET_PLAN.md) — 직접 만들 요소와 골라 다듬을 요소

현재 기준은 따뜻하고 장난스러운 동화풍 놀이공원입니다. 유명 공원이나 브랜드를 따라 만들지 않고 ParkPark만의 모습을 찾고 있습니다.
