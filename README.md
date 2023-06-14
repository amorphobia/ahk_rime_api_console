# AutoHotkey 实现的 Rime API 控制台

使用 AutoHotkey 移植了佛振用 C++ 编写的 [rime_api_console](https://github.com/rime/librime/blob/master/tools/rime_api_console.cc)

## 一些细节

- 使用 [AutoHotkey v2](https://www.autohotkey.com/docs/v2/v2-changes.htm) 编写
- 由于 AutoHotkey 脚本不是控制台程序，需要额外绘制一个图形界面来显示输出
- AutoHotkey 与 rime.dll 交互严重依赖于 [`DllCall`](https://www.autohotkey.com/docs/v2/lib/DllCall.htm)，需要小心处理偏移量
- librime 官方发布的动态库 rime.dll 是 32 位的，需要使用 32 位的 AutoHotkey 运行
- 整个 `rime_api.h` 的内容都是定义在 `extern "C"` 里的，所以使用 `DllCall` 时需要显式地声明 `"Cdecl"` 使用 C 语言调用约定
- `DllCall` 不支持 C++ `thiscall` 调用约定，庆幸 Rime API 没有放在 C++ 类里
- librime 内部使用 C 语言风格字符串，默认编码为 UTF-8，与之交互时可能需要使用 [`Buffer`](https://www.autohotkey.com/docs/v2/lib/Buffer.htm) 储存，并显式地声明编码
- librime 在维护的时候会启用新的线程，如果 `set_notification_handler` 中回调函数操作了 AutoHotkey 主线程的资源，似乎会造成脚本无响应

## 未来打算

- 最好是可以用符号查找到需要的结构体成员和函数指针，避免人工计算偏移量（但似乎用 AutoHotkey 不能办到），至少要把 Rime API 用 AutoHotkey 函数包起来，这样只用计算一次偏移量
- 尝试用 AutoHotkey 做一个稍微完整一点的 Rime 前端
