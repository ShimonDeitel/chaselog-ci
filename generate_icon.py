from PIL import Image, ImageDraw

SIZE = 1024
BACKDROP = "#1A3A66"   # deep slate blue, matches CLTheme.accentDeep family
img = Image.new("RGB", (SIZE, SIZE), BACKDROP)
draw = ImageDraw.Draw(img)

cx = SIZE // 2

# Invoice card: a rounded rectangle, white, filling ~70% of the tile.
card_w = 560
card_h = 700
card_left = cx - card_w // 2
card_top = (SIZE - card_h) // 2 - 20
card_right = card_left + card_w
card_bottom = card_top + card_h

draw.rounded_rectangle(
    [card_left, card_top, card_right, card_bottom],
    radius=48, fill="#F3F5F8"
)

# Left-edge "aging heat" bar: green -> amber -> red gradient blocks, the
# app's signature visual motif (matches the InvoiceCard heat bar in-app).
bar_w = 34
bar_margin = 36
bar_top = card_top + bar_margin
bar_bottom = card_bottom - bar_margin
bar_left = card_left + bar_margin
bar_right = bar_left + bar_w

heat_colors = ["#34985E", "#E6AD2D", "#E15A3B", "#BA2722"]
segment_h = (bar_bottom - bar_top) // len(heat_colors)
for i, color in enumerate(heat_colors):
    y0 = bar_top + i * segment_h
    y1 = y0 + segment_h if i < len(heat_colors) - 1 else bar_bottom
    draw.rounded_rectangle([bar_left, y0, bar_right, y1], radius=12, fill=color)

# Text lines on the invoice (simple rectangles standing in for line items),
# offset to the right of the heat bar.
line_left = bar_right + 40
line_right = card_right - 48
line_h = 26
line_gap = 46
first_line_y = bar_top + 6

for i in range(6):
    y = first_line_y + i * line_gap
    width_frac = 1.0 if i % 3 != 2 else 0.55
    x_end = line_left + int((line_right - line_left) * width_frac)
    shade = "#2A3F57" if i % 3 != 2 else "#1A3A66"
    draw.rounded_rectangle([line_left, y, x_end, y + line_h], radius=13, fill=shade)

# Amber "past due" badge stamped in the bottom-right corner of the card.
badge_r = 92
badge_cx = card_right - 130
badge_cy = card_bottom - 150
draw.ellipse(
    [badge_cx - badge_r, badge_cy - badge_r, badge_cx + badge_r, badge_cy + badge_r],
    fill="#E15A3B"
)
# Exclamation mark inside the badge.
excl_w = 22
excl_top = badge_cy - 46
excl_bottom = badge_cy + 8
draw.rounded_rectangle(
    [badge_cx - excl_w // 2, excl_top, badge_cx + excl_w // 2, excl_bottom],
    radius=11, fill="#F3F5F8"
)
dot_r = 15
draw.ellipse(
    [badge_cx - dot_r, badge_cy + 26 - dot_r, badge_cx + dot_r, badge_cy + 26 + dot_r],
    fill="#F3F5F8"
)

img.save("/tmp/chaselog_icon_1024.png")
print("done")
