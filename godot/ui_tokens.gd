extends RefCounted
## Single source of truth for Warm Paper & Forest Green UI tokens, typography,
## spacing, control sizing, and shared StyleBox builders.

# Palette: Surfaces
const SURFACE := Color("#faf9f5")
const SURFACE_ALT := Color("#f2f0e8")
const SURFACE_BACKDROP := Color("#eeede7")
const SURFACE_ALPHA := 0.90
const NESTED_SURFACE_ALPHA := 0.12

# Palette: Text / Ink
const INK := Color("#29332f")
const MUTED_INK := Color("#606960")
const INK_INVERSE := Color("#faf9f5")
const INK_INVERSE_MUTED := Color("#cbd2d8")

# Palette: Borders & Focus
const BORDER := Color("#cbd0c8")
const BORDER_ACCENT := Color("#345c4e")
const FOCUS := Color("#397794")

# Palette: Accent & Button Roles
const ACCENT := Color("#345c4e")
const ACTION := Color("#236044")
const ACTION_HOVER := Color("#2f7652")
const ACTION_PRESSED := Color("#194a34")
const SELECTED := Color("#dfe8dc")
const SELECTED_HOVER := Color("#d2e0d3")
const SELECTED_PRESSED := Color("#b7cebf")
const DEST := Color("#fff0ba")
const DEST_HOVER := Color("#f7e293")
const DEST_PRESSED := Color("#e8cb79")
const BTN_HOVER := Color("#e0e8dd")
const BTN_PRESSED := Color("#c6d6c9")
const BTN_DISABLED := Color("#e4e6e1")

# Palette: Semantic Status
const POSITIVE := Color("#28714c")
const DANGER := Color("#a84432")
const WARN := Color("#b7852b")

# Palette: Dark Overlays, Notices & Outlines
const OVERLAY_DARK := Color("#111820")
const OVERLAY_PANEL := Color(0.067, 0.094, 0.125, 0.94)
const OVERLAY_BORDER := Color("#9da7b0")
const NOTICE_BG := Color("#203c3bf2")
const NOTICE_BORDER := Color("#94c9b8")
const BACKDROP_DARK := Color("#191d23")
const TEXT_OUTLINE := Color("#283128")

# Typography (5-step scale)
const FONT_XS := 14
const FONT_SM := 16
const FONT_BODY := 20
const FONT_HEADING := 24
const FONT_DISPLAY := 28

# Geometry & Spacing (4px base)
const RADIUS_SM := 4
const RADIUS_LG := 8
const BORDER_WIDTH := 1
const BORDER_WIDTH_EMPHASIS := 2
const SPACE_NONE := 0
const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 12
const SPACE_LG := 16
const SPACE_XL := 24

# Control & Window Bar Sizes
const WINDOW_BAR_HEIGHT := 44
const CLOSE_BUTTON_SIZE := 36
const BUTTON_SM := 36
const BUTTON_MD := 44
const BUTTON_LG := 56
const BUTTON_W_SM := 120
const BUTTON_W_MD := 168
const BUTTON_W_LG := 224


static func box(
	fill: Color = SURFACE,
	border: Color = BORDER,
	radius: int = RADIUS_SM,
	margin: int = SPACE_SM,
	border_width: int = BORDER_WIDTH
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func surface_box(
	fill: Color = SURFACE,
	nested: bool = false,
	radius: int = RADIUS_SM,
	margin: int = SPACE_SM
) -> StyleBoxFlat:
	var s := box(fill, BORDER, radius, margin, BORDER_WIDTH)
	s.bg_color.a = NESTED_SURFACE_ALPHA if nested else SURFACE_ALPHA
	return s


static func window_bar_box() -> StyleBoxFlat:
	var s := box(ACCENT, BORDER_ACCENT, RADIUS_SM, SPACE_XS, BORDER_WIDTH)
	s.content_margin_left = SPACE_MD
	s.content_margin_right = SPACE_MD
	s.content_margin_top = SPACE_XS
	s.content_margin_bottom = SPACE_XS
	return s


static func apply_button_size(
	button: Control,
	height: int = BUTTON_MD,
	shrink_v: bool = true,
	min_width: int = 0
) -> void:
	if min_width > 0:
		button.custom_minimum_size.x = min_width
	button.custom_minimum_size.y = height
	if shrink_v:
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER


static func apply_button_preset(
	button: Control,
	preset: String,
	shrink_v: bool = true
) -> void:
	match preset:
		"sm":
			apply_button_size(button, BUTTON_MD, shrink_v, BUTTON_W_SM)
		"md":
			apply_button_size(button, BUTTON_MD, shrink_v, BUTTON_W_MD)
		"lg":
			apply_button_size(button, BUTTON_LG, shrink_v, BUTTON_W_LG)
		"md_lg":
			apply_button_size(button, BUTTON_LG, shrink_v, BUTTON_W_MD)
		"sm_lg":
			apply_button_size(button, BUTTON_LG, shrink_v, BUTTON_W_SM)
		"sm_compact":
			apply_button_size(button, BUTTON_SM, shrink_v, BUTTON_W_SM)
		"lg_md":
			apply_button_size(button, BUTTON_MD, shrink_v, BUTTON_W_LG)
		"":
			return
		_:
			push_warning("Unknown button preset: " + preset)
