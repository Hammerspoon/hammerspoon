#include "detectors.h"

#include <iostream>
#include <numeric>
#include <algorithm>
#include <cmath>
#include <limits>

using namespace std;

#include "popTemplate.h"

static const bool kDelayMatch = false;

static const int kBlockSize = DETECTORS_BLOCK_SIZE;
static const int kLogBlockSize = 9;
static const int kSpectrumSize = kBlockSize/2;
static const int kWindowSize = kBlockSize;

static const int kNumSteps = 4;
static const int kStepSize = kBlockSize / kNumSteps;

static const size_t kMainBandLow = 40;
static const size_t kMainBandHi = 100;
static const size_t kOptionalBandHi = 180;

static const size_t kLowerBandLow = 3;
static const size_t kLowerBandHi = kMainBandLow;
static const size_t kUpperBandLo = kOptionalBandHi;
static const size_t kUpperBandHi = kSpectrumSize;

static const float kDefaultLowPassWeight = 0.6;
static const int kSpeechShadowTime = 100;
static const float kSpeechThresh = 0.5;

Detectors::Detectors() {
  m_overlapBuffer = new float[kBlockSize * 2];

  // === Tss Detection
  m_sensitivity = 5.0;
  m_hysterisisFactor = 0.4;
  m_minFrames = 20;
  m_minFramesLong = 100;
  m_lowPassWeight = kDefaultLowPassWeight;

  // === Pop detection
  m_startBin = 2;
  m_maxShiftDown = 4;
  m_maxShiftUp = 2;
  m_popSensitivity = 8.5;
  m_framesSincePop = 0;

  // debugLog = new std::ofstream("/Users/tristan/misc/popclick.log");

  // === FFT
  m_inReal = new float[kBlockSize];
  m_splitData.realp = new float[kSpectrumSize];
  m_splitData.imagp = new float[kSpectrumSize];
  m_window = new float[kWindowSize];
  memset(m_window, 0, sizeof(float) * kWindowSize);
  vDSP_hann_window(m_window, kWindowSize, vDSP_HANN_NORM);

  m_fftSetup = vDSP_create_fftsetup(kLogBlockSize, FFT_RADIX2);
}

Detectors::~Detectors() {
  delete[] m_overlapBuffer;

  delete[] m_inReal;
  delete[] m_splitData.realp;
  delete[] m_splitData.imagp;
  delete[] m_window;
  // delete debugLog;

  vDSP_destroy_fftsetup(m_fftSetup);
}

bool Detectors::initialise() {
  // Real initialisation work goes here!
  m_savedOtherBands = 0.0002;
  m_consecutiveMatches = 0;
  m_framesSinceSpeech = 1000;
  m_framesSinceMatch = 1000;
  m_lowPassBuffer.resize(kSpectrumSize, 0.0);

  m_spectrum.resize(kSpectrumSize, 0.0);
  m_popBuffer.clear();
  for(unsigned i = 0; i < kBufferSize; ++i) {
    m_popBuffer.push_back(0.0);
  }

  return true;
}

int Detectors::process(const float *buffer) {
  // return processChunk(buffer);
  // copy last frame to start of the buffer
  std::copy(m_overlapBuffer+kBlockSize, m_overlapBuffer+(kBlockSize*2), m_overlapBuffer);
  // copy new input to the second half of the overlap buffer
  std::copy(buffer,buffer+kBlockSize,m_overlapBuffer+kBlockSize);

  int result = 0;
  for(int i = 0; i < kNumSteps; ++i) {
    float *ptr = m_overlapBuffer+((i+1)*kStepSize);
    result |= processChunk(ptr);
  }
  return result;
}

void Detectors::doFFT(const float *buffer) {
  vDSP_vmul(buffer, 1, m_window, 1, m_inReal, 1, kBlockSize);
  vDSP_ctoz(reinterpret_cast<DSPComplex*>(m_inReal), 2, &m_splitData, 1, kSpectrumSize);
  vDSP_fft_zrip(m_fftSetup, &m_splitData, 1, kLogBlockSize, FFT_FORWARD);
  m_splitData.imagp[0] = 0.0f;

  float scale = 1.0f / static_cast<float>(2 * kBlockSize);
  vDSP_vsmul(m_splitData.realp, 1, &scale, m_splitData.realp, 1, kSpectrumSize);
  vDSP_vsmul(m_splitData.imagp, 1, &scale, m_splitData.imagp, 1, kSpectrumSize);
}

int Detectors::processChunk(const float *buffer) {
  doFFT(buffer);

  int result = 0;
  size_t n = kSpectrumSize;

  for (size_t i = 0; i < n; ++i) {
    float real = m_splitData.realp[i];
    float imag = m_splitData.imagp[i];
    float newVal = real * real + imag * imag;
    m_spectrum[i] = newVal;
    m_lowPassBuffer[i] = m_lowPassBuffer[i]*(1.0f-m_lowPassWeight) + newVal*m_lowPassWeight;

    // infinite values happen non-deterministically, probably due to glitchy audio input at start of recording
    // but inifinities it could mess up things forever
    if(m_lowPassBuffer[i] >= numeric_limits<float>::infinity()) {
      std::fill(m_lowPassBuffer.begin(), m_lowPassBuffer.end(), 0.0f);
      return 0; // discard the frame, it's probably garbage
    }
  }

  float lowerBand = avgBand(m_lowPassBuffer, kLowerBandLow, kLowerBandHi);
  float mainBand = avgBand(m_lowPassBuffer, kMainBandLow, kMainBandHi);
  float upperBand = avgBand(m_lowPassBuffer, kUpperBandLo, kUpperBandHi);

  m_framesSinceSpeech += 1;
  if(lowerBand > kSpeechThresh) {
    m_framesSinceSpeech = 0;
  }

  float debugMarker = 0.0002;
  float matchiness = mainBand / ((lowerBand+upperBand)/2.0f);
  bool outOfShadow = m_framesSinceSpeech > kSpeechShadowTime;
  int immediateMatchFrame = kDelayMatch ? m_minFramesLong : m_minFrames;
  m_framesSinceMatch += 1;
  if(((matchiness >= m_sensitivity) ||
      (m_consecutiveMatches > 0 && matchiness >= m_sensitivity*m_hysterisisFactor) ||
      (m_consecutiveMatches > immediateMatchFrame && (mainBand/m_savedOtherBands) >= m_sensitivity*m_hysterisisFactor*0.5f))
     && outOfShadow) {
    debugMarker = 0.01;
    // second one in double "tss" came earlier than trigger timer
    if(kDelayMatch && m_consecutiveMatches == 0 && m_framesSinceMatch <= m_minFramesLong) {
      result |= TSS_START_CODE;
      result |= TSS_STOP_CODE;
      m_framesSinceMatch = 1000;
    }

    m_consecutiveMatches += 1;
    if(kDelayMatch && m_consecutiveMatches == m_minFrames) {
      m_framesSinceMatch = m_consecutiveMatches;
    } else if(m_consecutiveMatches == immediateMatchFrame) {
      debugMarker = 1.0;
      result |= TSS_START_CODE;
      m_savedOtherBands = ((lowerBand+upperBand)/2.0f);
    }
  } else {
    bool delayedMatch = kDelayMatch && (m_framesSinceMatch == m_minFramesLong && outOfShadow);
    if(delayedMatch) {
      result |= TSS_START_CODE;
    }
    if(m_consecutiveMatches >= immediateMatchFrame || delayedMatch) {
      debugMarker = 2.0;
      result |= TSS_STOP_CODE;
    }
    m_consecutiveMatches = 0;
  }

  // ===================== Pop Detection =================================
  // update buffer forward one time step
  for(unsigned i = 0; i < kBufferPrimaryHeight; ++i) {
    m_popBuffer.pop_front();
    m_popBuffer.push_back(m_spectrum[i]);
  }
  // high frequencies aren't useful so we bin them all together
  m_popBuffer.pop_front();
  float highSum = accumulate(m_spectrum.begin()+kBufferPrimaryHeight,m_spectrum.end(),0.0);
  m_popBuffer.push_back(highSum);

  std::deque<float>::iterator maxIt = max_element(m_popBuffer.begin(), m_popBuffer.end());
  float minDiff = 10000000.0;
  for(int i = -m_maxShiftUp; i < m_maxShiftDown; ++i) {
    float diff = templateDiff(*maxIt, i);
    if(diff < minDiff) minDiff = diff;
  }

  m_framesSincePop += 1;
  if(minDiff < m_popSensitivity && m_framesSincePop > 15) {
    result |= POP_CODE; // Detected pop
    m_framesSincePop = 0;
  }

  // *debugLog << lowerBand << ' ' << mainBand << ' ' << optionalBand << ' ' << upperBand << '-' << matchiness << ' ' << debugMarker << std::endl;
  return result;
}

float Detectors::avgBand(std::vector<float> &frame, size_t low, size_t hi) {
  float sum = 0;
  for (size_t i = low; i < hi; ++i) {
    sum += frame[i];
  }
  return sum / (hi - low);
}

float Detectors::templateAt(int i, int shift) {
  int bin = i % kBufferHeight;
  if(i % kBufferHeight >= kBufferPrimaryHeight) {
    return kPopTemplate[i]/kPopTemplateMax;
  }
  if(bin+shift < 0 || bin+shift >= kBufferPrimaryHeight) {
    return 0.0;
  }
  return kPopTemplate[i+shift]/kPopTemplateMax;
}

float Detectors::diffCol(int templStart, int bufStart, float maxVal, int shift) {
  float diff = 0;
  for(unsigned i = m_startBin; i < kBufferHeight; ++i) {
    float d = templateAt(templStart+i, shift) - m_popBuffer[bufStart+i]/maxVal;
    diff += abs(d);
  }
  return diff;
}

float Detectors::templateDiff(float maxVal, int shift) {
  float diff = 0;
  for(unsigned i = 0; i < kBufferSize; i += kBufferHeight) {
    diff += diffCol(i,i, maxVal,shift);
  }
  return diff;
}

extern "C" {
  detectors_t *detectors_new() {
    Detectors *dets = new Detectors();
    dets->initialise();
    return reinterpret_cast<detectors_t*>(dets);
  }
  void detectors_free(detectors_t *detectors) {
    Detectors *dets = reinterpret_cast<Detectors*>(detectors);
    delete dets;
  }
  int detectors_process(detectors_t *detectors, const float *buffer) {
    Detectors *dets = reinterpret_cast<Detectors*>(detectors);
    return dets->process(buffer);
  }
}

