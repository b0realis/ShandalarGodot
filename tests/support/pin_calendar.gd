extends GutHookScript
## The suite's calendar: a day in no season, so a card back is the skin's
## (or the plain one) on whatever day the suite runs. A test about the
## seasons sets [member GameSkin.season_date] itself and puts this back.

const NEUTRAL_DAY := {"month": 6, "day": 15}


func run() -> void:
	GameSkin.season_date = NEUTRAL_DAY.duplicate()
