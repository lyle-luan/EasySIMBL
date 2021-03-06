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

#import "SIMBL.h"
#import "NSAlert_SIMBL.h"

@implementation NSBundle (SIMBLCocoaExtensions)

/*!
 *  Non cached version of -infoDictionary
 *
 *  @return A dictionary, constructed from the bundle's Info.plist file, that contains information about the receiver.
 *          If the bundle does not contain an Info.plist file, a empty dictionary is returned.
 */
- (NSDictionary*) SIMBL_infoDictionary;
{
    // 将bundle的 Info.plist文件读取为一个字典。
    NSString* infoPath = [[self bundlePath]stringByAppendingPathComponent:@"/Contents/Info.plist"];
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    return dictionary;
}

/*!
 *  Non cached and non localized version of -objectForInfoDictionaryKey: key
 *
 *  @param key A key in the receiver's property list.
 *
 *  @return The value associated with key in the receiver's property list (Info.plist).
 */
- (id) SIMBL_objectForInfoDictionaryKey: (NSString*)key
{
    //读取bundleInfo.plist文件某个key的value。
    return [[self SIMBL_infoDictionary]objectForKey:key];
}

- (NSString*) _dt_info
{
    // CFBundleGetInfoString这个key来老了，NSHumanReadableCopyright来代替他。
    // 获取bundle的版权信息，比如： © 2008, My Company
	return [self SIMBL_objectForInfoDictionaryKey: @"CFBundleGetInfoString"];
}

- (NSString*) _dt_version
{
    // bundle版本
	return [self SIMBL_objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
}

- (NSString*) _dt_bundleVersion
{
    // bundle的版本
	return [self SIMBL_objectForInfoDictionaryKey: (NSString*)kCFBundleVersionKey];
}

- (NSString*) _dt_name
{
    // bundle名字
	return [self SIMBL_objectForInfoDictionaryKey:(NSString*)kCFBundleNameKey];
}

- (BOOL) SIMBL_isLSUIElement
{
    // 以下解释下LSUIElement：
    // “Application is agent (UIElement)”
    // Specifies whether the app is an agent app, that is, an app that should not appear in the Dock or Force Quit window. See LSUIElement for details.
    // details:
    // LSUIElement (String - OS X) specifies whether the app runs as an agent app. If this key is set to “1”, Launch Services runs the app as an agent app. Agent apps do not appear in the Dock or in the Force Quit window. Although they typically run as background apps, they can come to the foreground to present a user interface if desired. A click on a window belonging to an agent app brings that app forward to handle events.
    // controlWindows就是这样的嘛。
    // 不出现在“Dock”和“强制退出”中，一般运行在后台，偶尔出来接受用户的交互。
    
    // The Dock and loginwindow are two apps that run as agent apps.
    return [[self SIMBL_objectForInfoDictionaryKey:@"LSUIElement"]boolValue];
}

- (BOOL) SIMBL_isLSBackgroundOnly
{
    // 后台程序，嗯。
    return [[self SIMBL_objectForInfoDictionaryKey:@"LSBackgroundOnly"]boolValue];
}

@end

/*
 <key>SIMBLTargetApplications</key>
 <array>
 <dict>
 <key>BundleIdentifier</key>
 <string>com.apple.Safari</string>
 <key>MinBundleVersion</key>
 <integer>125</integer>
 <key>MaxBundleVersion</key>
 <integer>125</integer>
 </dict>
 </array>
 */

@implementation SIMBL

static NSMutableDictionary* loadedBundleIdentifiers = nil;

+ (void) initialize
{
    // The runtime sends initialize to each class in a program just before the class,
    // 也就是必然会执行。
    
    if (![[[NSBundle mainBundle]bundleIdentifier] isEqualToString:EasySIMBLSuiteBundleIdentifier])
    {
        //如果bundle不是com.github.norio-nomura.EasySIMBL的话
        //所以bundle到底是啥，这么神奇。
        NSUserDefaults* defaults = [[NSUserDefaults alloc] init];
        
        //Inserts the specified domain name into the receiver’s search list.
        //The suiteName domain is similar to a bundle identifier string, but is not necessarily tied to a particular application or bundle. A suite can be used to hold preferences that are shared between multiple applications.
        //Searches of preferences tied to a suite follow the normal pattern, searching first for current user, current host, then
        //嗯?
        [defaults addSuiteNamed:EasySIMBLSuiteBundleIdentifier];
        
        //关于log的等级，添加在NSUserDefaults里，奇怪。
        // 添加一个 NSRegistrationDomain 。
        // NSRegistrationDomain： The domain consisting of a set of temporary defaults whose values can be set by the application to ensure that searches will always be successful.
        // 避免搜索失败的临时工，，
        [defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:SIMBLLogLevelDefault], SIMBLPrefKeyLogLevel, nil]];
        
        // ARC与非ARC混合编译，所以我们不需要他。
#if !__has_feature(objc_arc)
        [defaults release];
#endif
    }
}

//哪些打印log宏定义的函数原型。
+ (void) logMessage:(NSString*)message atLevel:(int)level
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if (![[[NSBundle mainBundle]bundleIdentifier] isEqualToString:EasySIMBLSuiteBundleIdentifier])
    {
        [defaults addSuiteNamed:EasySIMBLSuiteBundleIdentifier];
    }
	if ([defaults integerForKey:SIMBLPrefKeyLogLevel] <= level)
    {
		NSLog(@"#EasySIMBL %@", message);
	}
}

+ (NSArray*) pluginPathList
{
	NSMutableArray* pluginPathList = [NSMutableArray array];
    
    // NSApplicationSupportDirectory does not return Container, so use NSLibraryDirectory.
    
    //在/Library/Application Support/SIMBL/Plugins和~/Library/Application Support/SIMBL/Plugins
    //两个路径下查找plugin。
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,  NSUserDomainMask, YES);
    
	for (NSString* libraryPath in paths)
    {
		NSString* simblPath = [NSString pathWithComponents:[NSArray arrayWithObjects:libraryPath, EasySIMBLApplicationSupportPathComponent, EasySIMBLPluginsPathComponent, nil]];
        
        NSError *err = NULL;
		
        //读取目录下，以bundle结尾的文件名的数组
        NSArray* simblBundles = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:simblPath error:&err] pathsMatchingExtensions:[NSArray arrayWithObject:@"bundle"]];
        
        if (err)
        {
            SIMBLLogNotice(@"contentsOfDirectoryAtPath err:%@",err);
        }
        
        //把读取到的需要注入的plugin放置到数组中备用。
		for (NSString* bundleName in simblBundles)
        {
			[pluginPathList addObject:[simblPath stringByAppendingPathComponent:bundleName]];
		}
	}
	return pluginPathList;
}


+ (void) installPlugins
{
    //在osax.m中调用。
	if (loadedBundleIdentifiers == nil)
    {
        //线程不安全的单例
		loadedBundleIdentifiers = [[NSMutableDictionary alloc] init];
    }
	
	SIMBLLogDebug(@"SIMBL loaded by path %@ <%@>", [[NSBundle mainBundle] bundlePath], [[NSBundle mainBundle]bundleIdentifier]);
	
    //为本程序安装插件。
	for (NSString* path in [SIMBL pluginPathList])
    {
		BOOL bundleLoaded = [SIMBL loadBundleAtPath:path];
		if (bundleLoaded)
        {
			SIMBLLogDebug(@"loaded %@", path);
        }
	}
    
    [[NSDistributedNotificationCenter defaultCenter]postNotificationName:EasySIMBLHasBeenLoadedNotification
                                                                  object:[[NSBundle mainBundle]bundleIdentifier]];
}


+ (BOOL) shouldInstallPluginsIntoApplication:(NSRunningApplication*)runningApp;
{
    //只安装一个plugin？
    //对于一个runningApp只注入一个plugin，可能是一次只注入一个吧。
    //不是上面的描述，这个类方法是判断对runningApp是否要注入。
    //读取目标路径内的每个需要注入的plugin。
	for (NSString* path in [SIMBL pluginPathList])
    {
		BOOL bundleShouldInstallPlugins = [SIMBL shouldApplication:runningApp loadBundleAtPath:path];
		if (bundleShouldInstallPlugins)
        {
			SIMBLLogDebug(@"should install plugin %@", path);
			return YES;
        }
	}
	return NO;
}


+ (NSString*)applicationSupportPath;
{
    // 返回该路径/Users/app/Library/Application Support/SIMBL
    static NSString *applicationSupportPath = nil;
    if (!applicationSupportPath) {
        
        // NSApplicationSupportDirectory does not return Container, so use NSLibraryDirectory.
        
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,  NSUserDomainMask, YES);
        applicationSupportPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:EasySIMBLApplicationSupportPathComponent];
    }
    return applicationSupportPath;
}

/**
 * get this list of allowed application identifiers from the plugin's Info.plist
 * the special value * will cause any Cocoa app to load a bundle
 * @return YES if this should be loaded
 */
+ (BOOL) shouldLoadBundleAtPath:(NSString*)_bundlePath
{
    //获取本程序的NSRunningApplication对象
	NSRunningApplication *runningApp = [NSRunningApplication currentApplication];
	return [SIMBL shouldApplication:runningApp loadBundleAtPath:_bundlePath];
}


/**
 * get this list of allowed application identifiers from the plugin's Info.plist
 * the special value * will cause any Cocoa app to load a bundle
 * @return YES if this should be loaded
 * plugin可以设置其需要注入的App，比如只注入Safari。
 */
+ (BOOL) shouldApplication:(NSRunningApplication*)runningApp loadBundleAtPath:(NSString*)_bundlePath
{
	SIMBLLogDebug(@"checking bundle %@", _bundlePath);
	_bundlePath = [_bundlePath stringByStandardizingPath];
    
	NSBundle* pluginBundle = [NSBundle bundleWithPath:_bundlePath];
    
	if (pluginBundle == nil)
    {
		SIMBLLogNotice(@"Unable to load bundle at path '%@'", _bundlePath);
		return NO;
	}
	
	NSString* pluginIdentifier = [pluginBundle bundleIdentifier];
	if (pluginIdentifier == nil)
    {
		SIMBLLogNotice(@"No identifier for bundle at path '%@'", _bundlePath);
		return NO;
	}
	
	// this is the new way of specifying when to load a bundle
    // 从bundle的info.plis文件中读出该bundle注入的App。
	NSArray* targetApplications = [pluginBundle SIMBL_objectForInfoDictionaryKey:SIMBLTargetApplications];
	if (targetApplications)
    {
		return [self shouldApplication:runningApp loadBundle:pluginBundle withTargetApplications:targetApplications];
    }
	
	// fall back to the old method for older plugins - we should probably throw a depreaction warning
    // 旧方法，跟上面那个差不多一样。
	NSArray* applicationIdentifiers = [pluginBundle SIMBL_objectForInfoDictionaryKey:SIMBLApplicationIdentifier];
    
	if (applicationIdentifiers)
    {
		return [self shouldApplication:runningApp loadBundle:pluginBundle withApplicationIdentifiers:applicationIdentifiers];
    }
	
	return NO;
}


/**
 * get this list of allowed application identifiers from the plugin's Info.plist
 * the special value * will cause any Cocoa app to load a bundle
 * if there is a match, this calls the main bundle's load method
 * @return YES if this bundle was loaded
 * 安装plugin。
 */
+ (BOOL) loadBundleAtPath:(NSString*)_bundlePath
{
	if ([SIMBL shouldLoadBundleAtPath:_bundlePath] == NO)
    {
		return NO;
	}
	
    //本程序需要安装该插件？有点不对呀。
    
	NSBundle* pluginBundle = [NSBundle bundleWithPath:_bundlePath];
    
	// check to see if we already loaded code for this identifier (keeps us from double loading)
	// this is common if you have User vs. System-wide installs - probably mostly for developers
	// "physician, heal thyself!"
	NSString* pluginIdentifier = [pluginBundle bundleIdentifier];
	if ([loadedBundleIdentifiers objectForKey:pluginIdentifier] != nil)
    {
		return NO;
    }
	return [SIMBL loadBundle:pluginBundle];
}


/**
 * get this list of allowed application identifiers from the plugin's Info.plist
 * the special value * will cause any Cocoa app to load a bundle
 * if there is a match, this calls the main bundle's load method
 * @return YES if this bundle should be loaded
 */
+ (BOOL) shouldApplication:(NSRunningApplication*)runningApp loadBundle:(NSBundle*)_bundle withApplicationIdentifiers:(NSArray*)_applicationIdentifiers
{
    // App是否需要安装改bundle。
	NSString* appIdentifier = [runningApp bundleIdentifier];
	for (NSString* specifiedIdentifier in _applicationIdentifiers) {
		SIMBLLogDebug(@"checking bundle %@ for identifier %@", [_bundle bundleIdentifier], specifiedIdentifier);
		if ([specifiedIdentifier isEqualToString:appIdentifier] == YES ||
            // wildcard targeting plugins should not be loaded into background apps or agent apps
			([specifiedIdentifier isEqualToString:@"*"] == YES &&
             runningApp.activationPolicy != NSApplicationActivationPolicyAccessory &&
             runningApp.activationPolicy != NSApplicationActivationPolicyProhibited)) {
			SIMBLLogDebug(@"load bundle %@", [_bundle bundleIdentifier]);
			SIMBLLogNotice(@"The plugin %@ (%@) is using a deprecated interface to SIMBL. Please contact the appropriate developer (not the SIMBL author) and refer them to http://code.google.com/p/simbl/wiki/Tutorial", [_bundle bundlePath], [_bundle bundleIdentifier]);
			return YES;
		}
	}
	
	return NO;
}


/**
 * get this list of allowed target applications from the plugin's Info.plist
 * the special value * will cause any Cocoa app to load a bundle
 * if there is a match, this calls the main bundle's load method
 * @return YES if this bundle should be loaded
 * 这里是主要的函数，貌似，它会调用在bundle中定义的函数，在runningApp中运行。结果不是。
 */
+ (BOOL) shouldApplication:(NSRunningApplication*)runningApp loadBundle:(NSBundle*)_bundle withTargetApplications:(NSArray*)_targetApplications
{
    //获取runningApp的标示
	NSString* appIdentifier = [runningApp bundleIdentifier];
    
    //获取runningApp的bundle
    NSURL *bundleURL = runningApp.bundleURL;
    NSBundle *_appBundle = bundleURL ? [NSBundle bundleWithURL:bundleURL] : nil;
    
    //遍历plugin的targetApp
	for (NSDictionary* targetAppProperties in _targetApplications)
    {
		NSString* targetAppIdentifier = [targetAppProperties objectForKey:SIMBLBundleIdentifier];
		SIMBLLogDebug(@"checking target identifier %@", targetAppIdentifier);
        
        //wildcard targeting plugins should not be loaded into background apps or agent apps
        
//        The following activation policies control whether and how an application may be activated.  They are determined by the Info.plist.
//        typedef NS_ENUM(NSInteger, NSApplicationActivationPolicy) {
//            The application is an ordinary app that appears in the Dock and may have a user interface.  This is the default for bundled apps, unless overridden in the Info.plist.
//            NSApplicationActivationPolicyRegular,
//            
//            The application does not appear in the Dock and does not have a menu bar, but it may be activated programmatically or by clicking on one of its windows.  This corresponds to LSUIElement=1 in the Info.plist.
//            NSApplicationActivationPolicyAccessory,
//            
//            The application does not appear in the Dock and may not create windows or be activated.  This corresponds to LSBackgroundOnly=1 in the Info.plist.  This is also the default for unbundled executables that do not have Info.plists.
//            NSApplicationActivationPolicyProhibited
//        };
        // 如果改plugin注入到所有的App（＊），不应该注入到后台(NSApplicationActivationPolicyAccessory)和agentApp(NSApplicationActivationPolicyProhibited)。
        if ([targetAppIdentifier isEqualToString:@"*"] == YES &&
            (runningApp.activationPolicy == NSApplicationActivationPolicyAccessory ||
             runningApp.activationPolicy == NSApplicationActivationPolicyProhibited))
        {
            continue;
        }
        
		if ([targetAppIdentifier isEqualToString:appIdentifier] == NO &&
            [targetAppIdentifier isEqualToString:@"*"] == NO)
        {
			continue;
        }
        
        //在plist中读取的App的路径，不同于runningApp的路径
		NSString* targetAppPath = [targetAppProperties objectForKey:SIMBLTargetApplicationPath];
		if (targetAppPath && [targetAppPath isEqualToString:[_appBundle bundlePath]] == NO)
        {
			continue;
        }
        
		// FIXME: this has never been used - it should probably be removed.
		NSArray* requiredFrameworks = [targetAppProperties objectForKey:SIMBLRequiredFrameworks];
		BOOL missingFramework = NO;
		if (requiredFrameworks)
		{
			SIMBLLogDebug(@"requiredFrameworks: %@", requiredFrameworks);
			NSEnumerator* requiredFrameworkEnum = [requiredFrameworks objectEnumerator];
			NSDictionary* requiredFramework;
			while ((requiredFramework = [requiredFrameworkEnum nextObject]) && missingFramework == NO)
			{
				NSBundle* framework = [NSBundle bundleWithIdentifier:[requiredFramework objectForKey:@"BundleIdentifier"]];
				NSString* frameworkPath = [framework bundlePath];
				NSString* requiredPath = [requiredFramework objectForKey:@"BundlePath"];
				if ([frameworkPath isEqualToString:requiredPath] == NO)
                {
					missingFramework = YES;
				}
			}
		}
		
		if (missingFramework)
        {
			continue;
        }
		
        //runningApp的版本
		int appVersion = [[_appBundle _dt_bundleVersion] intValue];
		
		int minVersion = 0;
		NSNumber* number;
		if ((number = [targetAppProperties objectForKey:SIMBLMinBundleVersion]))
        {
			minVersion = [number intValue];
        }
        
		int maxVersion = 0;
		if ((number = [targetAppProperties objectForKey:SIMBLMaxBundleVersion]))
        {
			maxVersion = [number intValue];
        }
		
		if ((maxVersion && appVersion > maxVersion) || (minVersion && appVersion < minVersion))
		{
			[NSAlert errorAlert:NSLocalizedStringFromTableInBundle(@"Error", SIMBLStringTable, [NSBundle bundleForClass:[self class]], @"Error alert primary message") withDetails:NSLocalizedStringFromTableInBundle(@"%@ %@ (v%@) has not been tested with the plugin %@ %@ (v%@). As a precaution, it has not been loaded. Please contact the plugin developer for further information.", SIMBLStringTable, [NSBundle bundleForClass:[self class]], @"Error alert details, substitute application and plugin version strings"), [_appBundle _dt_name], [_appBundle _dt_version], [_appBundle _dt_bundleVersion], [_bundle _dt_name], [_bundle _dt_version], [_bundle _dt_bundleVersion]];
			continue;
		}
		
        //runningApp要注入这个plugin。
		return YES;
	}
	
	return NO;
}

+ (BOOL) isRunningOriginalSIMBLAgent
{
    return [[NSRunningApplication runningApplicationsWithBundleIdentifier:EasySIMBLOriginalSIMBLAgentBundleIdentifier]count];
}

+ (BOOL) loadBundle:(NSBundle*)_plugin
{
	@try
	{
		// getting the principalClass should force the bundle to load
        // 这里重新创建一个新的bundle，为啥？
		NSBundle* bundle = [NSBundle bundleWithPath:[_plugin bundlePath]];
        
        //获取principalClass类，这个类会在plist文件内指定一个函数，该函数是plugin的入口函数。
		Class principalClass = [bundle principalClass];
		
		// if the principal class has an + (void) install message, call it
		if (principalClass && [principalClass respondsToSelector:@selector(install)])
        {
            if ([self isRunningOriginalSIMBLAgent])
            {
                SIMBLLogNotice(@"It seems the original SIMBL Agent is running. So, I don't call +install because which cause double initialization problem of plugin.");
            }
            else
            {
                [principalClass install];
            }
        }
		
		// set that we've loaded this bundle to prevent collisions
		[loadedBundleIdentifiers setObject:@"loaded" forKey:[bundle bundleIdentifier]];
		
		return YES;
	}
	@catch (NSException* exception)
	{
		[NSAlert errorAlert:NSLocalizedStringFromTableInBundle(@"Error", SIMBLStringTable, [NSBundle bundleForClass:[self class]], @"Error alert primary message") withDetails:NSLocalizedStringFromTableInBundle(@"Failed to load the %@ plugin.\n%@", SIMBLStringTable, [NSBundle bundleForClass:[self class]], @"Error alert details, sub plugin name and error reason"), [_plugin _dt_name], [exception reason]];
	}
	
	return NO;
}

@end
