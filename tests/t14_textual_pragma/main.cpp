import <stbish/stbish.h>;
import <vector>;
int impl_size();
int plain_value();
int main() { std::vector<int> v{stbish_value()}; return (v[0] == 42 && impl_size() == 1 && plain_value() == 42) ? 0 : 1; }
