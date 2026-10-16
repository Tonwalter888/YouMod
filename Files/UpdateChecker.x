#import "Headers.h"

static NSString *const YouModLatestReleaseAPI = @"https://api.github.com/repos/Tonwalter888/YouMod/releases/latest";
static NSString *const YouModLatestReleaseURL = @"https://github.com/Tonwalter888/YouMod/releases/latest";
static const NSInteger YouModMaximumUpdateCheckAttempts = 4; // Initial request plus three retries.
static const NSTimeInterval YouModUpdateRetryDelays[] = {5.0, 15.0, 45.0};
static BOOL YouModUpdateCheckInFlight = NO;
static BOOL YouModUpdateRetryScheduled = NO;

static void YouModCheckForUpdate(void);

static void YouModScheduleUpdateRetryAfter(NSTimeInterval delay) {
    if (YouModUpdateRetryScheduled) return;
    YouModUpdateRetryScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(0, delay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        YouModUpdateRetryScheduled = NO;
        YouModCheckForUpdate();
    });
}

static void YouModFinishUpdateCheck(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:UpdateHasChecked];
    [defaults removeObjectForKey:UpdateCheckAttempts];
    [defaults removeObjectForKey:UpdateNextRetryDate];
}

static void YouModRetryOrFinishUpdateCheck(void) {
    YouModUpdateCheckInFlight = NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger attempts = [defaults integerForKey:UpdateCheckAttempts];
    if (attempts < 1) attempts = 1;
    if (attempts >= YouModMaximumUpdateCheckAttempts) {
        YouModFinishUpdateCheck();
        return;
    }

    NSTimeInterval delay = YouModUpdateRetryDelays[attempts - 1];
    NSDate *retryDate = [NSDate dateWithTimeIntervalSinceNow:delay];
    [defaults setObject:retryDate forKey:UpdateNextRetryDate];
    YouModScheduleUpdateRetryAfter(delay);
}

static NSString *YouModVersionFromTag(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *version = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (version.length > 1 && ([[version substringToIndex:1] caseInsensitiveCompare:@"v"] == NSOrderedSame)) {
        version = [version substringFromIndex:1];
    }
    return version.length ? version : nil;
}

static void YouModCheckForUpdate(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:NotifyUpdates] || [defaults boolForKey:UpdateHasChecked] || YouModUpdateCheckInFlight) return;
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;

    NSDate *nextRetryDate = [defaults objectForKey:UpdateNextRetryDate];
    if ([nextRetryDate isKindOfClass:[NSDate class]]) {
        NSTimeInterval retryDelay = [nextRetryDate timeIntervalSinceNow];
        if (retryDelay > 0) {
            YouModScheduleUpdateRetryAfter(retryDelay);
            return;
        }
    }

    NSURL *url = [NSURL URLWithString:YouModLatestReleaseAPI];
    if (!url) return;

    YouModUpdateCheckInFlight = YES;
    [defaults setInteger:[defaults integerForKey:UpdateCheckAttempts] + 1 forKey:UpdateCheckAttempts];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"YouMod" forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || ![response isKindOfClass:[NSHTTPURLResponse class]] || ((NSHTTPURLResponse *)response).statusCode != 200 || !data) {
                YouModRetryOrFinishUpdateCheck();
                return;
            }

            id release = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![release isKindOfClass:[NSDictionary class]]) {
                YouModRetryOrFinishUpdateCheck();
                return;
            }
            NSString *latestVersion = YouModVersionFromTag(release[@"tag_name"]);
            NSString *installedVersion = YouModVersionFromTag(YouModVersion);
            if (!latestVersion || !installedVersion) {
                YouModRetryOrFinishUpdateCheck();
                return;
            }

            YouModUpdateCheckInFlight = NO;
            YouModFinishUpdateCheck();
            if ([latestVersion compare:installedVersion options:NSNumericSearch] != NSOrderedDescending) return;
            if (![defaults boolForKey:NotifyUpdates]) return;
            if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;

            YTAlertView *alert = [%c(YTAlertView) confirmationDialogWithAction:^{
                [%c(YTUIUtils) openURL:[NSURL URLWithString:YouModLatestReleaseURL]];
            } actionTitle:LOC(@"UPDATE_NOW")];
            alert.title = LOC(@"UPDATE");
            alert.subtitle = [NSString stringWithFormat:LOC(@"UPDATE_AVAILABLE_MESSAGE"), latestVersion];
            alert.shouldDismissOnBackgroundTap = YES;
            [alert show];
        });
    }];
    [task resume];
}

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
        YouModCheckForUpdate();
    }];
}
