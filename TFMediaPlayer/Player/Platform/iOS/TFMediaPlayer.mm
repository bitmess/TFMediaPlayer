//
//  TFMediaPlayer.m
//  TFMediaPlayer
//
//  Created by shiwei on 17/12/25.
//  Copyright © 2017年 shiwei. All rights reserved.
//

#define TFMPUseAudioUnitPlayer 0

#import "TFMediaPlayer.h"
#import "PlayController.hpp"
#import "TFOPGLESDisplayView.h"
#import "UIDevice+ForceChangeOrientation.h"
#import "TFMPPlayControlView.h"
#import "TFMPPlayCmdResolver.h"

#if TFMPUseAudioUnitPlayer
#import "TFAudioUnitPlayer.h"
#else
#import "TFAudioQueueController.h"
#endif

#import "TFMPDebugFuncs.h"


@interface TFMediaPlayer (){
    tfmpcore::PlayController *_playController;
    
    TFMPMediaType _mediaType;
    
    BOOL _innerPlayWhenReady;
    
#if TFMPUseAudioUnitPlayer
    TFAudioUnitPlayer *_audioPlayer;
#else
    TFAudioQueueController *_audioPlayer;
#endif
    
    TFOPGLESDisplayView *_displayView;
    
    TFMPPlayCmdResolver *_defaultPlayResolver;
    
    bool seeked;
}

@end

@implementation TFMediaPlayer

-(instancetype)init{
    if (self = [super init]) {
        
        _displayView = [[TFOPGLESDisplayView alloc] init];
        
        _playController = new tfmpcore::PlayController();
        
        _playController->setDesiredDisplayMediaType(TFMP_MEDIA_TYPE_ALL_AVIABLE);
        _playController->isAudioMajor = true;
        
        _playController->displayContext = (__bridge void *)self;
        _playController->displayVideoFrame = displayVideoFrame_iOS;
        
        _playController->connectCompleted = [self](tfmpcore::PlayController *playController){
            
            if (_state == TFMediaPlayerStateConnecting) {
                _state = TFMediaPlayerStateReady;
            }
            
            if (_innerPlayWhenReady || _autoPlayWhenReady) {
                [self play];
            }
        };
        
#if TFMPUseAudioUnitPlayer
        _audioPlayer = [[TFAudioUnitPlayer alloc] init];
        _audioPlayer.fillStruct = _playController->getFillAudioBufferStruct();
#endif
        
        _playController->negotiateAdoptedPlayAudioDesc = [self](TFMPAudioStreamDescription sourceDesc){
#if TFMPUseAudioUnitPlayer
            TFMPAudioStreamDescription result = [_audioPlayer resultAudioDescForSource:sourceDesc];
            return result;
#else
            _audioPlayer = [[TFAudioQueueController alloc] initWithSpecifics:sourceDesc];
            _audioPlayer.shareAudioStruct = _shareAudioStruct;
            _audioPlayer.fillStruct = _playController->getFillAudioBufferStruct();
            
            return _audioPlayer.resultSpecifics;
#endif
        };
        
        [self setupPlayControlView];
    }
    
    return self;
}

-(void)setupPlayControlView{
    _defaultControlView = [[TFMPPlayControlView alloc] init];
    _defaultControlView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    _defaultPlayResolver = [[TFMPPlayCmdResolver alloc] init];
    _defaultPlayResolver.player = self;
    _defaultControlView.delegate = _defaultPlayResolver;
    
    _defaultControlView.swipeSeekDuration = 5;
    
    self.controlView = _defaultControlView;
}

-(void)setControlView:(UIView *)controlView{
    if (_controlView == controlView) {
        return;
    }
    
    if (_controlView) {
        [_controlView removeFromSuperview];
    }
    
    _controlView = controlView;
    _controlView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.displayView addSubview:_controlView];
}

-(UIView *)displayView{
    return _displayView;
}

-(void)setMediaURL:(NSURL *)mediaURL{
    if (_mediaURL == mediaURL) {
        return;
    }
    
    _mediaURL = mediaURL;
    if (_state != TFMediaPlayerStateNone) {
        [self stop];
    }
}

-(void)setMediaType:(TFMPMediaType)mediaType{
    _mediaType = mediaType;
    _playController->setDesiredDisplayMediaType(mediaType);
    
    
    if ((_playController->getRealDisplayMediaType() & TFMP_MEDIA_TYPE_AUDIO)) {
        if (_audioPlayer.state == TFAudioQueueStateUnplay) {
            [_audioPlayer play];
        }
    }else{
        if (_audioPlayer.state == TFAudioQueueStatePlaying) {
            [_audioPlayer stop];
        }
    }
}

-(TFMPMediaType)mediaType{
    return _mediaType;
}

-(void)preparePlay{
    
    if (_mediaURL == nil) {
        _state = TFMediaPlayerStateNone;
        return;
    }
    
    _state = TFMediaPlayerStateConnecting;
    
    //local file or bundle file need a file reader which is different on different platform.
    bool succeed = _playController->connectAndOpenMedia([[_mediaURL absoluteString] cStringUsingEncoding:NSUTF8StringEncoding]);
    if (!succeed) {
        TFMPDLog(@"play media open error");
        _state = TFMediaPlayerStateNone;
    }
}

-(void)play{
    
    if (![self configureAVSession]) {
        _state = TFMediaPlayerStateNone;
        return;
    }
    
    if (_playController->getRealDisplayMediaType() != _mediaType) {
        _playController->setDesiredDisplayMediaType(_mediaType);
    }
    
    if (_state == TFMediaPlayerStateNone) {
        
        _innerPlayWhenReady = YES;
        [self preparePlay];
        
    }else if (_state == TFMediaPlayerStateConnecting) {
        _innerPlayWhenReady = YES;
    }else if (_state == TFMediaPlayerStateReady || _state == TFMediaPlayerStatePause){
        
        _playController->play();
        
        if (_playController->getRealDisplayMediaType() & TFMP_MEDIA_TYPE_AUDIO) {
            [_audioPlayer play];
        }
        
        _state = TFMediaPlayerStatePlaying;
    }
}

-(void)pause{
    switch (_state) {
        case TFMediaPlayerStateConnecting:
            //TODO: stop connecting
            _autoPlayWhenReady = false;
            _innerPlayWhenReady = false;
            break;
        case TFMediaPlayerStateReady:
            _autoPlayWhenReady = false;
            _innerPlayWhenReady = false;
            break;
        case TFMediaPlayerStatePlaying:
            _playController->pause();
            
            break;
        default:
            break;
    }
    _state = TFMediaPlayerStatePause;
}

-(void)stop{
    
    [_audioPlayer stop];
    
    switch (_state) {
        case TFMediaPlayerStateConnecting:
            _autoPlayWhenReady = false;
            _innerPlayWhenReady = false;
            _playController->stop();
            break;
        case TFMediaPlayerStateReady:
            _autoPlayWhenReady = false;
            _innerPlayWhenReady = false;
            _playController->stop();
            break;
        case TFMediaPlayerStatePlaying:
            _playController->stop();
            break;
        default:
            break;
    }
    
    _state = TFMediaPlayerStateNone;
}

-(BOOL)configureAVSession{
    
//    NSError *error = nil;
//
//    [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback error:&error];
//    if (error) {
//        TFMPDLog(@"audio session set category error: %@",error);
//        return NO;
//    }
//
//    [[AVAudioSession sharedInstance] setActive:YES error:&error];
//    if (error) {
//        TFMPDLog(@"active audio session error: %@",error);
//        return NO;
//    }
    
    return YES;
}

-(void)setShareAudioStruct:(TFMPShareAudioBufferStruct)shareAudioStruct{
    _shareAudioStruct = shareAudioStruct;
    [_audioPlayer setShareAudioStruct:shareAudioStruct];
}

#pragma mark - platform special

int displayVideoFrame_iOS(TFMPVideoFrameBuffer *frameBuf, void *context){
    TFMediaPlayer *player = (__bridge TFMediaPlayer *)context;
    
    [player->_displayView displayFrameBuffer:frameBuf];
    return 0;
}


#pragma mark - controls

-(void)seekToPlayTime:(NSTimeInterval)playTime{
    _playController->seekTo(playTime);
    seeked = YES;
}

-(void)seekByForward:(NSTimeInterval)interval{
    _playController->seekByForward(interval);
    seeked = YES;
}

-(void)changeFullScreenState{
    if ([UIDevice currentDevice].orientation == UIDeviceOrientationPortrait || [UIDevice currentDevice].orientation == UIDeviceOrientationPortraitUpsideDown) {
        [UIDevice changeOrientationTo:(UIDeviceOrientationLandscapeRight)];
    }else{
        [UIDevice changeOrientationTo:(UIDeviceOrientationPortrait)];
    }
}

-(double)currentTime{
    if (_state == TFMediaPlayerStatePlaying || _state == TFMediaPlayerStatePause) {
        return _playController->getDisplayer()->getCurrentPlayTime();
    }else{
        return 0;
    }
}

@end
