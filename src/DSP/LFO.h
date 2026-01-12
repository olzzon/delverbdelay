#pragma once

#include <cmath>

namespace DeliVerb {

// Low Frequency Oscillator for modulation effects
class LFO {
public:
    LFO() = default;

    void setSampleRate(double sampleRate) {
        m_sampleRate = sampleRate;
        updatePhaseIncrement();
    }

    void setRate(float rateHz) {
        m_rate = rateHz;
        updatePhaseIncrement();
    }

    // Set phase offset (0.0 - 1.0 range, where 1.0 = 2*PI)
    void setPhaseOffset(float offset) {
        m_phaseOffset = offset;
    }

    // Initialize with random phase for natural variation
    void randomizePhase() {
        m_phase = static_cast<float>(rand()) / static_cast<float>(RAND_MAX);
    }

    // Get next sample (output range: 0.0 to 1.0)
    float process() {
        // Sine wave output normalized to 0-1 range
        float output = 0.5f + 0.5f * std::sin(2.0f * M_PI * (m_phase + m_phaseOffset));

        // Advance phase
        m_phase += m_phaseIncrement;
        if (m_phase >= 1.0f) {
            m_phase -= 1.0f;
        }

        return output;
    }

    // Get current value without advancing (for preview/display)
    float getValue() const {
        return 0.5f + 0.5f * std::sin(2.0f * M_PI * (m_phase + m_phaseOffset));
    }

    void reset() {
        m_phase = 0.0f;
    }

private:
    void updatePhaseIncrement() {
        if (m_sampleRate > 0) {
            m_phaseIncrement = static_cast<float>(m_rate / m_sampleRate);
        }
    }

    double m_sampleRate = 44100.0;
    float m_rate = 1.0f;           // Hz
    float m_phase = 0.0f;          // 0.0 - 1.0
    float m_phaseOffset = 0.0f;    // 0.0 - 1.0
    float m_phaseIncrement = 0.0f;
};

} // namespace DeliVerb
