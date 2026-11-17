// Imports fmt but NOT <string>: fmt/format.h includes <string> itself; that copy lives inside the fmt
// header unit (built in isolation) and must be usable here.
import <fmt/format.h>;

int fmt_only() {
  std::string s = fmt::format("{}-{}", "fmt", 42);
  return s == "fmt-42" ? 0 : 1;
}
