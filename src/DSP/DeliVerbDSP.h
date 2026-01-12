#pragma once

#include "DelayLine.h"
#include "Reverb.h"
#include "Ducker.h"
#include "Biquad.h"
#include <cmath>
#include <algorithm>

namespace DeliVerb {

// Main DSP processor for DeliVerb Delay-Reverb effect
class DeliVerbDSP {
public:
    // Parameter indices (must match AU parameter tree)
    enum ParamID {
        // Delay parameters
        kDelayTime = 0,      // Delay time in ms (50-2000)
        kDelayRepeat,        // Delay feedback/repeat (0-1)
        kDelayMix,           // Delay wet mix (0-1)

        // Reverb parameters
        kReverbSize,         // Reverb size (0-1)
        kReverbStyle,        // Classic (0) to Atmospheric (1)
        kReverbMix,          // Reverb wet mix (0-1)

        // Delay filters (advanced)
        kDelayLowCut,        // Delay low cut frequency
        kDelayHighCut,       // Delay high cut frequency

        // Reverb filters (advanced)
        kReverbLowCut,       // Reverb low cut frequency
        kReverbHighCut,      // Reverb high cut frequency

        // Ducking (advanced)
        kDuckDelayAmount,    // Delay ducking amount (0-1)
        kDuckReverbAmount,   // Reverb ducking amount (0-1)
        kDuckBehaviour,      // Ducking behaviour (0-1)

        // UI toggle
        kAdvanced,

        kNumParams
    };

    DeliVerbDSP() {
        setDefaultParameters();
    }

    void setSampleRate(double sampleRate) {
        m_sampleRate = sampleRate;

        // Configure delay lines (max 2 seconds)
        m_delayL.setSampleRate(sampleRate);
        m_delayR.setSampleRate(sampleRate);
        m_delayL.setMaxDelayMs(2100.0f);
        m_delayR.setMaxDelayMs(2100.0f);

        // Configure reverb
        m_reverb.setSampleRate(sampleRate);

        // Configure ducker
        m_ducker.setSampleRate(sampleRate);

        // Configure delay filters
        m_delayLowCutL.setSampleRate(sampleRate);
        m_delayLowCutR.setSampleRate(sampleRate);
        m_delayHighCutL.setSampleRate(sampleRate);
        m_delayHighCutR.setSampleRate(sampleRate);

        // Anti-aliasing filter for delay feedback
        m_delayFeedbackFilterL.setSampleRate(sampleRate);
        m_delayFeedbackFilterR.setSampleRate(sampleRate);
        m_delayFeedbackFilterL.setCoefficients(Biquad::Type::LowPass, 12000.0, 0.707);
        m_delayFeedbackFilterR.setCoefficients(Biquad::Type::LowPass, 12000.0, 0.707);

        updateParameters();
    }

    void setParameter(ParamID param, float value) {
        switch (param) {
            case kDelayTime:        m_delayTime = value; break;
            case kDelayRepeat:      m_delayRepeat = value; break;
            case kDelayMix:         m_delayMix = value; break;
            case kReverbSize:       m_reverbSize = value; break;
            case kReverbStyle:      m_reverbStyle = value; break;
            case kReverbMix:        m_reverbMix = value; break;
            case kDelayLowCut:      m_delayLowCut = value; break;
            case kDelayHighCut:     m_delayHighCut = value; break;
            case kReverbLowCut:     m_reverbLowCut = value; break;
            case kReverbHighCut:    m_reverbHighCut = value; break;
            case kDuckDelayAmount:  m_duckDelayAmount = value; break;
            case kDuckReverbAmount: m_duckReverbAmount = value; break;
            case kDuckBehaviour:    m_duckBehaviour = value; break;
            case kAdvanced:         m_advanced = value > 0.5f; break;
            default: break;
        }
        updateParameters();
    }

    float getParameter(ParamID param) const {
        switch (param) {
            case kDelayTime:        return m_delayTime;
            case kDelayRepeat:      return m_delayRepeat;
            case kDelayMix:         return m_delayMix;
            case kReverbSize:       return m_reverbSize;
            case kReverbStyle:      return m_reverbStyle;
            case kReverbMix:        return m_reverbMix;
            case kDelayLowCut:      return m_delayLowCut;
            case kDelayHighCut:     return m_delayHighCut;
            case kReverbLowCut:     return m_reverbLowCut;
            case kReverbHighCut:    return m_reverbHighCut;
            case kDuckDelayAmount:  return m_duckDelayAmount;
            case kDuckReverbAmount: return m_duckReverbAmount;
            case kDuckBehaviour:    return m_duckBehaviour;
            case kAdvanced:         return m_advanced ? 1.0f : 0.0f;
            default: return 0.0f;
        }
    }

    // Stereo processing
    void processStereo(const float* inputL, const float* inputR,
                       float* outputL, float* outputR, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            float dryL = inputL[i];
            float dryR = inputR[i];

            // Calculate ducking gains based on input
            float delayGain, reverbGain;
            m_ducker.process(dryL, dryR, delayGain, reverbGain);

            // ==================== DELAY PROCESSING ====================
            // Read from delay lines
            float delayedL = m_delayL.read(m_delayTime);
            float delayedR = m_delayR.read(m_delayTime + 2.0f); // Slight stereo offset

            // Apply delay filters
            delayedL = m_delayLowCutL.process(delayedL);
            delayedL = m_delayHighCutL.process(delayedL);
            delayedR = m_delayLowCutR.process(delayedR);
            delayedR = m_delayHighCutR.process(delayedR);

            // Apply ducking to delay
            float delayWetL = delayedL * delayGain;
            float delayWetR = delayedR * delayGain;

            // Write to delay lines with feedback
            float feedbackL = m_delayFeedbackFilterL.process(delayedL) * m_delayRepeat;
            float feedbackR = m_delayFeedbackFilterR.process(delayedR) * m_delayRepeat;
            m_delayL.write(dryL + feedbackL);
            m_delayR.write(dryR + feedbackR);

            // ==================== REVERB PROCESSING ====================
            float reverbInL = dryL;
            float reverbInR = dryR;

            // Style-based routing: Atmospheric styles add some delay output to reverb
            if (m_reverbStyle > 0.3f) {
                float delayToReverb = (m_reverbStyle - 0.3f) / 0.7f * 0.3f;
                reverbInL += delayWetL * delayToReverb;
                reverbInR += delayWetR * delayToReverb;
            }

            float reverbWetL, reverbWetR;
            m_reverb.process(reverbInL, reverbInR, reverbWetL, reverbWetR);

            // Apply ducking to reverb
            reverbWetL *= reverbGain;
            reverbWetR *= reverbGain;

            // ==================== MIXING ====================
            // Mix delay
            float withDelayL = dryL + delayWetL * m_delayMix;
            float withDelayR = dryR + delayWetR * m_delayMix;

            // Mix reverb
            outputL[i] = withDelayL * (1.0f - m_reverbMix) + (withDelayL + reverbWetL) * m_reverbMix;
            outputR[i] = withDelayR * (1.0f - m_reverbMix) + (withDelayR + reverbWetR) * m_reverbMix;

            // Apply subtle output limiting to prevent clipping
            outputL[i] = std::tanh(outputL[i] * 0.9f) / 0.9f;
            outputR[i] = std::tanh(outputR[i] * 0.9f) / 0.9f;
        }
    }

    // Mono input, stereo output
    void process(const float* input, float* outputL, float* outputR, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            float dry = input[i];

            // Calculate ducking gains
            float delayGain, reverbGain;
            m_ducker.process(dry, dry, delayGain, reverbGain);

            // ==================== DELAY PROCESSING ====================
            float delayedL = m_delayL.read(m_delayTime);
            float delayedR = m_delayR.read(m_delayTime + 2.0f);

            // Apply delay filters
            delayedL = m_delayLowCutL.process(delayedL);
            delayedL = m_delayHighCutL.process(delayedL);
            delayedR = m_delayLowCutR.process(delayedR);
            delayedR = m_delayHighCutR.process(delayedR);

            // Apply ducking
            float delayWetL = delayedL * delayGain;
            float delayWetR = delayedR * delayGain;

            // Feedback
            float feedbackL = m_delayFeedbackFilterL.process(delayedL) * m_delayRepeat;
            float feedbackR = m_delayFeedbackFilterR.process(delayedR) * m_delayRepeat;
            m_delayL.write(dry + feedbackL);
            m_delayR.write(dry + feedbackR);

            // ==================== REVERB PROCESSING ====================
            float reverbInL = dry;
            float reverbInR = dry;

            if (m_reverbStyle > 0.3f) {
                float delayToReverb = (m_reverbStyle - 0.3f) / 0.7f * 0.3f;
                reverbInL += delayWetL * delayToReverb;
                reverbInR += delayWetR * delayToReverb;
            }

            float reverbWetL, reverbWetR;
            m_reverb.process(reverbInL, reverbInR, reverbWetL, reverbWetR);

            reverbWetL *= reverbGain;
            reverbWetR *= reverbGain;

            // ==================== MIXING ====================
            float withDelayL = dry + delayWetL * m_delayMix;
            float withDelayR = dry + delayWetR * m_delayMix;

            outputL[i] = withDelayL * (1.0f - m_reverbMix) + (withDelayL + reverbWetL) * m_reverbMix;
            outputR[i] = withDelayR * (1.0f - m_reverbMix) + (withDelayR + reverbWetR) * m_reverbMix;

            outputL[i] = std::tanh(outputL[i] * 0.9f) / 0.9f;
            outputR[i] = std::tanh(outputR[i] * 0.9f) / 0.9f;
        }
    }

    void reset() {
        m_delayL.reset();
        m_delayR.reset();
        m_reverb.reset();
        m_ducker.reset();
        m_delayLowCutL.reset();
        m_delayLowCutR.reset();
        m_delayHighCutL.reset();
        m_delayHighCutR.reset();
        m_delayFeedbackFilterL.reset();
        m_delayFeedbackFilterR.reset();
    }

private:
    void setDefaultParameters() {
        m_delayTime = 300.0f;      // 300ms delay
        m_delayRepeat = 0.3f;      // 30% feedback
        m_delayMix = 0.3f;         // 30% wet

        m_reverbSize = 0.5f;       // Medium room
        m_reverbStyle = 0.0f;      // Classic
        m_reverbMix = 0.3f;        // 30% wet

        m_delayLowCut = 80.0f;
        m_delayHighCut = 8000.0f;
        m_reverbLowCut = 100.0f;
        m_reverbHighCut = 10000.0f;

        m_duckDelayAmount = 0.0f;
        m_duckReverbAmount = 0.0f;
        m_duckBehaviour = 0.5f;

        m_advanced = false;
    }

    void updateParameters() {
        // Update reverb
        m_reverb.setSize(m_reverbSize);
        m_reverb.setStyle(m_reverbStyle);
        m_reverb.setLowCut(m_reverbLowCut);
        m_reverb.setHighCut(m_reverbHighCut);

        // Update delay filters
        m_delayLowCutL.setCoefficients(Biquad::Type::HighPass, m_delayLowCut, 0.707);
        m_delayLowCutR.setCoefficients(Biquad::Type::HighPass, m_delayLowCut, 0.707);
        m_delayHighCutL.setCoefficients(Biquad::Type::LowPass, m_delayHighCut, 0.707);
        m_delayHighCutR.setCoefficients(Biquad::Type::LowPass, m_delayHighCut, 0.707);

        // Update ducker
        m_ducker.setDelayAmount(m_duckDelayAmount);
        m_ducker.setReverbAmount(m_duckReverbAmount);
        m_ducker.setBehaviour(m_duckBehaviour);
    }

    double m_sampleRate = 44100.0;

    // Parameters
    float m_delayTime;
    float m_delayRepeat;
    float m_delayMix;
    float m_reverbSize;
    float m_reverbStyle;
    float m_reverbMix;
    float m_delayLowCut;
    float m_delayHighCut;
    float m_reverbLowCut;
    float m_reverbHighCut;
    float m_duckDelayAmount;
    float m_duckReverbAmount;
    float m_duckBehaviour;
    bool m_advanced;

    // DSP components
    DelayLine m_delayL;
    DelayLine m_delayR;
    Reverb m_reverb;
    Ducker m_ducker;

    // Delay filters
    Biquad m_delayLowCutL;
    Biquad m_delayLowCutR;
    Biquad m_delayHighCutL;
    Biquad m_delayHighCutR;
    Biquad m_delayFeedbackFilterL;
    Biquad m_delayFeedbackFilterR;
};

} // namespace DeliVerb
