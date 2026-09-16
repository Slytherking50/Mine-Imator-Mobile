/// minecraft_version_event_create()

function minecraft_assets_event_create()
{
	version = ""
	
	model_name_map = ds_map_create()
	
	char_list = ds_list_create()
	special_block_list = ds_list_create()
	
	block_list = ds_list_create()
	block_name_map = ds_map_create()
	block_id_map = ds_map_create()
	block_liquid_slot_map = ds_map_create()
	
	model_texture_list = ds_list_create()
	block_texture_list = ds_list_create()
	block_texture_ani_list = ds_list_create()
	// Name->first-index maps mirroring block_texture_list/block_texture_ani_list, built once
	// right after those lists are populated (minecraft_assets_load.gml). block_load_render_
	// model.gml used to do ds_list_find_index() (linear string scan) up to 6x per rendered
	// face - with a texture list in the hundreds/thousands of entries and thousands of faces
	// across a real block set, that scan dominated load time (CLAUDE.md B21, measured
	// 2026-09-09: 73% of block-loading time was inside block_load_render_model). These maps
	// give the same "first match wins" lookup in O(1) instead of O(n).
	block_texture_index_map = ds_map_create()
	block_texture_ani_index_map = ds_map_create()
	block_texture_color_map = ds_map_create()
	item_texture_list = ds_list_create()
	particle_texture_list = ds_list_create()
	block_texture_preview_map = ds_map_create()
}
