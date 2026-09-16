#include "Generated/GmlFunc.hpp"

#include "AppHandler.hpp"
#include "AppWindow.hpp"

namespace CppProject
{
	BoolType keyboard_check_direct(IntType key)
	{
	#ifdef OS_WINDOWS
		if (key == vk_ralt || key == vk_lalt ||
			key == vk_rcontrol || key == vk_lcontrol ||
			key == vk_rshift || key == vk_lshift)
			return App->keyStateMap[key].down;
		else
	#endif
		return App->keyStateMap[key].down;
	}

	BoolType keyboard_check_pressed(IntType key)
	{
		return (App->keyStateMap[key].pressed);
	}

	BoolType keyboard_check_released(IntType key)
	{
		return (!App->keyStateMap[key].released);
	}

	BoolType keyboard_check(IntType key)
	{
		return App->keyStateMap[key].down;
	}

	void keyboard_clear(IntType key)
	{
		App->keyStateMap[key] = { false, false, false };
	}

	BoolType mouse_check_button(IntType button)
	{
		return AppWin->mouseDown[button];
	}

	BoolType mouse_clear(IntType button)
	{
		AppWin->mouseDown[button] = false;
		return false;
	}

	BoolType mouse_wheel_down()
	{
		return (AppWin->mouseWheel < 0);
	}

	BoolType mouse_wheel_up()
	{
		return (AppWin->mouseWheel > 0);
	}

	// Fase 4 / Trampa 1, KNOWN_ISSUES.md B10 - pinch/pan gesture state populated by
	// AppWindow::event() from QTouchEvent (Android only; touchCount stays 0 everywhere else,
	// so these all read back as 0 on desktop with no platform check needed here). Divided by
	// App->scale to convert from the physical/widget pixels QTouchEvent reports into the same
	// logical GML units window_get_width()/mouse_x already use (AppHandler.cpp,
	// WindowFunc.cpp) - not pre-scaled at the point AppWindow::event() records them, since
	// that's before any per-frame processing and scale can only be read from App from Gml/*
	// code, not AppWindow.cpp itself.
	IntType touch_count()
	{
		return AppWin->touchCount;
	}

	RealType touch_pinch_delta()
	{
		return AppWin->touchPinchDelta / App->scale;
	}

	RealType touch_pan_dx()
	{
		return AppWin->touchPanDx / App->scale;
	}

	RealType touch_pan_dy()
	{
		return AppWin->touchPanDy / App->scale;
	}

	// Raw per-finger slots (0 or 1) - lets GML tell fingers apart across frames, for gestures
	// where two fingers need to do two INDEPENDENT things at once (virtual joystick held with
	// one finger while the other rotates the camera) rather than one aggregate quantity like
	// the pinch/pan above. slot is clamped so an out-of-range index reads back as slot 0
	// instead of undefined behaviour.
	static int ClampTouchSlot(IntType slot)
	{
		if (slot < 0)
			return 0;
		if (slot > AppWindow::TouchSlotCount - 1)
			return AppWindow::TouchSlotCount - 1;
		return (int)slot;
	}

	BoolType touch_point_active(IntType slot)
	{
		return AppWin->touchSlotActive[ClampTouchSlot(slot)];
	}

	RealType touch_point_x(IntType slot)
	{
		return AppWin->touchSlotPos[ClampTouchSlot(slot)].x() / App->scale;
	}

	RealType touch_point_y(IntType slot)
	{
		return AppWin->touchSlotPos[ClampTouchSlot(slot)].y() / App->scale;
	}
}