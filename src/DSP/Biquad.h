#pragma once

#include <cmath>
#include <array>

namespace DeliVerb {

// High-performance biquad filter with various filter types
// Used for EQ, tone shaping, and filtering
class Biquad {
public:
    enum class Type {
        LowPass,
        HighPass,
        BandPass,
        Notch,
        Peak,
        LowShelf,
        HighShelf,
        AllPass
    };

    Biquad() = default;

    void setSampleRate(double sampleRate) {
        m_sampleRate = sampleRate;
    }

    void setCoefficients(Type type, double frequency, double Q, double gainDB = 0.0) {
        if (m_sampleRate <= 0.0) return;

        const double omega = 2.0 * M_PI * frequency / m_sampleRate;
        const double sinOmega = std::sin(omega);
        const double cosOmega = std::cos(omega);
        const double alpha = sinOmega / (2.0 * Q);
        const double A = std::pow(10.0, gainDB / 40.0);

        double b0, b1, b2, a0, a1, a2;

        switch (type) {
            case Type::LowPass:
                b0 = (1.0 - cosOmega) / 2.0;
                b1 = 1.0 - cosOmega;
                b2 = (1.0 - cosOmega) / 2.0;
                a0 = 1.0 + alpha;
                a1 = -2.0 * cosOmega;
                a2 = 1.0 - alpha;
                break;

            case Type::HighPass:
                b0 = (1.0 + cosOmega) / 2.0;
                b1 = -(1.0 + cosOmega);
                b2 = (1.0 + cosOmega) / 2.0;
                a0 = 1.0 + alpha;
                a1 = -2.0 * cosOmega;
                a2 = 1.0 - alpha;
                break;

            case Type::BandPass:
                b0 = alpha;
                b1 = 0.0;
                b2 = -alpha;
                a0 = 1.0 + alpha;
                a1 = -2.0 * cosOmega;
                a2 = 1.0 - alpha;
                break;

            case Type::Notch:
                b0 = 1.0;
                b1 = -2.0 * cosOmega;
                b2 = 1.0;
                a0 = 1.0 + alpha;
                a1 = -2.0 * cosOmega;
                a2 = 1.0 - alpha;
                break;

            case Type::Peak:
                b0 = 1.0 + alpha * A;
                b1 = -2.0 * cosOmega;
                b2 = 1.0 - alpha * A;
                a0 = 1.0 + alpha / A;
                a1 = -2.0 * cosOmega;
                a2 = 1.0 - alpha / A;
                break;

            case Type::LowShelf: {
                const double sqrtA = std::sqrt(A);
                b0 = A * ((A + 1.0) - (A - 1.0) * cosOmega + 2.0 * sqrtA * alpha);
                b1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosOmega);
                b2 = A * ((A + 1.0) - (A - 1.0) * cosOmega - 2.0 * sqrtA * alpha);
                a0 = (A + 1.0) + (A - 1.0) * cosOmega + 2.0 * sqrtA * alpha;
                a1 = -2.0 * ((A - 1.0) + (A + 1.0) * cosOmega);
                a2 = (A + 1.0) + (A - 1.0) * cosOmega - 2.0 * sqrtA * alpha;
                break;
            }

            case Type::HighShelf: {
                const double sqrtA = std::sqrt(A);
                b0 = A * ((A + 1.0) + (A - 1.0) * cosOmega + 2.0 * sqrtA * alpha);
                b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosOmega);
                b2 = A * ((A + 1.0) + (A - 1.0) * cosOmega - 2.0 * sqrtA * alpha);
                a0 = (A + 1.0) - (A - 1.0) * cosOmega + 2.0 * sqrtA * alpha;
                a1 = 2.0 * ((A - 1.0) - (A + 1.0) * cosOmega);
                a2 = (A + 1.0) - (A - 1.0) * cosOmega - 2.0 * sqrtA * alpha;
                break;
            }

            case Type::AllPass:
                b0 = 1.0 - alpha;
                b1 = -2.0 * cosOmega;
                b2 = 1.0 + alpha;
                a0 = 1.0 + alpha;
                a1 = -2.0 * cosOmega;
                a2 = 1.0 - alpha;
                break;
        }

        // Normalize coefficients
        m_b0 = b0 / a0;
        m_b1 = b1 / a0;
        m_b2 = b2 / a0;
        m_a1 = a1 / a0;
        m_a2 = a2 / a0;
    }

    // Direct Form II Transposed - best numerical stability
    float process(float input) {
        const double output = m_b0 * input + m_z1;
        m_z1 = m_b1 * input - m_a1 * output + m_z2;
        m_z2 = m_b2 * input - m_a2 * output;
        return static_cast<float>(output);
    }

    void processBlock(float* buffer, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            buffer[i] = process(buffer[i]);
        }
    }

    void reset() {
        m_z1 = 0.0;
        m_z2 = 0.0;
    }

    // Copy coefficients from another biquad (useful for stereo processing)
    void copyCoefficientsFrom(const Biquad& other) {
        m_b0 = other.m_b0;
        m_b1 = other.m_b1;
        m_b2 = other.m_b2;
        m_a1 = other.m_a1;
        m_a2 = other.m_a2;
    }

private:
    double m_sampleRate = 44100.0;

    // Coefficients
    double m_b0 = 1.0, m_b1 = 0.0, m_b2 = 0.0;
    double m_a1 = 0.0, m_a2 = 0.0;

    // State (Direct Form II Transposed)
    double m_z1 = 0.0, m_z2 = 0.0;
};

// Cascaded biquad for higher-order filters (e.g., Linkwitz-Riley)
template<int Order>
class CascadedBiquad {
    static_assert(Order % 2 == 0, "Order must be even");
    static constexpr int NumStages = Order / 2;

public:
    void setSampleRate(double sampleRate) {
        for (auto& stage : m_stages) {
            stage.setSampleRate(sampleRate);
        }
    }

    void setLinkwitzRileyLP(double frequency) {
        // Linkwitz-Riley is two cascaded Butterworth filters
        // For LR4 (Order=4), we use two 2nd-order Butterworth LP with Q = 0.7071
        for (auto& stage : m_stages) {
            stage.setCoefficients(Biquad::Type::LowPass, frequency, 0.7071067811865476);
        }
    }

    void setLinkwitzRileyHP(double frequency) {
        for (auto& stage : m_stages) {
            stage.setCoefficients(Biquad::Type::HighPass, frequency, 0.7071067811865476);
        }
    }

    float process(float input) {
        float output = input;
        for (auto& stage : m_stages) {
            output = stage.process(output);
        }
        return output;
    }

    void processBlock(float* buffer, int numSamples) {
        for (auto& stage : m_stages) {
            stage.processBlock(buffer, numSamples);
        }
    }

    void reset() {
        for (auto& stage : m_stages) {
            stage.reset();
        }
    }

private:
    std::array<Biquad, NumStages> m_stages;
};

} // namespace DeliVerb
