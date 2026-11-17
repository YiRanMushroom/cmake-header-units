#pragma once
#include <core/types.h>
#ifndef EXTRA_ON
#error "EXTRA_ON missing: usage requirements of extra_defs not seen"
#endif
#if defined(PRIVDEP_LEAK) && !defined(MYLIB_BUILDING)
#error "a LINK_ONLY dependency leaked into the header unit"
#endif
int mylib_level();
