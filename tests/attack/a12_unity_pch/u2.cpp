import <vector>;
int u1(); int u3();
int main() { std::vector<int> v{u1(), u3()}; return v.size() == 2 ? 0 : 1; }
