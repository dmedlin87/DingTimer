import sys
import os
import ctypes
import traceback

class LuaRuntimeError(Exception):
    pass

class Lua:
    LUA_MULTRET = -1
    LUA_OK = 0

    def __init__(self):
        try:
            self.lib = ctypes.CDLL('liblua5.4.so.0')
        except OSError:
            try:
                self.lib = ctypes.CDLL('liblua5.3.so.0')
            except OSError:
                self.lib = ctypes.CDLL('liblua5.1.so.0')

        # Define types
        self.lib.luaL_newstate.restype = ctypes.c_void_p
        self.lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
        if hasattr(self.lib, 'luaL_loadfilex'):
            self.lib.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
        else:
            self.lib.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]

        if hasattr(self.lib, 'lua_pcallk'):
            self.lib.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]
        else:
            self.lib.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]

        self.lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
        self.lib.lua_tolstring.restype = ctypes.c_char_p

        self.L = self.lib.luaL_newstate()
        self.lib.luaL_openlibs(self.L)

    def dofile(self, path):
        if hasattr(self.lib, 'luaL_loadfilex'):
            res = self.lib.luaL_loadfilex(self.L, path.encode('utf-8'), None)
        else:
            res = self.lib.luaL_loadfile(self.L, path.encode('utf-8'))

        if res != self.LUA_OK:
            err = self.get_string(-1)
            raise LuaRuntimeError(f"Syntax error in {path}: {err}")

        if hasattr(self.lib, 'lua_pcallk'):
            res = self.lib.lua_pcallk(self.L, 0, self.LUA_MULTRET, 0, 0, None)
        else:
            res = self.lib.lua_pcall(self.L, 0, self.LUA_MULTRET, 0)

        if res != self.LUA_OK:
            err = self.get_string(-1)
            raise LuaRuntimeError(f"Runtime error in {path}: {err}")

    def get_string(self, index):
        size = ctypes.c_size_t()
        res = self.lib.lua_tolstring(self.L, index, ctypes.byref(size))
        return res.decode('utf-8') if res else ""

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python run_tests.py <test_file.lua>")
        sys.exit(1)

    lua = Lua()
    test_file = sys.argv[1]

    try:
        lua.dofile(test_file)
        print(f"✅ {test_file} passed")
        sys.exit(0)
    except Exception as e:
        print(f"❌ {test_file} failed")
        print(e)
        sys.exit(1)
