// HeaderUnits.cmake -- the GCC module mapper and, for every toolchain, the configure-time import scan (Common.cmake,
// _hu_build_helper, compiles this file at configure time with the project's own compiler).  Uses:
//   hu-mapper <map>                        a header unit's own compile ("-fmodule-mapper=|hu-mapper <map>")
//   hu-mapper -s <map>                     a consumer's dependency scan: <map> lists its header units; an unknown
//                                          (named) module gets a fallback name, as the scan never reads it
//   hu-mapper -c <modmap> <index> <source> a consumer's compile: CMake's module map of the TU (named modules) plus the
//                                          header-unit map that <index> ("<source>|<map>" per line) gives <source>
//                                          (Ninja's $in: CMake passes a compiled source by absolute path)
//   hu-mapper scan <request> <result>      configure time (Common.cmake, _hu_native_scan): the header-unit import
//                                          declarations of sources and the files their names resolve to; see below
//   hu-mapper -v                           prints the format version (configure checks that the program runs)
//
// GCC asks a mapper two things through the same table: where to write the CMI of the header unit it builds
// (MODULE-EXPORT), and whether an #include it meets is a header unit (INCLUDE-TRANSLATE).  GCC's own file mapper answers
// both from one entry, so a header that includes itself through another one (fmt's core.h includes "format.h") made GCC
// import the header unit being built.  This mapper answers MODULE-EXPORT with the CMI, and INCLUDE-TRANSLATE of the
// header being built with "BOOL TRUE" ("textual"), so that #include stays a plain include, guarded as usual.
//
// Map file (one directive or entry per line, words separated by blanks and quoted as in the protocol, see words()):
//   $root <dir>        MODULE-REPO answer (CMI paths below are relative to it)
//   $export <cmi>      the CMI to write, whatever name GCC exports under (one export per compilation)
//   $textual <path>    an #include of <path> stays textual (the header being built, each spelling GCC may use)
//   <path> <cmi>       a header unit this one imports (HU_ALLOW_HEADER_IMPORTS)
// Protocol: libcody (gcc/libcody/README.md): line-based blocks, " ;" continues a block, one response per request.
#if defined(_MSC_VER) && !defined(_CRT_SECURE_NO_WARNINGS)
#define _CRT_SECURE_NO_WARNINGS   // (fopen, _wfopen: no C4996 with a project's /W4 /WX)
#endif
#include <cctype>
#include <cstdio>
#include <filesystem>
#include <map>
#include <set>
#include <string>
#include <vector>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <shellapi.h>   // CommandLineToArgvW (shell32: a default library of MinGW, named below for the others)
#if defined(_MSC_VER)
#pragma comment(lib, "shell32")
#endif
#endif

namespace {

// Words of a protocol line, unquoted ('...' with \n \t \' \\ and hex escapes; quoted and plain parts may abut).
std::vector<std::string> words(const std::string& line) {
  std::vector<std::string> out;
  std::string w;
  bool have = false;
  for (size_t i = 0; i < line.size();) {
    char c = line[i];
    if (c == ' ' || c == '\t') {
      if (have) out.push_back(w);
      w.clear();
      have = false;
      ++i;
    } else if (c == '\'') {
      have = true;
      for (++i; i < line.size() && line[i] != '\''; ++i) {
        if (line[i] != '\\' || i + 1 >= line.size()) { w += line[i]; continue; }
        char e = line[++i];
        if (e == 'n') w += '\n';
        else if (e == 't') w += '\t';
        else if (e == '\'' || e == '\\') w += e;
        else {
          std::string hex(1, e);
          if (i + 1 < line.size() && std::isxdigit((unsigned char)line[i + 1])) hex += line[++i];
          w += (char)std::stoi(hex, nullptr, 16);
        }
      }
      ++i;  // closing quote
    } else {
      have = true;
      w += c;
      ++i;
    }
  }
  if (have) out.push_back(w);
  return out;
}

// A word for a response: plain if made of -+_/%.A-Za-z0-9 only, else quoted.
std::string quote(const std::string& s) {
  bool plain = !s.empty();
  for (char c : s)
    if (!(std::isalnum((unsigned char)c) || std::string("-+_/%.").find(c) != std::string::npos)) plain = false;
  if (plain) return s;
  std::string q = "'";
  for (char c : s) {
    if (c == '\'' || c == '\\') { q += '\\'; q += c; }
    else if (c == '\n') q += "\\n";
    else if (c == '\t') q += "\\t";
    else q += c;
  }
  return q + "'";
}

bool read_line(std::string& line) {
  line.clear();
  int c;
  while ((c = std::getchar()) != EOF && c != '\n')
    if (c != '\r') line += (char)c;
  return c != EOF || !line.empty();
}

struct Maps {
  std::string root = ".", exported;
  std::set<std::string> textual;
  std::map<std::string, std::string> units;
};

FILE* uopen(const std::string& p, bool write);

// One map file (see above); false if it cannot be opened.
bool load(const std::string& path, Maps& m) {
  FILE* f = uopen(path, false);
  if (!f) return false;
  std::string line;
  int c;
  for (;;) {
    line.clear();
    while ((c = std::fgetc(f)) != EOF && c != '\n')
      if (c != '\r') line += (char)c;
    std::vector<std::string> w = words(line);
    if (w.size() == 2 && w[0] == "$root") m.root = w[1];
    else if (w.size() == 2 && w[0] == "$export") m.exported = w[1];
    else if (w.size() == 2 && w[0] == "$textual") m.textual.insert(w[1]);
    else if (w.size() == 2 && w[0][0] != '$') m.units[w[0]] = w[1];
    if (c == EOF) break;
  }
  std::fclose(f);
  return true;
}

// A path for comparing with the index: forward slashes; on Windows without case.
std::string key(std::string s) {
  for (char& c : s) {
    if (c == '\\') c = '/';
#ifdef _WIN32
    c = (char)std::tolower((unsigned char)c);
#endif
  }
  return s;
}

// A CMI name for a module the scan does not read (as g++-mapper-server -f gives one).
std::string fallback_name(std::string n) {
  for (char& ch : n)
    if (ch == ':' || ch == '/' || ch == '\\') ch = '-';
  return "gcm.cache/" + n + ".gcm";
}

// The header-unit map the index gives <source>, or "".  Both are absolute paths, compared without regard to slash
// direction (and on Windows to case).
std::string lookup(const std::string& index, const std::string& source) {
  std::string want = key(source);
  FILE* f = uopen(index, false);
  if (!f) return "";
  std::string line, found;
  int c;
  for (;;) {
    line.clear();
    while ((c = std::fgetc(f)) != EOF && c != '\n')
      if (c != '\r') line += (char)c;
    size_t bar = line.rfind('|');
    if (bar != std::string::npos && key(line.substr(0, bar)) == want) {
      found = line.substr(bar + 1);
      break;
    }
    if (c == EOF) break;
  }
  std::fclose(f);
  return found;
}

// ---- scan --------------------------------------------------------------------------------------------------------
// Request (one directive per line): "cache <file>", then per auto request "req <id>", its search list "dir <d>" (in
// order) and its sources "src <s>".  Result per request: "req <id>", "file <s>" for each source that exists, the
// imported names, each once in order of first appearance, as "name <n>" followed by "cand <file or empty>", and
// "pragma <s>" for each source with the textual-includes marker.  This computes exactly what Common.cmake's
// _hu_scan_imports, _hu_import_name and _hu_find_header compute (the CMake fallback): keep the two in step.
// A source's import lines and marker are kept in the cache file under its modification time and size, so a
// reconfigure reads only the sources that changed.
namespace fs = std::filesystem;

bool is_ws(char c) { return c == ' ' || c == '\t'; }

// ^[ \t]*(export[ \t]+)?import[ \t]*[<"][^>"]+[>"][ \t]*;   (_hu_scan_imports' line filter)
bool import_line(const std::string& l) {
  size_t n = l.size(), i = 0;
  while (i < n && is_ws(l[i])) ++i;
  if (l.compare(i, 6, "export") == 0 && i + 6 < n && is_ws(l[i + 6])) {
    i += 6;
    while (i < n && is_ws(l[i])) ++i;
  }
  if (l.compare(i, 6, "import") != 0) return false;
  i += 6;
  while (i < n && is_ws(l[i])) ++i;
  if (i >= n || (l[i] != '<' && l[i] != '"')) return false;
  size_t e = i + 1;
  while (e < n && l[e] != '>' && l[e] != '"') ++e;
  if (e == i + 1 || e >= n) return false;
  ++e;
  while (e < n && is_ws(l[e])) ++e;
  return e < n && l[e] == ';';
}

// The leftmost match of import[ \t]*<open>([^<close>]+)<close> in l (CMake's MATCHES), into cap.
bool find_import(const std::string& l, char open, char close, std::string& cap) {
  for (size_t p = l.find("import"); p != std::string::npos; p = l.find("import", p + 1)) {
    size_t i = p + 6;
    while (i < l.size() && is_ws(l[i])) ++i;
    if (i >= l.size() || l[i] != open) continue;
    size_t e = l.find(close, i + 1);
    if (e == std::string::npos || e == i + 1) continue;
    cap = l.substr(i + 1, e - i - 1);
    return true;
  }
  return false;
}

bool has_marker(const std::string& l) {
  const std::string m = "HeaderUnits pragma:";
  for (size_t p = l.find(m); p != std::string::npos; p = l.find(m, p + 1)) {
    size_t i = p + m.size();
    while (i < l.size() && is_ws(l[i])) ++i;
    if (l.compare(i, 16, "textual-includes") == 0) return true;
  }
  return false;
}

struct Scanned {
  std::string stamp;                      // "<mtime> <size>"
  bool marker = false;
  std::vector<std::string> imports;       // "a|<name>" / "q|<name>"
};

bool absolute_path(const std::string& s) {
#ifdef _WIN32
  return (s.size() > 1 && s[1] == ':') || (!s.empty() && (s[0] == '/' || s[0] == '\\'));
#else
  return !s.empty() && s[0] == '/';
#endif
}


// Paths in the request, the result, the cache, the maps, hu-index.txt and the arguments (see arguments()) are UTF-8
// (CMake's encoding), also on Windows.
fs::path upath(const std::string& p) { return fs::u8path(p); }

// cmake_path(NORMAL_PATH): lexically normal, with forward slashes.
std::string normal(const std::string& p) { return upath(p).lexically_normal().generic_u8string(); }

FILE* uopen(const std::string& p, bool write) {
#ifdef _WIN32
  try {                 // (u8path throws on a string that is not UTF-8: no such file)
    return _wfopen(upath(p).c_str(), write ? L"wb" : L"rb");
  } catch (const std::exception&) {
    return nullptr;
  }
#else
  return std::fopen(p.c_str(), write ? "wb" : "rb");
#endif
}

bool exists(const std::string& p) {
  std::error_code ec;
  return fs::exists(upath(p), ec);
}

bool is_dir(const std::string& p) {
  std::error_code ec;
  return fs::is_directory(upath(p), ec);
}

std::string stamp_of(const std::string& p) {
  std::error_code e1, e2;
  auto t = fs::last_write_time(upath(p), e1);
  auto s = fs::file_size(upath(p), e2);
  if (e1 || e2) return "";
  return std::to_string((long long)t.time_since_epoch().count()) + " " + std::to_string((unsigned long long)s);
}

// The import lines and the marker of a file, from the pieces file(STRINGS) gives _hu_scan_imports and Core.cmake:
// lines without "\r", also ended by a byte that is neither printable ASCII nor a tab -- except non-ASCII bytes in a
// file that starts with a UTF-8 byte order mark (which is skipped; file(STRINGS) then reads UTF-8).
Scanned scan_file(const std::string& path, const std::string& stamp) {
  Scanned r;
  r.stamp = stamp;
  FILE* f = uopen(path, false);
  if (!f) return r;
  std::string data;
  char buf[65536];
  size_t got;
  while ((got = std::fread(buf, 1, sizeof buf, f)) > 0) data.append(buf, got);
  std::fclose(f);
  size_t i = 0;
  bool utf8 = data.compare(0, 3, "\xEF\xBB\xBF") == 0;
  if (utf8) i = 3;
  std::string piece;
  auto end_piece = [&] {
    if (!r.marker && has_marker(piece)) r.marker = true;
    if (import_line(piece)) {
      std::string cap;
      if (find_import(piece, '<', '>', cap)) r.imports.push_back("a|" + cap);
      else if (find_import(piece, '"', '"', cap)) r.imports.push_back("q|" + cap);
    }
    piece.clear();
  };
  for (; i < data.size(); ++i) {
    unsigned char c = (unsigned char)data[i];
    if (c == '\r') continue;
    if ((c >= 0x20 && c < 0x7F) || c == '\t' || (utf8 && c >= 0x80)) piece += (char)c;
    else end_piece();
  }
  end_piece();
  return r;
}

// Cache file: "f <stamp>\t<marker 0|1>\t<path>", then "i <import>" lines of that file.
const char* kCacheHeader = "hu-scan-cache 1";

void read_cache(const std::string& file, std::map<std::string, Scanned>& cache) {
  FILE* f = uopen(file, false);
  if (!f) return;
  std::string line;
  int c;
  bool first = true;
  Scanned* cur = nullptr;
  for (;;) {
    line.clear();
    while ((c = std::fgetc(f)) != EOF && c != '\n')
      if (c != '\r') line += (char)c;
    if (first) {
      first = false;
      if (line != kCacheHeader) break;
    } else if (line.compare(0, 2, "f ") == 0) {
      size_t t1 = line.find('\t'), t2 = t1 == std::string::npos ? t1 : line.find('\t', t1 + 1);
      if (t2 == std::string::npos) { cur = nullptr; continue; }
      Scanned& s = cache[line.substr(t2 + 1)];
      s = Scanned();
      s.stamp = line.substr(2, t1 - 2);
      s.marker = line.substr(t1 + 1, t2 - t1 - 1) == "1";
      cur = &s;
    } else if (cur && line.compare(0, 2, "i ") == 0) {
      cur->imports.push_back(line.substr(2));
    }
    if (c == EOF) break;
  }
  std::fclose(f);
}

void write_cache(const std::string& file, const std::map<std::string, Scanned>& cache) {
  std::string tmp = file + ".tmp";
  FILE* f = uopen(tmp, true);
  if (!f) return;
  std::fprintf(f, "%s\n", kCacheHeader);
  for (const auto& kv : cache) {
    std::fprintf(f, "f %s\t%d\t%s\n", kv.second.stamp.c_str(), kv.second.marker ? 1 : 0, kv.first.c_str());
    for (const auto& i : kv.second.imports) std::fprintf(f, "i %s\n", i.c_str());
  }
  std::fclose(f);
  std::error_code ec;
  fs::rename(upath(tmp), upath(file), ec);
}

// _hu_import_name: "a|x" -> x; "q|x" -> <dir>/x normalized if x is relative and exists there, else x.
std::string import_name(const std::string& entry, const std::string& dir) {
  std::string n = entry.substr(2);
  if (entry[0] == 'q' && !absolute_path(n) && exists(dir + "/" + n)) return normal(dir + "/" + n);
  return n;
}

// _hu_find_header: the first <d>/<name> that is a file (an absolute name: itself), normalized; "" if none.
std::string find_header(const std::string& name, const std::vector<std::string>& dirs) {
  std::string r;
  if (absolute_path(name)) {
    if (exists(name) && !is_dir(name)) r = name;
  } else {
    for (const auto& d : dirs) {
      std::string c = d + "/" + name;
      if (exists(c) && !is_dir(c)) {
        r = c;
        break;
      }
    }
  }
  return r.empty() ? r : normal(r);
}

std::string parent_dir(const std::string& p) {
  size_t s = p.find_last_of("/\\");
  return s == std::string::npos ? std::string() : p.substr(0, s);
}

// <request> and <result>: CMake passes them relative to the working directory.
int scan(const std::string& request, const std::string& result) {
  FILE* in = uopen(request, false);
  if (!in) {
    std::fprintf(stderr, "hu-mapper: cannot open %s\n", request.c_str());
    return 2;
  }
  struct Req { std::string id; std::vector<std::string> dirs, srcs; };
  std::vector<Req> reqs;
  std::string cache_file, line;
  int c;
  for (;;) {
    line.clear();
    while ((c = std::fgetc(in)) != EOF && c != '\n')
      if (c != '\r') line += (char)c;
    if (line.compare(0, 6, "cache ") == 0) cache_file = line.substr(6);
    else if (line.compare(0, 4, "req ") == 0) reqs.push_back(Req{line.substr(4), {}, {}});
    else if (line.compare(0, 4, "dir ") == 0 && !reqs.empty()) reqs.back().dirs.push_back(line.substr(4));
    else if (line.compare(0, 4, "src ") == 0 && !reqs.empty()) reqs.back().srcs.push_back(line.substr(4));
    if (c == EOF) break;
  }
  std::fclose(in);
  std::map<std::string, Scanned> cache;
  if (!cache_file.empty()) read_cache(cache_file, cache);
  bool changed = false;
  std::string out;
  for (const Req& q : reqs) {
    out += "req " + q.id + "\n";
    std::vector<std::string> names;
    std::set<std::string> seen;
    std::string pragmas;
    for (const std::string& s : q.srcs) {
      std::string st = exists(s) ? stamp_of(s) : "";
      if (st.empty()) continue;
      out += "file " + s + "\n";
      auto it = cache.find(s);
      if (it == cache.end() || it->second.stamp != st) {
        cache[s] = scan_file(s, st);
        it = cache.find(s);
        changed = true;
      }
      if (it->second.marker) pragmas += "pragma " + s + "\n";
      std::string dir = parent_dir(s);
      for (const std::string& e : it->second.imports) {
        std::string n = import_name(e, dir);
        if (seen.insert(n).second) names.push_back(n);
      }
    }
    for (const std::string& n : names) out += "name " + n + "\ncand " + find_header(n, q.dirs) + "\n";
    out += pragmas;
  }
  if (changed && !cache_file.empty()) write_cache(cache_file, cache);
  FILE* o = uopen(result, true);
  if (!o) {
    std::fprintf(stderr, "hu-mapper: cannot write %s\n", result.c_str());
    return 2;
  }
  std::fputs(out.c_str(), o);
  std::fclose(o);
  return 0;
}

// The program's arguments in UTF-8.  On Windows, argv is in the ANSI code page, which cannot spell every path (and
// spells the others in another encoding than hu-index.txt and the maps): the arguments come from the wide command
// line instead, which CMake and GCC (whose programs have a UTF-8 manifest) pass right.
std::vector<std::string> arguments(int argc, char** argv) {
  std::vector<std::string> a;
#ifdef _WIN32
  int n = 0;
  if (wchar_t** w = CommandLineToArgvW(GetCommandLineW(), &n)) {
    for (int i = 0; i < n; ++i) {
      int len = WideCharToMultiByte(CP_UTF8, 0, w[i], -1, nullptr, 0, nullptr, nullptr);
      std::string s(len > 0 ? len : 1, '\0');
      if (len > 0) WideCharToMultiByte(CP_UTF8, 0, w[i], -1, &s[0], len, nullptr, nullptr);
      s.resize(s.size() - 1);   // (the terminating NUL)
      a.push_back(s);
    }
    LocalFree(w);
    return a;
  }
#endif
  for (int i = 0; i < argc; ++i) a.push_back(argv[i]);
  return a;
}

}  // namespace

int main(int argc, char** argv) {
#ifdef _WIN32
  _setmode(_fileno(stdin), _O_BINARY);    // GCC takes a "\r" as part of a word
  _setmode(_fileno(stdout), _O_BINARY);
#endif
  Maps m;
  bool fallback = false;
  const std::vector<std::string> args = arguments(argc, argv);
  const size_t n = args.size();
  const std::string a1 = n > 1 ? args[1] : "";
  if (n == 2 && a1 == "-v") {
    std::puts("hu-mapper 2");
    return 0;
  }
  if (n == 4 && a1 == "scan") return scan(args[2], args[3]);
  if (n == 2 && a1[0] != '-') {
    if (!load(args[1], m)) {
      std::fprintf(stderr, "hu-mapper: cannot open %s\n", args[1].c_str());
      return 2;
    }
  } else if (n == 3 && a1 == "-s") {
    fallback = true;
    if (!load(args[2], m)) {
      std::fprintf(stderr, "hu-mapper: cannot open %s\n", args[2].c_str());
      return 2;
    }
  } else if (n == 5 && a1 == "-c") {
    load(args[2], m);                       // (CMake writes it before the compile; none: no named modules)
    std::string hu = lookup(args[3], args[4]);
    if (!hu.empty() && !load(hu, m)) {
      std::fprintf(stderr, "hu-mapper: cannot open %s\n", hu.c_str());
      return 2;
    }
  } else {
    std::fprintf(stderr, "usage: hu-mapper <map> | -s <map> | -c <modmap> <index> <source> | scan <request> <result> | -v\n");
    return 2;
  }
  const std::string& root = m.root;
  const std::string& exported = m.exported;
  const std::set<std::string>& textual = m.textual;
  const std::map<std::string, std::string>& units = m.units;
  std::string line;
  std::vector<std::vector<std::string>> block;
  while (read_line(line)) {
    std::vector<std::string> w = words(line);
    if (w.empty()) continue;
    bool more = w.back() == ";";
    if (more) w.pop_back();
    if (!w.empty()) block.push_back(w);
    if (more) continue;
    for (size_t i = 0; i < block.size(); ++i) {
      const std::vector<std::string>& r = block[i];
      const std::string& cmd = r[0];
      std::string arg = r.size() > 1 ? r[1] : std::string();
      std::string resp;
      if (cmd == "HELLO") {
        resp = arg == "1" ? "HELLO 1 HeaderUnits" : "ERROR " + quote("unsupported protocol version " + arg);
      } else if (cmd == "MODULE-REPO") {
        resp = "PATHNAME " + quote(root);
      } else if (cmd == "MODULE-EXPORT") {
        // a header unit's own compile: the one CMI to write; a consumer: its named module, from CMake's module map
        // (the scan: a fallback name)
        auto it = units.find(arg);
        resp = !exported.empty() ? "PATHNAME " + quote(exported)
             : it != units.end() ? "PATHNAME " + quote(it->second)
             : fallback          ? "PATHNAME " + quote(fallback_name(arg))
                                 : "ERROR " + quote("no CMI for " + arg);
      } else if (cmd == "MODULE-COMPILED") {
        resp = "OK";
      } else if (cmd == "MODULE-IMPORT") {
        auto it = units.find(arg);
        if (it != units.end()) {
          resp = "PATHNAME " + quote(it->second);
        } else if (fallback) {
          resp = "PATHNAME " + quote(fallback_name(arg));
        } else {
          resp = "ERROR " + quote("unknown module " + arg);
        }
      } else if (cmd == "INCLUDE-TRANSLATE") {
        auto it = units.find(arg);
        resp = textual.count(arg) ? "BOOL TRUE" : it != units.end() ? "PATHNAME " + quote(it->second) : "BOOL FALSE";
      } else {
        resp = "ERROR " + quote("unknown request " + cmd);
      }
      std::fputs(resp.c_str(), stdout);
      std::fputs(i + 1 < block.size() ? " ;\n" : "\n", stdout);
    }
    std::fflush(stdout);
    block.clear();
  }
  return 0;
}
