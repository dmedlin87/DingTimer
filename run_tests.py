import ctypes
import ctypes.util
import sys
import os

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 run_tests.py <test_file.lua>")
        sys.exit(1)

    test_file = sys.argv[1]

    # Try to find the lua library dynamically
    lib_name = ctypes.util.find_library("lua5.4") or \
               ctypes.util.find_library("lua54") or \
               ctypes.util.find_library("lua") or \
               "liblua5.4.so.0" # Fallback

    try:
        lua = ctypes.CDLL(lib_name)
    except Exception as e:
        print(f"Failed to load Lua library ({lib_name}): {e}")
        sys.exit(1)

    # Function prototypes
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
    lua.luaL_loadfilex.restype = ctypes.c_int
    lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_long, ctypes.c_void_p]
    lua.lua_pcallk.restype = ctypes.c_int
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
    lua.lua_close.argtypes = [ctypes.c_void_p]

    L = lua.luaL_newstate()
    if not L:
        print("Failed to create Lua state")
        sys.exit(1)

    lua.luaL_openlibs(L)

    status = lua.luaL_loadfilex(L, test_file.encode(), None)
    if status == 0:
        # lua_pcall is a macro for lua_pcallk(L, n, r, f, 0, NULL)
        status = lua.lua_pcallk(L, 0, -1, 0, 0, None)
        if status != 0:
            err = lua.lua_tolstring(L, -1, None)
            print(f"Test Execution Error: {err.decode() if err else 'unknown'}")
            sys.exit(1)
    else:
        err = lua.lua_tolstring(L, -1, None)
        print(f"Test Load Error: {err.decode() if err else 'unknown'}")
        sys.exit(1)

    lua.lua_close(L)
    print("Tests finished successfully.")

if __name__ == "__main__":
    main()
