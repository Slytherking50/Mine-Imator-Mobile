/// popup_saveas_draw()
/// @desc Settings for saving a new project.

function popup_saveas_draw()
{
	var issue = false;
	
	if (popup.folder = "" || directory_exists_lib(setting_project_folder + popup.folder))
		issue = true
	
	// Project name
	tab_control_textfield(true)
	if (draw_textfield("newprojectname", dx, dy, dw, ui_touch_textfield_height, popup.tbx_name, null, text_get("saveascopy", project_name), "top") || issue)
	{
		popup.folder = filename_get_valid(popup.tbx_name.text)
		
		if (popup.folder = "")
			popup.folder = text_get("saveascopy", project_name)
		
		popup.folder = filename_name(filename_get_unique(setting_project_folder + popup.folder))
	}
	tab_next()
	
	// Project author
	tab_control_textfield(true)
	if (draw_textfield("newprojectauthor", dx, dy, dw, ui_touch_textfield_height, popup.tbx_author, null, "", "top"))
	{
		popup.author = popup.tbx_author.text
	}
	tab_next()
	
	// Project description
	tab_control_textfield(true, 76)
	if (draw_textfield("newprojectdescription", dx, dy, dw, 76, popup.tbx_description, null, "", "top"))
	{
		popup.description = popup.tbx_description.text
	}
	tab_next()
	
	// Project location
	var directory = "../" + directory_name(setting_project_folder) + string_remove_newline(popup.folder);
	
	tab_control(40)
	draw_label_value(dx, dy, dw - 28, 40, text_get("newprojectlocation"), directory, true)
	// "Change folder" reuses the save dialog to pick a FOLDER (take the containing directory
	// of whatever file the user "saves" to) - a desktop file-dialog trick, not something
	// Android's SAF document picker can do (it hands back one picked document, not a folder
	// path Mine-imator's own file_find/etc. can read/write against directly - SAF's real
	// folder equivalent, ACTION_OPEN_DOCUMENT_TREE, is a tree of opaque document ids, not
	// filesystem paths, and would need every project-folder-reading call site rewritten to
	// match - out of scope here, tracked as its own gap). Hidden on Android rather than left
	// live and silently corrupting setting_project_folder into a URI the rest of the app can't
	// use (2026-09-15, alongside the get_open_filename_ext/Buffer::Save content:// URI fixes).
	if (platform_get() != e_platform.ANDROID && draw_button_icon("newprojectchangefolder", dx + dw - 24, dy + 8, 24, 24, false, icons.FOLDER_EDIT, null, null, "tooltipchangefolder"))
	{
		var fn = file_dialog_save_project(popup.folder)
		if (fn != "")
		{
			popup.folder = filename_name(fn)
			action_setting_project_folder(filename_path(fn))
		}
	}
	tab_next()
	
	// Save
	tab_control_button_label()
	if (draw_button_label("saveassave", dx + dw, dy, null, null, e_button.PRIMARY, null, e_anchor.RIGHT))
		project_save_as()
	tab_next()
}
