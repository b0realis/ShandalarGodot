extends GutHookScript
## The suite's calendar: a day in no season, so a card back is the skin's
## (or the plain one) on whatever day the suite runs. A test about the
## seasons sets [member GameSkin.season_date] itself and puts this back.

const NEUTRAL_DAY := {"month": 6, "day": 15}


func run() -> void:
	GameSkin.season_date = NEUTRAL_DAY.duplicate()
	# FRAME TIME IS REAL TIME in a test run (0.60.0): headless Godot
	# smooths the frame delta, and after a stretch of slow frames — a
	# loaded shard — fast frames count longer than they took, so a 0.4 s
	# timer could fire after 0.18 s and a test racing a wall-clock guard
	# lost (test_c13_G1_board, once in a gate).
	OS.delta_smoothing = false
