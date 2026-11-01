"""Encode data at the Lua and C++ generated-source boundaries."""


def lua_string(value):
    equals = '=='
    while ']' + equals + ']' in value:
        equals += '='
    return '[' + equals + '[' + value + ']' + equals + ']'


def cpp_string(value):
    return '"' + ''.join(f'\\{byte:03o}' for byte in value.encode('utf-8')) + '"'


def cpp_module(name, source):
    delimiter, counter = 'PAL_LUA', 0
    while ')' + delimiter + '"' in source:
        counter += 1
        delimiter = 'PAL_LUA' + str(counter)
        if len(delimiter) > 16:
            raise ValueError('Embedded source delimiter limit')
    return '{' + cpp_string(name) + ', R"' + delimiter + '(' + source + ')' + delimiter + '"}'
