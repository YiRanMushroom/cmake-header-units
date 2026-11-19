import <vector>;
import <t24/val.h>;

int main() {
  std::vector<int> v{1, 2, 3};
  return v.size() == 3 && t24_val() == 24 ? 0 : 1;
}
