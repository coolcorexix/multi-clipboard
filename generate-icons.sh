mkdir -p MultiClipboard.iconset

for size in 16 32 128 256 512; do
  rsvg-convert -w $size -h $size -o MultiClipboard.iconset/icon_${size}x${size}.png logo/Multi-clipboard.svg
  rsvg-convert -w $((size*2)) -h $((size*2)) -o MultiClipboard.iconset/icon_${size}x${size}@2x.png logo/Multi-clipboard.svg
done

# Add 1024x1024 for @2x of 512
rsvg-convert -w 1024 -h 1024 -o MultiClipboard.iconset/icon_512x512@2x.png logo/Multi-clipboard.svg