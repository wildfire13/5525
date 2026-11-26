extends RefCounted
## Single source of truth for Crisp Architectural Stone & Deep Pine Emerald UI
## tokens, typography, spacing, control sizing, elevation, and StyleBox builders.

# Palette: Surfaces (Crisp gallery stone-white so painted backgrounds pop)
const SURFACE := Color("#f8faf8")
const SURFACE_ALT := Color("#eef3ef")
const SURFACE_BACKDROP := Color("#e6ede8")
const SURFACE_ALPHA := 0.90
const NESTED_SURFACE_ALPHA := 0.12

# Palette: Text / Ink (High WCAG AA+ contrast)
const INK := Color("#16231e")
const MUTED_INK := Color("#4c5e56")
const INK_INVERSE := Color("#f8faf8")
const INK_INVERSE_MUTED := Color("#c7d6d0")

# Palette: Borders & Focus
const BORDER := Color("#c2cdc6")
const BORDER_ACCENT := Color("#1f5c45")
const FOCUS := Color("#0f766e")

# Palette: Accent & Button Roles
const ACCENT := Color("#1d4d3c")
const ACTION := Color("#1b6647")
const ACTION_HOVER := Color("#237d57")
const ACTION_PRESSED := Color("#134c34")
const SELECTED := Color("#d7ece2")
const SELECTED_HOVER := Color("#c5e3d5")
const SELECTED_PRESSED := Color("#aed6c4")
const DEST := Color("#fde68a")
const DEST_HOVER := Color("#fcd34d")
const DEST_PRESSED := Color("#f0be3c")
const BTN_HOVER := Color("#e5efe9")
const BTN_PRESSED := Color("#cfe0d7")
const BTN_DISABLED := Color("#e3e8e5")

# Palette: Semantic Status
const POSITIVE := Color("#1b7a4c")
const DANGER := Color("#b83227")
const WARN := Color("#b4690e")

# Palette: Dark Overlays, Notices & Outlines
const OVERLAY_DARK := Color("#0f1a18")
const OVERLAY_PANEL := Color(0.059, 0.102, 0.094, 0.94)
const OVERLAY_BORDER := Color("#7ea398")
const NOTICE_BG := Color("#142b26f2")
const NOTICE_BORDER := Color("#5eead4")
const BACKDROP_DARK := Color("#141c1a")
const TEXT_OUTLINE := Color("#16231e")

# Palette: Elevation Shadows
const SHADOW_SOFT := Color(0.06, 0.13, 0.10, 0.10)
const SHADOW_ELEVATED := Color(0.05, 0.14, 0.10, 0.20)

# Typography (5-step scale)
const FONT_XS := 14
const FONT_SM := 16
const FONT_BODY := 20
const FONT_HEADING := 24
const FONT_DISPLAY := 28

# Geometry & Spacing (4px base)
const RADIUS_SM := 6
const RADIUS_LG := 10
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
	s.anti_aliasing = true
	return s


static func elevate(
	s: StyleBoxFlat,
	shadow_size: int = 4,
	y_offset: float = 2.0,
	shadow_color: Color = SHADOW_SOFT
) -> StyleBoxFlat:
	s.shadow_size = shadow_size
	s.shadow_offset = Vector2(0.0, y_offset)
	s.shadow_color = shadow_color
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
