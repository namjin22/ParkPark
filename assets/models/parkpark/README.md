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

생성기는 저장 전에 연결된 부품마다 면 방향을 바깥쪽 반시계 방향으로 맞춥니다. Roblox는 반시계 방향 면만 앞면으로 그리므로, 이전 OBJ처럼 방향이 섞이면 Studio에서 일부 부품이 속이 빈 것처럼 보입니다.

미리보기는 형상 배치를 빠르게 살펴보는 용도이며 Roblox Studio의 재질·조명 결과를 대신하지 않습니다.

Roblox Studio의 [3D Importer](https://create.roblox.com/docs/studio/importer)에서 OBJ를 가져올 때 `ParkParkFairground.mtl`을 같은 폴더에 두세요. 차양 두 버전은 같은 원점·크기를 사용하며, broken/restored 중 한쪽만 표시하도록 구성합니다. 회전목마 rotor의 원점은 바닥 중앙 회전축에 맞췄습니다.

가져온 뒤 asset model을 다음 규약으로 묶어 `assets/models/roblox/`에 저장합니다. Rojo가 이 폴더를 `ReplicatedStorage/ParkParkAssets`로 동기화하며, `AssetManifest.luau`의 이름을 그대로 사용합니다.

- `RuinedEntrance` Model: 아치 메시와 `SignPanel` MeshPart를 포함하고, floor-center pivot을 사용합니다. `SignPanel`은 root 기준 `[0, 14.2, -1.35]`에 둡니다.
- `BrokenCarousel` Model: 고정 `RidePlatform` MeshPart, 고정 `RepairConsole` MeshPart, `CarouselRotor` Model을 포함합니다. Platform은 root 원점에, 콘솔은 root 기준 `[13, 0, 0]`에 둡니다.
- `CarouselRotor` 안에는 회전축 메시 `CenterPost`와 `CanopyNeglected`/`CanopyRestored` canopy variant를 둡니다. `CenterPost` pivot은 회전목마 바닥 중심에 맞춥니다. 콘솔은 rotor 밖에 둡니다.

OBJ 이름과 모델 안 이름은 다음처럼 대응합니다. 아래 방향 규약의 `RepairConsole`을 제외한 MeshPart는 OBJ 좌표 방향을 그대로 유지하고, 모두 `Anchored`로 저장합니다. rotor 쪽 파트는 게임 코드가 `CenterPost`에 weld한 뒤 unanchor합니다.

| OBJ | Studio 이름 | 부모 |
| --- | --- | --- |
| `ParkParkStorybookEntrance.obj` | `EntranceArch` | `RuinedEntrance` |
| `ParkParkEntranceSign.obj` | `SignPanel` | `RuinedEntrance` |
| `ParkParkCarouselPlatform.obj` | `RidePlatform` | `BrokenCarousel` |
| `ParkParkRepairConsole.obj` | `RepairConsole` | `BrokenCarousel` |
| `ParkParkCarouselRotor.obj` | `CenterPost` (중앙축·지지대·목마 전체) | `BrokenCarousel/CarouselRotor` |
| `ParkParkCanopyNeglected.obj` | `CanopyNeglected` | `BrokenCarousel/CarouselRotor` |
| `ParkParkCanopyRestored.obj` | `CanopyRestored` | `BrokenCarousel/CarouselRotor` |

방향 규약: 메시의 정면(간판 코랄 면, 콘솔 버튼 패널)은 Roblox Part와 같이 local `-Z`입니다. 게임에서 방문자는 `+Z` 쪽 스폰에서 `-Z` 방향의 회전목마로 걸어가므로, `ParkBuilder`는 입구 모델을 Y축 180° 돌려 배치해 아치 정면과 간판이 방문자를 향하게 합니다. 회전목마 모델은 회전하지 않으므로, `RepairConsole`만 모델 안에서 Y축 180° 돌려 버튼 패널이 root `+Z`(입구 쪽)를 보게 합니다. rotor·canopy·platform은 XZ 경계 상자 중심이 원점이라 Importer가 파트 중심을 경계 상자 중심으로 잡아도 회전축이 어긋나지 않습니다.

모델에 스크립트를 넣지 않습니다. 수리 prompt, 잔해 상호작용, 상태 변경은 게임 코드가 관리합니다. 규약을 갖춘 모델이 없으면 `ParkBuilder`가 기존 graybox를 계속 생성합니다.

OBJ는 현재 **메시 원본**이며 아직 Studio place에 들어간 모델이 아닙니다. Studio에서 import한 뒤 실루엣, 재질, 피벗, 입구에서 보이는 구도와 모바일 성능을 확인하고, 승인된 결과만 Rojo 경로에 연결합니다.
