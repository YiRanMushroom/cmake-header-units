import <t28_main.h>;
import m28;

int gen();
int lang();
int gx();
int obj();

int main() { return t28_main() + m28() + gen() + lang() + gx() + obj() == 1 + 2 + 3 + 4 + 5 + 6 ? 0 : 1; }
