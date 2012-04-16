/*
    File: OutputFile.m
    
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

#import "OutputFile.h"
#import "Piano.h"


static int sSecondsOfBuffer = 60;

typedef struct {
    char    c[4];                // Always 'RIFF'
    UInt32  packageLength;      
    char    f[4];                // Always 'WAVE'

    char    a[4];                // Always 'fmt '
    UInt32  formatChunkLength;   // Always 0x10
    UInt16  audioFormat;         // Always 0x01
    UInt16  numberOfChannels;
    UInt32  sampleRate;
    UInt32  byteRate;
    UInt16  blockAlign;
    UInt16  bitsPerSample;

    char    b[4];               // Always 'data'
    UInt32  dataChunkLength;
} WAVHeader;


@implementation OutputFile {
    NSString   *_path;
    SInt32     *_buffer;
    NSUInteger  _capacity;
}


- (id) initWithPath:(NSString *)path
{
    if ((self = [super init])) {
        _path     = [path copy];
        _capacity = (sSecondsOfBuffer * [Piano sampleRate]);
        _buffer   = (SInt32 *)calloc(sizeof(SInt32), _capacity);
    }
    
    return self;
}


- (void) dealloc
{
    free(_buffer);
}



- (void) write
{
    fprintf(stdout, "Writing %s\n", [_path UTF8String]);

    NSUInteger i;
    NSUInteger length = _capacity;

    while (length > 0) {
        if (_buffer[length - 1] != 0) {
            break;
        }

        length--;
    }

    NSInteger highest = 0, sample;

    for (i = 0; i < length; i++) {
        sample = _buffer[i];
        if (sample < 0) sample *= -1;
        if (sample > highest) highest = sample;
    }

    WAVHeader h;
    h.c[0] = 'R'; h.c[1] = 'I'; h.c[2] = 'F'; h.c[3] = 'F';
    h.f[0] = 'W'; h.f[1] = 'A'; h.f[2] = 'V'; h.f[3] = 'E';
    h.a[0] = 'f'; h.a[1] = 'm'; h.a[2] = 't'; h.a[3] = ' ';
    h.b[0] = 'd'; h.b[1] = 'a'; h.b[2] = 't'; h.b[3] = 'a';

    h.formatChunkLength = 0x10;
    h.audioFormat       = 0x01;
    h.numberOfChannels  = 1;
    h.sampleRate        = 22050;
    h.bitsPerSample     = 16;
    h.byteRate          = (h.sampleRate * h.numberOfChannels * (h.bitsPerSample / 8));
    h.blockAlign        = (h.bitsPerSample / 8) * h.numberOfChannels;
    h.dataChunkLength   = (length * h.numberOfChannels * (h.bitsPerSample / 8));
    h.packageLength     = h.dataChunkLength + 36;

    FILE *file = fopen([_path UTF8String], "w");
    fwrite(&h, sizeof(WAVHeader), 1, file);

    for (i = 0; i < length; i++) {
        SInt16 s;

        if (highest > 32767) {
            double d = (double)_buffer[i];
            d /= (double)highest;
            d *= 32767.0;
            s = (SInt16)d;

        } else {
            s = _buffer[i];
        }
        
        fwrite(&s, sizeof(SInt16), 1, file);
    }

    fclose(file);
}


- (SInt32 *) buffer
{
    return _buffer;
}


- (void) growBufferToCapacity:(NSUInteger)capacity
{
    if (capacity > _capacity) {
        SInt32    *oldBuffer   = _buffer;
        NSUInteger oldCapacity = _capacity;

        _buffer   = (SInt32 *)calloc(sizeof(SInt32), capacity);
        _capacity = capacity;

        memcpy(_buffer, oldBuffer, (sizeof(SInt32) * oldCapacity));

        free(oldBuffer);
    }
}


@end
