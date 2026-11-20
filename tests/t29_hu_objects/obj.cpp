import <compare>;

bool obj_greater() {
  const std::strong_ordering& g = std::strong_ordering::greater;
  return (2 <=> 1) == g;
}
