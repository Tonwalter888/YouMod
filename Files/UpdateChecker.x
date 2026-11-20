#import "Headers.h"

static NSString *const YouModLatestReleaseAPI = @"https://api.github.com/repos/Tonwalter888/YouMod/releases/tags/nightly";
static NSString *const YouModLatestReleaseURL = @"https://github.com/Tonwalter888/YouMod/releases/tag/nightly";
static const NSUInteger YouModReleaseNotesExcerptLength = 280;
static BOOL YouModUpdateCheckInFlight = NO;

// The nightly release body contains a line "Build <n> - <sha> - <commit subject>" (written by CI).
static NSTextCheckingResult *YouModBuildLine(NSDictionary *release) {
    NSString *body = release[@"body"];
    if (![body isKindOfClass:[NSString class]]) return nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"Build (\\d+) - ([0-9a-f]+) - (.*)" options:0 error:nil];
    return [re firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
}

static NSString *YouModLatestBuild(NSDictionary *release) {
    NSTextCheckingResult *m = YouModBuildLine(release);
    return m ? [release[@"body"] substringWithRange:[m rangeAtIndex:1]] : nil;
}

static NSString *YouModLatestSubject(NSDictionary *release) {
    NSTextCheckingResult *m = YouModBuildLine(release);
    return m ? [release[@"body"] substringWithRange:[m rangeAtIndex:3]] : nil;
}

// Local/dev builds have a non-numeric YouModVersion; treat them as "unknown".
static NSString *YouModInstalledBuild(void) {
    return YouModVersion.integerValue > 0 ? YouModVersion : nil;
}

static NSString *YouModReleaseNotesExcerpt(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *notes = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (notes.length > YouModReleaseNotesExcerptLength) {
        NSRange range = [notes rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, YouModReleaseNotesExcerptLength)];
        notes = [[notes substringToIndex:NSMaxRange(range)] stringByAppendingString:@"…"];
    }
    return notes.length ? notes : nil;
}

static BOOL YouModIsNewerVersion(NSString *latestVersion, NSString *installedVersion) {
    return [latestVersion compare:installedVersion options:NSNumericSearch] == NSOrderedDescending;
}

typedef void (^YouModLatestReleaseHandler)(NSDictionary *release);

static void YouModFetchLatestRelease(YouModLatestReleaseHandler handler) {
    NSURL *url = [NSURL URLWithString:YouModLatestReleaseAPI];
    if (!url) {
        handler(nil);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5.0];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"YouMod" forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *release = nil;
        if (!error && [response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode == 200 && data) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]]) release = json;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(release);
        });
    }];
    [task resume];
}

static void YouModPresentUpdateAlert(NSString *latestVersion, id notesValue) {
    NSString *message = [NSString stringWithFormat:LOC(@"UPDATE_AVAILABLE_MESSAGE"), latestVersion];
    NSString *notes = YouModReleaseNotesExcerpt(notesValue);
    if (notes) message = [message stringByAppendingFormat:@"\n\n%@", notes];

    YTAlertView *alert = [%c(YTAlertView) confirmationDialogWithAction:^{
        [%c(YTUIUtils) openURL:[NSURL URLWithString:YouModLatestReleaseURL]];
    } actionTitle:LOC(@"UPDATE_NOW") cancelAction:^{
        [[NSUserDefaults standardUserDefaults] setObject:latestVersion forKey:UpdateSkippedVersion];
    } cancelTitle:LOC(@"UPDATE_SKIP")];
    alert.title = LOC(@"UPDATE");
    alert.subtitle = message;
    alert.shouldDismissOnBackgroundTap = YES; // Dismissing without a choice means "later".
    [alert show];
}

static void YouModCheckForUpdate(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:NotifyUpdates] || [defaults boolForKey:UpdateHasChecked] || YouModUpdateCheckInFlight) return;
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;

    YouModUpdateCheckInFlight = YES;
    YouModFetchLatestRelease(^(NSDictionary *release) {
        YouModUpdateCheckInFlight = NO;

        NSString *latestVersion = YouModLatestBuild(release);
        NSString *installedVersion = YouModInstalledBuild();
        if (!latestVersion || !installedVersion) return;

        [defaults setBool:YES forKey:UpdateHasChecked];
        if (!YouModIsNewerVersion(latestVersion, installedVersion)) return;
        if (![defaults boolForKey:NotifyUpdates]) return;
        if ([[defaults stringForKey:UpdateSkippedVersion] isEqualToString:latestVersion]) return;
        if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;

        YouModPresentUpdateAlert(latestVersion, YouModLatestSubject(release));
    });
}

void YouModCheckForUpdateManually(void) {
    YouModFetchLatestRelease(^(NSDictionary *release) {
        NSString *latestVersion = YouModLatestBuild(release);
        NSString *installedVersion = YouModInstalledBuild();
        if (!latestVersion || !installedVersion) {
            YouModShowPill(LOC(@"UPDATE_CHECK_FAILED"), NO);
            return;
        }

        if (YouModIsNewerVersion(latestVersion, installedVersion)) {
            YouModPresentUpdateAlert(latestVersion, YouModLatestSubject(release));
            return;
        }
        YouModShowPill([NSString stringWithFormat:LOC(@"UPDATE_UP_TO_DATE"), installedVersion], YES);
    });
}

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
        YouModCheckForUpdate();
    }];
}
