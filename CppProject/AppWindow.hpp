#pragma once

#include "Common.hpp"
#include "Render/GraphicsApiHandler.hpp"

#include <QMainWindow>
#include <QLineEdit>
#include <QMouseEvent>
#include <QOpenGLWidget>
#include <QTouchEvent>

namespace CppProject
{
	struct GLWidget;
	struct FrameBuffer;

	// An application window
	struct AppWindow : QMainWindow
	{
		AppWindow(IntType id);
		~AppWindow();

		// Show window
		void ShowNormal();
		void Maximize();
		void UpdateSize();

		// Returns the current window surface to render to.
		Surface* GetSurface() const;

		// Present the rendered surface on the window.
		void Present();

		// Window events
		bool event(QEvent* event) override;
		void resizeEvent(QResizeEvent* event) override;
		void closeEvent(QCloseEvent* event) override;
		void dragEnterEvent(QDragEnterEvent* event) override;
		void dragMoveEvent(QDragMoveEvent* event) override;
		void dropEvent(QDropEvent* event) override;

		// Mouse events
		void mousePressEvent(QMouseEvent* event) override;
		void mouseReleaseEvent(QMouseEvent* event) override;
		void mouseMoveEvent(QMouseEvent* event) override;
		void wheelEvent(QWheelEvent* event) override;

		bool closing = false;
		IntType id = 0;
		QSize newSize = { 0, 0 };
	#if API_D3D11
		Surface* surface = nullptr;
		ID3D11RenderTargetView* d3dRTV = nullptr;
		IDXGISwapChain* d3dSwapchain = nullptr;
		QWidget* d3dWidget = nullptr;
	#else
		GLWidget* glWidget = nullptr;
	#endif

		QHash<IntType, BoolType> mouseDown;
		int mouseWheel = 0;
		QPoint mousePos, mouseLastPos, mouseLockPos, mouseLockWinPos;
		BoolType mouseLocked = false, mouseUnlock = true;

		// Two-finger pinch/pan state (Fase 4, Trampa 1) - derived each event from the 2 touch
		// slots below, read by GML through InputFunc.cpp getters, drained once per frame
		// (AppHandler.cpp) the same way mouseWheel above already is.
		IntType touchCount = 0;
		RealType touchPinchDelta = 0;
		RealType touchPanDx = 0, touchPanDy = 0;
		QPointF touchPrevMid;
		qreal touchPrevDist = 0;
		bool touchTracking = false;

		// Raw per-finger tracking (virtual joystick + simultaneous look, Fase 4) - unlike the
		// pinch/pan aggregate above (which only cares about the relationship BETWEEN 2 points),
		// this identifies WHICH physical finger is which across frames by Qt's own stable touch
		// point id(), so GML can say "whichever finger is inside the joystick's circle drives
		// it, and whatever finger remains free rotates the camera" - two fingers doing two
		// different, independent things at once, not obtainable from mouseX/mouseY (Qt's
		// single synthesized pointer) once a second finger is down at all.
		static const int TouchSlotCount = 2;
		int touchSlotId[TouchSlotCount] = { -1, -1 };
		QPointF touchSlotPos[TouchSlotCount];
		bool touchSlotActive[TouchSlotCount] = { false, false };

		// Stored so Maximize() can re-assert Qt focus on it once the native window actually
		// exists (KNOWN_ISSUES.md B20) - the constructor's own setFocus() call is too early on
		// Android (documented Qt timing bug: setFocus() before the platform window is realized
		// never registers a focusObject, so showInputPanel() later has nothing to show).
		struct KeyChecker* keyChecker = nullptr;

		static BoolType mouseEnableLock;
	};

	// Keyboard checker as a hidden QLineEdit widget
	struct KeyChecker : QLineEdit
	{
		KeyChecker(QWidget* parent);
		void focusOutEvent(QFocusEvent* e) override { QWidget::setFocus(); }
		void keyPressEvent(QKeyEvent* event) override;
		void keyReleaseEvent(QKeyEvent* event) override;
		void mouseDoubleClickEvent(QMouseEvent* event) override { event->ignore(); }
		void mouseMoveEvent(QMouseEvent* event) override { event->ignore(); }
		void mousePressEvent(QMouseEvent* event) override { event->ignore(); }
		void mouseReleaseEvent(QMouseEvent* event) override { event->ignore(); }
		void paintEvent(QPaintEvent* event) override { event->ignore(); }

		// Reports the real on-screen rect of whichever GML textbox currently has window_focus
		// (fieldX/Y/W/H below, set by keyboard_field_set() - UtilFunc.cpp - called every frame
		// from textbox_draw.gml) instead of this hidden QLineEdit's own meaningless geometry -
		// so Android's on-screen keyboard positions/scrolls around the actual field being
		// edited (KNOWN_ISSUES.md B20, piece 2 of the proposed fix).
		QVariant inputMethodQuery(Qt::InputMethodQuery query) const override;

		BoolType setPos = false;
		QString lastText = "";
		RealType fieldX = 0, fieldY = 0, fieldW = 0, fieldH = 0;
	};
}