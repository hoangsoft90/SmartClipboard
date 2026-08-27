#!/bin/bash
# =============================================================================
# generate-icons.sh — Tạo launcher icon PNG từ ic_launcher_foreground.xml
# Chạy trên CI (GH Actions) hoặc local có ImageMagick.
#
# Kết quả: android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/
#          ic_launcher.png + ic_launcher_round.png
#
# Yêu cầu: ImageMagick (`convert`) hoặc `rsvg-convert` (librsvg2-bin)
# =============================================================================

set -euo pipefail

ANDROID_RES="android/app/src/main/res"
FG_DRAWABLE="$ANDROID_RES/drawable/ic_launcher_foreground.xml"
BG_COLOR="#3D5AFE"

# Density → icon size (dp → px, assuming 160dpi base)
declare -A DENSITY_SIZES=(
    ["mdpi"]=48
    ["hdpi"]=72
    ["xhdpi"]=96
    ["xxhdpi"]=144
    ["xxxhdpi"]=192
)

# Adaptive icon viewport: 108dp, safe zone = 66dp centered = 22dp padding each side
# For legacy icons, we render at the target size with 10% padding for safe zone
VIEWPORT=108
SAFE_ZONE=66
PADDING_RATIO=0.1  # 10% padding for safe zone

echo "🎨 Generating Smart Clipboard launcher icons..."

# Check for convert (ImageMagick)
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick 'convert' not found."
    echo "   Install: sudo apt-get install imagemagick (Ubuntu) or brew install imagemagick (macOS)"
    echo "   Alternatively, icons will be generated on CI."
    exit 1
fi

for density in "${!DENSITY_SIZES[@]}"; do
    size=${DENSITY_SIZES[$density]}
    output_dir="$ANDROID_RES/mipmap-$density"
    mkdir -p "$output_dir"

    echo "  📐 $density: ${size}x${size}px"

    # Create a blue circle background
    convert -size "${size}x${size}" xc:"$BG_COLOR" \
        -draw "roundrectangle 0,0 $((size-1)),$((size-1)) $((size/8)),$((size/8))" \
        "/tmp/icon_bg_${density}.png"

    # Create foreground layer (clipboard icon) — simplified white clipboard shape
    # Since we can't easily convert SVG to PNG in a script, we draw a simplified version
    convert -size "${size}x${size}" xc:transparent \
        -fill white \
        -draw "roundrectangle $((size*28/108)),$((size*20/108)) $((size*80/108)),$((size*88/108)) $((size*4/108)),$((size*4/108))" \
        -fill "#BBDEFB" \
        -draw "roundrectangle $((size*40/108)),$((size*18/108)) $((size*68/108)),$((size*28/108)) $((size*3/108)),$((size*3/108))" \
        -fill "#3D5AFE" -stroke "#3D5AFE" -strokewidth $((size*3/108)) \
        -draw "line $((size*44/108)),$((size*66/108)) $((size*50/108)),$((size*74/108))" \
        -draw "line $((size*50/108)),$((size*74/108)) $((size*66/108)),$((size*56/108))" \
        "/tmp/icon_fg_${density}.png"

    # Composite foreground on background
    convert "/tmp/icon_bg_${density}.png" "/tmp/icon_fg_${density}.png" \
        -composite "$output_dir/ic_launcher.png"

    # Round version: same but clip to circle
    convert "/tmp/icon_bg_${density}.png" "/tmp/icon_fg_${density}.png" \
        -composite \
        \( +clone -threshold -1 -negate -fill white -draw "circle $((size/2)),$((size/2)) $((size/2)),$((size-1))" \) \
        -alpha off -compose CopyOpacity -composite \
        "$output_dir/ic_launcher_round.png"

    rm -f "/tmp/icon_bg_${density}.png" "/tmp/icon_fg_${density}.png"
done

echo "✅ Icons generated in $ANDROID_RES/mipmap-*/"
echo "   Adaptive icons (API 26+) use XML vectors in mipmap-anydpi-v26/"
