import <compare>;
import <format>;
import <string>;

std::string lib_text();
bool obj_greater();

int main() {
  const std::strong_ordering& less = std::strong_ordering::less;      // odr-uses: their definitions must be linked
  const std::strong_ordering* other[] = {&std::strong_ordering::equal, &std::strong_ordering::greater};
  std::string s = std::format("{:.3g}", 2.5);                         // <format>'s general precision tables
  return (1 <=> 2) == less && other[0] != other[1] && s == "2.5" && lib_text() == "1.25" && obj_greater() ? 0 : 1;
}
