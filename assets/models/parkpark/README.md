# ParkPark 놀이공원 모델 소스

이 폴더의 OBJ는 회전목마와 입구를 위한 **직접 제작한 저폴리 메시 원본**입니다. 기본 Part graybox를 최종 모델로 바꿔치기한 것이 아니라, 별도의 메시 지오메트리를 생성합니다.

![커스텀 메시 검토용 미리보기](ParkParkModelPreview.png)

## 모델 목록

| 파일 | 용도 |
| --- | --- |
| `ParkParkCarouselPlatform.obj` | 고정 원형 플랫폼과 계단 |
| `ParkParkCarouselRotor.obj` | 중앙축, 방사형 지지대, 목마 8개 |
| `ParkParkCanopyRestored.obj` | 코랄·크림 차양, 금빛 장식, 피니얼 |
| `ParkParkCanopyNeglected.obj` | 바랜 차양과 빠진 패널이 있는 폐허 상태 |
| `ParkParkStorybookEntrance.obj` | 둥근 아치와 장식 띠 |
| `ParkParkEntranceSign.obj` | SurfaceGui 글자를 얹을 별도 간판 메시 |
| `ParkParkRepairConsole.obj` | 수리 상호작용을 위한 작은 장식 콘솔 |
| `ParkParkFairground.mtl` | 공통 재질 팔레트 |

## 생성·가져오기

저장소 루트에서 Python 표준 라이브러리만으로 다시 생성할 수 있습니다.

```powershell
python tools/generate_parkpark_meshes.py
```

미리보기 시트는 Pillow가 설치된 환경에서 다시 만들 수 있습니다.

```powershell
python tools/render_parkpark_mesh_preview.py
```

미리보기는 형상 배치를 빠르게 살펴보는 용도이며 Roblox Studio의 재질·조명 결과를 대신하지 않습니다.

Roblox Studio의 [3D Importer](https://create.roblox.com/docs/studio/importer)에서 OBJ를 가져올 때 `ParkParkFairground.mtl`을 같은 폴더에 두세요. 차양 두 버전은 같은 원점·크기를 사용하며, broken/restored 중 한쪽만 표시하도록 구성합니다. 회전목마 rotor의 원점은 바닥 중앙 회전축에 맞췄습니다.

가져온 뒤 asset model을 다음 규약으로 묶어 `assets/models/roblox/`에 저장합니다. Rojo가 이 폴더를 `ReplicatedStorage/ParkParkAssets`로 동기화하며, `AssetManifest.luau`의 이름을 그대로 사용합니다.

- `RuinedEntrance` Model: 아치 메시와 `SignPanel` MeshPart를 포함하고, floor-center pivot을 사용합니다. `SignPanel`은 root 기준 `[0, 14.2, -1.35]`에 둡니다.
- `BrokenCarousel` Model: 고정 `RidePlatform` MeshPart, 고정 `RepairConsole` MeshPart, `CarouselRotor` Model을 포함합니다. Platform은 root 원점에, 콘솔은 root 기준 `[13, 0, 0]`에 둡니다.
- `CarouselRotor` 안에는 회전축 메시 `CenterPost`와 `CanopyNeglected`/`CanopyRestored` canopy variant를 둡니다. `CenterPost` pivot은 회전목마 바닥 중심에 맞춥니다. 콘솔은 rotor 밖에 둡니다.

모델에 스크립트를 넣지 않습니다. 수리 prompt, 잔해 상호작용, 상태 변경은 게임 코드가 관리합니다. 규약을 갖춘 모델이 없으면 `ParkBuilder`가 기존 graybox를 계속 생성합니다.

OBJ는 현재 **메시 원본**이며 아직 Studio place에 들어간 모델이 아닙니다. Studio에서 import한 뒤 실루엣, 재질, 피벗, 입구에서 보이는 구도와 모바일 성능을 확인하고, 승인된 결과만 Rojo 경로에 연결합니다.
