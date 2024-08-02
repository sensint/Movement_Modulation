#include <Wire.h>
// #include <elapsedMillis.h>
#include <Audio.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <assert.h>

// TO DO MAIN:
// Change the max and min of sensor to what the sensor actually measures
// Looking at different mappings
// To decide whether to stop the current pulse and play the next or just to play the next after finishing the current pulse

enum Mode {
  MODE_2,     // Continuous Vibration
  MODE_3,     // Motion-Coupled Continous Vibration
  MODE_OFF    // OFF Mode
};

Mode currentMode = MODE_OFF;  // Initialize current mode to MODE_3

//=========== Sensor Constants ===========
float filtered_sensor_value = 0.f;
float last_triggered_sensor_val = 0.f;
static constexpr uint32_t kSensorMinValue = 0;
static constexpr uint32_t kSensorMaxValue = 5359;

//=========== audio variables ===========
AudioSynthWaveform signal;
AudioOutputPT8211 dac;
AudioConnection patchCord1(signal, 0, dac, 0);
AudioConnection patchCord2(signal, 0, dac, 1);

//=========== control flow variables ===========
elapsedMicros pulse_time_us = 0;
bool is_vibrating = false;
uint16_t mapped_bin_id = 0;
uint16_t last_bin_id = 0;

//=========== signal generator ===========
static float kSignalFrequencyHz = 40.f; // Frequency of continuous vibration
static constexpr float kSignalAmp = 1.f;

//=========== other variables ===========
float xValue;
uint16_t condition;
float freqValue;
uint16_t binValue;
uint32_t signalDuration;

//=========== serial ===========
static constexpr int kBaudRate = 115200;

//=========== helper functions ===========
inline void SetupSerial() __attribute__((always_inline));

void SetupSerial() {
  while (!Serial && millis() < 2000);
  Serial.begin(kBaudRate);
  delay(50);
}

void SetupAudio() {
  AudioMemory(20);
  delay(50);  // time for DAC voltage stable
  signal.begin(WAVEFORM_SINE);
  signal.frequency(kSignalFrequencyHz);
}

void StartPulseCV(float freq) {
  signal.begin(WAVEFORM_SINE);
  signal.frequency(freq);
  signal.phase(0.0);
  signal.amplitude(kSignalAmp);
  pulse_time_us = 0;
  is_vibrating = true;
}

void StopPulse() {
  signal.amplitude(0.f);
  is_vibrating = false;
}

void GenerateContinuousVibration() {
  signal.begin(WAVEFORM_SINE);
  signal.frequency(kSignalFrequencyHz);
  signal.amplitude(kSignalAmp);
  is_vibrating = true;
}

void GenerateMotionCoupledVibration(float measuredDistance, float freq, uint16_t bin) {
  mapped_bin_id = bin;

  if (mapped_bin_id != last_bin_id) {
    // Uncomment below to stop the current vibration and play the next one.
    if (is_vibrating) {  // This loop is for the case when we want to stop the ongoing vibration and start the next one.
      StopPulse();
      delayMicroseconds(50);
    }
    StartPulseCV(freq);
    last_bin_id = mapped_bin_id;
  }
  signalDuration = 3 * 1000 * 1000* 1 / freq;
  if (is_vibrating && pulse_time_us >= signalDuration) {
    StopPulse();
  }
}

void setup() {
  SetupSerial();
  SetupAudio();
}

void loop() {

  if (Serial.available() > 0) {
    String data = Serial.readStringUntil('\n');  // Read the incoming data until newline

    data.trim();  // Remove any leading/trailing whitespace
    if (data.length() > 0) {
      int firstCommaIndex = data.indexOf(',');
      int secondCommaIndex = data.indexOf(',', firstCommaIndex + 1);
      int thirdCommaIndex = data.indexOf(',', secondCommaIndex + 1);

      if (firstCommaIndex > -1 && secondCommaIndex > -1 && thirdCommaIndex > -1) {
        String xValueStr = data.substring(0, firstCommaIndex);
        String conditionStr = data.substring(firstCommaIndex + 1, secondCommaIndex);
        String freqValueStr = data.substring(secondCommaIndex + 1, thirdCommaIndex);
        String binValueStr = data.substring(thirdCommaIndex + 1);

        xValue = xValueStr.toInt();
        condition = conditionStr.toInt();
        freqValue = freqValueStr.toInt();
        binValue = binValueStr.toInt();
      }
    }
  }
  // Map the sensor value to the bin numbers
  mapped_bin_id = map(xValue, kSensorMinValue, kSensorMaxValue, 0, binValue);

  // Switch between the modes of operation based on the user preference
  switch (condition) {
    case 1:
      currentMode = MODE_OFF;  // OFF mode
      break;
    case 2:
      currentMode = MODE_2;  //Continuous Vibration
      break;
    case 3:
      currentMode = MODE_3;  //Motion Coupled Vibration
      break;
  }

  switch (currentMode) {
    case MODE_OFF:
      StopPulse();
      break;
    case MODE_2:
      GenerateContinuousVibration();
      break;
    case MODE_3:
      GenerateMotionCoupledVibration(xValue, freqValue, mapped_bin_id);
      break;
  }
}
