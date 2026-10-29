extends GutTest
## Needs the imported 1997 skin.
## THE PANES' PICTURES WARMED (the smoothness pass, 0.50.66): two seconds
## after the world opens, the pictures the first hero's pane (F5), Wizards
## tab (F6) and map (M) would read and make on the thread that draws are
## decoded and made on worker threads ([SkinWarmer], [PaneWarmer]) — and
## what is made from the files is pixel for pixel what the panes made from
## the pictures read back off the card.

const SAVES := "user://adventure_tests_c20_m4_warmed"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await get_tree().process_frame
	screen.set_process(false)
	# Every skull's step shown, so the hall bleeds one of them too.
	var rows := WorldStatus.wizard_rows(screen.player)
	assert_false(rows.is_empty(), "control: the wizards' record")
	_forget()


func after_each() -> void:
	SkinWarmer.forced = -1
	_forget()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## The panes' own made pictures forgotten (test surgery on their caches).
func _forget() -> void:
	WizardsPicture._bled.clear()
	HeroStats._trims.clear()
	WorldMap._sprites.clear()


## The warm-up run to its end, now.
func _warm() -> void:
	SkinWarmer.forced = 1
	screen._warm_the_panes()
	SkinWarmer.finish_all()
	PaneWarmer.finish_all()


func _same(a: Image, b: Image) -> bool:
	if a == null or b == null or a.get_size() != b.get_size():
		return false
	var x := a.duplicate() as Image
	var y := b.duplicate() as Image
	x.convert(Image.FORMAT_RGBA8)
	y.convert(Image.FORMAT_RGBA8)
	return x.get_data() == y.get_data()


func test_nothing_is_warmed_where_no_worker_may_run() -> void:
	SkinWarmer.forced = 0
	screen._warm_the_panes()
	assert_eq(PaneWarmer.working(), 0, "headless, the web: made on demand, as before")


func test_the_panes_pictures_are_kept_before_they_open() -> void:
	var rows := WorldStatus.wizard_rows(screen.player)
	var keyed := WizardsPicture.pictures_for(rows)
	assert_gt(keyed.size(), 4, "control: the standing wizards' pictures")
	for key in keyed:
		assert_false(WizardsPicture.bled_kept(GameSkin.texture(key)), "control: %s not bled yet" % key)
	_warm()
	for key in WorldScreen.PANE_PICTURES:
		assert_true(GameSkin.picture_job(key).is_empty(), "%s kept by the warm-up" % key)
	for key in keyed:
		assert_true(WizardsPicture.bled_kept(GameSkin.texture(key)), "%s bled before F6" % key)
	for ref in HeroStats.castle_frames():
		assert_true(HeroStats.trim_kept(HeroStats.trim_key(String(ref[0]), int(ref[1]))),
			"castle %s trimmed before F5" % [ref])
	var sheet := GameSkin.texture("map_buttons")
	for place in WorldMap.sprite_places():
		assert_true(WorldMap.sprite_kept(sheet, place), "the map's cut %s made before M" % place)


func test_what_is_made_from_the_files_is_what_the_read_back_made() -> void:
	_warm()
	# The hall's bled pictures: the warm-up's against a bleed of the texture
	# read back, as WizardsPicture.picture made them.
	for key in WizardsPicture.pictures_for(WorldStatus.wizard_rows(screen.player)):
		var source := GameSkin.texture(key)
		var warmed := WizardsPicture.picture(key)
		var read := WizardsPicture.bleed(source.get_image())
		assert_true(_same(warmed.get_image(), read), "%s: the same pixels" % key)
		assert_eq(warmed.get_size(), source.get_size(), "%s: drawn at its slot's size" % key)
	# The castles' trims.
	var art := WorldArt.new()
	for ref in HeroStats.castle_frames():
		var key := String(ref[0])
		var sheet := art.texture(key)
		var region := art.frame_rect(key, int(ref[1]))
		var read := HeroStats.trimmed(sheet.get_image(), region, GameSkin.scale_of(sheet))
		assert_eq(HeroStats._trims[HeroStats.trim_key(key, int(ref[1]))], read, "castle %s: the same trim" % [ref])
	# The map's cuts.
	var buttons := GameSkin.texture("map_buttons")
	for place in WorldMap.sprite_places():
		var warmed := WorldMap.sprite(buttons, place)
		var scale := GameSkin.scale_of(buttons)
		var read := WorldMap.sprite_image(GameSkin.original(buttons), buttons.get_image() if scale > 1 else null,
			scale, place)
		assert_true(_same(warmed.get_image(), read), "the map's cut %s: the same pixels" % place)


func test_a_pane_opened_while_warming_still_draws() -> void:
	SkinWarmer.forced = 1
	screen._warm_the_panes()
	# F6 at once, the warm-up still under way: made on demand as before.
	screen.toggle_wizards()
	await get_tree().process_frame
	assert_true(screen.hud.hero_shown(), "the Wizards tab opens")
	SkinWarmer.finish_all()
	PaneWarmer.finish_all()
	for key in WizardsPicture.pictures_for(WorldStatus.wizard_rows(screen.player)):
		assert_true(WizardsPicture.bled_kept(GameSkin.texture(key)), "%s: one bled picture either way" % key)
