#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  bool EnterPip();
  bool ExitPip();
  void StartDragging();
  bool SetFullScreen(bool fullscreen);
  bool IsFullScreen() const { return is_in_fullscreen_; }

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // PiP MethodChannel
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> pip_channel_;

  bool is_in_pip_ = false;
  WINDOWPLACEMENT prev_placement_ = { sizeof(WINDOWPLACEMENT) };
  LONG_PTR prev_style_ = 0;
  LONG_PTR prev_ex_style_ = 0;

  bool is_in_fullscreen_ = false;
  WINDOWPLACEMENT prev_fullscreen_placement_ = { sizeof(WINDOWPLACEMENT) };
  LONG_PTR prev_fullscreen_style_ = 0;
  LONG_PTR prev_fullscreen_ex_style_ = 0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_