/* Host test runner for the unchanged badge Lua parser and 32-bit number model.
 * This is test tooling, not a substitute for the firmware sandbox. */
#include <stdio.h>
#include <string.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

/* Same standalone hooks as the upstream tools/luac/luac.c. The actual
 * firmware, exercised separately, owns stack and callback budgets. */
int lh_cstack_check(void) { return 0; }
void lh_charge_steps(lua_State *L, unsigned int n) { (void)L; (void)n; }
void lh_thread_new(lua_State *L) { (void)L; }

int main(int argc, char **argv) {
    lua_State *L = luaL_newstate();
    if (!L) { fputs("Cannot allocate Lua state\n", stderr); return 1; }
    const struct { const char *name; lua_CFunction open; } libs[] = {
        {"_G", luaopen_base}, {"table", luaopen_table}, {"string", luaopen_string},
        {"math", luaopen_math}, {"utf8", luaopen_utf8}, {"coroutine", luaopen_coroutine}
    };
    for (unsigned i = 0; i < sizeof(libs) / sizeof(libs[0]); i++) {
        luaL_requiref(L, libs[i].name, libs[i].open, 1);
        lua_pop(L, 1);
    }
    int check = argc > 1 && strcmp(argv[1], "--check") == 0;
    for (int i = check ? 2 : 1; i < argc; i++) {
        int status = luaL_loadfilex(L, argv[i], "t");
        if (status == LUA_OK && !check) status = lua_pcall(L, 0, 0, 0);
        if (status != LUA_OK) {
            fprintf(stderr, "%s: %s\n", argv[i], lua_tostring(L, -1));
            lua_close(L); return 1;
        }
        lua_settop(L, 0);
    }
    lua_close(L);
    return 0;
}
