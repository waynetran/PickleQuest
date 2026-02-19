#!/usr/bin/env swift

// Sound generation script for PickleQuest
// Run once: swift Scripts/generate_sounds.swift
// Generates 12 .caf files in PickleQuest/Resources/Sounds/

import AVFoundation
import Foundation

let outputDir = "PickleQuest/Resources/Sounds"

struct ToneSpec {
    let name: String
    let sampleRate: Double = 44100
    let channels: Int = 1
    let generate: (_ sampleRate: Double) -> [Float]
}

func sineWave(frequency: Double, duration: Double, sampleRate: Double, amplitude: Float = 1.0) -> [Float] {
    let count = Int(duration * sampleRate)
    return (0..<count).map { i in
        let t = Double(i) / sampleRate
        return amplitude * Float(sin(2.0 * .pi * frequency * t))
    }
}

func envelope(samples: inout [Float], attack: Int, decay: Int) {
    for i in 0..<min(attack, samples.count) {
        samples[i] *= Float(i) / Float(attack)
    }
    for i in 0..<min(decay, samples.count) {
        let idx = samples.count - 1 - i
        samples[idx] *= Float(i) / Float(decay)
    }
}

func noiseBuffer(count: Int, amplitude: Float = 1.0) -> [Float] {
    (0..<count).map { _ in Float.random(in: -amplitude...amplitude) }
}

func mixBuffers(_ buffers: [[Float]]) -> [Float] {
    let maxLen = buffers.map(\.count).max() ?? 0
    var result = [Float](repeating: 0, count: maxLen)
    for buf in buffers {
        for i in 0..<buf.count {
            result[i] += buf[i]
        }
    }
    let peak = result.map { abs($0) }.max() ?? 1.0
    if peak > 1.0 {
        for i in 0..<result.count { result[i] /= peak }
    }
    return result
}

func appendSamples(_ dest: inout [Float], _ src: [Float], at offset: Int) {
    let needed = offset + src.count
    if dest.count < needed {
        dest.append(contentsOf: [Float](repeating: 0, count: needed - dest.count))
    }
    for i in 0..<src.count {
        dest[offset + i] += src[i]
    }
}

let specs: [ToneSpec] = [
    // Paddle hit: higher pitched transient pop
    ToneSpec(name: "paddle_hit") { sr in
        let count = Int(0.08 * sr)
        var samples = (0..<count).map { i -> Float in
            let t = Double(i) / sr
            let sine = Float(sin(2.0 * .pi * 1100 * t)) * 0.7
            let noise = Float.random(in: -0.3...0.3)
            return sine + noise
        }
        envelope(samples: &samples, attack: Int(0.002 * sr), decay: Int(0.06 * sr))
        return samples
    },

    // Paddle hit smash: higher pitched power hit
    ToneSpec(name: "paddle_hit_smash") { sr in
        let count = Int(0.10 * sr)
        var samples = (0..<count).map { i -> Float in
            let t = Double(i) / sr
            let sine = Float(sin(2.0 * .pi * 900 * t)) * 0.8
            let noise = Float.random(in: -0.4...0.4)
            return sine + noise
        }
        envelope(samples: &samples, attack: Int(0.002 * sr), decay: Int(0.07 * sr))
        return samples
    },

    // Paddle hit distant: higher pitched, quieter
    ToneSpec(name: "paddle_hit_distant") { sr in
        let count = Int(0.06 * sr)
        var samples = (0..<count).map { i -> Float in
            let t = Double(i) / sr
            return Float(sin(2.0 * .pi * 900 * t)) * 0.4
        }
        envelope(samples: &samples, attack: Int(0.003 * sr), decay: Int(0.05 * sr))
        return samples
    },

    // Ball bounce: 90Hz low thud
    ToneSpec(name: "ball_bounce") { sr in
        let count = Int(0.08 * sr)
        var samples = (0..<count).map { i -> Float in
            let t = Double(i) / sr
            let thud = Float(sin(2.0 * .pi * 90 * t)) * 0.8
            let noise = (t < 0.005) ? Float.random(in: -0.2...0.2) : Float(0)
            return thud + noise
        }
        envelope(samples: &samples, attack: Int(0.0005 * sr), decay: Int(0.06 * sr))
        return samples
    },

    // Net thud: dull 150Hz
    ToneSpec(name: "net_thud") { sr in
        let count = Int(0.08 * sr)
        var samples = (0..<count).map { i -> Float in
            let t = Double(i) / sr
            let sine = Float(sin(2.0 * .pi * 150 * t)) * 0.6
            let noise = Float.random(in: -0.2...0.2)
            return sine + noise
        }
        envelope(samples: &samples, attack: Int(0.002 * sr), decay: Int(0.07 * sr))
        return samples
    },

    // Whistle: two-tone 2000+2400Hz
    ToneSpec(name: "whistle") { sr in
        let count = Int(0.30 * sr)
        var samples = (0..<count).map { i -> Float in
            let t = Double(i) / sr
            let a = Float(sin(2.0 * .pi * 2000 * t)) * 0.4
            let b = Float(sin(2.0 * .pi * 2400 * t)) * 0.3
            return a + b
        }
        envelope(samples: &samples, attack: Int(0.01 * sr), decay: Int(0.08 * sr))
        return samples
    },

    // Point chime: ascending triad arpeggio C5-E5-G5
    ToneSpec(name: "point_chime") { sr in
        let noteDuration = 0.12
        let notes: [Double] = [523.25, 659.25, 783.99] // C5, E5, G5
        var result = [Float](repeating: 0, count: Int(0.40 * sr))
        for (idx, freq) in notes.enumerated() {
            let noteCount = Int(noteDuration * sr)
            var note = (0..<noteCount).map { i -> Float in
                let t = Double(i) / sr
                return Float(sin(2.0 * .pi * freq * t)) * 0.5
            }
            envelope(samples: &note, attack: Int(0.005 * sr), decay: Int(0.08 * sr))
            appendSamples(&result, note, at: Int(Double(idx) * noteDuration * sr))
        }
        return result
    },

    // Match win: 5-note fanfare C5-E5-G5-C6-E6
    ToneSpec(name: "match_win") { sr in
        let noteDuration = 0.22
        let notes: [Double] = [523.25, 659.25, 783.99, 1046.5, 1318.5]
        var result = [Float](repeating: 0, count: Int(1.2 * sr))
        for (idx, freq) in notes.enumerated() {
            let noteCount = Int(noteDuration * sr)
            var note = (0..<noteCount).map { i -> Float in
                let t = Double(i) / sr
                return Float(sin(2.0 * .pi * freq * t)) * 0.5
            }
            envelope(samples: &note, attack: Int(0.005 * sr), decay: Int(0.15 * sr))
            appendSamples(&result, note, at: Int(Double(idx) * noteDuration * sr))
        }
        return result
    },

    // Match lose: descending minor 3-note E4-C4-A3
    ToneSpec(name: "match_lose") { sr in
        let noteDuration = 0.18
        let notes: [Double] = [329.63, 261.63, 220.0]
        var result = [Float](repeating: 0, count: Int(0.60 * sr))
        for (idx, freq) in notes.enumerated() {
            let noteCount = Int(noteDuration * sr)
            var note = (0..<noteCount).map { i -> Float in
                let t = Double(i) / sr
                return Float(sin(2.0 * .pi * freq * t)) * 0.5
            }
            envelope(samples: &note, attack: Int(0.005 * sr), decay: Int(0.12 * sr))
            appendSamples(&result, note, at: Int(Double(idx) * noteDuration * sr))
        }
        return result
    },

    // Serve whoosh: higher frequency breathy sweep
    ToneSpec(name: "serve_whoosh") { sr in
        let count = Int(0.15 * sr)
        var samples = noiseBuffer(count: count, amplitude: 0.5)
        // Brighter filter — less low-pass for a higher pitched whoosh
        for i in 1..<samples.count {
            let t = Double(i) / Double(count)
            let mix = Float(0.6 + 0.4 * t)
            samples[i] = samples[i] * mix + samples[i-1] * (1.0 - mix)
        }
        envelope(samples: &samples, attack: Int(0.01 * sr), decay: Int(0.08 * sr))
        return samples
    },

    // Button click: short tick
    ToneSpec(name: "button_click") { sr in
        let count = Int(0.03 * sr)
        var samples = (0..<count).map { i -> Float in
            let t = Double(i) / sr
            return Float(sin(2.0 * .pi * 1200 * t)) * 0.4
        }
        envelope(samples: &samples, attack: Int(0.001 * sr), decay: Int(0.025 * sr))
        return samples
    },

    // Footstep: soft court-shoe scuff (short noise burst, low-pass)
    ToneSpec(name: "footstep") { sr in
        let count = Int(0.05 * sr)
        var samples = noiseBuffer(count: count, amplitude: 0.3)
        // Low-pass filter: running average for muffled court shoe feel
        for i in 1..<samples.count {
            samples[i] = samples[i] * 0.25 + samples[i-1] * 0.75
        }
        // Add very slight tonal thump
        for i in 0..<count {
            let t = Double(i) / sr
            samples[i] += Float(sin(2.0 * .pi * 100 * t)) * 0.15
        }
        envelope(samples: &samples, attack: Int(0.001 * sr), decay: Int(0.035 * sr))
        return samples
    },

    // Footstep sprint: slightly louder/snappier shoe squeak
    ToneSpec(name: "footstep_sprint") { sr in
        let count = Int(0.04 * sr)
        var samples = noiseBuffer(count: count, amplitude: 0.4)
        // Slightly brighter than normal footstep
        for i in 1..<samples.count {
            samples[i] = samples[i] * 0.35 + samples[i-1] * 0.65
        }
        // Sharper tonal thump
        for i in 0..<count {
            let t = Double(i) / sr
            samples[i] += Float(sin(2.0 * .pi * 140 * t)) * 0.2
        }
        envelope(samples: &samples, attack: Int(0.0005 * sr), decay: Int(0.03 * sr))
        return samples
    },

    // Loot reveal: sparkle sweep (rising arpeggiated tones)
    ToneSpec(name: "loot_reveal") { sr in
        let noteDuration = 0.06
        let notes: [Double] = [880, 1047, 1319, 1568, 1760, 2093]
        var result = [Float](repeating: 0, count: Int(0.40 * sr))
        for (idx, freq) in notes.enumerated() {
            let noteCount = Int(noteDuration * sr)
            var note = (0..<noteCount).map { i -> Float in
                let t = Double(i) / sr
                return Float(sin(2.0 * .pi * freq * t)) * 0.35
            }
            envelope(samples: &note, attack: Int(0.003 * sr), decay: Int(0.04 * sr))
            appendSamples(&result, note, at: Int(Double(idx) * noteDuration * sr))
        }
        return result
    },
]

// Write CAF files
func writeCaf(name: String, samples: [Float], sampleRate: Double) throws {
    let url = URL(fileURLWithPath: "\(outputDir)/\(name).caf")
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
    buffer.frameLength = AVAudioFrameCount(samples.count)
    let channelData = buffer.floatChannelData![0]
    for i in 0..<samples.count {
        channelData[i] = samples[i]
    }

    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
    print("  Wrote \(name).caf (\(samples.count) samples, \(String(format: "%.0f", Double(samples.count) / sampleRate * 1000))ms)")
}

// Generate all sounds
print("Generating PickleQuest sound effects...")
try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for spec in specs {
    let samples = spec.generate(spec.sampleRate)
    try writeCaf(name: spec.name, samples: samples, sampleRate: spec.sampleRate)
}

print("Done! Generated \(specs.count) sound files in \(outputDir)/")
