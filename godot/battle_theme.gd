extends RefCounted
## Combat shares the approved campaign palette and typography.
## Board art, faction colors and combat result colors remain semantic.
const Tokens=preload("res://ui_tokens.gd")
static func apply(ui):
 ui.mock_shell.apply_theme()
 var tooltip=Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_MD)
 ui.theme.set_stylebox("panel","TooltipPanel",tooltip)
 ui.theme.set_color("font_color","TooltipLabel",Tokens.INK)
 ui.theme.set_font_size("font_size","TooltipLabel",Tokens.FONT_SM)
