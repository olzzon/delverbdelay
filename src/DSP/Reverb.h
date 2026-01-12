#pragma once

#include "DelayLine.h"
#include "Biquad.h"
#include <cmath>
#include <array>

namespace DeliVerb {

// Schroeder-style reverb with allpass diffusers and feedback comb filters
// Supports style morphing from Classic to Atmospheric
class Reverb {
public:
    Reverb() = default;

    void setSampleRate(double sampleRate) {
        m_sampleRate = sampleRate;

        // Initialize allpass diffusers with prime number delays
        for (int i = 0; i < kNumAllpass; ++i) {
            m_allpass[i].setSampleRate(sampleRate);
            m_allpass[i].setMaxDelayMs(100.0f);
        }

        // Initialize comb filters with prime number delays
        for (int i = 0; i < kNumComb; ++i) {
            m_combL[i].setSampleRate(sampleRate);
            m_combR[i].setSampleRate(sampleRate);
            m_combL[i].setMaxDelayMs(200.0f);
            m_combR[i].setMaxDelayMs(200.0f);

            m_combFilterL[i].setSampleRate(sampleRate);
            m_combFilterR[i].setSampleRate(sampleRate);
        }

        // Pre-delay
        m_preDelayL.setSampleRate(sampleRate);
        m_preDelayR.setSampleRate(sampleRate);
        m_preDelayL.setMaxDelayMs(100.0f);
        m_preDelayR.setMaxDelayMs(100.0f);

        // Input/output filters
        m_inputLowCutL.setSampleRate(sampleRate);
        m_inputLowCutR.setSampleRate(sampleRate);
        m_inputHighCutL.setSampleRate(sampleRate);
        m_inputHighCutR.setSampleRate(sampleRate);
        m_inputScoopL.setSampleRate(sampleRate);
        m_inputScoopR.setSampleRate(sampleRate);

        updateParameters();
    }

    void setSize(float size) {
        m_size = std::max(0.0f, std::min(1.0f, size));
        updateParameters();
    }

    void setStyle(float style) {
        m_style = std::max(0.0f, std::min(1.0f, style));
        updateParameters();
    }

    void setLowCut(float freqHz) {
        m_lowCutFreq = std::max(20.0f, std::min(2000.0f, freqHz));
        updateFilters();
    }

    void setHighCut(float freqHz) {
        m_highCutFreq = std::max(1000.0f, std::min(20000.0f, freqHz));
        updateFilters();
    }

    void setScoopAmount(float amount) {
        m_scoopAmount = std::max(0.0f, std::min(1.0f, amount));
        updateFilters();
    }

    void process(float inputL, float inputR, float& outputL, float& outputR) {
        // Apply input filters
        float filteredL = m_inputLowCutL.process(inputL);
        filteredL = m_inputHighCutL.process(filteredL);
        filteredL = m_inputScoopL.process(filteredL);
        float filteredR = m_inputLowCutR.process(inputR);
        filteredR = m_inputHighCutR.process(filteredR);
        filteredR = m_inputScoopR.process(filteredR);

        // Pre-delay (increases with size)
        float preDelayMs = 5.0f + m_size * 40.0f;
        m_preDelayL.write(filteredL);
        m_preDelayR.write(filteredR);
        float preL = m_preDelayL.read(preDelayMs);
        float preR = m_preDelayR.read(preDelayMs + 1.5f); // Slight stereo offset

        // Input diffusion through allpass chain
        float diffL = preL;
        float diffR = preR;

        for (int i = 0; i < kNumAllpass; ++i) {
            diffL = processAllpass(m_allpass[i], diffL, m_allpassDelays[i], m_allpassFeedback);
            diffR = processAllpass(m_allpass[i], diffR, m_allpassDelays[i] * 1.03f, m_allpassFeedback);
        }

        // Parallel comb filters
        float combSumL = 0.0f;
        float combSumR = 0.0f;

        for (int i = 0; i < kNumComb; ++i) {
            // Left channel
            float combOutL = m_combL[i].read(m_combDelays[i]);
            combOutL = m_combFilterL[i].process(combOutL);
            m_combL[i].write(diffL + combOutL * m_combFeedback);
            combSumL += combOutL;

            // Right channel (slightly different delays for width)
            float combOutR = m_combR[i].read(m_combDelays[i] * m_stereoSpread);
            combOutR = m_combFilterR[i].process(combOutR);
            m_combR[i].write(diffR + combOutR * m_combFeedback);
            combSumR += combOutR;
        }

        // Scale output
        outputL = combSumL * 0.25f;
        outputR = combSumR * 0.25f;
    }

    void reset() {
        for (int i = 0; i < kNumAllpass; ++i) {
            m_allpass[i].reset();
        }
        for (int i = 0; i < kNumComb; ++i) {
            m_combL[i].reset();
            m_combR[i].reset();
            m_combFilterL[i].reset();
            m_combFilterR[i].reset();
        }
        m_preDelayL.reset();
        m_preDelayR.reset();
        m_inputLowCutL.reset();
        m_inputLowCutR.reset();
        m_inputHighCutL.reset();
        m_inputHighCutR.reset();
        m_inputScoopL.reset();
        m_inputScoopR.reset();
    }

private:
    static constexpr int kNumAllpass = 4;
    static constexpr int kNumComb = 8;

    float processAllpass(DelayLine& delay, float input, float delayMs, float feedback) {
        float delayed = delay.read(delayMs);
        float output = -input + delayed;
        delay.write(input + delayed * feedback);
        return output;
    }

    void updateParameters() {
        // Allpass delays (prime numbers in ms, scaled by size)
        float sizeScale = 0.5f + m_size * 1.5f;
        m_allpassDelays[0] = 4.77f * sizeScale;
        m_allpassDelays[1] = 5.93f * sizeScale;
        m_allpassDelays[2] = 7.11f * sizeScale;
        m_allpassDelays[3] = 8.17f * sizeScale;

        // Style affects diffusion amount
        // Classic (0): Less diffusion, clearer echoes
        // Atmospheric (1): More diffusion, washy sound
        m_allpassFeedback = 0.5f + m_style * 0.25f;

        // Comb filter delays (prime numbers in ms, scaled by size)
        m_combDelays[0] = 25.31f * sizeScale;
        m_combDelays[1] = 26.93f * sizeScale;
        m_combDelays[2] = 28.97f * sizeScale;
        m_combDelays[3] = 30.71f * sizeScale;
        m_combDelays[4] = 32.83f * sizeScale;
        m_combDelays[5] = 34.49f * sizeScale;
        m_combDelays[6] = 36.37f * sizeScale;
        m_combDelays[7] = 38.89f * sizeScale;

        // Feedback increases with size for longer decay
        m_combFeedback = 0.7f + m_size * 0.25f;
        m_combFeedback = std::min(0.98f, m_combFeedback);

        // Style affects comb filter damping
        // Classic: More high frequency damping (warmer)
        // Atmospheric: Less damping (brighter, more diffuse)
        float dampingFreq = 4000.0f + m_style * 8000.0f;
        for (int i = 0; i < kNumComb; ++i) {
            m_combFilterL[i].setCoefficients(Biquad::Type::LowPass, dampingFreq, 0.707);
            m_combFilterR[i].setCoefficients(Biquad::Type::LowPass, dampingFreq, 0.707);
        }

        // Stereo spread increases slightly with style
        m_stereoSpread = 1.02f + m_style * 0.02f;

        updateFilters();
    }

    void updateFilters() {
        m_inputLowCutL.setCoefficients(Biquad::Type::HighPass, m_lowCutFreq, 0.707);
        m_inputLowCutR.setCoefficients(Biquad::Type::HighPass, m_lowCutFreq, 0.707);
        m_inputHighCutL.setCoefficients(Biquad::Type::LowPass, m_highCutFreq, 0.707);
        m_inputHighCutR.setCoefficients(Biquad::Type::LowPass, m_highCutFreq, 0.707);

        // Scoop filter (500Hz center, -12dB max cut)
        float scoopGain = m_scoopAmount * -12.0f;
        m_inputScoopL.setCoefficients(Biquad::Type::Peak, 500.0, 0.7, scoopGain);
        m_inputScoopR.setCoefficients(Biquad::Type::Peak, 500.0, 0.7, scoopGain);
    }

    double m_sampleRate = 44100.0;

    // Parameters
    float m_size = 0.5f;       // Room size (0-1)
    float m_style = 0.0f;      // Classic (0) to Atmospheric (1)
    float m_lowCutFreq = 100.0f;
    float m_highCutFreq = 10000.0f;
    float m_scoopAmount = 0.0f; // Scoop amount (0-1)

    // Derived parameters
    float m_allpassDelays[kNumAllpass];
    float m_allpassFeedback = 0.5f;
    float m_combDelays[kNumComb];
    float m_combFeedback = 0.8f;
    float m_stereoSpread = 1.03f;

    // DSP components
    DelayLine m_allpass[kNumAllpass];
    DelayLine m_combL[kNumComb];
    DelayLine m_combR[kNumComb];
    Biquad m_combFilterL[kNumComb];
    Biquad m_combFilterR[kNumComb];

    DelayLine m_preDelayL;
    DelayLine m_preDelayR;

    Biquad m_inputLowCutL;
    Biquad m_inputLowCutR;
    Biquad m_inputHighCutL;
    Biquad m_inputHighCutR;
    Biquad m_inputScoopL;
    Biquad m_inputScoopR;
};

} // namespace DeliVerb
