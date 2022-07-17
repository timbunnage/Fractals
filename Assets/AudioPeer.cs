using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent (typeof (AudioSource))]
public class AudioPeer : MonoBehaviour
{
    public Material mat;
    AudioSource audioSource;
    public float[] samples = new float[512];
    public float[] frequencyBands = new float[8];
    public float[] freqBandsBuffer = new float[8];
    private float[] buffDec = new float[8];

    private float[] freqBandsHighest = new float[8];
    public float[] audioBands = new float[8];
    public float[] audioBandsBuffer = new float[8];

    public bool clamp = false;

    // Start is called before the first frame update
    void Start()
    {
        audioSource = GetComponent<AudioSource>();
    }

    // Update is called once per frame
    void Update()
    {
        GetSpectrumAudioSource();
        CreateFrequencyBands();
        CreateFreqBandsBuffer();
        CreateAudioBands();

        if (clamp) {
            mat.SetVector("_LowFreq", new Vector4(audioBandsBuffer[0], audioBandsBuffer[1], audioBandsBuffer[2], audioBandsBuffer[3]));
            mat.SetVector("_HighFreq", new Vector4(audioBandsBuffer[4], audioBandsBuffer[5], audioBandsBuffer[6], audioBandsBuffer[7]));
        }
        else {
            mat.SetVector("_LowFreq", new Vector4(freqBandsBuffer[0], freqBandsBuffer[1], freqBandsBuffer[2], freqBandsBuffer[3]));
            mat.SetVector("_HighFreq", new Vector4(freqBandsBuffer[4], freqBandsBuffer[5], freqBandsBuffer[6], freqBandsBuffer[7]));
        }
    }

    // void FixedUpdate()
    // {
    //     CreateFreqBandsBuffer();
    // }

    void GetSpectrumAudioSource() {
        audioSource.GetSpectrumData(samples, 0, FFTWindow.Blackman);
    }

    void CreateFrequencyBands() {
        int sampleIndex = 0;
        for (int i = 0; i < 8; i++) {
            int sampleCount = i==7 ? (int)Mathf.Pow(2, i+1) + 2: (int)Mathf.Pow(2, i+1);   // number of samples in current band

            float sum = 0;
            for (int j = 0; j < sampleCount; j++) {
                sum += samples[sampleIndex] * (sampleIndex + 1);  // trick from tutorial to amplify high frequencies
                sampleIndex += 1;
            }
            sum /= sampleCount;
            frequencyBands[i] = sum * 100;
        }
    }

    void CreateFreqBandsBuffer() {
        for (int i = 0; i < 8; i++) {
            // set buffer to curr frequency
            if (frequencyBands[i] > freqBandsBuffer[i]) {
                freqBandsBuffer[i] = frequencyBands[i];
                buffDec[i] = 0.005f;
            }
            // gradually decrease buffer
            else if (frequencyBands[i] < freqBandsBuffer[i]) {
                freqBandsBuffer[i] -= buffDec[i];
                buffDec[i] *= 1.2f;
            }
        }
    }

    void CreateAudioBands() {
        for (int i = 0; i < 8; i++) {
            if (frequencyBands[i] > freqBandsHighest[i]) {
                freqBandsHighest[i] = frequencyBands[i];
            }
            audioBands[i] = frequencyBands[i] / freqBandsHighest[i];
            audioBandsBuffer[i] = freqBandsBuffer[i] / freqBandsHighest[i];
        }
    }
}
