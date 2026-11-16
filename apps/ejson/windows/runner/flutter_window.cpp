#include "flutter_window.h"

#include <dwmapi.h>
#include <dwrite_1.h>
#include <shlobj.h>
#include <wrl/client.h>

#include <optional>
#include <variant>

#include <flutter/standard_method_codec.h>
#include "flutter/generated_plugin_registrant.h"
#include "resource.h"
#include "utils.h"

namespace {
bool RevealInExplorer(const std::string& path) {
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                        path.c_str(), -1, nullptr, 0);
  if (length <= 1) return false;
  std::wstring wide_path(length, L'\0');
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path.c_str(), -1,
                           wide_path.data(), length)) {
    return false;
  }
  PIDLIST_ABSOLUTE item = nullptr;
  if (FAILED(SHParseDisplayName(wide_path.c_str(), nullptr, &item, 0, nullptr))) {
    return false;
  }
  const HRESULT opened = SHOpenFolderAndSelectItems(item, 0, nullptr, 0);
  CoTaskMemFree(item);
  return SUCCEEDED(opened);
}

std::string FontFamilyName(IDWriteLocalizedStrings* names, UINT32 index) {
  UINT32 length = 0;
  if (FAILED(names->GetStringLength(index, &length))) return {};
  std::wstring value(length + 1, L'\0');
  if (FAILED(names->GetString(index, value.data(), length + 1))) return {};
  return Utf8FromUtf16(value.c_str());
}

std::optional<flutter::EncodableList> InstalledFonts() {
  using Microsoft::WRL::ComPtr;
  ComPtr<IDWriteFactory> factory;
  if (FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory),
      reinterpret_cast<IUnknown**>(factory.GetAddressOf())))) return std::nullopt;
  ComPtr<IDWriteFontCollection> collection;
  if (FAILED(factory->GetSystemFontCollection(&collection, TRUE))) return std::nullopt;
  wchar_t locale[LOCALE_NAME_MAX_LENGTH] = {};
  GetUserDefaultLocaleName(locale, LOCALE_NAME_MAX_LENGTH);
  flutter::EncodableList result;
  for (UINT32 index = 0; index < collection->GetFontFamilyCount(); ++index) {
    ComPtr<IDWriteFontFamily> family;
    ComPtr<IDWriteLocalizedStrings> names;
    if (FAILED(collection->GetFontFamily(index, &family)) ||
        FAILED(family->GetFamilyNames(&names)) || names->GetCount() == 0) continue;
    UINT32 canonical = 0;
    BOOL found = FALSE;
    names->FindLocaleName(L"en-us", &canonical, &found);
    if (!found) canonical = 0;
    UINT32 localized = canonical;
    names->FindLocaleName(locale, &localized, &found);
    if (!found) localized = canonical;
    ComPtr<IDWriteFont> font;
    ComPtr<IDWriteFont1> extended;
    const bool monospace = SUCCEEDED(family->GetFont(0, &font)) &&
        SUCCEEDED(font.As(&extended)) && extended->IsMonospacedFont();
    result.emplace_back(flutter::EncodableMap{
      {flutter::EncodableValue("family"), flutter::EncodableValue(FontFamilyName(names.Get(), canonical))},
      {flutter::EncodableValue("name"), flutter::EncodableValue(FontFamilyName(names.Get(), localized))},
      {flutter::EncodableValue("monospace"), flutter::EncodableValue(monospace)},
    });
  }
  return result;
}
}  // namespace

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
  UpdateWindowIcons(GetHandle(), GetDpiForWindow(GetHandle()));

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
          const HWND window = GetHandle();
          const BOOL immersive_dark = *dark;
          // Explicit caption colors also follow an in-app theme override.
          const COLORREF caption = *dark ? RGB(43, 43, 45) : RGB(239, 239, 241);
          const COLORREF text = *dark ? RGB(242, 242, 244) : RGB(37, 37, 39);
          DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                                &immersive_dark, sizeof(immersive_dark));
          DwmSetWindowAttribute(window, DWMWA_CAPTION_COLOR, &caption,
                                sizeof(caption));
          DwmSetWindowAttribute(window, DWMWA_TEXT_COLOR, &text, sizeof(text));
          dark_appearance_ = *dark;
          UpdateWindowIcons(window, GetDpiForWindow(window));
        }
        result->Success();
      });

  fonts_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "dev.ekko.ejson/fonts",
      &flutter::StandardMethodCodec::GetInstance());
  fonts_channel_->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() != "list") {
      result->NotImplemented();
      return;
    }
    const auto fonts = InstalledFonts();
    if (fonts) {
      result->Success(flutter::EncodableValue(*fonts));
    } else {
      result->Error("font_list_failed", "Could not enumerate installed fonts");
    }
  });

  files_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "dev.ekko.ejson/files",
      &flutter::StandardMethodCodec::GetInstance());
  files_channel_->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() != "revealFile") {
      result->NotImplemented();
      return;
    }
    const auto* path = call.arguments()
                           ? std::get_if<std::string>(call.arguments())
                           : nullptr;
    result->Success(flutter::EncodableValue(path && RevealInExplorer(*path)));
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

void FlutterWindow::UpdateWindowIcons(HWND window, UINT dpi) {
  const int resource = dark_appearance_ ? IDI_APP_ICON_DARK : IDI_APP_ICON;
  const HINSTANCE instance = GetModuleHandle(nullptr);
  const auto update = [&](WPARAM slot, int width, int height, HICON& current) {
    const auto icon = static_cast<HICON>(LoadImage(
        instance, MAKEINTRESOURCE(resource), IMAGE_ICON,
        GetSystemMetricsForDpi(width, dpi), GetSystemMetricsForDpi(height, dpi),
        LR_DEFAULTCOLOR));
    if (icon) {
      SendMessage(window, WM_SETICON, slot, reinterpret_cast<LPARAM>(icon));
      if (current) DestroyIcon(current);
      current = icon;
    }
  };
  update(ICON_SMALL, SM_CXSMICON, SM_CYSMICON, small_icon_);
  update(ICON_BIG, SM_CXICON, SM_CYICON, large_icon_);
  if (const HICON shell_icon = LoadIcon(instance, MAKEINTRESOURCE(resource))) {
    SetClassLongPtr(window, GCLP_HICON, reinterpret_cast<LONG_PTR>(shell_icon));
  }
}

void FlutterWindow::OnDestroy() {
  if (files_channel_) {
    files_channel_->SetMethodCallHandler(nullptr);
    files_channel_.reset();
  }
  if (const HWND window = GetHandle()) {
    SendMessage(window, WM_SETICON, ICON_SMALL, 0);
    SendMessage(window, WM_SETICON, ICON_BIG, 0);
  }
  if (small_icon_) DestroyIcon(small_icon_);
  if (large_icon_) DestroyIcon(large_icon_);
  small_icon_ = nullptr;
  large_icon_ = nullptr;

  if (fonts_channel_) {
    fonts_channel_->SetMethodCallHandler(nullptr);
    fonts_channel_.reset();
  }
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
  if (message == WM_DPICHANGED) {
    UpdateWindowIcons(hwnd, LOWORD(wparam));
  }

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
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
