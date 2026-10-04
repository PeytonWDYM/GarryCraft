#pragma once
#include <cstdint>
#include <mathlib/vector.h>

// Bounds use Source axes without the vertical grid translation.
void recordLightingChange(const Vector& minimum, const Vector& maximum);
void clearLightingChanges();
std::uint64_t lightingChangeRevision();
bool lightingChanged(const Vector& minimum, const Vector& maximum, float height, std::uint64_t since);
