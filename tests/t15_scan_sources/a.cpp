import <cfg.h>;
import <vector>;
int b_value();
int c_value();
int main() { std::vector<int> v{CFG_VALUE}; return (v[0] == 10 && b_value() == 5 && c_value() == 20) ? 0 : 1; }
