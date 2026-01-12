#pragma once

#include <vector>
#include <cmath>
#include <algorithm>

namespace DeliVerb {

// Circular buffer delay line with linear interpolation for sub-sample accuracy
class DelayLine {
public:
    DelayLine() = default;

    void setSampleRate(double sampleRate) {
        m_sampleRate = sampleRate;
    }

    // Allocate buffer for a maximum delay time in milliseconds
    void setMaxDelayMs(float maxDelayMs) {
        size_t maxSamples = static_cast<size_t>(m_sampleRate * maxDelayMs / 1000.0) + 4;
        m_buffer.resize(maxSamples, 0.0f);
        m_writeIndex = 0;
    }

    // Write a sample to the delay line
    void write(float sample) {
        if (m_buffer.empty()) return;
        m_buffer[m_writeIndex] = sample;
        m_writeIndex++;
        if (m_writeIndex >= m_buffer.size()) {
            m_writeIndex = 0;
        }
    }

    // Read from delay line with linear interpolation
    // delayMs: delay time in milliseconds
    float read(float delayMs) const {
        if (m_buffer.empty()) return 0.0f;

        // Convert ms to samples
        float delaySamples = static_cast<float>(delayMs * m_sampleRate / 1000.0);

        // Ensure minimum delay to avoid reading current write position
        delaySamples = std::max(1.0f, delaySamples);

        // Clamp to buffer size
        delaySamples = std::min(delaySamples, static_cast<float>(m_buffer.size() - 2));

        // Calculate read position
        float readPos = static_cast<float>(m_writeIndex) - delaySamples;
        if (readPos < 0.0f) {
            readPos += static_cast<float>(m_buffer.size());
        }

        // Linear interpolation
        size_t index0 = static_cast<size_t>(readPos);
        size_t index1 = index0 + 1;
        if (index1 >= m_buffer.size()) {
            index1 = 0;
        }

        float frac = readPos - static_cast<float>(index0);
        return m_buffer[index0] * (1.0f - frac) + m_buffer[index1] * frac;
    }

    // Read from delay line in samples (for tempo-synced delays)
    float readSamples(float delaySamples) const {
        if (m_buffer.empty()) return 0.0f;

        // Ensure minimum delay
        delaySamples = std::max(1.0f, delaySamples);

        // Clamp to buffer size
        delaySamples = std::min(delaySamples, static_cast<float>(m_buffer.size() - 2));

        // Calculate read position
        float readPos = static_cast<float>(m_writeIndex) - delaySamples;
        if (readPos < 0.0f) {
            readPos += static_cast<float>(m_buffer.size());
        }

        // Linear interpolation
        size_t index0 = static_cast<size_t>(readPos);
        size_t index1 = index0 + 1;
        if (index1 >= m_buffer.size()) {
            index1 = 0;
        }

        float frac = readPos - static_cast<float>(index0);
        return m_buffer[index0] * (1.0f - frac) + m_buffer[index1] * frac;
    }

    void reset() {
        std::fill(m_buffer.begin(), m_buffer.end(), 0.0f);
        m_writeIndex = 0;
    }

    double getSampleRate() const { return m_sampleRate; }

private:
    double m_sampleRate = 44100.0;
    std::vector<float> m_buffer;
    size_t m_writeIndex = 0;
};

} // namespace DeliVerb
