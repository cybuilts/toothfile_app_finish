#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>
#include <shlwapi.h>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert the UTF-16 command line arguments to UTF-8 for the Engine to use.
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  // Skip the first argument as it's the binary name.
  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);

  return command_line_arguments;
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }
  unsigned int target_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      -1, nullptr, 0, nullptr, nullptr)
    -1; // remove the trailing null character
  int input_length = (int)wcslen(utf16_string);
  std::string utf8_string;
  if (target_length == 0 || target_length > utf8_string.max_size()) {
    return utf8_string;
  }
  utf8_string.resize(target_length);
  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, utf8_string.data(), target_length, nullptr, nullptr);
  if (converted_length == 0) {
    return std::string();
  }
  return utf8_string;
}

void RegisterUrlScheme(const wchar_t* scheme) {
  wchar_t exe_path[MAX_PATH];
  ::GetModuleFileName(nullptr, exe_path, MAX_PATH);

  wchar_t key_path[MAX_PATH];
  swprintf_s(key_path, MAX_PATH, L"Software\\Classes\\%s", scheme);

  HKEY hKey;
  if (::RegCreateKeyEx(HKEY_CURRENT_USER, key_path, 0, nullptr,
                       REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &hKey,
                       nullptr) == ERROR_SUCCESS) {
    std::wstring description = L"URL:" + std::wstring(scheme) + L" Protocol";
    ::RegSetValueEx(hKey, nullptr, 0, REG_SZ,
                    reinterpret_cast<const BYTE*>(description.c_str()),
                    static_cast<DWORD>((description.size() + 1) * sizeof(wchar_t)));
    ::RegSetValueEx(hKey, L"URL Protocol", 0, REG_SZ, nullptr, 0);

    HKEY hCommandKey;
    if (::RegCreateKeyEx(hKey, L"shell\\open\\command", 0, nullptr,
                         REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr,
                         &hCommandKey, nullptr) == ERROR_SUCCESS) {
      std::wstring command = L"\"" + std::wstring(exe_path) + L"\" \"%1\"";
      ::RegSetValueEx(hCommandKey, nullptr, 0, REG_SZ,
                      reinterpret_cast<const BYTE*>(command.c_str()),
                      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
      ::RegCloseKey(hCommandKey);
    }
    ::RegCloseKey(hKey);
  }
}

void RegisterQuickShareContextMenu() {
  wchar_t exe_path[MAX_PATH];
  ::GetModuleFileName(nullptr, exe_path, MAX_PATH);

  const wchar_t* key_path = L"Software\\Classes\\*\\shell\\ToothFileQuickShare";
  HKEY hKey;
  if (::RegCreateKeyEx(HKEY_CURRENT_USER, key_path, 0, nullptr,
                       REG_OPTION_NON_VOLATILE, KEY_WRITE, nullptr, &hKey,
                       nullptr) != ERROR_SUCCESS) {
    return;
  }

  const wchar_t* label = L"Quick Share with ToothFile";
  ::RegSetValueEx(hKey, nullptr, 0, REG_SZ,
                  reinterpret_cast<const BYTE*>(label),
                  static_cast<DWORD>((wcslen(label) + 1) * sizeof(wchar_t)));
  ::RegSetValueEx(hKey, L"Icon", 0, REG_SZ,
                  reinterpret_cast<const BYTE*>(exe_path),
                  static_cast<DWORD>((wcslen(exe_path) + 1) * sizeof(wchar_t)));

  HKEY hCommandKey;
  if (::RegCreateKeyEx(hKey, L"command", 0, nullptr, REG_OPTION_NON_VOLATILE,
                       KEY_WRITE, nullptr, &hCommandKey,
                       nullptr) == ERROR_SUCCESS) {
    std::wstring command =
        L"\"" + std::wstring(exe_path) + L"\" --quick-share \"%1\"";
    ::RegSetValueEx(hCommandKey, nullptr, 0, REG_SZ,
                    reinterpret_cast<const BYTE*>(command.c_str()),
                    static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
    ::RegCloseKey(hCommandKey);
  }

  ::RegCloseKey(hKey);
}
