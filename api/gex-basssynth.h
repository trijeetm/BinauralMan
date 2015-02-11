//-----------------------------------------------------------------------------
// name: gex-basssynth.h
// desc: BASS software synthesizer wrapper
//
// authors: Ge Wang (ge@ccrma.stanford.edu)
//    based on Amar's BASS renderer from SmuleAudio, from Ge's fluidsynth
//    date: Fall 2011
//    version: 1.0
//-----------------------------------------------------------------------------
#ifndef __GEX_BASSSYNTH_H__
#define __GEX_BASSSYNTH_H__


#include "bass.h"
#include "bassmidi.h"
#include "mo-thread.h"




//-----------------------------------------------------------------------------
// name: class GeXBASSSynth
// desc: SoftSynth class
//-----------------------------------------------------------------------------
class GeXBASSSynth
{
public:
    GeXBASSSynth();
    ~GeXBASSSynth();
    
public:
    // initialization
    bool init( int srate, int polophony );    
    // load a font
    bool load( const char * filename );
    
public:
    // program change
    void programChange( int channel, int program );
    // control change
    void controlChange( int channel, int data2, int data3 );
    // noteOn
    void noteOn( int channel, float pitch, int velocity );
    // pitchBend
    void pitchBend( int channel, float pitchDiff );
    // noteOff
    void noteOff( int channel, int pitch );
    // all notes off
    void allNotesOff( int channel );
    // all notes off all channcels
    void allNotesOffAllChannels();
    // synthesize (stereo)
    bool synthesize2( float * buffer, unsigned int numFrames );
    
protected:
    HSTREAM m_stream;
    HSOUNDFONT m_sf;
    static bool s_isBassInit;
    MoMutex m_mutex;
};




#endif
