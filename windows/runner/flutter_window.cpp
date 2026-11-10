#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Setup PiP MethodChannel: com.moko.app/pip
  pip_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.moko.app/pip",
      &flutter::StandardMethodCodec::GetInstance());

  pip_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("isPipSupported") == 0) {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name().compare("enterPip") == 0) {
          bool res = this->EnterPip();
          result->Success(flutter::EncodableValue(res));
        } else if (call.method_name().compare("exitPip") == 0) {
          bool res = this->ExitPip();
          result->Success(flutter::EncodableValue(res));
        } else if (call.method_name().compare("setAutoPip") == 0) {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name().compare("startDragging") == 0) {
          this->StartDragging();
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name().compare("setFullScreen") == 0) {
          bool fullscreen = false;
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("fullscreen"));
            if (it != args->end() && std::holds_alternative<bool>(it->second)) {
              fullscreen = std::get<bool>(it->second);
            }
          } else if (std::holds_alternative<bool>(*call.arguments())) {
            fullscreen = std::get<bool>(*call.arguments());
          }
          bool res = this->SetFullScreen(fullscreen);
          result->Success(flutter::EncodableValue(res));
        } else if (call.method_name().compare("isFullScreen") == 0) {
          result->Success(flutter::EncodableValue(is_in_fullscreen_));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

bool FlutterWindow::EnterPip() {
  HWND hwnd = GetHandle();
  if (!hwnd) return false;
  if (is_in_pip_) return true;

  if (is_in_fullscreen_) {
    SetFullScreen(false);
  }

  prev_placement_.length = sizeof(WINDOWPLACEMENT);
  ::GetWindowPlacement(hwnd, &prev_placement_);
  prev_style_ = ::GetWindowLongPtr(hwnd, GWL_STYLE);
  prev_ex_style_ = ::GetWindowLongPtr(hwnd, GWL_EXSTYLE);

  HMONITOR monitor = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO mi = { sizeof(MONITORINFO) };
  ::GetMonitorInfo(monitor, &mi);
  RECT work_area = mi.rcWork;

  int pip_width = 440;
  int pip_height = 248; // 16:9 ratio
  int margin = 24;

  int x = work_area.right - pip_width - margin;
  int y = work_area.bottom - pip_height - margin;

  is_in_pip_ = true;

  if (prev_placement_.showCmd == SW_SHOWMAXIMIZED) {
    ::ShowWindow(hwnd, SW_RESTORE);
  }

  ::SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE | WS_CLIPCHILDREN | WS_CLIPSIBLINGS);
  ::SetWindowLongPtr(hwnd, GWL_EXSTYLE, (prev_ex_style_ & ~WS_EX_APPWINDOW) | WS_EX_TOPMOST);

  ::SetWindowPos(hwnd, HWND_TOPMOST, x, y, pip_width, pip_height,
                 SWP_SHOWWINDOW | SWP_FRAMECHANGED);

  if (pip_channel_) {
    pip_channel_->InvokeMethod("onPipChanged",
                               std::make_unique<flutter::EncodableValue>(true));
  }
  return true;
}

bool FlutterWindow::ExitPip() {
  HWND hwnd = GetHandle();
  if (!hwnd) return false;
  if (!is_in_pip_) return true;

  is_in_pip_ = false;

  ::SetWindowLongPtr(hwnd, GWL_STYLE, prev_style_);
  ::SetWindowLongPtr(hwnd, GWL_EXSTYLE, prev_ex_style_);
  ::SetWindowPlacement(hwnd, &prev_placement_);

  ::SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);

  if (pip_channel_) {
    pip_channel_->InvokeMethod("onPipChanged",
                               std::make_unique<flutter::EncodableValue>(false));
  }
  return true;
}

void FlutterWindow::StartDragging() {
  HWND hwnd = GetHandle();
  if (hwnd && is_in_pip_) {
    ::ReleaseCapture();
    ::SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
  }
}

bool FlutterWindow::SetFullScreen(bool fullscreen) {
  HWND hwnd = GetHandle();
  if (!hwnd) return false;

  if (fullscreen) {
    if (is_in_fullscreen_) return true;
    if (is_in_pip_) {
      ExitPip();
    }

    is_in_fullscreen_ = true;

    prev_fullscreen_placement_.length = sizeof(WINDOWPLACEMENT);
    ::GetWindowPlacement(hwnd, &prev_fullscreen_placement_);
    prev_fullscreen_style_ = ::GetWindowLongPtr(hwnd, GWL_STYLE);
    prev_fullscreen_ex_style_ = ::GetWindowLongPtr(hwnd, GWL_EXSTYLE);

    HMONITOR monitor = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi = { sizeof(MONITORINFO) };
    ::GetMonitorInfo(monitor, &mi);
    RECT monitor_rect = mi.rcMonitor;

    if (prev_fullscreen_placement_.showCmd == SW_SHOWMAXIMIZED) {
      ::ShowWindow(hwnd, SW_RESTORE);
    }

    ::SetWindowLongPtr(hwnd, GWL_STYLE, (prev_fullscreen_style_ & ~WS_OVERLAPPEDWINDOW) | WS_POPUP | WS_VISIBLE | WS_CLIPCHILDREN | WS_CLIPSIBLINGS);
    ::SetWindowLongPtr(hwnd, GWL_EXSTYLE, prev_fullscreen_ex_style_);

    ::SetWindowPos(hwnd, HWND_TOP,
                   monitor_rect.left, monitor_rect.top,
                   monitor_rect.right - monitor_rect.left,
                   monitor_rect.bottom - monitor_rect.top,
                   SWP_SHOWWINDOW | SWP_FRAMECHANGED);

    if (pip_channel_) {
      pip_channel_->InvokeMethod("onFullscreenChanged",
                                 std::make_unique<flutter::EncodableValue>(true));
    }
    return true;
  } else {
    if (!is_in_fullscreen_) return true;

    is_in_fullscreen_ = false;

    ::SetWindowLongPtr(hwnd, GWL_STYLE, prev_fullscreen_style_);
    ::SetWindowLongPtr(hwnd, GWL_EXSTYLE, prev_fullscreen_ex_style_);
    ::SetWindowPlacement(hwnd, &prev_fullscreen_placement_);

    ::SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);

    if (pip_channel_) {
      pip_channel_->InvokeMethod("onFullscreenChanged",
                                 std::make_unique<flutter::EncodableValue>(false));
    }
    return true;
  }
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}