// HeaderUnits.cmake -- the GCC module mapper (GCC.cmake compiles this file at configure time with the project's own
// compiler).  Three uses:
//   hu-mapper <map>                        a header unit's own compile ("-fmodule-mapper=|hu-mapper <map>")
//   hu-mapper -s <map>                     a consumer's dependency scan: <map> lists its header units; an unknown
//                                          (named) module gets a fallback name, as the scan never reads it
//   hu-mapper -c <modmap> <index> <source> a consumer's compile: CMake's module map of the TU (named modules) plus the
//                                          header-unit map that <index> ("<source>|<map>" per line) gives <source>
//                                          (Ninja's $in; relative = inside the build dir, its working directory)
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
#include <cctype>
#include <cstdio>
#include <map>
#include <set>
#include <string>
#include <vector>
#ifdef _WIN32
#include <direct.h>
#include <fcntl.h>
#include <io.h>
#else
#include <unistd.h>
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

// One map file (see above); false if it cannot be opened.
bool load(const std::string& path, Maps& m) {
  FILE* f = std::fopen(path.c_str(), "rb");
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

bool absolute(const std::string& s) {
#ifdef _WIN32
  return (s.size() > 1 && s[1] == ':') || (!s.empty() && (s[0] == '/' || s[0] == '\\'));
#else
  return !s.empty() && s[0] == '/';
#endif
}

// A CMI name for a module the scan does not read (as g++-mapper-server -f gives one).
std::string fallback_name(std::string n) {
  for (char& ch : n)
    if (ch == ':' || ch == '/' || ch == '\\') ch = '-';
  return "gcm.cache/" + n + ".gcm";
}

// The header-unit map the index gives <source>, or "".
std::string lookup(const std::string& index, std::string source) {
  if (!absolute(source)) {
    char buf[4096];
#ifdef _WIN32
    if (_getcwd(buf, sizeof buf)) source = std::string(buf) + "/" + source;
#else
    if (getcwd(buf, sizeof buf)) source = std::string(buf) + "/" + source;
#endif
  }
  std::string want = key(source);
  FILE* f = std::fopen(index.c_str(), "rb");
  if (!f) return "";
  std::string line, found;
  int c;
  for (;;) {
    line.clear();
    while ((c = std::fgetc(f)) != EOF && c != '\n')
      if (c != '\r') line += (char)c;
    size_t bar = line.find('|');
    if (bar != std::string::npos && key(line.substr(0, bar)) == want) {
      found = line.substr(bar + 1);
      break;
    }
    if (c == EOF) break;
  }
  std::fclose(f);
  return found;
}

}  // namespace

int main(int argc, char** argv) {
#ifdef _WIN32
  _setmode(_fileno(stdin), _O_BINARY);    // GCC takes a "\r" as part of a word
  _setmode(_fileno(stdout), _O_BINARY);
#endif
  Maps m;
  bool fallback = false;
  std::string a1 = argc > 1 ? argv[1] : "";
  if (argc == 2 && a1[0] != '-') {
    if (!load(argv[1], m)) {
      std::fprintf(stderr, "hu-mapper: cannot open %s\n", argv[1]);
      return 2;
    }
  } else if (argc == 3 && a1 == "-s") {
    fallback = true;
    if (!load(argv[2], m)) {
      std::fprintf(stderr, "hu-mapper: cannot open %s\n", argv[2]);
      return 2;
    }
  } else if (argc == 5 && a1 == "-c") {
    load(argv[2], m);                       // (CMake writes it before the compile; none: no named modules)
    std::string hu = lookup(argv[3], argv[4]);
    if (!hu.empty() && !load(hu, m)) {
      std::fprintf(stderr, "hu-mapper: cannot open %s\n", hu.c_str());
      return 2;
    }
  } else {
    std::fprintf(stderr, "usage: hu-mapper <map> | -s <map> | -c <modmap> <index> <source>\n");
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
