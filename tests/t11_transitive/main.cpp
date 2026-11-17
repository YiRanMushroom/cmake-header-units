import <mylib/api.h>;
int main() { return (mylib_level() == CORE_LEVEL && core_str(1) == "core1" && EXTRA_ON == 1) ? 0 : 1; }
