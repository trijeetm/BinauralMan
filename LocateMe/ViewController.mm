//
//  ViewController.m
//  BinauralMan
//
//  Created by Trijeet Mukhopadhyay on 2/3/15.
//  Copyright (c) 2015 blah. All rights reserved.
//

//#import "Clarinet.h"

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <vector>
#import <math.h>

#import "mo-audio.h"
#import "mo-fun.h"

#import "bassmidi.h"

// defines
#define SRATE 44100
#define N_CHANNELS 16

// audio generator
//stk::Clarinet *clueSounder;

// clues
std::vector <CLLocation *> clues;
int currClue = 0;
BOOL collectedAllClues = false;
bool clueSounderOn = false;

// location metrics
float minDistToHearClue = 60.0;
float distanceToClue = -1.0;

float minDistToCollectClue = 10.0;

// boost hearing drugs
bool boostHearing = false;
int boostHearingFactor = 5;
int boostHearingDuration = 16;      // in beats
int boostRemaining = boostHearingDuration;

// BASS
HSTREAM stream;
BASS_MIDI_FONT fonts[1];

// audio constants
int ambientChan = 0;
int taikoChan = 1;
int taikoFreq = 32;
int clueSounderChan = 3;

// tempo/beats
int g_bpm = 90;
float g_t = 0;
float g_acculumator = 0;
uint beatCounter = 0;
bool beatUsed = false;

@interface ViewController () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *firstClueLocation;
@property (strong, nonatomic) IBOutlet UILabel *latitudeLabel;
@property (strong, nonatomic) IBOutlet UILabel *longitudeLabel;
@property (strong, nonatomic) IBOutlet UILabel *accuracyLabel;
@property (strong, nonatomic) IBOutlet UILabel *distanceLabel;

@end

@implementation ViewController

DWORD CALLBACK BASSCallback(HSTREAM handle, void *buffer, DWORD length, void *user) {
//    NSLog(@"CB %d", length);
//    g_t += frameSize;
    
    float tempoPeriod = SRATE / (g_bpm / 60.0);
    // beat event
    if (g_acculumator > tempoPeriod) {
        g_acculumator -= tempoPeriod;
        beatCounter++;
        beatUsed = false;
        
        if (boostHearing)
            boostRemaining--;
    }
    g_acculumator += 512;
    
//    for (UInt32 i = 0; i < frameSize; i++) {
        // synthesize
        // buffer[i*2] = clueSounder->tick() * clueSounderAmplifier;
        // silence
//        buffer[i*2+1] = buffer[i*2] = 0;
//    }
    
    float clueSounderAmplifier;
    float _minDistToHearClue = minDistToHearClue * (boostHearing ? boostHearingFactor : 1);
    if ((_minDistToHearClue == -1) || (distanceToClue == -1) || (_minDistToHearClue - distanceToClue) <= 0 || collectedAllClues)
        clueSounderAmplifier = 0;
    else
        clueSounderAmplifier = pow(2.0 * ((_minDistToHearClue - distanceToClue) / _minDistToHearClue), 2);
    
//     beat independant audio
//     modulate clueSounder volume with distance
    BASS_MIDI_StreamEvent(stream, clueSounderChan, MIDI_EVENT_VOLUME, 127 * clueSounderAmplifier);
    
//     beat dependant audio
    if (beatUsed == false) {
        if (beatCounter % taikoFreq == 0) {
            changeProgam(taikoChan, 116);
            BASS_MIDI_StreamEvent(stream, taikoChan, MIDI_EVENT_REVERB, 127);
            playNote(taikoChan, 12, 127);
            playNote(taikoChan, 19, 127);
            playNote(taikoChan, 24, 127);
            playNote(taikoChan, 31, 127);
            playNote(taikoChan, 36, 127);
            playNote(taikoChan, 48, 127);
        }
    }
    beatUsed = true;
    
    return length;
}

void audioCallback( Float32 * buffer, UInt32 frameSize, void * userData ) {
    g_t += frameSize;
    
    float tempoPeriod = SRATE / (g_bpm / 60.0);
    // beat event
    if (g_acculumator > tempoPeriod) {
        g_acculumator -= tempoPeriod;
        beatCounter++;
        beatUsed = false;
        
        if (boostHearing)
            boostRemaining--;
    }
    g_acculumator += frameSize;
    
    for (UInt32 i = 0; i < frameSize; i++) {
        // synthesize
        // buffer[i*2] = clueSounder->tick() * clueSounderAmplifier;
        // silence
        buffer[i*2+1] = buffer[i*2] = 0;
    }
    
    float clueSounderAmplifier;
    float _minDistToHearClue = minDistToHearClue;
    if ((_minDistToHearClue == -1) || (distanceToClue == -1) || (_minDistToHearClue - distanceToClue) <= 0 || collectedAllClues)
        clueSounderAmplifier = 0;
    else
        clueSounderAmplifier = pow(2.0 * ((_minDistToHearClue - distanceToClue) / _minDistToHearClue), 2);
    
    // beat independant audio
    // modulate clueSounder volume with distance
//    BASS_MIDI_StreamEvent(stream, clueSounderChan, MIDI_EVENT_VOLUME, 127 * clueSounderAmplifier);
    
    // beat dependant audio
//    if (beatUsed == false) {
//        if (beatCounter % taikoFreq == 0) {
//            changeProgam(taikoChan, 116);
//            BASS_MIDI_StreamEvent(stream, taikoChan, MIDI_EVENT_REVERB, 127);
//            playNote(taikoChan, 12, 127);
//            playNote(taikoChan, 19, 127);
//            playNote(taikoChan, 24, 127);
//            playNote(taikoChan, 31, 127);
//            playNote(taikoChan, 36, 127);
//            playNote(taikoChan, 48, 127);
//        }
//    }
    beatUsed = true;

//    if (boostRemaining <= 0) {
//        boostHearing = false;
//        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ear enhancing drugs wore off"
//                                                        message:@"Your hearing is now normal. Wait for a while before taking drugs again"
//                                                       delegate:nil
//                                              cancelButtonTitle:@"OK"
//                                              otherButtonTitles:nil];
//        [alert show];
//
//    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // locationManager init
    _locationManager = [[CLLocationManager alloc] init];
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
    self.locationManager.delegate = self;
    
    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.locationManager requestWhenInUseAuthorization];
    }
    NSLog(@"leggo");
    [self.locationManager startUpdatingLocation];
    
    // Start heading updates.
//    if ([CLLocationManager headingAvailable]) {
//        self.locationManager.headingFilter = 5;
//        NSLog(@"leggo heading");
//        [self.locationManager startUpdatingHeading];
//    }
    
    // clues init
    
    // CCRMA
//    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.4206994, -122.1720117) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
//    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.4212873, -122.1719312) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
//    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.4214279, -122.1714216) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
//    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.4215174, -122.1707618) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    
    // BrannerPL/Escondido/BrannerCY/Wilbur/EscondidoTA/Crothers
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.425535, -122.162451) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.424663, -122.162405) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.425166, -122.162958) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.424852, -122.164095) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.425227, -122.164841) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.426062, -122.164117) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    
    // init instrument
//    clueSounder = new stk::Clarinet();
//    clueSounder->setFrequency(440);
//    clueSounder->noteOn(440, 1);
    
//    // log
//    NSLog( @"starting real-time audio..." );
//    
//    // init the audio layer
//    bool result = MoAudio::init(SRATE, 32, 2);
//    if( !result )
//    {
//        // something went wrong
//        NSLog( @"cannot initialize real-time audio!" );
//        // bail out
//        return;
//    }
//    
//    // start the audio layer, registering a callback method
//    result = MoAudio::start( audioCallback, NULL );
//    if( !result )
//    {
//        // something went wrong
//        NSLog( @"cannot start real-time audio!" );
//        // bail out
//        return;
//    }
    
    // init BASS
    initBASS();
    
    fireClueSounder(10);
}

void fireClueSounder(DWORD gain) {
    changeProgam(clueSounderChan, 16);
//    BASS_MIDI_StreamEvent(stream, clueSounderChan, MIDI_EVENT_REVERB, 127);
    playNote(clueSounderChan, 24, gain);
    playNote(clueSounderChan, 36, gain);
    playNote(clueSounderChan, 43, gain);
    playNote(clueSounderChan, 48, gain);
    playNote(clueSounderChan, 60, gain);
//    playNote(clueSounderChan, 67, 127);
//    playNote(clueSounderChan, 72, 127);
}

void initBASS() {
    int err;
    
    // check the correct BASS was loaded
    if (HIWORD(BASS_GetVersion()) != BASSVERSION)
        NSLog(@"An incorrect version of BASS was loaded");
    
    // initialize default output device
    if (!BASS_Init(-1, SRATE, 0, 0, NULL))
        NSLog(@"Can't initialize output device");

    HSTREAM _stream = BASS_StreamCreate(SRATE, N_CHANNELS, 0, BASSCallback, NULL);
//    BASS_SetConfig(BASS_CONFIG_BUFFER, 512); // set the buffer length
    BASS_ChannelSetAttribute(_stream, BASS_ATTRIB_NOBUFFER, 1);
    BASS_ChannelPlay(_stream, 0);
    
    // might not need 16 input channels but it also might not hurt anything
    stream = BASS_MIDI_StreamCreate(N_CHANNELS, 0, 1); // create the MIDI stream (16 MIDI channels for device input + 1 for keyboard input)
    
    BASS_ChannelSetAttribute(stream, BASS_ATTRIB_NOBUFFER, 1); // no buffering for minimum latency

    for(int i = 0; i < N_CHANNELS; i++){
        BASS_ChannelPlay(stream, 0); // start it
        err = BASS_ErrorGetCode();
        if (err != 0) {
            NSLog(@"Bass error code %d after initializing channel %d", err, i);
            return;
        }
    }
    
//    HSOUNDFONT sfont1 = BASS_MIDI_FontInit([[[NSBundle mainBundle] pathForResource: @"ChoriumRevA" ofType: @"SF2"] UTF8String], 0);
    HSOUNDFONT sfont1 = BASS_MIDI_FontInit([[[NSBundle mainBundle] pathForResource: @"rocking8m11e" ofType: @"sf2"] UTF8String], 0);
    
    err = BASS_ErrorGetCode();
    if (err != 0) {
        NSLog(@"Bass error code %d after loading soundfont", err);
        return;
    }
    
    fonts[0].font = sfont1;
    fonts[0].preset = -1;
    fonts[0].bank = 0;
    
    BASS_MIDI_StreamSetFonts(stream, fonts, 1);
    
    NSLog(@"BASS Initialized");
}

void playNote(DWORD chan, DWORD note, DWORD velocity, float pan = 0, DWORD attack = 0, DWORD release = 0) {
    BASS_MIDI_StreamEvent(stream, chan, MIDI_EVENT_RELEASE, release);
    BASS_MIDI_StreamEvent(stream, chan, MIDI_EVENT_ATTACK, attack);
    BASS_MIDI_StreamEvent(stream, chan, MIDI_EVENT_PAN, ((pan + 1) / 2) * 127);
    BASS_MIDI_StreamEvent(stream, chan, MIDI_EVENT_NOTE, MAKEWORD(note, velocity));
}

void changeProgam(DWORD chan, DWORD program) {
    BASS_MIDI_StreamEvent(stream, chan, MIDI_EVENT_PROGRAM, program);
}

void stopNote(DWORD chan, DWORD note){
    playNote(note, 0, 64, chan, 0);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


#pragma mark - Location Manager Interactions


- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    CLLocation *location = newLocation;
//    NSLog(@"Current Location: %f, %f +/- %fm", location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy);
    
    CLLocation *clueLocation = clues[currClue];
    CLLocationDistance distance = [location distanceFromLocation:clueLocation];
//    NSLog(@"Distance %f", distance);
    
    if (minDistToHearClue == -1)
        minDistToHearClue = distance;
    
    distanceToClue = distance;
    
    _distanceLabel.text = [NSString stringWithFormat:@"Dist: %f", distanceToClue];
    _latitudeLabel.text = [NSString stringWithFormat:@"Lat: %f", location.coordinate.latitude];
    _longitudeLabel.text = [NSString stringWithFormat:@"Long: %f", location.coordinate.longitude];
    _accuracyLabel.text = [NSString stringWithFormat:@"Acc (+/-): %f", location.horizontalAccuracy];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    if (newHeading.headingAccuracy < 0)
        return;
    
    // Use the true heading if it is valid.
//    CLLocationDirection  theHeading = ((newHeading.trueHeading > 0) ?
//                                       newHeading.trueHeading : newHeading.magneticHeading);
    
    NSLog(@"Heading %@", newHeading.description);
//    self.currentHeading = theHeading;
//    [self updateHeadingDisplays];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // The location "unknown" error simply means the manager is currently unable to get the location.
    // We can ignore this error for the scenario of getting a single location fix, because we already have a
    // timeout that will stop the location manager to save power.
}

- (void)stopUpdatingLocationWithMessage:(NSString *)state {
    
}

- (IBAction)takeBoostHearinDrug:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Took ear enhancing drugs"
                                                    message:@"You can now hear hear clues more sharply and from farther away"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    boostHearing = true;
    boostRemaining = boostHearingDuration;
}

- (IBAction)collectClue:(id)sender {
    if (distanceToClue > minDistToCollectClue) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Too far from clue!"
                                                        message:@"Keeping looking around till you find it, or you die by the hands of Binaural Man."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    else {
        NSString *alertMsg = [NSString stringWithFormat:@"Congratulations! You have %lu clues left to find", (clues.size() - 1 - currClue)];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Picked up clue"
                                                        message: alertMsg
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        if (currClue < clues.size()) {
            currClue++;
            if (taikoFreq != 1)
                taikoFreq /= 2;
            if (currClue == clues.size()) {
                currClue--;     // to avoid bound overflow
                collectedAllClues = true;
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Congratulations! You found all clues."
                                                                message:@"Wait till rest of the game is implemented"
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            }
        }
    }
}

@end
