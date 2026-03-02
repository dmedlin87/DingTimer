import ctypes
import sys

lua = ctypes.CDLL('liblua5.4.so.0')

LUA_MULTRET = -1

lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]

def run_lua_file(filename):
    L = lua.luaL_newstate()
    lua.luaL_openlibs(L)

    if lua.luaL_loadfilex(L, filename.encode('utf-8'), None) != 0:
        lua.lua_tolstring.restype = ctypes.c_char_p
        err = lua.lua_tolstring(L, -1, None)
        print(f"Error loading {filename}: {err.decode('utf-8')}")
        sys.exit(1)

    if lua.lua_pcallk(L, 0, LUA_MULTRET, 0, None, None) != 0:
        lua.lua_tolstring.restype = ctypes.c_char_p
        err = lua.lua_tolstring(L, -1, None)
        print(f"Error running {filename}: {err.decode('utf-8')}")
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) > 1:
        run_lua_file(sys.argv[1])
    else:
        print("Usage: python3 run_tests.py <file.lua>")
