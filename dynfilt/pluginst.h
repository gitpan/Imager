#include "../plug.h"

symbol_table_t *symbol_table;
UTIL_table_t *util_table;

void
install_tables(symbol_table_t *s,UTIL_table_t *u) {
  symbol_table=s;
  util_table=u;
}
