//
//  AudioResampler.hpp
//  TFMediaPlayer
//
//  Created by shiwei on 18/1/11.
//  Copyright © 2018年 shiwei. All rights reserved.
//

#ifndef AudioResampler_hpp
#define AudioResampler_hpp

#include <stdio.h>
#include "TFMPUtilities.h"
extern "C"{
#include <libswresample/swresample.h>
}

namespace tfmpcore {
    
    //inline bool isNeedResamplexx(AVFrame *sourceFrame, TFMPAudioStreamDescription *destDesc);
    
    class AudioResampler{
        
        TFMPAudioStreamDescription adoptedAudioDesc;
        SwrContext *swrCtx = nullptr;
        void initResampleContext(AVFrame *sourceFrame);
        
        TFMPAudioStreamDescription *lastSourceAudioDesc = nullptr;
        
        
    public:
        
        uint8_t **resampledBuffers;
        int resampledLineCount;
        
        void setAdoptedAudioDesc(TFMPAudioStreamDescription adoptedAudioDesc){
            this->adoptedAudioDesc = adoptedAudioDesc;
        }
        
        bool isNeedResample(AVFrame *sourceFrame);
        
        uint8_t **reampleAudioFrame(AVFrame *inFrame, int *outSamples, int *linesize);
    };
}

#endif /* AudioResampler_hpp */
