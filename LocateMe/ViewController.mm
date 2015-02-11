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

#import "gex-basssynth.h"

// defines
#define SRATE 44100
#define N_CHANNELS 16

// clues
std::vector <CLLocation *> clues;
int currClue = 0;
BOOL collectedAllClues = false;
bool clueSounderOn = false;
float minDistToCollectClue = 15.0;

// location metrics
float minDistToHearClue = 60.0;
float distanceToClue = -1.0;
float trueHeading = 180.0;

// boost hearing drugs
bool boostHearing = false;
int boostHearingFactor = 5;
int boostHearingDuration = 16;      // in beats
int boostRemaining = boostHearingDuration;

// BASS
GeXBASSSynth *g_synth;

// audio constants
int ambientChan = 0;
int taikoChan = 1;
int taikoFreq = 16;
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


// ====================================================
// Audio Callback:
// Records beat events, updates audio data,
// and synthesizes BASSsynth to buffer
// ====================================================
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
        // silence
        buffer[i*2+1] = buffer[i*2] = 0;
    }
    
    float clueSounderAmplifier;
    float _minDistToHearClue = minDistToHearClue * (boostHearing ? boostHearingFactor : 1);
    if ((_minDistToHearClue == -1) || (distanceToClue == -1) || (_minDistToHearClue - distanceToClue) <= 0 || collectedAllClues)
        clueSounderAmplifier = 0;
    else
        clueSounderAmplifier = pow(2.0 * ((_minDistToHearClue - distanceToClue) / _minDistToHearClue), 2);
    
    // beat independant audio
    // modulate clueSounder volume with distance
    g_synth->programChange(clueSounderChan, 16);
    g_synth->noteOn(clueSounderChan, 24, 126 * clueSounderAmplifier);
    
    // beat dependant audio
    if (beatUsed == false) {
        if (beatCounter % taikoFreq == 0) {
            g_synth->programChange(taikoChan, 116);
            g_synth->controlChange(taikoChan, MIDI_EVENT_REVERB, 127);
            g_synth->noteOn(taikoChan, 12, 127);
            g_synth->noteOn(taikoChan, 19, 127);
            g_synth->noteOn(taikoChan, 24, 127);
            g_synth->noteOn(taikoChan, 31, 127);
            g_synth->noteOn(taikoChan, 36, 127);
            g_synth->noteOn(taikoChan, 48, 127);
        }
    }
    
    beatUsed = true;
    
    // synthesize
    g_synth->synthesize2(buffer, frameSize);
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
    
//     Start heading updates.
    if ([CLLocationManager headingAvailable]) {
        self.locationManager.headingFilter = 5;
        NSLog(@"leggo heading");
        [self.locationManager startUpdatingHeading];
    }
    
    // clues init
    
    // CCRMA Courtyard / Backroad / Backroad Right / CCRMA Right / CCRMA Entrance / CCRMA Left Front
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.420964, -122.172379) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.420816, -122.172671) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.420745, -122.172160) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.420973, -122.172093) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.421159, -122.172340) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.421520, -122.172905) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    
//    // BrannerPL/Escondido/BrannerCY/Wilbur/EscondidoTA/Crothers
//    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.425535, -122.162451) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
//    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.424663, -122.162405) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
//    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.425166, -122.162958) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
//    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.424852, -122.164095) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
//    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.425227, -122.164841) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
//    clues.push_back([[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.426062, -122.164117) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil]);
    
    // init bass synth
    g_synth = new GeXBASSSynth();
    NSLog( @"starting BASS synth..." );
    
    if (!g_synth->init(SRATE, N_CHANNELS)) {
        NSLog( @"cannot init BASS synth..." );
        return;
    }
        
    if (!g_synth->load([[[NSBundle mainBundle] pathForResource: @"rocking8m11e" ofType: @"sf2"] UTF8String])) {
        NSLog( @"cannot load soundfont in BASS..." );
        return;
    }
    
    // log
    NSLog( @"starting real-time audio..." );
    
    // init the audio layer
    bool result = MoAudio::init(SRATE, 32, 2);
    if( !result )
    {
        // something went wrong
        NSLog( @"cannot initialize real-time audio!" );
        // bail out
        return;
    }
    
    // start the audio layer, registering a callback method
    result = MoAudio::start( audioCallback, NULL );
    if( !result )
    {
        // something went wrong
        NSLog( @"cannot start real-time audio!" );
        // bail out
        return;
    }
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
    
    
//     Use the true heading if it is valid.
    trueHeading = ((newHeading.trueHeading > 0) ?
                                       newHeading.trueHeading : newHeading.magneticHeading);
    
    NSLog(@"Heading %@", newHeading.description);
    
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
