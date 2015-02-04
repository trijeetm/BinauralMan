//
//  ViewController.m
//  LocateMe
//
//  Created by Trijeet Mukhopadhyay on 2/3/15.
//  Copyright (c) 2015 blah. All rights reserved.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>

@interface ViewController () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *firstClueLocation;

@end

@implementation ViewController

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
    
    // firstClue init
    _firstClueLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.4213587, -122.1729927) altitude: 0 horizontalAccuracy: 0 verticalAccuracy: 0 course: 0 speed: 0 timestamp: nil];
    NSLog(@"First clue: %f, %f +/- %fm", _firstClueLocation.coordinate.latitude, _firstClueLocation.coordinate.longitude, _firstClueLocation.horizontalAccuracy);
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
    NSLog(@"Current Location: %f, %f +/- %fm", location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy);
    
    CLLocationDistance distance = [location distanceFromLocation:_firstClueLocation];
    NSLog(@"Distance %f", distance);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // The location "unknown" error simply means the manager is currently unable to get the location.
    // We can ignore this error for the scenario of getting a single location fix, because we already have a
    // timeout that will stop the location manager to save power.
}

- (void)stopUpdatingLocationWithMessage:(NSString *)state {
    
}

@end
