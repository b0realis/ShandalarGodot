class_name PluginText
extends RefCounted
## ADVENTURE PLUGINS — a plugin's words (`text.json`): every sentence,
## title and button by key, filled with `{placeholders}` from one closed
## list ([constant PLACEHOLDERS], the same list `schema_v1.json` gives the
## authoring tool). A placeholder outside the list refuses the plugin
## ([method unknown_placeholders]); nothing in a text is ever evaluated.
##
## The engine's own sentences ([constant DEFAULTS]) — a deck problem, a
## reward pane's buttons — are said in plain words when a plugin leaves
## them out; any of them a plugin's text.json names replaces the default.

const PLACEHOLDERS: Array[String] = ["pledges", "quests_total", "target", "town", "title", "foe", "life",
	"count", "total", "required", "percent", "left", "color", "cards", "hero", "region"]

## The keys the interpreter speaks with, and what it says without them.
const DEFAULTS := {
	"region.subtitle": "",
	"voyage.out": "",
	"voyage.home": "",
	"port.sail_out": "Sail to the island",
	"port.sail_home": "Sail home",
	"port.leave": "Leave",
	"castle.leave": "Leave",
	"guide.petition": "{title}: hear the petition at {target}.",
	"guide.duel": "{title}: return to {target} and defeat {foe}.",
	"guide.done": "{title}: done.",
	"quest.reward_line": "",
	"quest.retry_line": "No ante is staked. A loss or draw lets you retry. Enemy life: {life}.",
	"quest.secure": "This quest is done.",
	"quest.accept": "Accept",
	"quest.fight": "Duel: {foe}",
	"quest.back": "Return",
	"quest.done_log": "{title} completed.",
	"rewards.choose": "Choose reward cards ({count})",
	"rewards.claim": "Collect waiting cards ({count})",
	"rewards.title": "Rewards",
	"rewards.intro": "Choose one bundle for each reward owed. Cards that do not fit your bag are kept safely.",
	"rewards.offer": "{color}: {cards}",
	"rewards.rules": "Copy limits and bans apply.",
	"rewards.later": "Choose later",
	"rewards.pending_line": "{count} reward cards are waiting; make room in your bag to collect them.",
	"rewards.collected": "Collected {count} cards. {left} remain safely held for you.",
	"deck.no_pack": "Enable this adventure's card packs in Options to begin this battle.",
	"deck.empty": "Choose a deck in a town's deck builder before beginning this battle.",
	"deck.unknown": "Your deck contains unavailable cards. Enable their packs or edit the deck in town.",
	"duel.leave_question": "Return to the main menu? This unfinished battle is not saved. Your adventure resumes before the challenge.",
	"duel.over": "The battle is over. You may prepare and try again; no cards were staked.",
	"duel.won_reward": "",
	"duel.won_again": "",
	"duel.won_log": "Defeated {foe}.",
	"duel.lost_log": "Lost to {foe}.",
	"duel.title": "{region}",
	"duel.victory": "Victory",
	"duel.ended": "The battle ends",
	"duel.continue": "Continue",
	"target.none": "the island",
	"task.petition": "Hear the petition at {town}.",
	"task.duel": "Defeat {foe} at {target}.",
	"task.done": "Done at {town}.",
	"talk.will_you": "Will you...",
}


## [param key]'s words in [param words] (a plugin's text.json), else the
## engine's default, filled with [param values]; "" for an unknown key.
static func say(words: Dictionary, key: String, values := {}) -> String:
	if key == "": return ""
	var template: Variant = words.get(key, DEFAULTS.get(key, ""))
	return fill(String(template), values)


## [param template] with each `{name}` of [constant PLACEHOLDERS] that
## [param values] holds replaced by its value; other braces stay as they are.
static func fill(template: String, values: Dictionary) -> String:
	if not "{" in template: return template
	var out := template
	for name in values:
		out = out.replace("{" + String(name) + "}", str(values[name]))
	return out


## Each `{word}` in [param template] that is not a placeholder of the list.
static func unknown_placeholders(template: String) -> Array[String]:
	var out: Array[String] = []
	var at := template.find("{")
	while at >= 0:
		var close := template.find("}", at)
		if close < 0: break
		var word := template.substr(at + 1, close - at - 1)
		if _is_word(word) and not word in PLACEHOLDERS and not word in out: out.append(word)
		at = template.find("{", at + 1)
	return out


static func _is_word(word: String) -> bool:
	if word.is_empty() or word.length() > 40: return false
	for i in word.length():
		var c := word.unicode_at(i)
		if not ((c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95): return false
	return true
