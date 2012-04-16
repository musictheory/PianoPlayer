/*
    File: Piano.m
    
    License: The MIT License

    Copyright (c) 2011-2012 musictheory.net, LLC
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/

#import "Piano.h"


extern short pianoData[];
static const NSUInteger sPianoDataLength = 586349;

static short sNormalizedPeak = 16384;

static double sSilence = 1.0/65535.0;

#define kNumberOfPitches 15


static double sGetFrequency(NSUInteger midiValue)
{
    double m = (double)(midiValue - 69.0) / 12.0;
    return pow(2.0, m) * 440.0;
}



typedef struct {
    double    volume;
    NSInteger root;
    NSInteger high;
    NSInteger pos;
    NSInteger end;
    NSInteger loop;
} KeyGroup;

static KeyGroup kgrp[kNumberOfPitches];


@interface Piano ()
- (void) _applyLimiter;
@end


@implementation Piano {
    short *_data;
}


+ (int) sampleRate
{
    return 22050;
}


+ (id) sharedInstance
{
    static id sharedInstance = nil;
    if (!sharedInstance) sharedInstance = [[self alloc] init];
    return sharedInstance;
}


+ (void) initialize
{
    static dispatch_once_t once;

    dispatch_once(&once, ^{
        kgrp[ 0].volume = 1.0;  kgrp[ 0].root = 36;  kgrp[ 0].high = 37;  kgrp[ 0].pos = 0;       kgrp[ 0].end = 36275;   kgrp[ 0].loop = 14774;
        kgrp[ 1].volume = 1.0;  kgrp[ 1].root = 40;  kgrp[ 1].high = 41;  kgrp[ 1].pos = 36278;   kgrp[ 1].end = 83135;   kgrp[ 1].loop = 16268;
        kgrp[ 2].volume = 1.0;  kgrp[ 2].root = 43;  kgrp[ 2].high = 45;  kgrp[ 2].pos = 83137;   kgrp[ 2].end = 146756;  kgrp[ 2].loop = 33541;
        kgrp[ 3].volume = 1.0;  kgrp[ 3].root = 48;  kgrp[ 3].high = 49;  kgrp[ 3].pos = 146758;  kgrp[ 3].end = 204997;  kgrp[ 3].loop = 21156;
        kgrp[ 4].volume = 1.0;  kgrp[ 4].root = 52;  kgrp[ 4].high = 53;  kgrp[ 4].pos = 204999;  kgrp[ 4].end = 244908;  kgrp[ 4].loop = 17191;
        kgrp[ 5].volume = 1.0;  kgrp[ 5].root = 55;  kgrp[ 5].high = 57;  kgrp[ 5].pos = 244910;  kgrp[ 5].end = 290978;  kgrp[ 5].loop = 23286;
        kgrp[ 6].volume = 1.0;  kgrp[ 6].root = 60;  kgrp[ 6].high = 61;  kgrp[ 6].pos = 290980;  kgrp[ 6].end = 342948;  kgrp[ 6].loop = 18002;
        kgrp[ 7].volume = 1.0;  kgrp[ 7].root = 64;  kgrp[ 7].high = 65;  kgrp[ 7].pos = 342950;  kgrp[ 7].end = 391750;  kgrp[ 7].loop = 19746;
        kgrp[ 8].volume = 1.0;  kgrp[ 8].root = 67;  kgrp[ 8].high = 69;  kgrp[ 8].pos = 391752;  kgrp[ 8].end = 436915;  kgrp[ 8].loop = 22253;
        kgrp[ 9].volume = 1.0;  kgrp[ 9].root = 72;  kgrp[ 9].high = 73;  kgrp[ 9].pos = 436917;  kgrp[ 9].end = 468807;  kgrp[ 9].loop = 8852;
        kgrp[10].volume = 1.0;  kgrp[10].root = 76;  kgrp[10].high = 77;  kgrp[10].pos = 468809;  kgrp[10].end = 492772;  kgrp[10].loop = 9693;
        kgrp[11].volume = 1.0;  kgrp[11].root = 79;  kgrp[11].high = 81;  kgrp[11].pos = 492774;  kgrp[11].end = 532293;  kgrp[11].loop = 10596;
        kgrp[12].volume = 1.0;  kgrp[12].root = 84;  kgrp[12].high = 85;  kgrp[12].pos = 532295;  kgrp[12].end = 560192;  kgrp[12].loop = 6011;
        kgrp[13].volume = 1.0;  kgrp[13].root = 88;  kgrp[13].high = 89;  kgrp[13].pos = 560194;  kgrp[13].end = 574121;  kgrp[13].loop = 3414;
        kgrp[14].volume = 1.0;  kgrp[14].root = 93;  kgrp[14].high = 999; kgrp[14].pos = 574123;  kgrp[14].end = 586343;  kgrp[14].loop = 2399;
    });
}





- (id) init
{
    if (self = [super init]) {
        NSUInteger length = sizeof(short) * sPianoDataLength;
        _data = malloc(length);
        memcpy(_data, pianoData, length);
    }
    
    return self;
}


- (void) dealloc
{
    if (_data) free(_data);
}


#pragma mark -
#pragma mark Limiter

- (double) _findZeroCrossingNearIndex:(double)inIndex
{
    float  a, b;
    double indexOfFutureZeroCrossing = inIndex;
    double indexOfPastZeroCrossing   = inIndex;
    
    NSInteger i = inIndex;
    a = _data[i];
    while (++i < sPianoDataLength) {
        b = _data[i];

        if ((a >= 0 && b < 0) || (b >= 0 && a < 0)) {
            indexOfFutureZeroCrossing = i + (a / (b - a));
            break;
        }

        a = b;
    }

    i = inIndex;
    b = _data[i];
    while (--i > 0) {
        a = _data[i];

        if ((a >= 0 && b < 0) || (b >= 0 && a < 0)) {
            indexOfPastZeroCrossing = i + (a / (b - a));
            break;
        }

        b = a;
    }

    if ((indexOfFutureZeroCrossing - inIndex) < (inIndex - indexOfPastZeroCrossing)) {
        return indexOfFutureZeroCrossing;
    } else {
        return indexOfPastZeroCrossing;
    }
}


- (void) _limitPitchWithSamplesPerCycle:(double)samplesPerCycle start:(NSUInteger)start end:(NSUInteger)end
{
    NSInteger zeroStart = 0;
    NSInteger zeroEnd   = 0;
    
    while (start < (end - samplesPerCycle)) {
        short max = INT16_MIN;
        
        for (NSInteger i = 0 ; i < samplesPerCycle; i++) {
            zeroStart = lround([self _findZeroCrossingNearIndex:start]);
            zeroEnd   = lround([self _findZeroCrossingNearIndex:(start + samplesPerCycle)]);
        }
        
        for (NSInteger i = zeroStart; i < zeroEnd; i++) {
            short sample = pianoData[i];
            if (sample < 0) sample = -sample;
            if (sample > max) max = sample;
        }
        

        // Normalize to peak
        if (max > sNormalizedPeak) {
            for (NSInteger i = zeroStart; i < zeroEnd; i++) {
                _data[i] = pianoData[i] * ((double)sNormalizedPeak / (double)max);
            }        
        }
        
        start += samplesPerCycle;
    }

}

- (void) _applyLimiter
{
    NSInteger k;
    double samplesPerCycle;

    for (k = 0; k < kNumberOfPitches; k++) {
        samplesPerCycle = (22050.0 / (pow(2, ((kgrp[k].root - 69) / 12.0)) * 440.0));
        [self _limitPitchWithSamplesPerCycle:samplesPerCycle start:kgrp[k].pos end:kgrp[k].end];
    }
}


- (void) playNote: (NSUInteger) midiValue
       intoBuffer: (SInt32 *) buffer
           offset: (NSUInteger) offset
         duration: (NSUInteger) duration
          options: (NSArray *) options
{
    __block NSUInteger i, o;

    for (i = 0; i < kNumberOfPitches; i++) {
        if (midiValue <= kgrp[i].high) {
            break;
        }
    }

    KeyGroup k          = kgrp[i];
    double   factor     = sGetFrequency(midiValue) / sGetFrequency(k.root);
    double   sampleRate = (double)[Piano sampleRate];

    __block double decay  = exp(-(1/sampleRate) * exp(-0.6 + 0.033 * (double)midiValue - 1.0));
    __block double env    = 1.0;

    i = 0;
    o = offset;

    void (^addSample)() = ^() {
        double sourceFrameReal = i * factor;
        int    sourceFrame     = (int)sourceFrameReal;
        double realOffset      = sourceFrameReal - sourceFrame;

        while ((k.pos + sourceFrame) > k.end) sourceFrame -= k.loop;

        SInt16 source0 = _data[k.pos +  sourceFrame];
        SInt16 source1 = _data[k.pos + (sourceFrame + 1)];
        
        buffer[o] += k.volume * env * (source0 + (realOffset * (source1 - source0)));
        
        env *= decay;
        o++;
        i++;
    };

    while (o < (offset + duration)) {
        addSample();
    }


    // Do release
    decay = exp(log(sSilence / env) / (sampleRate * 0.25));

    while (env > sSilence) {
        addSample();
    }
}




@end
