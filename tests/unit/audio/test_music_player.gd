## The web rule of MusicPlayer: music waits for the first click/key press because browsers keep audio suspended until then.
extends TestCase


func test_only_the_web_waits_and_only_until_the_first_press() -> void:
	assert_true(MusicPlayer.needs_gesture(true, false), "web, no press yet: wait")
	assert_false(MusicPlayer.needs_gesture(true, true), "web, a press was already seen: start now")
	assert_false(MusicPlayer.needs_gesture(false, false), "desktop: start now")
	assert_false(MusicPlayer.needs_gesture(false, true), "desktop: start now")


func test_presses_count_but_releases_and_motion_do_not() -> void:
	var down := InputEventMouseButton.new()
	down.pressed = true
	var up := InputEventMouseButton.new()
	up.pressed = false
	assert_true(MusicPlayer.is_user_gesture(down), "mouse button down")
	assert_false(MusicPlayer.is_user_gesture(up), "mouse button up")
	var key := InputEventKey.new()
	key.pressed = true
	assert_true(MusicPlayer.is_user_gesture(key), "key down")
	key = InputEventKey.new()
	key.pressed = false
	assert_false(MusicPlayer.is_user_gesture(key), "key up")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	assert_true(MusicPlayer.is_user_gesture(touch), "touch down")
	assert_false(MusicPlayer.is_user_gesture(InputEventMouseMotion.new()), "mouse motion")
