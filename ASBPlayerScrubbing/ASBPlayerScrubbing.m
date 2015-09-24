//
//  ASBPlayerScrubbing.m
//  ASBPlayerScrubbing
//
//  Created by Philippe Converset on 09/04/13.
//  Copyright (c) 2013 AutreSphere. All rights reserved.
//

#import "ASBPlayerScrubbing.h"

@interface ASBPlayerScrubbing ()

@property (nonatomic, assign) BOOL playAfterDrag;
@property (nonatomic, assign) id timeObserver;
@property (nonatomic, assign) CGFloat frameDuration;
@property (nonatomic, assign) CGFloat nbFramesPerSecond;

@end


@implementation ASBPlayerScrubbing

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib
{
    [self setup];
}

- (void)setup
{
    self.showMinusSignOnRemainingTime = YES;
}

- (void)setSlider:(UISlider *)slider
{
    _slider = slider;
    [self setupSlider];
}

- (void)setPlayer:(AVPlayer *)player
{
    [self.player pause];
    [self removeTimeObserver];
    _player = player;

    self.nbFramesPerSecond = [ASBPlayerScrubbing nominalFrameRateForPlayer:self.player];
    
    if (self.nbFramesPerSecond > 0) {
        self.frameDuration = 1/self.nbFramesPerSecond;
    } else {
        self.frameDuration = 1/5.0;
    }
    
    [self setupTimeObserver];
    [self updateCurrentTimeLabelWithTime:0];
}

- (void)setShowMinusSignOnRemainingTime:(BOOL)showMinusSignOnRemainingTime
{
    if(_showMinusSignOnRemainingTime == showMinusSignOnRemainingTime)
        return;
    
    _showMinusSignOnRemainingTime = showMinusSignOnRemainingTime;
    [self playerTimeChanged];
}

- (void)setShowTimeFrames:(BOOL)showTimeFrames
{
    if(_showTimeFrames == showTimeFrames)
        return;
    
    _showTimeFrames = showTimeFrames;
    [self playerTimeChanged];
}

- (void)setShowTimeHours:(BOOL)showTimeHours
{
    if(_showTimeHours == showTimeHours)
        return;
    
    _showTimeHours = showTimeHours;
    [self playerTimeChanged];
}

- (NSString *)timecodeForTimeInterval:(NSTimeInterval)time
{
    NSInteger seconds;
    NSInteger hours;
    NSInteger minutes;
    CGFloat milliseconds;
    NSInteger nbFrames = 0;
    NSString *timecode;
    NSString *sign;
    
    sign = ((time < 0) && self.showMinusSignOnRemainingTime?@"\u2212":@"");
    time = ABS(time);
    hours = time/60/24;
    minutes = (time - hours*24)/60;
    seconds = (time - hours*24) - minutes*60;
    
    if(self.showTimeFrames)
    {
        milliseconds = time - (NSInteger)time;
        nbFrames = milliseconds*self.nbFramesPerSecond;
    }
    
    if((hours > 0) || self.showTimeHours)
    {
        if(self.showTimeFrames)
        {
            timecode = [NSString stringWithFormat:@"%@%d:%02d:%02d:%02d", sign, (int)hours, (int)minutes, (int)seconds, (int)nbFrames];
        }
        else
        {
            timecode = [NSString stringWithFormat:@"%@%d:%02d:%02d", sign, (int)hours, (int)minutes, (int)seconds];
        }
    }
    else
    {
        if(self.showTimeFrames)
        {
            timecode = [NSString stringWithFormat:@"%@%02d:%02d:%02d", sign, (int)minutes, (int)seconds, (int)nbFrames];
        }
        else
        {
            timecode = [NSString stringWithFormat:@"%@%02d:%02d", sign, (int)minutes, (int)seconds];
        }
    }
    
    return timecode;
}

#pragma mark - Private
+ (CGFloat)nominalFrameRateForPlayer:(AVPlayer *)player
{
    AVAssetTrack *track = nil;
    NSArray *tracks;
    
    tracks = player.currentItem.asset.tracks;
    if(tracks.count > 0)
    {
        track = tracks[0];
    }
    
    return track.nominalFrameRate;
}

- (void)setupSlider
{
    UITapGestureRecognizer *gesture;
    
    if(self.slider == nil)
        return;
    
    gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSliderTap:)];
    [self.slider addGestureRecognizer:gesture];
    
    [self.slider addTarget:self action:@selector(sliderValueChanged:forEvent:) forControlEvents:UIControlEventValueChanged];
    [self.slider addTarget:self action:@selector(sliderDidEndDragging:forEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.slider addTarget:self action:@selector(sliderDidCancelDragging:forEvent:) forControlEvents:UIControlEventTouchUpOutside];
    [self.slider addTarget:self action:@selector(sliderDidCancelDragging:forEvent:) forControlEvents:UIControlEventTouchCancel];
}

- (void)removeTimeObserver
{
    if(self.timeObserver != nil)
    {
        [self.player removeTimeObserver:self.timeObserver];
    }
    self.timeObserver = nil;
}

- (void)setupTimeObserver
{
    __weak ASBPlayerScrubbing *weakSelf;
    
    if(self.timeObserver != nil)
        return;

    weakSelf = self;
    if(self.frameDuration > 0)
    {
        self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(self.frameDuration, NSEC_PER_SEC)
                                                                      queue:NULL
                                                                 usingBlock:^(CMTime time) {
                                                                     [weakSelf playerTimeChanged];
                                                                 }];
    }
}

- (void)playerTimeChanged
{
    CGFloat nbSecondsElapsed;
    CGFloat nbSecondsDuration = 0;
    CGFloat ratio = 0;
    
    if(self.player.currentItem == nil)
        return;
    
    if (CMTIME_COMPARE_INLINE(self.player.currentItem.currentTime, ==, self.player.currentItem.duration)) {
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(playerScrubbingDidFinishPlaying:)]) {
            [self.delegate playerScrubbingDidFinishPlaying:self];
        }
    }
    
    nbSecondsElapsed = CMTimeGetSeconds(self.player.currentItem.currentTime);
    if(CMTIME_IS_VALID(self.player.currentItem.duration) && !CMTIME_IS_INDEFINITE(self.player.currentItem.duration))
    {
        nbSecondsDuration = CMTimeGetSeconds(self.player.currentItem.duration);
    }
    
    if(nbSecondsDuration != 0)
    {
        ratio = nbSecondsElapsed/nbSecondsDuration;
        [self updateDurationLabelWithTime:nbSecondsDuration];
    }
    
    self.slider.value = ratio;
    
    [self updateCurrentTimeLabelWithTime:nbSecondsElapsed];
    [self updateRemainingTimeLabelWithTime:nbSecondsDuration - nbSecondsElapsed];
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(playerScrubbingDidUpdateTime:)]) {
        [self.delegate playerScrubbingDidUpdateTime:self];
    }
}

- (void)updateDurationLabelWithTime:(NSTimeInterval)time
{
    if(self.durationLabel == nil)
        return;
    
    self.durationLabel.text = [self timecodeForTimeInterval:time];
}

- (void)updateCurrentTimeLabelWithTime:(NSTimeInterval)time
{
    if(self.currentTimeLabel == nil)
        return;
    
    self.currentTimeLabel.text = [self timecodeForTimeInterval:time];
}

- (void)updateRemainingTimeLabelWithTime:(NSTimeInterval)time
{
    if(self.remainingTimeLabel == nil)
        return;
    
    self.remainingTimeLabel.text = [self timecodeForTimeInterval:-time];
}

- (void)updatePlayer
{
    CGFloat nbSecondsDuration;
    CMTime time;

    nbSecondsDuration = CMTimeGetSeconds(self.player.currentItem.duration);
    int timescale = self.player.currentItem.asset.duration.timescale;
    time = CMTimeMakeWithSeconds(nbSecondsDuration*self.slider.value, timescale);
    [self.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {}];
}

#pragma mark - Actions
- (IBAction)sliderValueChanged:(id)sender forEvent:(UIEvent *)event
{
    UITouch *touch;
    
    touch = [[event allTouches] anyObject];

    if([self isPlaying] && touch.phase == UITouchPhaseBegan)
    {
        self.playAfterDrag = [self isPlaying];
        [self.player pause];
    }
    
    [self updatePlayer];
}

- (IBAction)sliderDidEndDragging:(id)sender forEvent:(UIEvent *)event
{
    if(self.playAfterDrag)
    {
        self.playAfterDrag = NO;
        [self.player play];
    }
}

- (IBAction)sliderDidCancelDragging:(id)sender forEvent:(UIEvent *)event
{
    if(self.playAfterDrag)
    {
        self.playAfterDrag = NO;
        [self.player play];
    }
}

- (BOOL)isPlaying
{
    return !(self.player.rate == 0);
}

- (IBAction)playPause:(id)sender
{
    if(self.isPlaying)
    {
        [self pause:sender];
    }
    else
    {
        
        [self play:sender];
    }
}

- (IBAction)play:(id)sender
{
    if(CMTIME_COMPARE_INLINE(self.player.currentTime, == , self.player.currentItem.duration))
    {
        [self.player seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
            [self.player play];
        }];
    }
    else
    {
        [self.player play];
    }
}

- (IBAction)pause:(id)sender
{
    [self.player pause];
}

- (void)handleSliderTap:(UIGestureRecognizer *)gesture
{
    CGPoint point;
    CGFloat ratio;
    CGFloat delta;
    CGFloat value;
    CGFloat thumbWidth;
    
    // tap on thumb, let slider deal with it
    if (self.slider.highlighted)
        return;
    
    CGRect trackRect = [self.slider trackRectForBounds:self.slider.bounds];
    CGRect thumbRect = [self.slider thumbRectForBounds:self.slider.bounds trackRect:trackRect value:0];
    CGSize thumbSize = thumbRect.size;
    thumbWidth = thumbSize.width;
    point = [gesture locationInView: self.slider];
    if(point.x < thumbWidth/2)
    {
        ratio = 0;
    }
    else if(point.x > self.slider.bounds.size.width - thumbWidth/2)
    {
        ratio = 1;
    }
    else
    {
        ratio = (point.x - thumbWidth/2) / (self.slider.bounds.size.width - thumbWidth);
    }
    delta = ratio * (self.slider.maximumValue - self.slider.minimumValue);
    value = self.slider.minimumValue + delta;
    [self.slider setValue:value animated:YES];
    [self updatePlayer];
}

@end
