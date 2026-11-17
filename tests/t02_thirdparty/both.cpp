// Imports <string> AND fmt: std::string is defined in both header units (overlapping content), the
// compiler must merge the two definitions.
import <string>;
import <fmt/format.h>;

int both() {
  std::string a = "x";
  std::string b = fmt::format("{}{}", a, a);
  return (b == "xx" && b.size() == 2) ? 0 : 1;
}
