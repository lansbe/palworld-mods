#pragma once
#include "symbols.hpp"
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

namespace pal::engine {
template<class T> T read(const void* base, size_t offset) {
    T value{}; std::memcpy(&value, static_cast<const char*>(base) + offset, sizeof(T)); return value;
}
template<class T> void write(void* base, size_t offset, const T& value) {
    std::memcpy(static_cast<char*>(base) + offset, &value, sizeof(T));
}
struct Name { uint64_t value = 0; };
struct String { char16_t* data = nullptr; int32_t count = 0; int32_t capacity = 0; };
struct Handle {
    void* pointer = nullptr;
    int32_t index = -1;
    int32_t serial = 0;
    explicit Handle(void* object = nullptr);
    void* get() const;
};
std::u16string wide(const std::string& value);
std::string utf8(const char16_t* value, size_t count);
Name name(const std::string& value);
std::string text(Name value);
std::string objectName(void* object);
std::string objectPath(void* object);
void* find(const std::string& path);
void* findFunction(void* object, const std::string& method);
void* findProperty(void* structure, const std::string& property);
std::vector<void*> properties(void* structure);
std::vector<Handle> objects(const std::string& className, size_t limit = 4096);
std::string propertyKind(void* property);
void event(void* object, void* function, void* parameters);
void* construct(void* type, void* outer);
void initialize(void* property, void* value);
void destroy(void* property, void* value);
void* allocate(size_t bytes);
void release(void* memory);
}
