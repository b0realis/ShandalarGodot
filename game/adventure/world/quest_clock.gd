class_name QuestClock
extends Control
## THE QUEST'S CLOCK on the quest pane — 1.3's `DrawQuestDeadlineClock`
## (adventureWorldUi.c 1663), three layers of 67 × 88 drawn at one place
## while a quest is under way: the pendulum clock (`Clocknew.spr`, frame
## `clock & 7` — it swings as the hero walks), the sun and the moon crossing
## (`Sunmoon.spr`, frame `(deadline − now) % 14`) and the days left in its
## window (`Daysnew.spr`, the numeral `(deadline − now) / 16 + 1`). Nothing
## without a quest, or without the 1997 sheets.
##
## Beside it, THE NEXT DUEL'S GIFTS (`Worlds.spr` 56–59), an icon for each
## part of the next duel's line ([method WorldStatus.next_duel_line]), as
## 1997 drew one per part (adventureWorldUi.c 1495–1548): the lives carried
## from the last duel (the skull — 1997 drew it for any carried lives, more
## or fewer), the gift's extra lives (the ankh), the first move (the
## dagger), a card to start with in play. [Ours: side by side, where 1997
## drew the three lives-and-move icons on one spot, the last over the
## others.]

const FRAME := Vector2(67, 88)
const SHOWN := 0.7

var player: AdventurePlayer
var _art := WorldArt.new()


func _init() -> void:
	name = "QuestClock"
	custom_minimum_size = FRAME * SHOWN
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Whether the clock has anything to show.
func wanted() -> bool:
	return player != null and Quests.has_quest(player) and _art.texture("quest_clock") != null


func _draw() -> void:
	if not wanted():
		return
	var left := int(player.quest.get("deadline", 0)) - player.quest_timer
	var layers := [["quest_clock", player.monster_timer & 7], ["quest_sunmoon", posmod(left, 14)],
		["quest_days", clampi(left / WorldStatus.DAY + 1, 0, 5)]]
	for layer in layers:
		var sheet := _art.texture(String(layer[0]))
		if sheet != null:
			draw_texture_rect_region(sheet, Rect2(Vector2.ZERO, FRAME * SHOWN),
				Rect2(_art.frame_rect(String(layer[0]), int(layer[1])).position, FRAME))


## THE NEXT DUEL'S GIFT ICONS for [param hero]: `[[frame, words]]`, in the
## line's order — 59 the lives carried (more or fewer), 58 the gift's extra
## lives, 57 the first move, 56 a card in play.
static func gifts(hero: AdventurePlayer) -> Array[Array]:
	var out: Array[Array] = []
	if hero == null:
		return out
	var carried := hero.next_duel_life_carried
	if carried > 0:
		out.append([59, "Next duel: %d more lives, carried from the last" % carried])
	elif carried < 0:
		out.append([59, "Next duel: %d fewer lives, carried from the last" % -carried])
	if hero.next_duel_life > 0:
		out.append([58, "Next duel: %d more lives" % hero.next_duel_life])
	elif hero.next_duel_life < 0:
		out.append([58, "Next duel: %d fewer lives" % -hero.next_duel_life])
	if hero.next_duel_first_move:
		out.append([57, "Next duel: the first move"])
	if hero.next_duel_card != "":
		out.append([56, "Next duel: %s in play" % hero.next_duel_card])
	return out
