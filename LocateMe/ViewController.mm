//
//  ViewController.m
//  BinauralMan
//
//  Created by Trijeet Mukhopadhyay on 2/3/15.
//  Copyright (c) 2015 blah. All rights reserved.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <vector>
#import <math.h>

#import "mo-audio.h"
#import "mo-fun.h"
#import "mo-gfx.h"

#import "gex-basssynth.h"

// defines
#define SRATE 44100
#define N_CHANNELS 16
#define PI 3.14159265


// ====================================================
// Globals
// ====================================================

// game
BOOL collectedAllClues = false;
int score = 0;
bool compassNotCalibrated = false;

// clues
std::vector <Vector3D> clues;
int currClue = 0;
int totalClues = 8;
bool clueSounderOn = false;

float minDistToCollectClue = 100.0;
float minDistToHearClue = 7000.0;

float g_distanceToClue = -1.0;
float g_initDistToClue = -1.0;

int clueSounderFreq = 12;
int cluePitchBendRange = 9;
int boostedClueSounderFreq = 6;

// world
float worldSize = 6000.0;       // (-3000.0, 3000.0)

// player location
Vector3D playerLocation = Vector3D(0, 0, 0);
float playerHeading = -1;
int playerMoveForward = 0;
int playerMoveBackward = 0;

// boost hearing drugs
bool boostHearing = false;
int boostHearingFactor = 5;
int boostHearingDuration = 16;      // in beats
int boostRemaining = boostHearingDuration;

// BASS
GeXBASSSynth *g_synth;

// audio constants
int ambientChan = 0;
//int taikoChan = 1;
//int taikoFreq = 32;
int clueSounderChan = 3;
int clueDistChan = 4;       // 104 : sitar
int clueDistPeriodMax = 24;
int clueDistPeriod = clueDistPeriodMax;
int footstepsPeriod = 4;
int footstepsChan = 2;
int warningChan = 5;
int alarmChan = 6;

// tempo/beats
int g_bpm = 240;
float g_t = 0;
float g_acculumator = 0;
uint beatCounter = 0;
bool beatUsed = false;

@interface ViewController () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (strong, nonatomic) IBOutlet UILabel *scoreLabel;
@property (strong, nonatomic) IBOutlet UILabel *timerLabel;
@property (strong, nonatomic) IBOutlet UILabel *distanceLabel;

@end

@implementation ViewController


// ====================================================
// Audio Callback:
// Records beat events, updates audio data,
// and synthesizes BASSsynth to buffer
// ====================================================
void audioCallback( Float32 * buffer, UInt32 frameSize, void * userData ) {
    // increment global time
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
    
    // loop over audio buffer
    for (UInt32 i = 0; i < frameSize; i++) {
        // silence
        buffer[i*2+1] = buffer[i*2] = 0;
    }
    
    if (collectedAllClues || playerDead)
        return;
    
    // player location
    if (!movePlayer()) {
        compassNotCalibrated = true;
        return;
    }
    else
        compassNotCalibrated = false;
    float distanceToClue = g_distanceToClue = get2DDistance(playerLocation, clues[currClue]);
    
    // beat independant stuff
    // modulate clueSounder volume with distance
    float clueSounderAmplifier = getVolumeAmpFromDistance(distanceToClue);
    g_synth->controlChange(clueSounderChan, MIDI_EVENT_VOLUME, (int)(clueSounderAmplifier * 127.0));
    // pan with angle
    float anglePlayerToClue = getPanAngle(playerLocation, clues[currClue]);
    if (anglePlayerToClue > 180.0)
        anglePlayerToClue = -180.0 + (anglePlayerToClue - 180.0);
    float panLeftFactor = 0, panRightFactor = 0;
    if (anglePlayerToClue > 0)
        panLeftFactor = sinf(anglePlayerToClue * PI / 180.0);
    if (anglePlayerToClue < 0)
        panRightFactor = sinf(-anglePlayerToClue  * PI / 180.0);
    g_synth->controlChange(clueSounderChan, MIDI_EVENT_PAN, 64 - (panLeftFactor * 63.0) + (panRightFactor * 63.0));
    g_synth->controlChange(clueSounderChan, MIDI_EVENT_PITCH, 8192 - (8192.0 * fabsf(anglePlayerToClue) / 180.0));
    g_synth->controlChange(clueDistChan, MIDI_EVENT_PAN, 64 - (panLeftFactor * 63.0) + (panRightFactor * 63.0));
    // volume cap with angle
    if (fabsf(anglePlayerToClue) > 90.0) {
        float dampenClueSounder = 1.0 - ((fabsf(anglePlayerToClue) - 90.0) / 90.0);
        if (dampenClueSounder < 0.75)
            dampenClueSounder = 0.75;
        g_synth->controlChange(clueSounderChan, MIDI_EVENT_VOLUME, (int)(dampenClueSounder * clueSounderAmplifier * 127.0));
        g_synth->controlChange(clueDistChan, MIDI_EVENT_VOLUME, (int)(dampenClueSounder * clueSounderAmplifier * 127.0));
    }
    
//    float distanceToLight = get2DDistance(playerLocation, searchlightLocation.actual());
    // modulate alarm volume with distance
//    float lightSoundAmp = 1.0 - (distanceToLight / (distToHearSearchlight * 1.5));
    g_synth->controlChange(alarmChan, MIDI_EVENT_VOLUME, 127);
    // pan with angle
    float anglePlayerToLight = getPanAngle(playerLocation, searchlightLocation.actual());
    if (anglePlayerToLight > 180.0)
        anglePlayerToLight = -180.0 + (anglePlayerToLight - 180.0);
    panLeftFactor = 0, panRightFactor = 0;
    if (anglePlayerToClue > 0)
        panLeftFactor = sinf(anglePlayerToLight * PI / 180.0);
    if (anglePlayerToLight < 0)
        panRightFactor = sinf(-anglePlayerToLight  * PI / 180.0);
    g_synth->controlChange(alarmChan, MIDI_EVENT_PAN, 64 - (panLeftFactor * 63.0) + (panRightFactor * 63.0));
    g_synth->controlChange(alarmChan, MIDI_EVENT_PITCHRANGE, 4);
    g_synth->controlChange(alarmChan, MIDI_EVENT_PITCH, 8192 - (8192.0 * fabsf(anglePlayerToLight) / 180.0));
    
    // beat dependant stuff
    if (beatUsed == false) {
        if (boostHearing) {
            boostRemaining--;
            if (boostRemaining == 0) {
                boostHearing = false;
                boostRemaining = boostHearingDuration;
            }
        }
        if ((beatCounter % footstepsPeriod == 0) && ((playerMoveBackward != 0) || (playerMoveForward != 0))) {
            g_synth->programChange(footstepsChan, 126);
            g_synth->controlChange(footstepsChan, MIDI_EVENT_REVERB, 100);
            g_synth->noteOn(footstepsChan, 47 - MoFun::rand2i(-5, 5), 127);
        }
//        if (beatCounter % 4 == 0) {
//            NSLog(@"dist: %f", distanceToClue);
//            NSLog(@"angle to clue: %f", anglePlayerToClue);
//            NSLog(@"location: (%f, %f)", playerLocation.x, playerLocation.y);
//            NSLog(@"player heading: %f", playerHeading);
//            NSLog(@"clue: (%f, %f)", clues[currClue].x, clues[currClue].y);
//            NSLog(@"------------------------------");
//        }
        if (beatCounter % clueDistPeriod == 0)
            distanceTicker(get2DDistance(playerLocation, clues[currClue]));
//        if (beatCounter % taikoFreq == 0) {
//            g_synth->programChange(taikoChan, 116);
//            g_synth->controlChange(taikoChan, MIDI_EVENT_REVERB, 127);
//            g_synth->noteOn(taikoChan, 12, 127);
//            g_synth->noteOn(taikoChan, 19, 127);
//            g_synth->noteOn(taikoChan, 24, 127);
//            g_synth->noteOn(taikoChan, 31, 127);
//            g_synth->noteOn(taikoChan, 36, 127);
//            g_synth->noteOn(taikoChan, 48, 127);
//        }
        if (beatCounter % clueSounderFreq == 0)
            soundClue();
    }
    // mark beat as used
    beatUsed = true;
    
    // synthesize
    g_synth->synthesize2(buffer, frameSize);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // locationManager init
    _locationManager = [[CLLocationManager alloc] init];
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
    self.locationManager.delegate = self;
    // Start heading updates.
    if ([CLLocationManager headingAvailable]) {
        self.locationManager.headingFilter = kCLHeadingFilterNone;
        NSLog(@"leggo heading");
        [self.locationManager startUpdatingHeading];
    }
    
    
    
    // clues init
    createClues();
    
    // init bass synth
    initBASSSynth();
    
    // MAudio init
    initAudio();
    
    // start audio from clues
    soundClue();
    
    [NSTimer scheduledTimerWithTimeInterval:0.001 target:self
                                   selector:@selector(timerCallback) userInfo:nil repeats:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:false];
    
    
}

// searchlight
iSlew3D searchlightLocation = iSlew3D(- worldSize / 2, 0, 0);
float g_distanceToSearchlight = -1;
int searchlightUpdateLag = 16;     // in seconds
float searchlightSlew = 0.0025;
float g_timer = 0;      // in ms
uint g_timer_s = 0;    // in sec
float timeTakenToCollectClue = 0;   // in seconds
float bonusPointsTimeCutoff = 45;
uint timeSpotted = 0;
uint timeForAlarmRaised = 5;
float distToHearSearchlight = 1000.0;
float distToBeSpotted = 500.0;
bool warningSIG = false;
bool spottedSIG = false;
bool alarmSIG = false;
bool playerDead = false;
bool showDistance = false;
bool disableAlarm = false;

// callback every 1ms
- (void)timerCallback {
//    while (compassNotCalibrated) {
//        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Compass not calibrated."
//                                                        message:@"Move your device around till compass is calibrated."
//                                                       delegate:nil
//                                              cancelButtonTitle:@"OK"
//                                              otherButtonTitles:nil];
//        [alert show];
//    }
    
    g_timer += 1;
    
    // update text
    _scoreLabel.text = [NSString stringWithFormat:@"%d", score];
    _timerLabel.text = [NSString stringWithFormat:@"Time survived: %ds", (int)(g_timer / 1000.0)];
    if (showDistance)
        _distanceLabel.text = [NSString stringWithFormat:@"Distance to clue: %.2fk", (get2DDistance(playerLocation, clues[currClue])) / 1000];
    else
        _distanceLabel.text = [NSString stringWithFormat:@"Distance to clue: xxx"];
    
    if (currClue == 0)
        return;
    
    if (disableAlarm) {
        g_synth->noteOff(alarmChan, 59);
        g_synth->noteOff(alarmChan, 66);
        g_synth->noteOff(alarmChan, 71);
        alarmSIG = false;
        warningSIG = false;
        spottedSIG = false;
        return;
    }
    
    searchlightLocation.interp2(searchlightSlew);
    
    float distToSearchlight = get2DDistance(playerLocation, searchlightLocation.actual());
    
    // a second
    if (fmod(g_timer, 1000) == 0) {
        timeTakenToCollectClue += 1.0;
        g_timer_s++;
        if (spottedSIG) {
            timeSpotted++;
            if (timeSpotted >= timeForAlarmRaised) {
                score -= 10;
                if (!alarmSIG) {
                    NSLog(@"Alarm raised!");
                    g_synth->programChange(alarmChan, 125);
                    g_synth->noteOn(alarmChan, 71, 120);
                }
                alarmSIG = true;
            }
            else {
                alarmSIG = false;
            }
        }
        
        NSLog(@"player: (%f, %f)", playerLocation.x, playerLocation.y);
        NSLog(@"searchlight: (%f, %f)", searchlightLocation.actual().x, searchlightLocation.actual().y);
        NSLog(@"dist (light to player): %f", distToSearchlight);
        NSLog(@"clue: (%f, %f)", clues[currClue].x, clues[currClue].y);
        NSLog(@"dist (clue to player): %f", get2DDistance(playerLocation, clues[currClue]));
    }
    
    // # clues left timer
    searchlightUpdateLag = 2 * (totalClues - currClue);
    if (g_timer_s % searchlightUpdateLag == 0) {
        // update end point of searchlight path
        searchlightLocation.update(playerLocation, searchlightSlew);
    }
    
    if (distToSearchlight < distToHearSearchlight) {
        if (!warningSIG) {
            NSLog(@"Warning!");
            g_synth->programChange(alarmChan, 125);
            g_synth->noteOn(alarmChan, 59, 85);
        }
        warningSIG = true;
    }
    else {
        warningSIG = false;
        g_synth->noteOff(alarmChan, 59);
    }
    
    if (distToSearchlight < distToBeSpotted) {
        if (!spottedSIG) {
            NSLog(@"Spotted!");
            g_synth->programChange(alarmChan, 125);
            g_synth->noteOn(alarmChan, 66, 100);
        }
        spottedSIG = true;
    }
    else {
        spottedSIG = false;
        timeSpotted = 0;
        alarmSIG = false;
        g_synth->noteOff(alarmChan, 66);
    }
    
    if (!alarmSIG)
        g_synth->noteOff(alarmChan, 71);
    
    if (collectedAllClues) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Exellent work, BinAural Man! You saved the day again."
                                                        message:[NSString stringWithFormat:@"Your score is %d.", score]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

void distanceTicker(float dist) {
    g_synth->programChange(clueDistChan, 104);
    g_synth->noteOn(clueDistChan, 59, 70);
    
    for (int i = clueDistPeriodMax; i > 0; i--) {
        if (dist < minDistToCollectClue / 2 * i)
            clueDistPeriod = i;
        else
            break;
    }
    
    if (dist < minDistToCollectClue) {
        g_synth->noteOn(clueDistChan, 59, 95);
        g_synth->noteOn(clueDistChan, 66, 95);
        g_synth->noteOn(clueDistChan, 71, 75);
    }       clueDistPeriod = (clueDistPeriodMax - 1) * ((dist / g_initDistToClue));
}

void initBASSSynth() {
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
}

void initAudio() {
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

void createClues() {
//    clues.push_back(Vector3D(0, 90, 0));
//    clues.push_back(Vector3D(0, -90, 0));
//    clues.push_back(Vector3D(90, 0, 0));
//    clues.push_back(Vector3D(-90, 0, 0));
//    clues.push_back(Vector3D(30, 30, 0));
//    clues.push_back(Vector3D(30, -30, 0));
//    clues.push_back(Vector3D(-30, -30, 0));
//    clues.push_back(Vector3D(-30, 30, 0));
//    clues.push_back(Vector3D(400, 800, 0));
	for (int i = 0; i < totalClues; i++)
        clues.push_back(Vector3D(MoFun::rand2f(-worldSize / 2, worldSize / 2), MoFun::rand2f(-worldSize / 2, worldSize / 2), 0));
    
    g_initDistToClue = get2DDistance(playerLocation, clues[0]);
}

void soundClue() {
    g_synth->programChange(clueSounderChan, 96);
    g_synth->noteOn(clueSounderChan, 35, 110);
    g_synth->noteOn(clueSounderChan, 47, 120);
    g_synth->noteOn(clueSounderChan, 59, 110);
    g_synth->noteOn(clueSounderChan, 71, 95);
    g_synth->noteOn(clueSounderChan, 83, 70);
    g_synth->controlChange(clueSounderChan, MIDI_EVENT_PITCHRANGE, cluePitchBendRange);
}

bool movePlayer() {
    if (playerHeading != -1) {
        float playerMoveBy = 0;
        if (playerMoveForward == 1) {
            playerMoveBy = 0.1;
        }
        if (playerMoveForward == 2) {
            playerMoveBy = 0.1 * 4;
        }
        if (playerMoveBackward == 1) {
            playerMoveBy = -0.1;
        }
        if (playerMoveBackward == 2) {
            playerMoveBy = -0.1 * 2;
        }
        
        if (playerMoveBy != 0) {
            playerLocation.x += sinf(playerHeading * PI / 180.0) * playerMoveBy;
            playerLocation.y += cosf(playerHeading * PI / 180.0) * playerMoveBy;
        }
        return true;
    }
    return false;
}

float get2DDistance(Vector3D v1, Vector3D v2) {
    return sqrtf(powf(v1.x - v2.x, 2) + powf(v1.y - v2.y, 2));
}

float getPanAngle(Vector3D player, Vector3D object) {
//    Vector3D magneticNorth = Vector3D(75.7667, 99.7833, 0);
    Vector3D magneticNorth = Vector3D(0, 5000, 0);

    // line vector from player to magnetic NP
    Vector3D playerToNP = magneticNorth - player;
    // line vector from player to object
    Vector3D playerToObject = object - player;
    float angleObjectNP = acos(playerToNP * playerToObject / (playerToNP.magnitude() * playerToObject.magnitude()));
    angleObjectNP *= (180.0 / PI);
    
    if (object.x < player.x) {
        angleObjectNP = 360.0 - angleObjectNP;
    }
    

    // check if player has invalid heading data
    if (playerHeading == -1)
        return -1;
    
    float angle = playerHeading - angleObjectNP;
    angle = angle < 0 ? 360.0 + angle : angle;
    
//    NSLog(@"Player heading: %f", playerHeading);
//    NSLog(@"Angle Object NP: %f", angleObjectNP);
//    NSLog(@"Angle: %f", angle);
//    NSLog(@"dist: %f", get2DDistance(playerLocation, clues[currClue]));
//    NSLog(@"location: (%f, %f)", playerLocation.x, playerLocation.y);
//    NSLog(@"Player heading: %f", playerHeading);
//    NSLog(@"Angle Object NP: %f", angleObjectNP);
//    NSLog(@"Angle to clue: %f", angle);
//    NSLog(@"clue: (%f, %f)", clues[currClue].x, clues[currClue].y);
//    NSLog(@"------------------------------");
    
    // return angle between player's heading and object
    return angle;
}

float getVolumeAmpFromDistance(float distanceToClue) {
    float volumeAmp;
    float _minDistToHearClue = minDistToHearClue * (boostHearing ? boostHearingFactor : 1);
    if ((_minDistToHearClue == -1) || (distanceToClue == -1) || (_minDistToHearClue - distanceToClue) <= 0 || collectedAllClues)
        volumeAmp = 0;
    else
        volumeAmp = (_minDistToHearClue - distanceToClue) / _minDistToHearClue;
//    NSLog(@"clueSounderAmplifier: %f", clueSounderAmplifier);
    return volumeAmp;
}

void displayStatistics(Vector3D location, float distance) {
//    _distanceLabel.text = [NSString stringWithFormat:@"Dist: %f", distanceToClue];
//    _latitudeLabel.text = [NSString stringWithFormat:@"X: %f", location.x];
//    _longitudeLabel.text = [NSString stringWithFormat:@"Y: %f", location.y];
//    
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

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    if (newHeading.headingAccuracy < 0)
        return;
    
    playerHeading = newHeading.magneticHeading;
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
    clueSounderFreq = boostedClueSounderFreq;
}

- (IBAction)collectClue:(id)sender {
    if (g_distanceToClue > minDistToCollectClue) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Too far from clue!"
                                                        message:@"Keeping looking around till you find it. Move using buttons for running walking and turn by pointing device in the direction."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    else {
        clueDistPeriod = clueDistPeriodMax;
        score += 100;
        searchlightSlew += 0.0025;
        if (!showDistance && !disableAlarm)
            if (timeTakenToCollectClue < bonusPointsTimeCutoff)
                score += 200 * (1.0 - (timeTakenToCollectClue / bonusPointsTimeCutoff));
        showDistance = false;
        disableAlarm = false;
        NSString *alertMsg = [NSString stringWithFormat:@"Congratulations! You have %lu clues left to find", (clues.size() - 1 - currClue)];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Picked up clue"
                                                        message: alertMsg
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        if (currClue < clues.size()) {
            currClue++;
//            if (taikoFreq != 1)
//                taikoFreq /= 2;
            if (currClue == clues.size()) {
                currClue--;     // to avoid bound overflow
                collectedAllClues = true;
            }
            g_initDistToClue = get2DDistance(playerLocation, clues[currClue]);
        }
    }
}

- (IBAction)playerStartMovingForward:(id)sender {
    NSLog(@"start moving forward");
    playerMoveForward = 1;
    footstepsPeriod = 4;
}

- (IBAction)playerStopMovingForward:(id)sender {
    NSLog(@"stop moving forward");
    playerMoveForward = 0;
}

- (IBAction)playerStartMovingBackward:(id)sender {
    NSLog(@"start moving backward");
    playerMoveBackward = 1;
    footstepsPeriod = 4;
}

- (IBAction)playerStopMovingBackward:(id)sender {
    NSLog(@"stop moving backward");
    playerMoveBackward = 0;
}

- (IBAction)playerStartRunningForward:(id)sender {
    NSLog(@"start running forward");
    playerMoveForward = 2;
    footstepsPeriod = 2;
}

- (IBAction)playerStopRunningForward:(id)sender {
    NSLog(@"stop running forward");
    playerMoveForward = 0;
}

- (IBAction)playerStartRunningBackward:(id)sender {
    NSLog(@"start running backward");
    playerMoveBackward = 2;
    footstepsPeriod = 3;
}

- (IBAction)playerStopRunningBackward:(id)sender {
    NSLog(@"stop running backward");
    playerMoveBackward = 0;
}

- (IBAction)showDistance:(id)sender {
    showDistance = true;
    score -= 50;
}

- (IBAction)disableAlarm:(id)sender {
    disableAlarm = true;
    score -= 200;
}

@end
