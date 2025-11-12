"""
한밭대학교 흡연 감지 앱 아이콘 생성 스크립트
HBNU 공식 색상(Hanbat Dark Blue)과 금연 심볼 사용
"""
from PIL import Image, ImageDraw, ImageFont
import os

# 한밭대학교 공식 색상 (CMYK to RGB 변환)
# Hanbat Dark Blue: C80, M50, Y17, K10
# 대략적인 RGB 변환: (31, 73, 125)
HBNU_DARK_BLUE = (31, 73, 125)
HBNU_BACKGROUND = (26, 26, 46)  # 앱 테마 색상 #1A1A2E
WHITE = (255, 255, 255)
RED = (239, 83, 80)  # 경고 빨강

def create_base_icon(size=1024):
    """기본 아이콘 생성 (1024x1024)"""
    # 배경 생성
    img = Image.new('RGB', (size, size), HBNU_BACKGROUND)
    draw = ImageDraw.Draw(img)

    # 원형 배경 (HBNU Dark Blue)
    margin = size // 8
    circle_bbox = [margin, margin, size - margin, size - margin]
    draw.ellipse(circle_bbox, fill=HBNU_DARK_BLUE)

    # 금연 심볼 그리기
    center = size // 2

    # 담배 아이콘 (간단한 직사각형)
    cigarette_width = size // 6
    cigarette_height = size // 20
    cigarette_x = center - cigarette_width // 2
    cigarette_y = center - cigarette_height // 2

    # 담배 본체 (흰색)
    draw.rectangle(
        [cigarette_x, cigarette_y,
         cigarette_x + cigarette_width, cigarette_y + cigarette_height],
        fill=WHITE
    )

    # 담배 끝 (주황색/빨강)
    tip_width = cigarette_width // 4
    draw.rectangle(
        [cigarette_x + cigarette_width - tip_width, cigarette_y,
         cigarette_x + cigarette_width, cigarette_y + cigarette_height],
        fill=RED
    )

    # 금연 표시 (붉은 원에 사선)
    prohibition_radius = size // 3
    prohibition_width = size // 20

    # 붉은 원
    draw.ellipse(
        [center - prohibition_radius, center - prohibition_radius,
         center + prohibition_radius, center + prohibition_radius],
        outline=RED, width=prohibition_width
    )

    # 사선 (왼쪽 위에서 오른쪽 아래로)
    line_offset = int(prohibition_radius * 0.7)
    draw.line(
        [center - line_offset, center - line_offset,
         center + line_offset, center + line_offset],
        fill=RED, width=prohibition_width
    )

    return img

def create_foreground_icon(size=1024):
    """Adaptive icon foreground 생성 (투명 배경)"""
    # 투명 배경 생성
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    center = size // 2

    # 금연 심볼 그리기 (foreground는 중앙 영역만 사용)
    # 담배 아이콘
    cigarette_width = size // 6
    cigarette_height = size // 20
    cigarette_x = center - cigarette_width // 2
    cigarette_y = center - cigarette_height // 2

    # 담배 본체 (흰색)
    draw.rectangle(
        [cigarette_x, cigarette_y,
         cigarette_x + cigarette_width, cigarette_y + cigarette_height],
        fill=WHITE
    )

    # 담배 끝 (빨강)
    tip_width = cigarette_width // 4
    draw.rectangle(
        [cigarette_x + cigarette_width - tip_width, cigarette_y,
         cigarette_x + cigarette_width, cigarette_y + cigarette_height],
        fill=RED
    )

    # 금연 표시
    prohibition_radius = size // 3
    prohibition_width = size // 20

    # 붉은 원
    draw.ellipse(
        [center - prohibition_radius, center - prohibition_radius,
         center + prohibition_radius, center + prohibition_radius],
        outline=RED, width=prohibition_width
    )

    # 사선
    line_offset = int(prohibition_radius * 0.7)
    draw.line(
        [center - line_offset, center - line_offset,
         center + line_offset, center + line_offset],
        fill=RED, width=prohibition_width
    )

    return img

# 아이콘 생성
print("아이콘 생성 중...")

# assets/icon 디렉토리 확인
icon_dir = "assets/icon"
os.makedirs(icon_dir, exist_ok=True)

# 기본 아이콘 생성 및 저장
base_icon = create_base_icon(1024)
base_icon.save(f"{icon_dir}/app_icon.png", "PNG")
print(f"[OK] Base icon created: {icon_dir}/app_icon.png")

# Adaptive icon foreground 생성 및 저장
foreground_icon = create_foreground_icon(1024)
foreground_icon.save(f"{icon_dir}/app_icon_foreground.png", "PNG")
print(f"[OK] Foreground icon created: {icon_dir}/app_icon_foreground.png")

print("\nIcon generation completed!")
print("Next step: flutter pub run flutter_launcher_icons")
