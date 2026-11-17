import <vector>;
int other();
int main() { std::vector<int> v{1, 2}; return (v.size() == 2 && other() == 0) ? 0 : 1; }
