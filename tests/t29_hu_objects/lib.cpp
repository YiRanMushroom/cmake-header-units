import <compare>;
import <format>;
import <string>;

std::string lib_text() {
  const std::strong_ordering* e = &std::strong_ordering::equivalent;
  return e == &std::strong_ordering::equivalent ? std::format("{:.3g}", 1.25f) : std::string();
}
