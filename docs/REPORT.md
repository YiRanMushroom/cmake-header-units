# CMake 与 C++20 头文件单元（Header Units）调研报告

> 日期：2026-11-17　｜　范围（按用户要求收窄）：把**外部头文件**（标准库 + 第三方库）做成头文件单元；只考虑 **GCC 16 + libstdc++（Linux）**、**Clang 22 + libstdc++ 16（Linux）**、**Clang 22 clang++ + MSVC STL（Windows）**。MSVC 走 MSBuild 原生支持，clang-cl / libc++ 不考虑。
> 所有"PASS/FAIL"均来自实际运行的命令（日志在 experiments/ 与 proto/ 下）；文档类结论附原文链接。

## 1. 结论摘要

1. **CMake 官方**：最新 4.5.0 仍然写着 "Header units are not supported"。官方态度是"计划中、无排期"（#25293），**不是**"不会支持"。
2. **CMake 原生**在 GCC 16 和 Clang 22 上都是**硬失败**：
   - GCC 在扫描阶段就要读 CMI；clang-scan-deps 直接报错。
   - collator 会静默丢掉头文件单元的依赖。
3. **用 CMake 脚本可以做，但只能走"显式声明 + 预先构建"路线。** xmake、build2、Meson 实验分支、Buck2 也都是这条路。
   - 原型 `proto/cmake/HeaderUnits.cmake` 在自己的测试套件里 **36/36 PASS**（6 个测试 × GCC 16 / Clang 22 + libstdc++ / Clang 22 + MSVC STL × CMake 4.4.5 / 4.5.0）。
   - **对抗测试被提前中止，未完成。**
4. **Clang 推荐改用 Buck2 式方案**：模块映射文件 + 按名字延迟加载 + 影子 include 存根。实测它解决了 Windows MSVC STL 上 include/import 混用报错的问题：急切加载方式下失败的 TU，在这个方案下**全部**通过。它还让 `#include <x>` 透明地变成 import。
5. **GCC 依赖 CMake 内部变量 `CMAKE_CXX_MODULE_MAP_FLAG`**，属于不受支持的用法，CMake 升级随时可能失效。

## 2. CMake 官方态度：是"还不支持（计划中）"，不是"不会支持"

- cmake-cxxmodules(7) 自 3.28 到最新 4.5.0（2026-11-13 发布）与 git-master 都写着："For all generators: Header units are not supported."
  https://cmake.org/cmake/help/latest/manual/cmake-cxxmodules.7.html
- 跟踪 issue **#25293 "cxxmodules: Header unit support plan"**（Ben Boeckel，2023-10-03 开）仍 open、无里程碑；3 项任务完成 2 项（4.3 的 per-consumer synthetic targets、4.4 的 usage effects），剩 `FILE_SET TYPE CXX_MODULE_HEADER_UNITS`。https://gitlab.kitware.com/cmake/cmake/-/issues/25293
- 开发者表态："header units are planned"（Ben Boeckel, 2023）；"not yet supported… no set milestone… more-or-less blocked on the majority of open area:cxxmodules issues"（2025-03）；"Header units need first class support"（Vito Gamberini, 2026-10）。未找到任何"不会支持"的表态。
- 用户"CMake 说不支持"的印象很可能来自：手册那句话 + MR !8510（2023-06）以"for now"移除了无实现的实验性 `CXX_MODULE_HEADER_UNITS` file set。
- 对"自己写脚本"不利的官方信号：
  - BMI 由 CMake 之外构建"not a supported configuration"（Ben Boeckel, 2025）。
  - #28166（2026-10）：有人用 add_custom_command + `-fmodule-file` 自制头文件单元，单目标可用、跨目标坏（synthetic target 复制了编译选项却没复制 BMI 的构建依赖）；Kitware 不愿为"ersatz header units"改选项传播，但承认底层依赖传播问题是 bug（#28167，open）。
- import std：4.4.x 仍需实验开关 `CMAKE_EXPERIMENTAL_CXX_IMPORT_STD`（4.4.5 实测 UUID f35a9ac6-…）；4.5 转正（仅 Ninja；CXX_MODULE_STD / CMAKE_CXX_COMPILER_IMPORT_STD 被移除，#27992/#28000/#28183）。

## 3. 为什么头文件单元对构建系统难（根因）

1. **宏问题**：头文件单元导出宏，扫描导入方之前就需要它的 BMI（GCC 手册明说 "When preprocessing, it is necessary to load the CMI"）→ "先扫描再排序"的命名模块模型失效。
2. **身份 = 路径 + 编译选项**：同一头文件在不同选项下需要不同 BMI；GCC 以解析后的路径字符串作为名字。
3. **扫描器不支持**：clang-scan-deps P1689 文档写明 "Only named modules are supported currently"；GCC 的 P1689 输出只有 logical-name（源码有 TODO），没有 lookup-method。
4. **三家机制不同**：GCC 用 module mapper；Clang 用逐个 `-fmodule-file=<pcm>`；MSVC 用 `/headerUnit`。

## 4. 编译器层面实测（不经 CMake）

（详见 experiments/gcc-raw、clang-linux-raw、clang-win-raw 的 README）

| 能力 | GCC 16.2 | Clang 22 + libstdc++ | Clang 22 + MSVC STL (Win) |
|---|---|---|---|
| 用户头 → HU 并导入 | PASS | PASS | PASS |
| STL 头 → HU（vector/string/iostream） | PASS | PASS | PASS |
| 多个重叠 HU 同一 TU 导入 | PASS（原型 t02） | PASS（16 个） | PASS |
| include 翻译（#include→import） | PASS（自动，经 mapper/gcm.cache） | 仅全局模块片段 | 仅全局模块片段 |
| P1689 扫描发现 HU | FAIL（需先有 CMI；输出无 lookup-method） | FAIL（报错或静默省略） | FAIL |
| 选项不一致检测 | -std/异常/RTTI 报错；-D/-O/-fPIC 静默 | 同左（c++20 vs gnu++20 也报错） | 同左；运行库静默 |
| 过期 BMI 检测 | 无（静默用旧的） | 仅检测文件大小变化 | 仅检测大小变化 |
| 并行构建 | 不同 HU 安全；同一 CMI 并发写必崩(ICE) | 安全 | 安全 |

## 5. CMake 原生行为实测（4.4.5，Ninja）

- GCC：扫描阶段即失败（"failed to read compiled module … imports must be built before being imported"）。即使手工预编 CMI，collator 静默丢掉 HU 依赖，编译阶段报 "unknown compiled module interface"。
- Clang：clang-scan-deps 报 "not known to be a header unit"。若在目标选项里加 `-fmodule-file=<pcm>`，扫描通过（结果中省略 HU），可构建运行，但无重建依赖，且额外选项会触发 synthetic target 复制（#28166 风险）。
- `CMAKE_CXX_SCAN_FOR_MODULES OFF`：连命名模块也不能用了。
- Unix Makefiles 生成器：直接拒绝模块。
- GCC mapper：只认最后一个 `-fmodule-mapper`，用户选项在 CMake 的 mapper 之前 → 无效；modmap 每次 collate 重写。唯一可行钩子：`project()` 后覆盖内部变量 `CMAKE_CXX_MODULE_MAP_FLAG`，用 `g++-mapper-server` 同时提供 CMake 的 modmap 与额外的 HU 映射（**内部、无文档、不受支持**）。

## 6. 不用 clang-scan-deps 也能用 Clang

- 头文件单元（显式声明路线）：完全不需要扫描器。
- 命名模块：把缓存变量 `CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS` 指向自写扫描器（`clang -E` + 正则输出 P1689），实测 CMake 4.4.5 + Clang 22（Win/Linux）构建与增量重建全部正确，输出与 clang-scan-deps 逐字节一致（变量无文档）。但它救不了 HU：collator 照样丢弃。
- Clang 22 无内建替代（`-fmodules-driver` 不存在于 22.1.8）。

## 7. 前人方案（深挖并核对源码，详见 research/prior-art-synthesis.md）

**结论：没有任何现成方案能在 CMake 里同时把 GCC 和 Clang 的头文件单元做好。** 成熟的都在别的构建系统里，CMake 社区脚本大多只支持 MSVC，或者是半成品。

| 项目 | 支持哪些编译器的 HU | 怎么发现 HU | 对我们的价值 |
|---|---|---|---|
| **xmake**（活跃，2026-11） | MSVC 稳定；GCC 能用，但 `<dir/x.h>` 坏了约 18 个月，2026-10 才在 dev 分支修好；Clang 的 HU 在 2025-05 被移出 CI（"not stable"） | MSVC 用原生 P1689；GCC 和 Clang 用 `-E` 加正则（维护者自己说 "deprecated … isn't really tested"） | GCC 每个 TU 一个静态 mapper；身份用"规范路径 + defines 哈希"；不同拼写走 alias 模型 |
| **build2** | 只支持 GCC（MSVC 和 Clang 分支是 assert） | **mapper server**：编译过程中在线回答 GCC 的查询，按需构建 HU，支持 include 翻译 | 语义上最正确，但需要构建系统在编译期间在线应答，CMake 脚本做不到。维护者原话："只有在预先编好全部头文件单元的受控环境里才可行" |
| **Buck2（Meta）** | 只支持 Clang | 静态声明 | **Clang 最有价值的参考**：模块映射文件 + 按名字延迟加载 `-fmodule-file=名=pcm` + "影子 include 目录"存根 → 延迟加载、include 翻译、链式再导出（正在验证） |
| **Meson 实验分支（talisein）** | GCC、Clang、MSVC | 每个目标一个静态列表 | 结论同样是"声明，而不是发现"；GCC 方面用自写的 mapper 程序替换文件 mapper |
| **MSBuild / VS** | MSVC | 原生扫描，递归 | 用户已经知道：MSVC 走 MSBuild 即可。CMake VS 生成器在 C++20 下默认打开 `ScanSourceForModuleDependencies`（实测可行） |
| **microsoft/STL 测试脚本** | MSVC | 静态列表 + 扫描后拓扑分层 | HU 依赖 HU 的分层构建方法 |
| CMake 社区脚本：openage `StdHeaderUnit.cmake`（GCC）、jegp.cmake_modules（GCC）、sodaCat、iris（MSVC + Clang）、Boza（MSVC）、knockin-on-headers-door、DanielaE/std.module（OBJECT 库编 HU） | 大多只支持单个编译器，或只能在一个目标内使用 | 全部是静态声明 | 共同的坑：编译选项写死或不一致；只跟踪头文件本身，传递包含的头改了不会重建；在 GCC 上和 CMake 自己的 mapper 冲突（openage 的办法只能触发 include 翻译，显式的 `import <x>` 无法满足）；用 add_custom_target 导致永远视为过期 |
| Kitware #25293 计划 / Ben Boeckel 的 sandbox | — | 计划中的 `FILE_SET CXX_MODULE_HEADER_UNITS` + 每个消费者一个合成目标 | 未来官方方案的方向，命名时要避免和它冲突 |

前人方案里反复出现、可以直接拿来做测试用例的坑：
- GCC mapper 的键和规范名不一致（相对路径与绝对路径、`..`），报 "unknown compiled module interface"。
- mapper 文件里漏写 `$root` 的 `# CMake 与 C++20 头文件单元（Header Units）调研报告

> 日期：2026-11-17　｜　范围（按用户要求收窄）：把**外部头文件**（标准库 + 第三方库）做成头文件单元；只考虑 **GCC 16 + libstdc++（Linux）**、**Clang 22 + libstdc++ 16（Linux）**、**Clang 22 clang++ + MSVC STL（Windows）**。MSVC 走 MSBuild 原生支持，clang-cl / libc++ 不考虑。
> 所有"PASS/FAIL"均来自实际运行的命令（日志在 experiments/ 与 proto/ 下）；文档类结论附原文链接。

## 8. 推荐方案与原型结果

### 8.1 原型 HeaderUnits.cmake（proto/，详见 proto/README.md）
```cmake
include(HeaderUnits)
add_header_units(hu_std HEADERS vector string iostream)
add_header_units(hu_fmt HEADERS fmt/format.h LINK_LIBRARIES fmt::fmt)
target_import_header_units(app hu_std)               # 或用 SOURCES 指定部分源文件
```
- **用 OBJECT 库编 BMI**：走 CMake 自己的编译规则，编译选项和使用方完全一致，头文件依赖跟踪也是原生的。
- **配置期解析头文件路径**：用 try_compile 加 `-H`，把 `<vector>` 这样的名字解析成绝对路径。
- **构建顺序**：使用方的扫描边和编译边都依赖 BMI（已检查 build.ninja）。
- **GCC**：每个头文件单元独立构建（mapper 里只列它自己），两种构建顺序下 CMI 逐字节一致。编译阶段通过覆盖 `CMAKE_CXX_MODULE_MAP_FLAG`，用包装脚本让 `g++-mapper-server` 同时读 CMake 的 modmap 和头文件单元映射。
- **Clang**：按源文件加 `-fmodule-file`，不会产生 `m@synth_*` 合成目标。

**实测结果**（proto/_build/*/results.txt 和 proto/_build/linux/run-*.txt）：

| 测试 | GCC 16 | Clang 22 + libstdc++ | Clang 22 + MSVC STL |
|---|---|---|---|
| t01 STL 头文件单元 | PASS | PASS | PASS |
| t02 fmt / json（Linux 另有 Boost）+ STL 重叠导入 | PASS | PASS | PASS |
| t03 与命名模块共存，含跨目标导入 | PASS | PASS | PASS |
| t04 多目标共享；选项不兼容时配置期报错 | PASS | PASS | PASS |
| t05 重建：空构建、touch、长度不变的修改 | PASS | PASS | PASS |
| t06 同一 TU 里 #include 与 import 混用 | 6 种顺序全部可以 | 6 种顺序全部可以 | **只有先 import 后 include 可以** |

CMake 4.4.5 和 4.5.0 的结果相同。每项都有反向验证（删掉 BMI 后编译必须失败）和依赖文件证据（头文件没有按文本展开）。整套测试的墙钟时间约 3.6 分钟。

**已知限制：**
- 只支持单配置 Ninja。
- GCC：每个构建树里每个头文件只能有一套编译选项；路径里不能有空格。
- Clang：模块接口里不带 export 的 `import <hdr>`，导入方看不到其中的定义，需要改用 `export import`。
- 头文件单元集合不能 install/export。
- set 的 LINK_LIBRARIES 必须是 IMPORTED 目标。
- 对抗测试未完成。

### 8.2 Clang 推荐的 Buck2 式方案（experiments/clang-lazy-hu/，Windows 和 Linux 实测）

每个头文件单元由三样东西组成：
- 一个 umbrella 头（`#include <hdr>`）；
- 一个 modulemap：`module "名" { header "名.h" export * }`；
- 一个影子目录存根，名字和外部头完全相同，内容是 `#ifdef HU_BUILDING export #endif import "umbrella";`。

**命令：**
- 编 BMI：`-xc++-user-header -fmodule-header -fmodule-name=名 --precompile`。编的时候**不能**让它看到自己的 modulemap，否则产出的 pcm 会让所有使用方崩溃（实测确认）。
- 使用方：影子目录的 `-I` 放在最前面，加上 `-fmodule-map-file=…`、`-fmodule-file=名=pcm`、`-fmodule-file-deps`。

**实测结果：**

| 项目 | Windows MSVC STL | Linux libstdc++ |
|---|---|---|
| 急切加载方式（`-fmodule-file=<pcm>`）下的混用 TU（t1–t7、t10–t12） | **全部失败** | 全部通过 |
| 同样的 TU 用延迟加载方案 | **全部通过** | 全部通过 |
| 延迟加载：不用某个头的 TU 不需要它的 pcm 存在 | PASS | PASS |
| 删掉 vector.pcm：用 vector 的 TU 失败，不用的照常编过 | PASS | PASS |
| 链式构建（fmt 的 `#include <string>` 变成 import std_string） | PASS（MSVC 的头不直接 include `<string>`，pcm 没变小） | PASS（iostream pcm 从 5.9 MB 降到 2.5 MB） |
| 显式写 `import <vector>;` | 普通存根下失败；改用"自存根"布局（编译时 #include_next，平时 import）后 `import <vector>` 和 `#include <vector>` 都通过 | 同左 |
| 不加 `-fmodule-map-file` | 失败（"not known to be a header unit"），所以必须加 | 同左 |

接进 CMake 4.5 + Ninja 的实验 agent 报告可以跑通，做法是每个头文件单元一个 OBJECT 库，再满足三个条件：
1. 使用方的 order-depends 里有一个工具目标，保证扫描前 pcm 已经存在；
2. `-fmodule-file=` 里的 pcm 路径写成相对构建目录的形式；
3. 编 pcm 时不能看到它自己的 modulemap。

**这部分没有经过独立复核，因为时间限制被中止了。**

### 8.3 推荐落地方式
- **源码写法**：继续用 `#include <fmt/format.h>`，由构建系统透明地把它变成头文件单元。也可以显式写 `import <x>;`。
  - GCC：mapper 的 include 翻译本身就会做这件事（已实测自动生效）。
  - Clang：用 Buck2 式影子存根做到同样的效果。
- **把 Buck2 方案合进 HeaderUnits.cmake 的 Clang 分支**，替换现在的急切 `-fmodule-file`。这是下一步工作，还没做。

### 8.4 更新：Buck2 方案已合进原型，并支持项目自己的头（2026-11-17）
- **Clang 分支已改为"modulemap 登记真实头文件 + 按名字延迟加载"**。不用影子存根，因为存根在"相对当前文件查找头文件"时会失效。
  - 实测 MSVC STL 上之前失败的所有混用顺序全部通过。
  - 源码里的 `#include`（包括第三方头内部的 include）都会被翻译成 import。
- **项目自己的头**：`LINK_LIBRARIES` 可以写工程内目标，新增 `INCLUDE_DIRECTORIES`；新测试 t07 覆盖这两种情况。
- **结果**：CMake 4.5.0 和 4.4.5 下 t01–t07 在三种组合上 **42/42 PASS**（详见 proto/README.md 的"更新"一节）。
- **GCC 的限制**：带 `..` 的相对拼写不会被翻译，会退回文本包含；显式 `import "../x.h"` 会报错。
- **建议的写法**：头文件里保持 `#include`；源文件里写 `import` 或 `#include` 都可以，两个编译器都会把它们变成头文件单元导入。

## 9. 路线排序与风险

1. **短期，推荐**：用本原型这样的 CMake 脚本。GCC 依赖内部变量；Clang 换成 Buck2 式。要把 CMake 版本锁定在测过的 4.4/4.5，并在 CI 里跑 proto/run-linux.sh 和 run-win.bat，一旦 CMake 升级就能及时发现问题。
2. **中长期**：跟进 Kitware #25293（`FILE_SET CXX_MODULE_HEADER_UNITS`）。官方方案落地后迁移过去，API 尽量向它靠拢。
3. **替代方案**：
   - 标准库部分可以改用 `import std`（CMake 4.5 已转正，仅支持 Ninja）。
   - 第三方库可以包进命名模块，但**只能用"全局模块片段 + using 导出"的写法**，这才是 CMake 原生支持、不需要头文件单元的路径：
     ```cpp
     module;
     #include <fmt/format.h>          // 在全局模块片段里按文本包含，只在这一个 TU 里解析一次
     export module fmt_wrap;
     export namespace fmt { using fmt::format; using fmt::print; /* …逐个列出要导出的名字 */ }
     ```
     代价：宏导不出来（比如 `FMT_STRING`）；要逐个列出导出的名字；如果另一个 TU 又按文本 #include 了同一个头，再和 import 混用，编译器在声明合并上历史上有过 bug。部分库已经自带官方模块（例如 fmt 有 `src/fmt.cc`），能用就优先用。
     **更正**：初稿这里写的 `export import <fmt/format.h>;` 本身就是导入头文件单元，**同样需要头文件单元支持**，不是替代方案。前人项目里 iris 的"包进命名模块再 re-export"也属于这种情况。
   - 换构建系统：xmake 的 GCC/Clang 头文件单元支持并不稳定，build2 只支持 GCC，所以都不推荐。

**主要风险：**
- GCC 依赖 CMake 内部实现。
- Clang 的头文件单元仍然标为 experimental，GCC 也有未关闭的 bug（PR 128040、127695、126577）。
- BMI 过期只能靠依赖文件检测：Clang 只检查文件大小，GCC 完全不检查。原型已经用 CMake 的依赖文件处理了这一点。
- 编译选项不一致时，-D、-O 这类差异编译器不会报错。原型的做法是让 BMI 走使用方完全相同的编译规则来规避。
