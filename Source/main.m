/*
    File: main.m
    
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
#import "OutputFile.h"


static NSInteger sGetMIDIValueForString(NSString *string)
{
    static int map[] = { 12, 14, 16, 17, 19, 21, 23 };

    NSInteger letter  = 0;
    NSInteger quality = 0;
    NSInteger octave  = 0;
    NSInteger midiValue;
    
    const char *cPtr = [string UTF8String];
    char c;
    while ((c = *cPtr)) {
        if      (c >= 'A' && c <= 'G') letter = ((c - 'A') + 5) % 7;
        else if (c >= '0' && c <= '9') octave =  (c - '0');
        else if (c == 'x') quality = 2;
        else if (c == '#') quality++;
        else if (c == 'b') quality--;
        cPtr++;
    }
    
    midiValue = map[letter];
    midiValue += (octave * 12);
    midiValue += quality;

    return midiValue;
}

int main(int argc, char *argv[]) { @autoreleasepool
{
    if (argc != 3) fprintf(stderr, "Usage: PianoPlayer input_file output_wav\n");

    NSError  *error       = nil;
    NSString *inputPath   = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
    NSString *outputPath  = [NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding];
    NSString *inputString = [NSString stringWithContentsOfFile:inputPath encoding:NSUTF8StringEncoding error:&error];

    OutputFile *output = nil;

    if (error) {
        fprintf(stderr, "Could not read contents of %s\n", [inputPath UTF8String]);
        exit(1);
    }

    NSArray *inputLines = [inputString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    for (NSString *line in inputLines) {
        if ([line hasPrefix:@"#"]) continue;

        NSArray *components = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSUInteger i = 0, count = [components count];

        NSString *nameString     = nil;
        NSString *offsetString   = nil; 
        NSString *durationString = nil;
        
        NSMutableArray *options = [NSMutableArray array];
        
        while ((i < count) && [nameString     length] == 0) nameString     = [components objectAtIndex:i++];
        while ((i < count) && [offsetString   length] == 0) offsetString   = [components objectAtIndex:i++];
        while ((i < count) && [durationString length] == 0) durationString = [components objectAtIndex:i++];

        // If only name is specified, the line is a file path
        if ([nameString length] > 0 && ([offsetString length] == 0) && ([durationString length] == 0)) {
            [output write];
            output = [[OutputFile alloc] initWithPath:nameString];
        }

        if (([nameString length] == 0) || ([offsetString length] == 0) || ([durationString length] == 0)) {
            continue;
        }

        while ((i < count)) {
            NSString *string = [components objectAtIndex:i++];
            [options addObject:string];
        }

        int        sampleRate   = [Piano sampleRate];
        NSInteger  midiValue    = sGetMIDIValueForString(nameString);
        NSUInteger offset       = [offsetString   doubleValue] * sampleRate;
        NSUInteger duration     = [durationString doubleValue] * sampleRate;
        NSUInteger decayPadding = 5.0 * sampleRate;

        if (!output) {
            output = [[OutputFile alloc] initWithPath:outputPath];
        }

        [output growBufferToCapacity:(offset + duration + decayPadding)];

        [[Piano sharedInstance] playNote: midiValue
                              intoBuffer: [output buffer]
                                  offset: offset 
                                duration: duration 
                                 options: options];
    }

    [output write];
}
    return 0;
}
