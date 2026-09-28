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
| `ParkParkStorybookEntrance.obj` | 둥근 아치, 장식 띠와 간판 바탕 |
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

OBJ는 현재 **메시 원본**이며 아직 Studio place에 들어간 모델이 아닙니다. Studio에서 import한 뒤 실루엣, 재질, 피벗, 입구에서 보이는 구도와 모바일 성능을 확인하고, 승인된 결과만 Rojo 경로에 연결합니다.
