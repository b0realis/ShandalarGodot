extends GutTest
## EVERY TOOLTIP ON OPAQUE PAPER (the owner, 2026-11-03: "Fix tooltip see
## through over the playmat"). The engine's own tooltip panel let the
## Embark's playmat, its buttons and the pack list read through a pack's
## hint; [method UiChrome.watch_tooltips] now puts [method
## UiChrome.tooltip_paper] on every tooltip, stock or custom.


func test_the_tooltip_panel_is_opaque_paper() -> void:
	UiChrome.watch_tooltips(get_tree())
	var panel := ThemeDB.get_default_theme().get_stylebox("panel", "TooltipPanel") as StyleBoxFlat
	assert_not_null(panel, "a flat panel")
	assert_gte(panel.bg_color.a, 0.95, "nothing reads through it")
	assert_gt(panel.border_width_top, 0, "a rule round it")


func test_a_control_asking_for_the_tooltip_panel_gets_the_paper() -> void:
	UiChrome.watch_tooltips(get_tree())
	var host := Control.new()
	add_child_autofree(host)
	var panel := host.get_theme_stylebox("panel", "TooltipPanel") as StyleBoxFlat
	assert_not_null(panel, "custom tooltips read the same panel")
	assert_gte(panel.bg_color.a, 0.95)


func test_embarks_hints_wear_the_same_paper() -> void:
	var paper := UiChrome.tooltip_paper()
	assert_eq(paper.bg_color, Color(0.035, 0.03, 0.025, 0.98), "the Embark's card-rule paper, now shared")
	assert_eq(paper.content_margin_left, 10.0)
	assert_eq(paper.content_margin_top, 8.0)
