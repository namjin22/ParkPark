# ParkPark 루프 로그

반복마다 3줄(한 일 / 검증 결과 / 다음 계획)을 아래에 추가합니다. 반복 번호는 1부터 이어서 셉니다.

## 반복 기록

- 반복 1 (2026-10-13): 한 일: S1 광장 미니게임 부스 6개(`MinigameService`, 고리/사격/점집/사진/인형뽑기/다트), 배치 `ParkLayout.MinigameBooths`, OBJ 6개 생성, 템플릿 빌더 `build_booth`. / 검증: verify.ps1 통과, 메모리 저장 모드 Play에서 6개 부스 모두 지급 확인(회전목마만 수리한 상태, 5~9코인), 그레이박스 캡처로 배치 확인. 쿨다운·시간당 상한은 코드 검토만. / 다음: S3 금고(방치 수입), 코드 전용이라 가져오기 없이 진행 가능.

- 반복 2 (2026-10-13): 한 일: S3 금고 `VaultService`(자리 비운 시간 x 현재 분당 수입 x 25%, 최대 4시간, 광장 (-62,0,36)에서 E로 수령), 프로필 `LastSeen`/`Vault` 저장, OBJ `ParkParkCoinVault`. / 검증: verify.ps1 통과, 시드 프로필(2시간 전, 금고 100)로 Play에서 1,454 적립과 수령 후 0 확인. 상한(4시간)과 최소 부재 시간 경로는 코드 검토만. / 다음: S2 계절 이벤트 엔진(날짜 기반, 장식 6종은 그레이박스).

- 반복 3 (2026-10-13): 한 일: S2 계절 이벤트 엔진 `SeasonService`(UTC 날짜로 핼러윈 10/24~11/2, 겨울맞이 12/15~1/2, 새해 등불 1/20~2/12, 한가위 9/15~9/30, `ForceSeason`으로 테스트), 길가 장식 배치(임시 모양), 수입 +8% (`SeasonBonus`), 계절 한정 꾸미기 4개(핼러윈 2, 겨울 2)의 구입 제한, OBJ 6개 생성. / 검증: verify.ps1 통과. Studio 장소가 닫혀 있어 Play 확인은 **확인 대기**("Place is not open"). / 다음: Studio가 다시 열리면 S2 Play 확인(장식 개수, 한정 꾸미기 구입 제한, 수입 보너스)부터, 안 열리면 코드 전용인 S4(VIP 라운지·매표소·후원사 간판)를 진행.

## 가져오기 대기 목록 (사용자가 3D Importer로 가져올 OBJ)

- ParkParkBoothRing
- ParkParkBoothShooting
- ParkParkBoothFortune
- ParkParkBoothPhoto
- ParkParkBoothClaw
- ParkParkBoothDart
- ParkParkCoinVault
- ParkParkDecorPumpkin
- ParkParkDecorSpookyLamp
- ParkParkDecorSnowman
- ParkParkDecorXmasTree
- ParkParkDecorPaperLantern
- ParkParkDecorFireworkLauncher

## 사용자 메모 (폰 확인, 패스 ID, 오디오 ID 등)

- (비어 있음)
