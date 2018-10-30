#ifndef _DETECTORS_H_
#define _DETECTORS_H_

// this header file and its implementation are intentionally not specific to use in Lua so that they can be copy-pasted
// into any other project that wants to use them. It's open source so might as well make sharing easy.
// The header exposes a C API along with C++ so that it can be used from .m and .c files and not just .mm and .cpp files

#ifdef __cplusplus
extern "C" {
#endif

#define DETECTORS_BLOCK_SIZE 512
#define TSS_START_CODE 1
#define TSS_STOP_CODE 2
#define POP_CODE 4

  typedef void detectors_t; // just an opaque wrapper for the C++ type
  detectors_t *detectors_new(void);
  void detectors_free(detectors_t *detectors);
  int detectors_process(detectors_t *detectors, const float *buffer);

#ifdef __cplusplus
}
#endif

// Also expose C++ API if used from C++ (or included in the implementation file)
#ifdef __cplusplus

#include <vector>
#include <deque>
#include <Accelerate/Accelerate.h>
class Detectors {
public:
  Detectors();
  ~Detectors();

  bool initialise();

  int process(const float *buffer);

protected:
  int processChunk(const float *buffer);
  void doFFT(const float *buffer);

  // Overlap
  float *m_overlapBuffer;

  // Tss detection
  float m_sensitivity;
  float m_hysterisisFactor;
  float m_lowPassWeight;
  int m_minFrames;
  int m_minFramesLong;

  std::vector<float> m_lowPassBuffer;
  int m_consecutiveMatches;
  unsigned long m_framesSinceSpeech;
  unsigned long m_framesSinceMatch;
  float m_savedOtherBands;

  // Pop detection
  std::vector<float> m_spectrum;
  std::deque<float> m_popBuffer;
  int m_maxShiftDown;
  int m_maxShiftUp;
  float m_popSensitivity;
  unsigned long m_framesSincePop;
  int m_startBin;
  float templateAt(int i, int shift);
  float templateDiff(float maxVal, int shift);
  float diffCol(int templStart, int bufStart, float maxVal, int shift);

  float *m_inReal;
  float *m_window;
  FFTSetup m_fftSetup;
  DSPSplitComplex m_splitData;

  float avgBand(std::vector<float> &frame, size_t low, size_t hi);
};
#endif

#endif
