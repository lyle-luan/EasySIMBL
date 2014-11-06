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
    // 为什么easy的osax拷贝在用户目录下可行，但是simbl和我的都不行。
    // 难道是sdef这种方式的问题？
    // 把osaxhandlers的Context从Process改为User后，将osax放在/Libarary...目录下不能加载，但是放到用户的library目录下也不行，但是感觉就是这里了。
    
    // easy还可以hack carbon程序呢。
    // 不是，是能hack finder，但是sublime不行。
    
    // 不要SB，，，在osax中实现带Initializer字段的函数就行，该函数在osax被加载时自动调用。
    // 不是函数名的问题，是要加这个字段__attribute__((constructor))，这个字段修饰的函数会在share library加载的时候调用。
    // 这个字段__attribute__((destructor))修饰的是在share library卸载的时候调用。
    // 这样可以把osax放到用户的library目录下。GOOD。
    
    // 还是要SB，不然不会加载__attribute__((constructor))函数，奇怪，但是osax不用sdef文件了。那传什么命令都可以么？
    // 不行，还是要发osaxhandlers注册的命令。
    
    // 总之SB都是要的，都要发Apple events，使用__attribute__((constructor))可以在用户的目录下，而且两种都不是每次都触发。所以感觉用__attribute__((constructor))好一点。
    
    // 不是每次都触发可能跟监听app启动有关感觉。
    
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
    
    
    //
    // 看了easysimbl的提交纪录，发现easysimbl的修改不关乎怎么注入，以下事件用来注入：
    //
    // SBApplication 发送事件（这个没弄懂）看了SBApplication文档也看了示例还是没弄懂。
    // 在EasySIMBL中没有了sdp,sdef这两个命令，在SIMBL中有。
    // sdef命令产生.sdef文件，在SIMBL中有该文件，形似XML，使用sdp转化该文件后，可以得到SBApplication的某个子类的头文件，该文件里定义了SBApplicatin发送event对应的函数。EasySIMBL应该是直接把该头文件include进工程了。
    // 在SIMBL中SBApplication发送SIMe，在SIMBL.sdef中找到命令是SIMeleop或者SIMeload，在SIMBL目标的plist中找到对应value是InjectEventHandler。就是调用installPlugins。也就是找到Principal 然后执行install。
    // 在InjectEventHandler函数中已经是其他App了？
    // 这里执行的是bundle的类install方法，为什么在plugin中执行的确实load类方法。
    // 在SIMBL中install是以下：
    // @protocol SIMBLPlugin
    // + (void) install;
    // @end
    // 定义的协议中的类方法。只是为了声明一个install类方法，不然在用principal那就不能调用，函数未定义。也可以声明为一个简单的类方法声明，但是这样会有警告，有声明没定义。
    //
    
    // 在Afloat中的plist文件内定义的Principal类是Afloat类，里面定义了load类方法，但是该方法没有外部链接。
    // 这个install是什么？
    // load和install都会执行，load是加载bundle自动执行的，install是principal类执行的。load跟principal无关，应该类似main这样的函数。
    
    // 接口：- (id)sendEvent:(AEEventClass)eventClass id:(AEEventID)eventID parameters:(DescType)firstParamCode。sendEvent参数是SIMe，id参数是AEEventID类型的'load'或者'leop'来确定执行的事sdef文件中SIMeleop和SIMeload分别定义的命令，只是这里是一样的。
    
    // 这跟Info.plist文件内的OSAXHandlers有毛关系。here
    // 大关系咯，SIMBL既是event的发送者也是接收者，发送用SBApplication可以发送，接收需要一个OSAX类型的bundle，并且通过定义OSAXHandlers来确定接收event后的处理。
    
    // SIMBL里好像不用指定目标App的头文件？SBApplication发送就是接收到的都会响应？也就是说不用sdef文件哪些东西？还是先试试OSAX好了，如果不行在详细看看Scripting Bridge的编程指南。
    
    // SIMBL的文档：描述怎么写plugin的，步骤如下：
    
    // 1.编辑Info.plist文件，添加principalclass。
    // 2.+(void)load类方法，SIMBL加载某个plugin的principal类后执行的方法。单实例：singleton object。
    //
    // 这么看来SBApplication没用呀：启动的App发送event，SIMBL得到event触发自己的函数？奇怪
    // SIMBL用[[NSWorkspace sharedWorkspace] notificationCenter]的NSWorkspaceDidLaunchApplicationNotification事件获取启动的App。
    // Easy用[NSWorkspace sharedWorkspace]的KVO来获取正在执行的App。
    
    
    
    
    
    // 拷贝EasySIMBL.osax，Container等，easy修改了路径。
    // SIMBL没有该部分代码。
    
    
    
    
    
    
    // Principal class：
    // NSPrincipalClass (String - OS X). This key contains a string with the name of a bundle’s principal class. This key is used to identify the entry point for dynamically loaded code, such as plug-ins and other dynamically-loaded bundles. The principal class of a bundle typically controls all other classes in the bundle and mediates between those classes and any classes outside the bundle. The class identified by this value can be retrieved using the principalClass method of NSBundle. For Cocoa apps, the value for this key is NSApplication by default.
    
    /*NSBundle principalClass
     The bundle’s principal class. (read-only)
     
     Declaration
     SWIFT
     var principalClass: AnyClass? { get }
     OBJECTIVE-C
     @property(readonly) Class principalClass
     Discussion
     This property is set after ensuring that the code containing the definition of the class is dynamically loaded. If the bundle encounters errors in loading or if it can’t find the executable code file in the bundle directory, this property is nil.
     
     The principal class typically controls all the other classes in the bundle; it should mediate between those classes and classes external to the bundle. Classes (and categories) are loaded from just one file within the bundle directory. The bundle obtains the name of the code file to load from the dictionary returned from infoDictionary, using “NSExecutable” as the key. The bundle determines its principal class in one of two ways:
     
     It first looks in its own information dictionary, which extracts the information encoded in the bundle’s property list (Info.plist). The bundle obtains the principal class from the dictionary using the key NSPrincipalClass. For non-loadable bundles (applications and frameworks), if the principal class is not specified in the property list, this property is nil.
     
     If the principal class is not specified in the information dictionary, the bundle identifies the first class loaded as the principal class. When several classes are linked into a dynamically loadable file, the default principal class is the first one listed on the ld command line. In the following example, Reporter would be the principal class:
     
     ld -o myBundle -r Reporter.o NotePad.o QueryList.o
     The order of classes in Xcode’s project browser is the order in which they will be linked. To designate the principal class, control-drag the file containing its implementation to the top of the list.
     
     As a side effect of code loading, the receiver posts NSBundleDidLoadNotification after all classes and categories have been loaded; see Notifications for details.
     */
    
    // 这貌似是个坑。SIMBL有两个target，其中一个的principalClass是SIMBL类，该类没有实现install方法。
    
    
    // 貌似是目标App发送events，比如你想给mail发送event，那么你需要过的mail的SBApplicatin类，然后sendEvent。发送者就是接受者。
    // 是的，用谁的sbapplication发送，谁就是terget，它就响应。
    
    
    
    // 终于弄明白了：
    // osax放到系统目录下，某个app都会加载osax，osax注册接受Apple event。
    // simbl检测启动的app，然后像app发送Apple event，相当于向osax发送。
    // 因此目标app加载plugin。
    // osax为脚本扩展，给所有app添加了响应Apple event的方法。
    // 但是carban为啥不行勒。
    
    // 编译osaxTry将osaxTryosax.osax放置到/Library/ScriptingAdditions目录下。
    // 启动AnthorScriptTest项目，监听启动App和发送scripting bridge消息。
    // 启动thirdScriptTest，自动加载osax，响应AnthorScriptTest向osax发送的消息。

    
    // [sbApp setSendMode:kAENoReply | kAENeverInteract | kAEDontRecord];
    // [sbApp sendEvent:kASAppleScriptSuite id:kGetAEUT parameters:0];
    // 多发以上两行，App启动后响应的概率提高。
    
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
        // SBApplication的父类SBObject的方法sendEvent。
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
