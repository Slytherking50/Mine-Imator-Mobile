/// app_mouse_wrap(x, y, width, height)
/// @arg x
/// @arg y
/// @arg width
/// @arg height
/// @desc Wraps mouse position in a box

function app_mouse_wrap(xx, yy, w, h)
{
	if (!window_mouse_get_permission())
		return 0;

	// INSTRUMENTAL: no-op en Android (B10, KNOWN_ISSUES.md). Esta función usa
	// window_mouse_set() -> display_mouse_set() para "envolver" el cursor de un borde del
	// viewport al opuesto y así permitir arrastre de mouse sin límite en escritorio - en
	// touch no hay nada que envolver (el dedo ya está limitado por el borde físico de la
	// pantalla), y el intento de recentrar compite con la posición real reportada por
	// Android, igual que en draw_dragger.gml/camera_control_rotate.gml.
	if (platform_get() == e_platform.ANDROID)
		return 0;
	
	var setx, sety, size;
	setx = mouse_x
	sety = mouse_y
	size = 8
	
	if ((mouse_x - (size/2)) < xx)
	{
		setx = xx + w - size
		mouse_wrap_x--
	}
	
	if ((mouse_y - (size/2)) < yy)
	{
		sety = yy + h - size
		mouse_wrap_y--
	}
	
	// Wrap on right
	if (mouse_x > (xx + w - (size/2)) || (display_mouse_get_x() > (window_get_x() + window_get_width()) - (size/2)))
	{
		setx = xx + size
		mouse_wrap_x++
	}
	
	// Wrap on bottom
	if (mouse_y > (yy + h - (size/2)) || (display_mouse_get_y() > (window_get_y() + window_get_height()) - (size/2)))
	{
		sety = yy + size
		mouse_wrap_y++
	}
	
	if (setx != mouse_x || sety != mouse_y)
	{
		window_mouse_set(setx, sety)
		
		mouse_current_x = setx
		mouse_current_y = sety
	}
}
