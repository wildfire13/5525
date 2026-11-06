extends RefCounted
## Combat shares the approved campaign palette and typography.
## Board art, faction colors and combat result colors remain semantic.
static func apply(ui):
 ui.mock_shell.apply_theme()
 var ink=ui.mock_shell.INK
 var paper=ui.mock_shell.PAPER
 var green=ui.mock_shell.GREEN
 var tooltip=ui.mock_shell.style(paper)
 tooltip.set_content_margin_all(12)
 ui.theme.set_stylebox("panel","TooltipPanel",tooltip)
 ui.theme.set_color("font_color","TooltipLabel",ink)
 ui.theme.set_font_size("font_size","TooltipLabel",18)
 var focus=StyleBoxFlat.new()
 focus.bg_color=Color.TRANSPARENT;focus.border_color=green
 focus.set_border_width_all(2);focus.set_corner_radius_all(3)
 for kind in ["Button","OptionButton","CheckButton","ItemList","TabBar"]:
  ui.theme.set_stylebox("focus",kind,focus)
 for kind in ["Button","OptionButton"]:
  for state in ["normal","hover","pressed","disabled"]:
   var fill=Color("#e0e8dd") if state in ["hover","pressed"] else paper
   var panel=ui.mock_shell.style(fill)
   panel.content_margin_left=12;panel.content_margin_right=12
   panel.content_margin_top=8;panel.content_margin_bottom=8
   ui.theme.set_stylebox(state,kind,panel)
 ui.menu.add_theme_stylebox_override("panel",ui.mock_shell.style())
