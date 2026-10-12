#pragma once
#include "engine.hpp"
namespace pal::events {
void attach();
std::vector<engine::Handle> takeClicks();
}
