#pragma once

#include "Common.hpp"
#include "Render/GraphicsApiHandler.hpp"

namespace CppProject
{
	// Wrapper for a texture, mipmaps are only generated when required.
	struct Texture
	{
		Texture(const QImage& img);
		~Texture();

		// Returns the unique ID of the texture and generate mipmaps if enabled.
		IntType GetId();

		// Patches a sub-region of an already-uploaded texture in place (no delete/recreate of
		// the underlying GPU resource). Used by TexturePage::Add() so that packing a new sprite
		// into a shared page never has to destroy and fully re-upload the whole page texture.
		// Returns false (does nothing) if img/pos don't fit inside the texture's current bounds.
		bool UpdateSubImage(const QImage& img, QPoint pos);

		int width = 0, height = 0;

	#if API_D3D11
		ID3D11Texture2D* d3dTex = nullptr;
		ID3D11ShaderResourceView* d3dSRV = nullptr;
		IntType d3dSRVId = 0;

		static QHash<IntType, ID3D11ShaderResourceView*> d3dIdSRVMap;
		static IntType d3dSRVNextId;
	#else
		GLuint glTexId = 0;
	#endif

		static QHash<IntType, BoolType> hasMipMaps;
	};
}