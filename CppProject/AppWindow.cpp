#include "AppWindow.hpp"
#include "AppHandler.hpp"
#include "Asset/Surface.hpp"
#include "Render/GLWidget.hpp"
#include "Render/GraphicsApiHandler.hpp"
#include "Generated/Scripts.hpp"

#include <QLineF>
#include <QMimeData>
#include <QScreen>
#include <QStyle>
#include <QTimer>

namespace CppProject
{
#if !OS_MAC
	BoolType AppWindow::mouseEnableLock = true;
#else
	BoolType AppWindow::mouseEnableLock = false;
#endif

	AppWindow::AppWindow(IntType id) : id(id)
	{
	#if API_OPENGL
		glWidget = new GLWidget;
		QMainWindow::setCentralWidget(glWidget);
		keyChecker = new KeyChecker(glWidget);
	#else

		// QWidget subclass for ignoring mouse events, WA_TransparentForMouseEvents attribute breaks mouse locking
		struct D3DWidget : public QWidget
		{
			void mousePressEvent(QMouseEvent* event) override { event->ignore(); }
			void mouseReleaseEvent(QMouseEvent* event) override { event->ignore(); }
			void mouseMoveEvent(QMouseEvent* event) override { event->ignore(); }
		};
		d3dWidget = new D3DWidget;
		d3dWidget->setMouseTracking(true);
		QMainWindow::setCentralWidget(d3dWidget);
		new KeyChecker(d3dWidget);

		// Create swapchain
		DXGI_SWAP_CHAIN_DESC swapchainDesc = {};
		swapchainDesc.BufferDesc.Width = 0;
		swapchainDesc.BufferDesc.Height = 0;
		swapchainDesc.BufferDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
		swapchainDesc.BufferDesc.RefreshRate = { 1, 60 };
		swapchainDesc.BufferDesc.Scaling = DXGI_MODE_SCALING_UNSPECIFIED;
		swapchainDesc.BufferDesc.ScanlineOrdering = DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;
		swapchainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
		swapchainDesc.BufferCount = 2;
		swapchainDesc.SampleDesc.Count = 1;
		swapchainDesc.SampleDesc.Quality = 0;
		swapchainDesc.OutputWindow = (HWND)winId();
		swapchainDesc.Windowed = true;
		swapchainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
		swapchainDesc.Flags = 0;
		HRESULT hr = DXGIFactory->CreateSwapChain(D3DDevice, &swapchainDesc, &d3dSwapchain);
		if (FAILED(hr))
		{
			// FLIP_SEQUENTIAL not supported on Windows 7
			swapchainDesc.SwapEffect = DXGI_SWAP_EFFECT_SEQUENTIAL;
			hr = DXGIFactory->CreateSwapChain(D3DDevice, &swapchainDesc, &d3dSwapchain);
		}
		D3DCheckError(hr);

		surface = new Surface;
	#endif

		QWidget::setMouseTracking(true);
		QWidget::setAcceptDrops(true);
		if (!QWidget::acceptDrops())
			WARNING("setAcceptDrops failed");

		QWidget::setAttribute(Qt::WA_KeyCompression, true);
		QWidget::setMinimumSize(100, 50);

		// Fase 4 / Trampa 1 (CLAUDE.md §6.3): Qt on Android already synthesizes single-touch
		// drags into the mousePressEvent/mouseMoveEvent/mouseReleaseEvent overrides above
		// (that's how single-finger camera orbit already works, verified on device) - but
		// synthesis is single-pointer only, so a second finger has never reached the app at
		// all. WA_AcceptTouchEvents is required for QTouchEvent to be delivered here in the
		// first place (off by default on QWidget); AppWindow::event() below only acts on it
		// when 2+ points are down, so single-touch keeps flowing through the already-verified
		// mouse-synthesis path unchanged - zero risk to existing single-finger orbit/drag.
		QWidget::setAttribute(Qt::WA_AcceptTouchEvents, true);
	}

	AppWindow::~AppWindow()
	{
	#if API_D3D11
		delete surface;
	#endif
	}

	void AppWindow::ShowNormal()
	{
		QMainWindow::showNormal();
	#if API_OPENGL
		glWidget->widgetRender = true;
	#endif
	}

	void AppWindow::Maximize()
	{
	#if API_OPENGL
		glWidget->hide(); // Mac OS fix
	#ifdef Q_OS_ANDROID
		// showFullScreen() (not showMaximized()) hides the system status bar via Qt's own
		// Android platform layer (QAndroidPlatformWindow::updateStatusBarVisibility()) -
		// the Qt-native way to do this, no custom Java needed. Reapplied 2026-09-09 at
		// explicit user request ("saca la hora").
		QMainWindow::showFullScreen();

		// Re-assert KeyChecker's Qt focus now that the native window actually exists
		// (KNOWN_ISSUES.md B20) - its own setFocus() in the constructor runs too early on
		// Android: a documented Qt timing bug (QAndroidInputContext never registers a
		// focusObject when setFocus() precedes the platform window's realization), which
		// otherwise leaves showInputPanel() with nothing to show later no matter how many
		// times GML asks for the keyboard.
		if (keyChecker)
		{
			keyChecker->clearFocus();
			keyChecker->setFocus();
		}
	#else
		QMainWindow::showMaximized();
	#endif
		glWidget->show();
	#else
		QMainWindow::showMaximized();
	#endif
	}

	void AppWindow::UpdateSize()
	{
		if (newSize == QSize(0, 0))
			return;

	#ifndef Q_OS_ANDROID
		newSize.rwidth() *= App->scale;
		newSize.rheight() *= App->scale;
		QMainWindow::setGeometry(QStyle::alignedRect(Qt::LeftToRight, Qt::AlignCenter, newSize, qApp->primaryScreen()->geometry()));
		QTimer::singleShot(100, [&]()
			{
				QMainWindow::showNormal();
				QMainWindow::activateWindow();
			});
	#else
		// window_set_size() (WindowFunc.cpp) is what feeds newSize here - GML calls it
		// expecting DESKTOP behaviour: shrink the OS window itself to a small fixed size
		// (the loading screen's 740x450 box, window_draw_load_assets.gml). Android has no
		// such concept - an Activity's window is always fullscreen. Leaving it alone (no
		// setGeometry()) keeps window_get_width()/height() at the real screen size, which
		// window_draw_load_assets.gml now uses to STRETCH the 740x450 box to fill the
		// screen instead of floating small in the middle (explicit user request,
		// 2026-09-09: "que ocupe todo el espacio"). Reintroduced together with that GML
		// change - without this, the real window would shrink to literally 740x450 and
		// there would be no extra space left to stretch into.
	#endif

	#if API_OPENGL
		glWidget->widgetRender = true;
	#endif
		newSize = { 0, 0 };
	}

	Surface* AppWindow::GetSurface() const
	{
	#if API_D3D11
		return surface;
	#else
		return glWidget->swapchain[glWidget->swapchainIndex];
	#endif
	}

	void AppWindow::Present()
	{
	#if API_D3D11
		D3DContext->OMSetRenderTargets(1, &d3dRTV, nullptr);
		D3D11_VIEWPORT viewport = { 0, 0, (float)width(), (float)height(), 0.0, 1.0 };
		D3DContext->RSSetViewports(1, &viewport);

		// Disable blending
		float blendFactor[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
		ID3D11BlendState* prevState = nullptr;
		D3DContext->OMGetBlendState(&prevState, nullptr, nullptr);
		D3DContext->OMSetBlendState(GFX->d3dNoBlendState, blendFactor, 0xFFFFFFFF);

		// Draw rendered surface
		GFX->surface = surface;
		GFX->SetCulling(false);
		gpu_set_texfilter(false);
		draw_surface_ext(surface->id, 0, 0, App->scale, App->scale, 0.0, -1, 1.0);
		GFX->SubmitBatch();
		GFX->SetCulling(true);

		d3dSwapchain->Present(0, 0);

		// Restore blending
		D3DContext->OMSetBlendState(prevState, blendFactor, 0xFFFFFFFF);
	#else
		// Redo frame if blocked, otherwise flip swapchain index and schedule draw
		if (!App->blocked)
			glWidget->swapchainIndex = 1 - glWidget->swapchainIndex;
		glWidget->update();
	#endif
	}

	bool AppWindow::event(QEvent* event)
	{
		if (event->type() == QEvent::WindowDeactivate && !closing)
		{
			// Clear keys
			for (IntType key : App->keyStateMap.keys())
				App->keyStateMap[key] = {};
			for (IntType key : App->keyWinStateMap.keys())
				App->keyWinStateMap[key] = {};
		}

		// Fase 4 / Trampa 1 (CLAUDE.md §6.3, KNOWN_ISSUES.md B10): pinch-zoom, two-finger pan,
		// and per-finger tracking for the virtual joystick + simultaneous look (one finger
		// held on the on-screen joystick, a second, independent finger free to rotate the
		// camera at the same time - explicit user request, 2026-09-11). Slots are updated for
		// ANY touch (including a single finger), by Qt's own stable point id() so GML can
		// tell fingers apart across frames - but the event is only CONSUMED (bypassing Qt's
		// single-pointer mouse synthesis) once 2 fingers are down at once, since synthesis can
		// only sensibly follow one of them anyway. A single finger keeps flowing through the
		// existing, already-verified mouse-synthesis path unchanged (mousePressEvent/
		// mouseMoveEvent below) in addition to updating its slot here - both run together.
		QEvent::Type t = event->type();
		if (t == QEvent::TouchBegin || t == QEvent::TouchUpdate || t == QEvent::TouchEnd || t == QEvent::TouchCancel)
		{
			QTouchEvent* touchEvent = static_cast<QTouchEvent*>(event);
			const QList<QTouchEvent::TouchPoint>& points = touchEvent->touchPoints();

			for (const QTouchEvent::TouchPoint& tp : points)
			{
				int id = tp.id();
				int slot = -1;
				for (int i = 0; i < TouchSlotCount; i++)
					if (touchSlotActive[i] && touchSlotId[i] == id) { slot = i; break; }
				if (slot < 0)
					for (int i = 0; i < TouchSlotCount; i++)
						if (!touchSlotActive[i]) { slot = i; break; }

				if (slot >= 0)
				{
					touchSlotId[slot] = id;
					touchSlotPos[slot] = tp.pos();
					touchSlotActive[slot] = (tp.state() != Qt::TouchPointReleased);
				}
			}

			if (t == QEvent::TouchEnd || t == QEvent::TouchCancel)
			{
				for (int i = 0; i < TouchSlotCount; i++)
					touchSlotActive[i] = false;
			}

			touchCount = (touchSlotActive[0] ? 1 : 0) + (touchSlotActive[1] ? 1 : 0);

			if (touchSlotActive[0] && touchSlotActive[1])
			{
				QPointF p0 = touchSlotPos[0];
				QPointF p1 = touchSlotPos[1];
				QPointF mid = (p0 + p1) / 2.0;
				qreal dist = QLineF(p0, p1).length();

				if (touchTracking)
				{
					// Accumulated, not overwritten - AppHandler.cpp only drains these once per
					// rendered frame (same pattern as mouseWheel), but several QTouchUpdate
					// events can arrive per frame.
					touchPinchDelta += (dist - touchPrevDist);
					touchPanDx += (mid.x() - touchPrevMid.x());
					touchPanDy += (mid.y() - touchPrevMid.y());
				}

				touchPrevMid = mid;
				touchPrevDist = dist;
				touchTracking = true;

				event->accept();
				return true;
			}
			else
				touchTracking = false;
		}

		return QMainWindow::event(event);
	}

	void AppWindow::resizeEvent(QResizeEvent* event)
	{
	#if API_D3D11
		surface->Resize(size());
		releaseAndReset(d3dRTV);

		D3DCheckError(d3dSwapchain->ResizeBuffers(2, width(), height(), DXGI_FORMAT_B8G8R8A8_UNORM, 0));

		// Create RTV from window swapchain backbuffer
		ID3D11Texture2D* backBufferTex = nullptr;
		d3dSwapchain->GetBuffer(0, __uuidof(ID3D11Texture2D), (LPVOID*)&backBufferTex);
		if (!backBufferTex)
			FATAL("Could not get back buffer texture");
		else
			D3DCheckError(D3DDevice->CreateRenderTargetView(backBufferTex, NULL, &d3dRTV));
		backBufferTex->Release();
	#endif
	}

	void AppWindow::closeEvent(QCloseEvent* event)
	{
		// Confirm close
		if (App->mainWindow == this)
		{
			if (global::_app)
			{
				if (!app_event_game_end(ScopeAny(global::_app->id)))
				{
					event->ignore();
					return;
				}
			}

			for (AppWindow* appWindow : App->windows)
			{
				appWindow->id = 0;
				appWindow->close();
			}
			delete App;
		}
		else
		{
			if (id)
				window_event_closed(id);

			if (App->mouseWindow == this)
				App->mouseWindow = App->mainWindow;
			App->windows.removeOne(this);
		}

		closing = true;
		event->accept();
	}

	ArrType MimeDataToFiles(const QMimeData* mimeData)
	{
		ArrType files;
		if (mimeData->hasUrls())
			for (QUrl url : mimeData->urls())
				files.Append(StringType(url.toLocalFile()));

		return files;
	}

	void AppWindow::dragEnterEvent(QDragEnterEvent* event)
	{
		ArrType files = MimeDataToFiles(event->mimeData());
		if (files.Size() && window_drop_enter(ScopeAny(global::_app->id), files))
			event->accept();
		else
			event->ignore();
	}

	void AppWindow::dragMoveEvent(QDragMoveEvent* event)
	{
		ArrType files = MimeDataToFiles(event->mimeData());
		if (files.Size() && window_drop_enter(ScopeAny(global::_app->id), files))
			event->accept();
		else
			event->ignore();
	}

	void AppWindow::dropEvent(QDropEvent* event)
	{
		GFX->StartOffScreenRender();
		window_drop(ScopeAny(global::_app->id), MimeDataToFiles(event->mimeData()));
	}

	KeyChecker::KeyChecker(QWidget* parent) : QLineEdit(parent)
	{
		QWidget::setAcceptDrops(false);
		QWidget::setContextMenuPolicy(Qt::NoContextMenu);
		QWidget::unsetCursor();
		QWidget::setAttribute(Qt::WA_MacShowFocusRect, 0);
		QLineEdit::setEchoMode(QLineEdit::NoEcho);

		// setEchoMode(NoEcho) above automatically ORs in 4 input method hints meant for real
		// password fields - ImhHiddenText, ImhSensitiveData, ImhNoPredictiveText,
		// ImhNoAutoUppercase (qlineedit.cpp:576-579, confirmed by reading the real Qt 5.15.19
		// source installed on this machine, not assumed). Correct for an actual password box;
		// wrong here - NoEcho is used purely so this invisible widget never paints anything
		// (GML draws its own text for every field, sensitive or not), not because the content
		// is secret. Left set, Android's on-screen keyboard treats every GML text field as a
		// password box - KNOWN_ISSUES.md B20's own "riesgo secundario" flagged this as
		// unverified without a device; confirmed now as the likely cause of typed characters
		// never reaching the field (reported on real device, 2026-09-11). Cleared back to
		// normal-field hints right after.
		QLineEdit::setInputMethodHints(Qt::ImhNone);

		QWidget::connect(this, &QLineEdit::cursorPositionChanged, [&](int oldPos, int newPos)
			{
				// Disable left/right/home/end, keep cursor at string end
				if (!setPos)
				{
					setPos = true;
					QLineEdit::setCursorPosition(text().length());
					setPos = false;
				}
			});
		QWidget::connect(this, &QLineEdit::textChanged, [&]()
			{
				// Add
				if (QLineEdit::text().length() > lastText.length())
					gmlGlobal::keyboard_string += QString(QLineEdit::text().at(QLineEdit::text().length() - 1));
				else // Erase (last only)
					gmlGlobal::keyboard_string = gmlGlobal::keyboard_string.Left(gmlGlobal::keyboard_string.GetLength() - 1);

				lastText = QLineEdit::text();
			});

		QWidget::setFocus();

	#ifdef Q_OS_ANDROID
		// NOT hide() on Android - QWidgetPrivate::updateFocusChild() (run by setFocus(),
		// qwidget.cpp:6436-6457 in the real Qt 5.15.19 source) only walks focus_child up
		// through ancestors that are ALL hidden; it stops at the first VISIBLE one. Our
		// parent (glWidget) is visible, so once the window is shown, every later setFocus()
		// call on this hidden widget (keyboard_virtual_show()/Maximize() re-asserting focus,
		// UtilFunc.cpp/AppWindow.cpp) can only ever reach as far as glWidget - it never
		// reaches AppWindow. AppWindow's own focus_child is left null (clearFocus() clears it
		// unconditionally first, qwidget.cpp:6494-6500, and this setFocus() then fails to
		// restore it), so qGuiApp->focusObject() falls back to AppWindow itself (a
		// QMainWindow) instead of this QLineEdit - confirmed on a real device via logcat,
		// 2026-09-11: Qt's own QAndroidInputContext logged "QObject::connect: No such signal
		// QMainWindow::cursorPositionChanged()" (it tried to connect to the WRONG focus
		// object's signal) and every keystroke came back as "RemoteInputConnectionImpl:
		// commitText on inactive InputConnection" - the on-screen keyboard appeared but typed
		// text had nowhere real to go (KNOWN_ISSUES.md B20). Resizing to 0x0 and keeping it
		// "shown" instead avoids the hidden-ancestor special case entirely (nothing to paint
		// at zero size anyway, and paintEvent()/mouse handlers above already no-op), so
		// setFocus() takes updateFocusChild()'s unrestricted else-branch and correctly
		// reaches AppWindow every time. Desktop is untouched (still hide()s below) - it never
		// re-asserts focus after the window is shown, so it never hits this bug in the first
		// place; no need to risk changing its long-proven behavior.
		QWidget::resize(0, 0);
		QWidget::show();
	#else
		QWidget::hide();
	#endif
	}

	QVariant KeyChecker::inputMethodQuery(Qt::InputMethodQuery query) const
	{
		// fieldX/Y/W/H (set by keyboard_field_set(), UtilFunc.cpp) are logical GML units -
		// App->scale converts them to the same physical pixel space window_get_width()/
		// height() and the mouse position already use (WindowFunc.cpp, AppHandler.cpp) so the
		// reported rect lines up with what's actually drawn on screen, not this hidden
		// QLineEdit's own default geometry (KNOWN_ISSUES.md B20, piece 2).
		if (query == Qt::ImCursorRectangle || query == Qt::ImInputItemClipRectangle)
		{
			return QRectF(
				fieldX * App->scale,
				fieldY * App->scale,
				fieldW * App->scale,
				fieldH * App->scale
			).toRect();
		}

		return QLineEdit::inputMethodQuery(query);
	}

	void KeyChecker::keyPressEvent(QKeyEvent* event)
	{
		if (!event->isAutoRepeat())
		{
			// Send key to AppHandler
			App->SetKeyDown(event, true);
			App->SetWinKeyDown(event->nativeScanCode(), true);
		}

		// Add text if not copy/paste
		if (!event->matches(QKeySequence::Copy) && !event->matches(QKeySequence::Cut) && !event->matches(QKeySequence::Paste))
			QLineEdit::keyPressEvent(event);

		// Propagate to application
		event->ignore();
	}

	void KeyChecker::keyReleaseEvent(QKeyEvent* event)
	{
		if (!event->isAutoRepeat())
		{
			// Send key to AppHandler
			App->SetKeyDown(event, false);
			App->SetWinKeyDown(event->nativeScanCode(), false);
		}

		// Add text
		QLineEdit::keyReleaseEvent(event);

		// Propagate to application
		event->ignore();
	}

	void AppWindow::mousePressEvent(QMouseEvent* event)
	{
		switch (event->button())
		{
			case Qt::LeftButton: mouseDown[mb_left] = true; break;
			case Qt::RightButton: mouseDown[mb_right] = true; break;
			case Qt::MiddleButton: mouseDown[mb_middle] = true; break;
		}
	}

	void AppWindow::mouseReleaseEvent(QMouseEvent* event)
	{
		switch (event->button())
		{
			case Qt::LeftButton: mouseDown[mb_left] = false; break;
			case Qt::RightButton: mouseDown[mb_right] = false; break;
			case Qt::MiddleButton: mouseDown[mb_middle] = false; break;
		}
		mouseUnlock = true;
	}

	void AppWindow::mouseMoveEvent(QMouseEvent* event)
	{
		App->mouseWindow = this;
		mousePos = event->pos();
	}

	void AppWindow::wheelEvent(QWheelEvent* event)
	{
		if (event->angleDelta().y() < 0)
			mouseWheel = -1;
		else if (event->angleDelta().y() > 0)
			mouseWheel = 1;
		else
			mouseWheel = 0;
	}
}
