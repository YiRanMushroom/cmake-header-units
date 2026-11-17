import <string>;
import <fmt/format.h>;
int dfn();
int main() { std::string s = fmt::format("{}{}", "a", 1); return (s == "a1" && dfn() == 0) ? 0 : 1; }
