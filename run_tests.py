import ctypes
import ctypes.util
import sys
from pathlib import Path


class LuaRunner:
    LUA_OK = 0
    LUA_MULTRET = -1

    def __init__(self):
        self.lua, self.lib_name = self._load_lua_lib()

        self.lua.luaL_newstate.restype = ctypes.c_void_p
        self.lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
        self.lua.lua_close.argtypes = [ctypes.c_void_p]

        self._has_loadfilex = hasattr(self.lua, "luaL_loadfilex")
        if self._has_loadfilex:
            self.lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
            self.lua.luaL_loadfilex.restype = ctypes.c_int
        else:
            self.lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
            self.lua.luaL_loadfile.restype = ctypes.c_int

        self._has_pcallk = hasattr(self.lua, "lua_pcallk")
        if self._has_pcallk:
            self.lua.lua_pcallk.argtypes = [
                ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p
            ]
            self.lua.lua_pcallk.restype = ctypes.c_int
        else:
            self.lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
            self.lua.lua_pcall.restype = ctypes.c_int

        self.lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
        self.lua.lua_tolstring.restype = ctypes.c_char_p

    def _load_lua_lib(self):
        dynamic_candidates = [
            ctypes.util.find_library("lua5.4"),
            ctypes.util.find_library("lua54"),
            ctypes.util.find_library("lua5.3"),
            ctypes.util.find_library("lua53"),
            ctypes.util.find_library("lua"),
        ]
        static_fallbacks = [
            "liblua5.4.so.0",
            "liblua5.3.so.0",
            "lua54.dll",
            "lua53.dll",
            "lua5.4.dll",
            "lua5.3.dll",
            "lua.dll",
        ]
        candidates = []
        seen = set()
        for name in dynamic_candidates + static_fallbacks:
            if name and name not in seen:
                candidates.append(name)
                seen.add(name)

        errors = []
        for name in candidates:
            try:
                return ctypes.CDLL(name), name
            except Exception as exc:
                errors.append(f"{name}: {exc}")

        raise RuntimeError(
            "Failed to load a Lua shared library.\nTried:\n  " + "\n  ".join(errors)
        )

    def _error_from_stack(self, L):
        size = ctypes.c_size_t()
        err = self.lua.lua_tolstring(L, -1, ctypes.byref(size))
        return err.decode("utf-8", errors="replace") if err else "unknown"

    def run_file(self, test_file: Path):
        L = self.lua.luaL_newstate()
        if not L:
            raise RuntimeError("Failed to create Lua state")

        try:
            self.lua.luaL_openlibs(L)

            path_bytes = str(test_file).encode("utf-8")
            if self._has_loadfilex:
                status = self.lua.luaL_loadfilex(L, path_bytes, None)
            else:
                status = self.lua.luaL_loadfile(L, path_bytes)
            if status != self.LUA_OK:
                raise RuntimeError(f"load error: {self._error_from_stack(L)}")

            if self._has_pcallk:
                status = self.lua.lua_pcallk(L, 0, self.LUA_MULTRET, 0, 0, None)
            else:
                status = self.lua.lua_pcall(L, 0, self.LUA_MULTRET, 0)
            if status != self.LUA_OK:
                raise RuntimeError(f"runtime error: {self._error_from_stack(L)}")
        finally:
            self.lua.lua_close(L)


def discover_tests():
    tests_dir = Path("tests")
    tests = sorted(tests_dir.glob("test_*.lua"), key=lambda p: p.as_posix().lower())

    seen = {}
    collisions = []
    for path in tests:
        key = path.as_posix().lower()
        existing = seen.get(key)
        if existing and existing != path.as_posix():
            collisions.append((existing, path.as_posix()))
        else:
            seen[key] = path.as_posix()

    if collisions:
        lines = ["Case-colliding test paths detected; keep exactly one canonical filename:"]
        for a, b in collisions:
            lines.append(f"  - {a}  <->  {b}")
        raise RuntimeError("\n".join(lines))

    return tests


def main():
    if len(sys.argv) > 1:
        tests = [Path(sys.argv[1])]
    else:
        tests = discover_tests()
        if not tests:
            print("No tests found under tests/test_*.lua")
            sys.exit(1)

    try:
        runner = LuaRunner()
    except Exception as exc:
        print(exc)
        sys.exit(1)

    failed = []
    for test in tests:
        try:
            runner.run_file(test)
            print(f"[PASS] {test}")
        except Exception as exc:
            failed.append((test, str(exc)))
            print(f"[FAIL] {test}")
            print(f"       {exc}")

    print(f"\nResults: {len(tests) - len(failed)} passed, {len(failed)} failed")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
