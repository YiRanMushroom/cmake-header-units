import <proj2/c.h>;
int main() { std::vector<int> v = c_vec(); return (v.size() == 2 && v[0] == 3 && d_val() == 3) ? 0 : 1; }
