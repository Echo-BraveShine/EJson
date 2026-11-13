#include "flutter_window.h"

#include <optional>
#include <tuple>
#include <variant>

#include <flutter/standard_method_codec.h>
#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  appearance_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "dev.ekko.ejson/appearance",
          &flutter::StandardMethodCodec::GetInstance());
  appearance_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() != "setDarkAppearance") {
          result->NotImplemented();
          return;
        }
        const bool* dark = call.arguments()
                               ? std::get_if<bool>(call.arguments())
                               : nullptr;
        if (dark) {
          const int resource = *dark ? IDI_APP_ICON_DARK : IDI_APP_ICON;
          const HWND window = GetHandle();
          const HINSTANCE instance = GetModuleHandle(nullptr);
          const UINT dpi = GetDpiForWindow(window);
          for (const auto& [slot, width, height] :
               {std::tuple{ICON_SMALL, SM_CXSMICON, SM_CYSMICON},
                std::tuple{ICON_BIG, SM_CXICON, SM_CYICON}}) {
            const HANDLE icon = LoadImage(
                instance, MAKEINTRESOURCE(resource), IMAGE_ICON,
                GetSystemMetricsForDpi(width, dpi),
                GetSystemMetricsForDpi(height, dpi), LR_SHARED);
            if (icon) {
              SendMessage(window, WM_SETICON, slot,
                          reinterpret_cast<LPARAM>(icon));
            }
          }
        }
        result->Success();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (appearance_channel_) {
    appearance_channel_->SetMethodCallHandler(nullptr);
    appearance_channel_.reset();
  }
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
