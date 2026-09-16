#if API_OPENGL
#include "GLWidget.hpp"

#include "AppHandler.hpp"
#include "Asset/Shader.hpp"
#include "Asset/Surface.hpp"
#include "Generated/Scripts.hpp"
#include "GraphicsApiHandler.hpp"
#include "PrimitiveRenderer.hpp"
#include "TexturePage.hpp"
#include "VertexBufferRenderer.hpp"

#include <QDesktopWidget>

namespace CppProject
{
	void GLWidget::initializeGL()
	{
		GFX->Init();

		// Create VAO to enable OpenGL Core
		GFX->glGenVertexArrays(1, &glVboId);
		GL_CHECK_ERROR();

		// Create swapchain
		swapchain[0] = new Surface;
		swapchain[1] = new Surface;

		QWidget::setAttribute(Qt::WA_TransparentForMouseEvents);
	}

	void GLWidget::resizeGL(int width, int height)
	{
		QWidget::update();
	}

	void GLWidget::paintGL()
	{
		if (!widgetRender)
			return;

		RealType scale = QApplication::desktop()->devicePixelRatio();
		GFX->glViewport(0, 0, width() * scale, height() * scale);
		GL_CHECK_ERROR();

		GFX->surface = swapchain[1 - swapchainIndex];
 
		if (!App->blocked)
		{
			GFX->shader = PR->GetShader();
			// This BeginUse() is the shader for the FINAL swapchain->screen composite blit
			// (draw_surface_ext below) - if it silently fails, the composite draws with
			// whatever program was left bound from earlier in the frame (a world/UI shader,
			// wrong textures/attributes for a full-screen blit), which would plausibly show up
			// as visibly wrong content on screen, not just a log line. Was previously silently
			// ignored here too (2026-09-16, see AppHandler.cpp's main render loop for context).
			if (!GFX->shader->BeginUse())
				DEBUG("[WARNING] Shader::BeginUse() failed in GLWidget::paintGL() composite - GL program not bound, final blit is likely corrupted");
		}

		GFX->SetCulling(false);
		GFX->glDisable(GL_BLEND);
		
		// Render swapchain surface
		draw_clear_alpha(0, 0.0);
		// REVERTED 2026-09-09: se probó gpu_set_texfilter(true) en Android para el final
		// swapchain->screen composite (arregla logo/texto en bloques), pero el usuario
		// reportó en dispositivo real que de paso emborrona las nubes y otras texturas que
		// deben verse nítidas/pixeladas a propósito (estética de Minecraft) - el composite
		// no es un blit 1:1 exacto en este dispositivo (probable descalce de
		// devicePixelRatio() vs App->scale, KI-1), así que el filtro suave afecta a TODO lo
		// dibujado, no solo texto/logo. No reintroducir sin resolver ese descalce primero.
		gpu_set_texfilter(false);
		draw_surface_ext(GFX->surface->id, 0, 0, App->scale, App->scale, 0.0, -1, 1.0);
		GFX->SubmitBatch();
		
		GFX->SetCulling(true);
		GFX->glEnable(GL_BLEND);

		if (!App->blocked)
			GFX->shader->EndUse();
	}
}
#endif