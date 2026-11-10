extends GutTest
## ADVENTURE PLUGINS — a plugin's words ([PluginText]): keys, the closed
## placeholder list, the engine's defaults; nothing in a text is evaluated.


func test_placeholders_from_the_list_are_filled_and_others_stay_words() -> void:
	assert_eq(PluginText.fill("{title}: seek {target}.", {"title": "The Bread Road", "target": "Refuge Harbor"}), "The Bread Road: seek Refuge Harbor.")
	assert_eq(PluginText.fill("{count} of {total}", {"count": 3, "total": 5}), "3 of 5", "numbers are written as numbers")
	assert_eq(PluginText.fill("No braces here.", {"title": "x"}), "No braces here.")
	assert_eq(PluginText.fill("{life} {unknown}", {"life": 26}), "26 {unknown}", "an unfilled brace stays as it is")
	assert_eq(PluginText.fill("{title}", {"title": "{foe}", "foe": "X"}).length() > 0, true)


func test_unknown_placeholders_are_found_and_plain_braces_are_not() -> void:
	assert_eq(PluginText.unknown_placeholders("Hello {hero}, {name} and {Weird} and {}."), ["name"] as Array[String])
	assert_eq(PluginText.unknown_placeholders("{a b} {x-y} {pledges}"), [] as Array[String], "not words: not placeholders")
	assert_eq(PluginText.unknown_placeholders("{zz} {zz}"), ["zz"] as Array[String], "named once")
	for name in PluginText.PLACEHOLDERS:
		assert_eq(PluginText.unknown_placeholders("{%s}" % name), [] as Array[String], name)


func test_a_plugin_says_its_own_words_else_the_engines_defaults() -> void:
	var words := {"quest.back": "Go back", "deck.line": "{count}/{total}"}
	assert_eq(PluginText.say(words, "quest.back"), "Go back")
	assert_eq(PluginText.say(words, "deck.line", {"count": 2, "total": 4}), "2/4")
	assert_eq(PluginText.say(words, "deck.empty"), PluginText.DEFAULTS["deck.empty"], "a sentence the plugin leaves out")
	assert_eq(PluginText.say(words, "no.such.key"), "")
	assert_eq(PluginText.say(words, ""), "")
	for key in PluginText.DEFAULTS:
		assert_eq(PluginText.unknown_placeholders(PluginText.DEFAULTS[key]), [] as Array[String], key)
