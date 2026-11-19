// HeaderUnits.cmake -- the GCC module mapper for building one header unit (GCC.cmake compiles this file at configure
// time with the project's own compiler and passes "-fmodule-mapper=|hu-mapper <map file>" to the header unit's compile).
//
// GCC asks a mapper two things through the same table: where to write the CMI of the header unit it builds
// (MODULE-EXPORT), and whether an #include it meets is a header unit (INCLUDE-TRANSLATE).  GCC's own file mapper answers
// both from one entry, so a header that includes itself through another one (fmt's core.h includes "format.h") made GCC
// import the header unit being built.  This mapper answers MODULE-EXPORT with the CMI, and INCLUDE-TRANSLATE of the
// header being built with "BOOL TRUE" ("textual"), so that #include stays a plain include, guarded as usual.
//
// Map file (one directive or entry per line, words separated by blanks, no quoting):
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
#include <fcntl.h>
#include <io.h>
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

}  // namespace

int main(int argc, char** argv) {
#ifdef _WIN32
  _setmode(_fileno(stdin), _O_BINARY);    // GCC takes a "\r" as part of a word
  _setmode(_fileno(stdout), _O_BINARY);
#endif
  if (argc != 2) {
    std::fprintf(stderr, "usage: hu-mapper <map file>\n");
    return 2;
  }
  std::string root = ".", exported;
  std::set<std::string> textual;
  std::map<std::string, std::string> units;
  if (FILE* f = std::fopen(argv[1], "rb")) {
    std::string line;
    int c;
    for (;;) {
      line.clear();
      while ((c = std::fgetc(f)) != EOF && c != '\n')
        if (c != '\r') line += (char)c;
      std::vector<std::string> w = words(line);
      if (w.size() == 2 && w[0] == "$root") root = w[1];
      else if (w.size() == 2 && w[0] == "$export") exported = w[1];
      else if (w.size() == 2 && w[0] == "$textual") textual.insert(w[1]);
      else if (w.size() == 2 && w[0][0] != '$') units[w[0]] = w[1];
      if (c == EOF) break;
    }
    std::fclose(f);
  } else {
    std::fprintf(stderr, "hu-mapper: cannot open %s\n", argv[1]);
    return 2;
  }

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
        resp = exported.empty() ? "ERROR " + quote("no CMI for " + arg) : "PATHNAME " + quote(exported);
      } else if (cmd == "MODULE-COMPILED") {
        resp = "OK";
      } else if (cmd == "MODULE-IMPORT") {
        auto it = units.find(arg);
        resp = it == units.end() ? "ERROR " + quote("unknown header unit " + arg) : "PATHNAME " + quote(it->second);
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
