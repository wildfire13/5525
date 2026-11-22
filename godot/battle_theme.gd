extends RefCounted
## Combat shares the approved campaign palette and typography.
## Board art, faction colors and combat result colors remain semantic.
static func apply(ui):
 ui.mock_shell.apply_theme()
 var ink=ui.mock_shell.INK
 var paper=ui.mock_shell.PAPER
 var tooltip=ui.mock_shell.surface_style(paper)
 tooltip.set_content_margin_all(12)
 ui.theme.set_stylebox("panel","TooltipPanel",tooltip)
 ui.theme.set_color("font_color","TooltipLabel",ink)
 ui.theme.set_font_size("font_size","TooltipLabel",18)
