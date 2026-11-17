import <fmt/format.h>;
import <string>;
int dfn() { std::string s = fmt::format("{}", 2); return s == "2" ? 0 : 1; }
