#pragma once

#include <cmath>
#include <algorithm>

namespace DeliVerb {

// Envelope follower with attack/release for ducking control
class EnvelopeFollower {
public:
    EnvelopeFollower() = default;

    void setSampleRate(double sampleRate) {
        m_sampleRate = sampleRate;
        updateCoefficients();
    }

    void setAttackMs(float attackMs) {
        m_attackMs = attackMs;
        updateCoefficients();
    }

    void setReleaseMs(float releaseMs) {
        m_releaseMs = releaseMs;
        updateCoefficients();
    }

    float process(float input) {
        float absInput = std::abs(input);

        if (absInput > m_envelope) {
            // Attack phase
            m_envelope = m_attackCoeff * m_envelope + (1.0f - m_attackCoeff) * absInput;
        } else {
            // Release phase
            m_envelope = m_releaseCoeff * m_envelope + (1.0f - m_releaseCoeff) * absInput;
        }

        return m_envelope;
    }

    void reset() {
        m_envelope = 0.0f;
    }

private:
    void updateCoefficients() {
        if (m_sampleRate <= 0) return;

        // Time constant to coefficient conversion
        // coeff = exp(-1 / (time_in_seconds * sample_rate))
        m_attackCoeff = std::exp(-1.0f / (m_attackMs * 0.001f * static_cast<float>(m_sampleRate)));
        m_releaseCoeff = std::exp(-1.0f / (m_releaseMs * 0.001f * static_cast<float>(m_sampleRate)));
    }

    double m_sampleRate = 44100.0;
    float m_attackMs = 10.0f;
    float m_releaseMs = 100.0f;
    float m_attackCoeff = 0.99f;
    float m_releaseCoeff = 0.9999f;
    float m_envelope = 0.0f;
};

// Ducker for delay and reverb with behaviour control
// Reduces effect level when input signal is present
class Ducker {
public:
    Ducker() = default;

    void setSampleRate(double sampleRate) {
        m_sampleRate = sampleRate;
        m_envelopeFollower.setSampleRate(sampleRate);
        m_envelopeFollower.setAttackMs(5.0f);   // Fast attack
        m_envelopeFollower.setReleaseMs(150.0f); // Medium release
    }

    // Amount of ducking (0-1) - how much the effect is reduced when input is present
    void setDelayAmount(float amount) {
        m_delayAmount = std::max(0.0f, std::min(1.0f, amount));
    }

    void setReverbAmount(float amount) {
        m_reverbAmount = std::max(0.0f, std::min(1.0f, amount));
    }

    // Behaviour (0-1):
    // 0 = Duck delay while playing, swell reverb when stopping
    // 0.5 = Both ducked equally
    // 1 = Duck reverb while playing, swell delay when stopping
    void setBehaviour(float behaviour) {
        m_behaviour = std::max(0.0f, std::min(1.0f, behaviour));
    }

    // Process input signal and calculate ducking gains for delay and reverb
    void process(float inputL, float inputR, float& delayGain, float& reverbGain) {
        // Follow the input envelope
        float envelope = m_envelopeFollower.process((std::abs(inputL) + std::abs(inputR)) * 0.5f);

        // Normalize envelope (assuming typical audio levels)
        float normalizedEnv = std::min(1.0f, envelope * 4.0f);

        // Calculate base ducking (higher envelope = more ducking)
        float baseDucking = normalizedEnv;

        // Apply behaviour to distribute ducking between delay and reverb
        // behaviour = 0: delay gets full ducking, reverb gets inverse
        // behaviour = 1: reverb gets full ducking, delay gets inverse
        float delayDuckFactor = 1.0f - m_behaviour;  // 1.0 at behaviour=0, 0.0 at behaviour=1
        float reverbDuckFactor = m_behaviour;        // 0.0 at behaviour=0, 1.0 at behaviour=1

        // Calculate individual duck amounts
        float delayDuck = baseDucking * delayDuckFactor * m_delayAmount;
        float reverbDuck = baseDucking * reverbDuckFactor * m_reverbAmount;

        // When not playing (low envelope), create swell effect
        // The effect that was ducked should swell up
        float invEnv = 1.0f - normalizedEnv;
        float delaySwell = invEnv * (1.0f - delayDuckFactor) * m_delayAmount * 0.3f;
        float reverbSwell = invEnv * (1.0f - reverbDuckFactor) * m_reverbAmount * 0.3f;

        // Combine ducking and swell
        // Gain = 1.0 - duck + swell, clamped to 0-1
        delayGain = std::max(0.0f, std::min(1.0f, 1.0f - delayDuck + delaySwell));
        reverbGain = std::max(0.0f, std::min(1.0f, 1.0f - reverbDuck + reverbSwell));
    }

    void reset() {
        m_envelopeFollower.reset();
    }

private:
    double m_sampleRate = 44100.0;
    EnvelopeFollower m_envelopeFollower;

    float m_delayAmount = 0.0f;   // 0-1
    float m_reverbAmount = 0.0f;  // 0-1
    float m_behaviour = 0.5f;     // 0-1 (0=duck delay, 1=duck reverb)
};

} // namespace DeliVerb
