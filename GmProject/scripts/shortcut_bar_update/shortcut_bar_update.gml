/// shortcut_bar_update()

function shortcut_bar_update()
{
	if (shortcut_bar_state != shortcut_bar_state_prev)
	{
		ds_list_clear(shortcut_bar_list)
		
		if (shortcut_bar_state = "viewport" || shortcut_bar_state = "viewportcam")
		{
			shortcut_bar_add(null, e_mouse.CLICK_LEFT, "select")

			// Android (Fase 4, 2026-09-15, user report: the mouse-button/keyboard-modifier
			// hints below don't correspond to anything on a touchscreen - "Shift" for pan and
			// a scroll-wheel icon for zoom read as instructions for a gesture that doesn't
			// exist, which is what made the real pinch-to-zoom feel "stuck" when tried
			// against the wrong mental model). Text-only labels (no keybind, no mouse icon -
			// both null) describing the real gestures this session's touch work implemented:
			// 1-finger orbit (view_update.gml, proven since B10), 2-finger pan and pinch-zoom
			// (view_update.gml, Fase 4 2026-09-11), and the virtual joystick substituting
			// "walk navigation" (view_update.gml/view_draw.gml, Fase 4, predates this
			// session). "viewtimeline" (the V key toggle) is skipped outright on Android
			// rather than shown with no touch equivalent - there isn't one yet, a real gap,
			// not something to paper over with a misleading hint.
			if (platform_get() == e_platform.ANDROID)
			{
				shortcut_bar_add(null, null, "androidorbit")
				shortcut_bar_add(null, null, "androidpan")
				shortcut_bar_add(null, null, "androidzoom")
				shortcut_bar_add(null, null, "androidwalk")
			}
			else
			{
				if (shortcut_bar_state = "viewport")
					shortcut_bar_add(keybinds[e_keybind.CAM_VIEW_TIMELINE].keybind, null, "viewtimeline")

				shortcut_bar_add(null, e_mouse.DRAG_LEFT, "orbit")
				shortcut_bar_add(keybind_new(null, false, true, false), e_mouse.DRAG_LEFT, "pan")
				shortcut_bar_add(null, e_mouse.SCROLL, "zoom")
				shortcut_bar_add(null, e_mouse.DRAG_RIGHT, "walk")
			}
		}
		
		if (shortcut_bar_state = "cameramove" || shortcut_bar_state = "tlcameramove")
		{
			shortcut_bar_add(keybinds[e_keybind.CAM_FORWARD].keybind, null, "forward")
			shortcut_bar_add(keybinds[e_keybind.CAM_LEFT].keybind, null, "left")
			shortcut_bar_add(keybinds[e_keybind.CAM_BACK].keybind, null, "back")
			shortcut_bar_add(keybinds[e_keybind.CAM_RIGHT].keybind, null, "right")
			shortcut_bar_add(keybinds[e_keybind.CAM_ASCEND].keybind, null, "ascend")
			shortcut_bar_add(keybinds[e_keybind.CAM_DESCEND].keybind, null, "descend")
			shortcut_bar_add(keybinds[e_keybind.CAM_FAST].keybind, null, "faster")
			shortcut_bar_add(keybinds[e_keybind.CAM_SLOW].keybind, null, "slower")
			
			if (shortcut_bar_state = "tlcameramove")
			{
				shortcut_bar_add(keybinds[e_keybind.CAM_ROLL_FORWARD].keybind, null, "rollforward")
				shortcut_bar_add(keybinds[e_keybind.CAM_ROLL_BACK].keybind, null, "rollback")
				shortcut_bar_add(keybinds[e_keybind.CAM_ROLL_RESET].keybind, null, "rollreset")
			}
			else if (window_state != "world_import")
				shortcut_bar_add(keybinds[e_keybind.CAM_RESET].keybind, null, "reset")
		}
		
		if (string_contains(shortcut_bar_state, "timeline"))
		{
			if (shortcut_bar_state = "timelinekeyframes")
			{
				shortcut_bar_add(null, e_mouse.CLICK_LEFT, "tlkeyframeselect")
				shortcut_bar_add(keybind_new(null, false, true, false), e_mouse.CLICK_LEFT, "tlkeyframeselectadd")
				shortcut_bar_add(null, e_mouse.DRAG_LEFT, "tlkeyframeselectgroup")
				shortcut_bar_add(keybind_new(null, false, true, false), e_mouse.DRAG_LEFT, "tlkeyframeselectgroupadd")
				shortcut_bar_add(keybind_new(null, true, false, false), e_mouse.CLICK_LEFT, "tlkeyframedeselect")
				shortcut_bar_add(keybind_new(null, true, false, false), e_mouse.DRAG_LEFT, "tlkeyframedeselectgroup")
			}
			
			if (shortcut_bar_state = "timelinenames")
			{
				shortcut_bar_add(null, e_mouse.CLICK_LEFT, "tltimelineselect")
				shortcut_bar_add(keybind_new(null, false, true, false), e_mouse.CLICK_LEFT, "tltimelineselectadd")
				shortcut_bar_add(null, e_mouse.DRAG_LEFT, "tltimelineselectgroup")
				shortcut_bar_add(keybind_new(null, false, true, false), e_mouse.DRAG_LEFT, "tltimelineselectgroupadd")
				shortcut_bar_add(keybind_new(null, true, false, false), e_mouse.CLICK_LEFT, "tltimelinedeselect")
				shortcut_bar_add(keybind_new(null, true, false, false), e_mouse.DRAG_LEFT, "tltimelinedeselectgroup")
			}
			
			if (shortcut_bar_state = "timelinebar")
			{
				shortcut_bar_add(null, e_mouse.DRAG_LEFT, "tlsettime")
				shortcut_bar_add(null, e_mouse.DRAG_RIGHT, "tlsetregion")
			}
			
			shortcut_bar_add(null, e_mouse.SCROLL, "scrollvertical")
			shortcut_bar_add(keybind_new(null, false, true, false), e_mouse.SCROLL, "scrollhorizontal")
			shortcut_bar_add(keybind_new(null, true, false, false), e_mouse.SCROLL, "zoom")
		}
		
		if (shortcut_bar_state = "worldimport")
		{
			shortcut_bar_add(null, e_mouse.CLICK_LEFT, "worldcreateselection")
			shortcut_bar_add(null, e_mouse.DRAG_LEFT, "orbit")
			shortcut_bar_add([ null, false, false, true ], null, "worldignoreselection")
			shortcut_bar_add(keybind_new(null, false, true, false), e_mouse.DRAG_LEFT, "pan")
			shortcut_bar_add(null, e_mouse.SCROLL, "zoom")
			shortcut_bar_add(null, e_mouse.DRAG_RIGHT, "walk")
		}
		if (shortcut_bar_state = "worldimportselection")
		{
			shortcut_bar_add(null, e_mouse.CLICK_LEFT, "worldfinishselection")
			shortcut_bar_add(null, e_mouse.CLICK_RIGHT, "worldclearselection")
		}
	}
	
	shortcut_bar_state_prev = shortcut_bar_state
	shortcut_bar_state = ""
}
