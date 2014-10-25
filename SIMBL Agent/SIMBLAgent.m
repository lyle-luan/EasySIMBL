/**
 * Copyright 2003-2009, Mike Solomon <mas63@cornell.edu>
 * SIMBL is released under the GNU General Public License v2.
 * http://www.opensource.org/licenses/gpl-2.0.php
 */
/**
 * Copyright 2012, Norio Nomura
 * EasySIMBL is released under the GNU General Public License v2.
 * http://www.opensource.org/licenses/gpl-2.0.php
 */

#import <ScriptingBridge/ScriptingBridge.h>
#import <Carbon/Carbon.h>
#import "SIMBL.h"
#import "SIMBLAgent.h"

@implementation SIMBLAgent

@synthesize waitingInjectionNumber=_waitingInjectionNumber;
@synthesize scriptingAdditionsPath=_scriptingAdditionsPath;
@synthesize osaxPath=_osaxPath;
@synthesize linkedOsaxPath=_linkedOsaxPath;
@synthesize applicationSupportPath=_pluginsPath;
@synthesize plistPath=_plistPath;
@synthesize runningSandboxedApplications=_runningSandboxedApplications;

NSString * const kInjectedSandboxBundleIdentifiers = @"InjectedSandboxBundleIdentifiers";

#pragma NSApplicationDelegate Protocol

- (void) applicationDidFinishLaunching:(NSNotification*)notificaion
{
    //看过
    
    //所以注入就是- (void) injectSIMBL:(NSRunningApplication *)runningApp方法。
    //而注入就是一些注入文件的拷贝EasySIMBL.osax，Container等；
    //SBApplication 发送事件（这个没弄懂）
    //osax.m这个文件应该是EasySIMBL.osax。
    //还有一些漏的源码没看，注入应该还有其他的操作。
    //先弄懂SBApplication好了。
    // plist 文件内Principal class 这个东西调用了plugin的install函数，该函数定义了plugin注入的操作貌似。
    // plist文件内OSAXHandlers，指定了一个handler：InjectEventHandler
    // 该函数在osax.m中调用.被EasySIMBLInitializer代替了，在queue中运行installPlugins，安装plugins。
    
    
    SIMBLLogInfo(@"agent started");
    
    /*You should consider using the NSFileManager methods URLsForDirectory:inDomains: and URLForDirectory:inDomain:appropriateForURL:create:error:. which return URLs, which are the preferred format.*/
    
    //获取Libarary路径:/Users/app/Library
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,  NSUserDomainMask, YES);
    NSString *libraryPath = (NSString*)[paths objectAtIndex:0];
    
    //获取scriptingAdditions路径:/Users/app/Library/ScriptingAdditions
    self.scriptingAdditionsPath = [libraryPath stringByAppendingPathComponent:EasySIMBLScriptingAdditionsPathComponent];
    
    //osaxPath: testVarious.app/Contents/PlugIns/EasySIMBL.osax，貌似是创建了一个EasySIMBL.osax bundle。
    self.osaxPath = [[[[NSBundle mainBundle]builtInPlugInsPath]stringByAppendingPathComponent:EasySIMBLBundleBaseName]stringByAppendingPathExtension:EasySIMBLBundleExtension];
    
    //linkedOsaxPath:/Users/app/Library/ScriptingAdditions/EasySIMBL.osax
    self.linkedOsaxPath = [self.scriptingAdditionsPath stringByAppendingPathComponent:EasySIMBLBundleName];
    
    //避免simbl多次运行吧。
    self.waitingInjectionNumber = 0;
    
    //applicationSupportPath: /Users/app/Library/Application Support/SIMBL simbl在这里读取bundle吧。
    self.applicationSupportPath = [SIMBL applicationSupportPath];
    
    //plistPath:/Users/app/Library/Preferences/com.github.norio-nomura.EasySIMBL.plist
    self.plistPath = [NSString pathWithComponents:[NSArray arrayWithObjects:libraryPath, EasySIMBLPreferencesPathComponent, [EasySIMBLSuiteBundleIdentifier stringByAppendingPathExtension:EasySIMBLPreferencesExtension], nil]];
    
    //我以为是在EasySIMBL中添加的支持
    self.runningSandboxedApplications = [NSMutableArray array];
    
    //The NSDistributedNotificationCenter class provides a way to send notifications to objects in other tasks. It takes NSNotification objects and broadcasts them to any objects in other tasks that have registered for the notification with their task’s default distributed notification center.
    [[NSDistributedNotificationCenter defaultCenter]addObserver:self
                                                       selector:@selector(receiveSIMBLHasBeenLoadedNotification:)
                                                           name:EasySIMBLHasBeenLoadedNotification
                                                         object:nil];
    
    // Save version information，存储App的版本信息，这方法也是有点醉人。
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:[[NSBundle mainBundle]_dt_bundleVersion]
                forKey:[[NSBundle mainBundle]bundleIdentifier]];
    
    // hold previous injected sandbox
    NSMutableSet *previousInjectedSandboxBundleIdentifierSet = [NSMutableSet setWithArray:[defaults objectForKey:kInjectedSandboxBundleIdentifiers]];
    [defaults removeObjectForKey:kInjectedSandboxBundleIdentifiers];
    [defaults synchronize];
    
    /*
     An NSWorkspace object responds to app requests to perform a variety of services:
     
     1.Opening, manipulating, and obtaining information about files and devices
     
     2.Tracking changes to the file system, devices, and the user database
     
     3.Getting and setting Finder information for files.
     
     3.Launching apps
     
     There is one shared NSWorkspace object per app. You use the class method sharedWorkspace to access it. For example, the following statement uses an NSWorkspace object to request that a file be opened in the TextEdit app:
     
     [[NSWorkspace sharedWorkspace] openFile:@"/Myfiles/README"
     withApplication:@"TextEdit"];
     
     懂不起，貌似会触发，以后借蒋公子。
     - (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
     这个函数。
     */
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    [workspace addObserver:self
                forKeyPath:@"runningApplications"
                   options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
                   context:NULL];
    
    // inject into resumed applications，这里不能获取到全部的运行中程序。
    for (NSRunningApplication *runningApp in [workspace runningApplications])
    {
        //一些注入文件的拷贝EasySIMBL.osax，Container等；
        //SBApplication 发送事件（这个没弄懂）
        [self injectSIMBL:runningApp];
    }
    
    // previous minus running, it should be uninject
    [previousInjectedSandboxBundleIdentifierSet minusSet:[NSMutableSet setWithArray:[defaults objectForKey:kInjectedSandboxBundleIdentifiers]]];
    if ([previousInjectedSandboxBundleIdentifierSet count])
    {
        [[NSProcessInfo processInfo] disableSuddenTermination];
        for (NSString *bundleItentifier in previousInjectedSandboxBundleIdentifierSet)
        {
            [self injectContainerBundleIdentifier:bundleItentifier enabled:NO];
        }
        [[NSProcessInfo processInfo] enableSuddenTermination];
    }
}

#pragma mark SBApplicationDelegate Protocol

- (id) eventDidFail:(const AppleEvent *)event withError:(NSError *)error;
{
    return nil;
}

#pragma mark NSKeyValueObserving Protocol

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    //大概看了下，需要kvo知识支撑。
    if ([keyPath isEqualToString:@"isTerminated"])
    {
        SIMBLLogDebug(@"runningApp %@ isTerminated.", object);
        [object removeObserver:self forKeyPath:keyPath];
        
        [self injectContainerForApplication:(NSRunningApplication*)object enabled:NO];
    }
    else if ([keyPath isEqualToString:@"runningApplications"])
    {
        // for apps which will be terminated without called @"isFinishedLaunching"
        static NSMutableSet *appsObservingFinishedLaunching = nil;
        if (!appsObservingFinishedLaunching)
        {
            appsObservingFinishedLaunching = [NSMutableSet set];
        }
        
		for (NSRunningApplication *app in [change objectForKey:NSKeyValueChangeNewKey])
        {
            if (app.isFinishedLaunching)
            {
                SIMBLLogDebug(@"runningApp %@ is already isFinishedLaunching", app);
                [self injectSIMBL:app];
            } else
            {
                [app addObserver:self forKeyPath:@"isFinishedLaunching" options:NSKeyValueObservingOptionNew context:NULL];
                [appsObservingFinishedLaunching addObject:app];
            }
		}
        
		for (NSRunningApplication *app in [change objectForKey:NSKeyValueChangeOldKey])
        {
            if ([appsObservingFinishedLaunching containsObject:app])
            {
                [app removeObserver:self forKeyPath:@"isFinishedLaunching"];
                [appsObservingFinishedLaunching removeObject:app];
            }
        }
    }
    else if ([keyPath isEqualToString:@"isFinishedLaunching"])
    {
        SIMBLLogDebug(@"runningApp %@ isFinishedLaunching.", object);
        [self injectSIMBL:(NSRunningApplication*)object];
    }
}

#pragma mark EasySIMBLHasBeenLoadedNotification

- (void) receiveSIMBLHasBeenLoadedNotification:(NSNotification*)notification
{
    // SIMBL已经成功启动。貌似是注入成功了某个App。
    SIMBLLogDebug(@"receiveSIMBLHasBeenLoadedNotification from %@", notification.object);
	self.waitingInjectionNumber--;
    if (!self.waitingInjectionNumber)
    {
        NSError *error = nil;
        if (![[NSFileManager defaultManager]removeItemAtPath:self.linkedOsaxPath error:&error])
        {
            //如果所有的App都被注入了，则删除/Users/app/Library/ScriptingAdditions/EasySIMBL.osax文件？
            SIMBLLogNotice(@"removeItemAtPath error:%@",error);
        }
    }
    [[NSProcessInfo processInfo]enableSuddenTermination];
}

#pragma mark -

- (void) injectSIMBL:(NSRunningApplication *)runningApp
{
    //对正在运行的程序开始注入。
    
	// NOTE: if you change the log level externally, there is pretty much no way
	// to know when the changed. Just reading from the defaults doesn't validate
	// against the backing file very ofter, or so it seems.
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults synchronize];
    
    if ([[NSRunningApplication currentApplication] isEqual:runningApp])
    {
        //自己当然不用诸如自己
        return;
    }
    
	NSString* appName = [runningApp localizedName];
	SIMBLLogInfo(@"%@ started", appName);
	SIMBLLogDebug(@"app start notification: %@", runningApp);
    
	// check to see if there are plugins to load，
    // 这里的plugin就是开发者开发的目标插件吧，例如afloat。
    if ([SIMBL shouldInstallPluginsIntoApplication:runningApp] == NO)
    {
        SIMBLLogDebug(@"No plugins match for %@", runningApp);
		return;
	}
	
	// BUG: http://code.google.com/p/simbl/issues/detail?id=11
	// NOTE: believe it or not, some applications cause a crash deep in the
	// ScriptingBridge code. Due to the launchd behavior of restarting crashed
	// agents, this is mostly harmless. To reduce the crashing we leave a
	// blacklist to prevent injection.  By default, this is empty.
    // 因为有些App在ScriptingBridge调用中会崩溃，所以添加了个黑名单功能。好吧。
	NSString* appIdentifier = [runningApp bundleIdentifier];
	NSArray* blacklistedIdentifiers = [defaults stringArrayForKey:@"SIMBLApplicationIdentifierBlacklist"];
	if (blacklistedIdentifiers != nil &&
        [blacklistedIdentifiers containsObject:appIdentifier])
    {
		SIMBLLogNotice(@"ignoring injection attempt for blacklisted application %@ (%@)", appName, appIdentifier);
		return;
	}
    
	SIMBLLogDebug(@"send inject event");
	
    //现在是要开始注入了吧。
    
    ///Users/app/Library/ScriptingAdditions/ 判断是否存在该目录。
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:self.scriptingAdditionsPath isDirectory:&isDirectory])
    {
        if (![fileManager createDirectoryAtPath:self.scriptingAdditionsPath
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&error])
        {
            SIMBLLogNotice(@"createDirectoryAtPath error:%@",error);
            return;
        }
    }
    else if (!isDirectory)
    {
        SIMBLLogNotice(@"%@ is file. Expect are directory", self.scriptingAdditionsPath);
        return;
    }
    
    //testVarious.app/Contents/PlugIns/EasySIMBL.osax 判断该文件存在，所以这是个啥文件？
    if ([fileManager fileExistsAtPath:self.osaxPath isDirectory:&isDirectory] && isDirectory)
    {
        // Find the process to target
        pid_t pid = [runningApp processIdentifier];
        
        //通过runningApp的pid来创建一个SBApplication对象
        SBApplication* sbApp = [SBApplication applicationWithProcessIdentifier:pid];
        [sbApp setDelegate:self];
        if (!sbApp)
        {
            SIMBLLogNotice(@"Can't find app with pid %d", pid);
            return;
        }
        
        // create SIMBL.osax to ScriptingAdditions
        // 原来是在这里生成的
        // 把App文件内的该文件拷贝到Library目录下。
        if (!self.waitingInjectionNumber)
        {
            // 删除/Users/app/Library/ScriptingAdditions/EasySIMBL.osax该文件，要重新生成
            // 看来EasySIMBL.osax本来是在App文件内的，运行时会被拷贝到Library目录下。
            [fileManager removeItemAtPath:self.linkedOsaxPath error:nil];
            
            // check fileSystems
            // NSFileSystemNumber:The key in a file system attribute dictionary dictionary whose value indicates the filesystem number of the file system.不懂。
            id fsOflinkedOsax = [[fileManager attributesOfItemAtPath:self.scriptingAdditionsPath error:&error] objectForKey:NSFileSystemNumber];
            if (error)
            {
                SIMBLLogNotice(@"attributesOfItemAtPath error:%@",error);
                return;
            }
            id fsOfOsax = [[fileManager attributesOfItemAtPath:self.osaxPath error:&error] objectForKey:NSFileSystemNumber];
            if (error)
            {
                SIMBLLogNotice(@"attributesOfItemAtPath error:%@",error);
                return;
            }
            
            // 貌似是如果在同一个文件系统，就创建硬链接，不然就拷贝。
            if ([fsOflinkedOsax isEqual:fsOfOsax])
            {
                // create hard link
                if (![fileManager linkItemAtPath:self.osaxPath toPath:self.linkedOsaxPath error:&error])
                {
                    SIMBLLogNotice(@"linkItemAtPath error:%@",error);
                    return;
                }
            }
            else
            {
                // create copy
                if (![fileManager copyItemAtPath:self.osaxPath toPath:self.linkedOsaxPath error:&error])
                {
                    SIMBLLogNotice(@"copyItemAtPath error:%@",error);
                    return;
                }
            }
        }
        
        self.waitingInjectionNumber++;
        
        // hardlink to Container
        // 什么东东？
        // 对runningApp注入Container，并将其bundleIdentifier保存起来。
        [self injectContainerForApplication:runningApp enabled:YES];
        
        
        // Force AppleScript to initialize in the app, by getting the dictionary
        // When initializing, you need to wait for the event reply, otherwise the
        // event might get dropped on the floor. This is only seems to happen in 10.5
        // but it shouldn't harm anything.
        
        // 10.9 stop responding here when injecting into some non-sandboxed apps,
        // because those target apps never reply.
        // EasySIMBL stop waiting reply.
        // It works on OS X 10.7, 10.8 and 10.9 all of EasySIMBL target.
        //总之对于OS X 10.7, 10.8 and 10.9没有问题，不知道10.10有问题不。
        
        // 这两句不好懂呐，要看苹果官方文档才行。
        [sbApp setSendMode:kAENoReply | kAENeverInteract | kAEDontRecord];
        [sbApp sendEvent:kASAppleScriptSuite id:kGetAEUT parameters:0];
        
        // the reply here is of some unknown type - it is not an Objective-C object
        // as near as I can tell because trying to print it using "%@" or getting its
        // class both cause the application to segfault. The pointer value always seems
        // to be 0x10000 which is a bit fishy. It does not seem to be an AEDesc struct
        // either.
        // since we are waiting for a reply, it seems like this object might need to
        // be released - but i don't know what it is or how to release it.
        // NSLog(@"initReply: %p '%64.64s'", initReply, (char*)initReply);
        // 因为EasySIMBL不用等回复，所以不管。
        
        // Inject!
        //ESIM应该是自定义的事件。
        [sbApp setSendMode:kAENoReply | kAENeverInteract | kAEDontRecord];
        id injectReply = [sbApp sendEvent:'ESIM' id:'load' parameters:0];
        if (injectReply != nil)
        {
            SIMBLLogNotice(@"unexpected injectReply: %@", injectReply);
        }
        [[NSProcessInfo processInfo] disableSuddenTermination];
    }
}

- (void)injectContainerForApplication:(NSRunningApplication*)runningApp enabled:(BOOL)bEnabled;
{
    NSString *identifier = [runningApp bundleIdentifier];
    if (bEnabled)
    {
        if ([self injectContainerBundleIdentifier:identifier enabled:YES])
        {
            SIMBLLogDebug(@"Start observing %@'s 'isTerminated'.", identifier);
            
            //监听isTerminated，又是KVO.
            [runningApp addObserver:self forKeyPath:@"isTerminated" options:NSKeyValueObservingOptionNew context:NULL];
            
            //注入完Container的runningApp暂存在runningSandboxedApplications
            [self.runningSandboxedApplications addObject:runningApp];
            
            //将runningSandboxedApplications中的runningApp的bundleIdentifier存放到injectedSandboxBundleIdentifierSet中。
            NSMutableSet *injectedSandboxBundleIdentifierSet = [NSMutableSet set];
            for (NSRunningApplication *app in self.runningSandboxedApplications)
            {
                [injectedSandboxBundleIdentifierSet addObject:[app bundleIdentifier]];
            }
            
            //将这些bundleIdentifier保存起来。
            [[NSUserDefaults standardUserDefaults]setObject:[injectedSandboxBundleIdentifierSet allObjects]
                                                     forKey:kInjectedSandboxBundleIdentifiers];
            [[NSUserDefaults standardUserDefaults]synchronize];
        }
    }
    else
    {
        //这里是清除咯，先不看。
        BOOL (^hasSameBundleIdentifier)(id, NSUInteger, BOOL *) = ^(id obj, NSUInteger idx, BOOL *stop) {
            return *stop = [identifier isEqualToString:[(NSRunningApplication*)obj bundleIdentifier]];
        };
        
        [self.runningSandboxedApplications removeObject:runningApp];
        // check multi instance application
        if (NSNotFound == [self.runningSandboxedApplications indexOfObjectWithOptions:NSEnumerationConcurrent
                                                                          passingTest:hasSameBundleIdentifier])
        {
            if ([self injectContainerBundleIdentifier:identifier enabled:NO])
            {
                
                NSMutableSet *injectedSandboxBundleIdentifierSet = [NSMutableSet set];
                for (NSRunningApplication *app in self.runningSandboxedApplications)
                {
                    [injectedSandboxBundleIdentifierSet addObject:[app bundleIdentifier]];
                }
                [[NSUserDefaults standardUserDefaults]setObject:[injectedSandboxBundleIdentifierSet allObjects]
                                                         forKey:kInjectedSandboxBundleIdentifiers];
                [[NSUserDefaults standardUserDefaults]synchronize];
            }
        }
    }
}

//把/Users/app/Library/中的一些文件注入到/Users/app/Library/Containers/xxx(bundleIdentifier)/Data/Library/中
- (BOOL)injectContainerBundleIdentifier:(NSString*)bundleIdentifier enabled:(BOOL)bEnabled;
{
    BOOL bResult = NO;
    if ([bundleIdentifier length]>0)
    {
        // 创建containerPath：/Users/app/Library/Containers/xxx(bundleIdentifier)/
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,  NSUserDomainMask, YES);
        NSString *containerPath = [NSString pathWithComponents:[NSArray arrayWithObjects:[paths objectAtIndex:0], @"Containers", bundleIdentifier, nil]];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        BOOL isDirectory = NO;
        
        if ([fileManager fileExistsAtPath:containerPath isDirectory:&isDirectory] && isDirectory)
        {
            ///Users/app/Library/Containers/xxx(bundleIdentifier)/ 是一个路径而不是文件。
            
            //containerScriptingAddtionsPath: /Users/app/Library/Containers/xxx(bundleIdentifier)/Data/Library/ScriptingAdditions
            NSString *dataLibraryPath = @"Data/Library";
            NSString *containerScriptingAddtionsPath = [NSString pathWithComponents:[NSArray arrayWithObjects:containerPath, dataLibraryPath, EasySIMBLScriptingAdditionsPathComponent, nil]];
            
            //containerApplicationSupportPath: /Users/app/Library/Containers/xxx(bundleIdentifier)/Data/Library/Application Support/SIMBL
            NSString *containerApplicationSupportPath = [NSString pathWithComponents:[NSArray arrayWithObjects:containerPath, dataLibraryPath, EasySIMBLApplicationSupportPathComponent, nil]];
            
            //containerPlistPath: /Users/app/Library/Containers/xxx(bundleIdentifier)/Data/Library/com.github.norio-nomura.EasySIMBL.plist
            NSString *containerPlistPath = [NSString pathWithComponents:[NSArray arrayWithObjects:containerPath, dataLibraryPath,EasySIMBLPreferencesPathComponent, [EasySIMBLSuiteBundleIdentifier stringByAppendingPathExtension:EasySIMBLPreferencesExtension], nil]];
            
            if (bEnabled)
            {
                if (![fileManager linkItemAtPath:self.scriptingAdditionsPath toPath:containerScriptingAddtionsPath error:&error])
                {
                    SIMBLLogNotice(@"linkItemAtPath error:%@",error);
                }
                if (![fileManager linkItemAtPath:self.applicationSupportPath toPath:containerApplicationSupportPath error:&error])
                {
                    SIMBLLogNotice(@"linkItemAtPath error:%@",error);
                }
                if ([fileManager fileExistsAtPath:self.plistPath] && ![fileManager linkItemAtPath:self.plistPath toPath:containerPlistPath error:&error])
                {
                    SIMBLLogNotice(@"linkItemAtPath error:%@",error);
                }
                bResult = YES;
                SIMBLLogDebug(@"%@'s container has been injected.", bundleIdentifier);
            }
            else
            {
                if (![fileManager removeItemAtPath:containerScriptingAddtionsPath error:&error])
                {
                    SIMBLLogNotice(@"removeItemAtPath error:%@",error);
                }
                if (![fileManager removeItemAtPath:containerApplicationSupportPath error:&error])
                {
                    SIMBLLogNotice(@"removeItemAtPath error:%@",error);
                }
                if ([fileManager fileExistsAtPath:containerPlistPath] && ![fileManager removeItemAtPath:containerPlistPath error:&error])
                {
                    SIMBLLogNotice(@"removeItemAtPath error:%@",error);
                }
                bResult = YES;
                SIMBLLogDebug(@"%@'s container has been uninjected.", bundleIdentifier);
            }
        }
    }
    return bResult;
}

@end
