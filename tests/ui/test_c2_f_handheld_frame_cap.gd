extends GutTest
## THE FRAME CAP WHERE V-SYNC IS REFUSED ([GameDisplay], hunt r5-10,
## 2026-10-12). Where the graphics driver will not set V-Sync (Xvfb, a
## virtual machine, some remote desktops: "Could not set V-Sync mode")
## nothing paced the frames: the title screen idled at about 700 frames a
## second on eight cores. The window's V-Sync then reads DISABLED, and the
## boot caps the frame rate at the screen's refresh rate, 60 where that is
## unknown. A cap a launcher set (ArkOS's `--max-fps 30`) is kept, and a
## working V-Sync needs none.


func test_no_vsync_and_no_cap_is_capped_at_the_screens_rate() -> void:
	assert_eq(GameDisplay.frame_cap_from(0, DisplayServer.VSYNC_DISABLED, NAN), 60,
		"an unknown refresh rate (Xvfb reports NaN): 60")
	assert_eq(GameDisplay.frame_cap_from(0, DisplayServer.VSYNC_DISABLED, -1.0), 60)
	assert_eq(GameDisplay.frame_cap_from(0, DisplayServer.VSYNC_DISABLED, 144.0), 144)
	assert_eq(GameDisplay.frame_cap_from(0, DisplayServer.VSYNC_DISABLED, 59.94), 60)


func test_a_launchers_cap_is_kept() -> void:
	assert_eq(GameDisplay.frame_cap_from(30, DisplayServer.VSYNC_DISABLED, NAN), 30,
		"ArkOS's --max-fps 30")


func test_a_working_vsync_needs_no_cap() -> void:
	for mode in [DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_MAILBOX]:
		assert_eq(GameDisplay.frame_cap_from(0, mode, 60.0), 0, "V-Sync mode %d paces the frames" % mode)


func test_headless_the_cap_is_left_alone() -> void:
	var before := Engine.max_fps
	GameDisplay.apply_frame_cap()
	GameDisplay.apply_settings()
	assert_eq(Engine.max_fps, before, "no window, nothing to pace (the suite, the Deck Lab)")
