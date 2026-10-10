// Some are adapted from https://github.com/Mark02-2012/YTPlaybackFix
// TV Client Spoof https://github.com/AppropriateNet2928/YTLitePlusRenewed/blob/main/YouFixPlaybackIssues/Tweak.xm
#import "Headers.h"

/* Old method
%hook YTMainAppVideoPlayerOverlayViewController
- (void)handleError:(NSError *)error {
    if (error && [error.domain isEqualToString:@"com.google.ios.youtube.ErrorDomain.playback"] && error.code == 14) {
        YTPlayerViewController *playerViewController = self.parentViewController;
        if (![playerViewController.UIDelegate isKindOfClass:%c(YTWatchController)]) return;
        YTWatchController *watchController = (YTWatchController *)playerViewController.UIDelegate;
        dispatch_async(dispatch_get_main_queue(), ^{  
            [watchController reload];
        });
        return;
    }
    %orig;
}
%end
*/

// ============================================================================
//                               PART 1: CONFIG
// ============================================================================

static NSString * const kEndpointPlayer       = @"/player";
static NSString * const kEndpointNext         = @"/next";
static NSString * const kEndpointBrowse       = @"/browse";
static NSString * const kEndpointInitPlayback  = @"/initplayback";
static NSString * const kEndpointVideoPlayback = @"/videoplayback";

static NSString * const kJSONKeyContext       = @"context";
static NSString * const kJSONKeyClient        = @"client";
static NSString * const kJSONKeyVideoId       = @"videoId";
static NSString * const kJSONKeyBrowseId      = @"browseId";
static NSString * const kJSONKeyContinuation  = @"continuation";

// ============================================================================
//                          PART 2: PLAYBACK CLIENT
// ============================================================================

@interface YTDirectPlaybackClient : NSObject
+ (NSDictionary *)apiHeadersForVisitorData:(NSString *)visitorData;
+ (NSDictionary *)contextBlueprint;
@end

@implementation YTDirectPlaybackClient

+ (NSDictionary *)apiHeadersForVisitorData:(NSString *)visitorData {
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    headers[@"Content-Type"] = @"application/x-protobuf";
    headers[@"Accept-Language"] = @"*";
    
    headers[@"X-YouTube-Client-Name"] = @"75";
    headers[@"X-YouTube-Client-Version"] = @"1.1";
    headers[@"User-Agent"] =
    @"Mozilla/5.0 (PS4; Leanback Shell) "
    @"Gecko/20100101 Firefox/65.0 LeanbackShell/01.00.01.75 "
    @"Sony PS4/ (PS4, , no, CH)";
    headers[@"Origin"] = @"https://www.youtube.com";

if (visitorData.length > 0) {
    headers[@"X-Goog-Visitor-Id"] = visitorData;
}

return [headers copy];
}

+ (NSDictionary *)contextBlueprint {
    return @{
        kJSONKeyContext: @{
            kJSONKeyClient: @{
                @"clientName": @"TVHTML5_SIMPLY",
                @"clientVersion": @"1.1",

                @"hl": @"en",
                @"timeZone": @"UTC",
                @"utcOffsetMinutes": @0,

                @"deviceMake": @"Sony",
                @"deviceModel": @"PS4",

                @"osName": @"",
                @"osVersion": @"7.20260707.07.00",

                @"clientPlatform": @"GAME_CONSOLE",

                @"userAgent":
                    @"Mozilla/5.0 (PS4; Leanback Shell) "
                    @"Gecko/20100101 Firefox/65.0 LeanbackShell/01.00.01.75 "
                    @"Sony PS4/ (PS4, , no, CH)"
            }
        }
    };
}
@end

// ============================================================================
//                          PART 3: INNERTUBE SESSION
// ============================================================================

@interface YTInnertubeSession : NSObject
@property (nonatomic, copy) NSString *visitorData;
+ (instancetype)sharedSession;
- (NSDictionary *)buildPayloadWithIncomingBody:(NSDictionary *)incomingBody;
@end

@implementation YTInnertubeSession
+ (instancetype)sharedSession {
    static YTInnertubeSession *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[YTInnertubeSession alloc] init]; });
    return shared;
}

- (NSDictionary *)buildPayloadWithIncomingBody:(NSDictionary *)incomingBody {
    if (![incomingBody isKindOfClass:[NSDictionary class]]) return incomingBody;
    
    NSMutableDictionary *mutatedBody = [incomingBody mutableCopy];
    
    NSDictionary *incomingContext = incomingBody[kJSONKeyContext];
    NSMutableDictionary *mutableContext = [incomingContext isKindOfClass:[NSDictionary class]] ? [incomingContext mutableCopy] : [NSMutableDictionary dictionary];
    
    NSDictionary *vrBlueprint = [YTDirectPlaybackClient contextBlueprint];
    NSDictionary *vrClientData = vrBlueprint[kJSONKeyContext][kJSONKeyClient];
    
    if (vrClientData) {
        NSMutableDictionary *mutableClientData = [vrClientData mutableCopy];
        
        
        if (self.visitorData.length > 0) {
            mutableClientData[@"visitorData"] = self.visitorData;
        }
        mutableContext[kJSONKeyClient] = [mutableClientData copy];
    }
    
    mutatedBody[kJSONKeyContext] = [mutableContext copy];
    return [mutatedBody copy];
}
@end


// ============================================================================ 
//                      PART 4: NETWORK INTERCEPTOR
// ============================================================================


// ============================================================================ 
//                   PART 4a: NSMutableURLRequest
// ============================================================================

 // Initial hook for intercepting and modifying the request in its earliest state possible
%hook NSMutableURLRequest

- (id)initWithURL:(NSURL *)URL cachePolicy:(unsigned long long)cachePolicy timeoutInterval:(double)timeoutInterval {
    self = %orig;
    if (!self || !URL) return self;
    
    NSString *path = [URL.path lowercaseString];
    

    if ([path containsString:[kEndpointPlayer lowercaseString]] || 
        [path containsString:[kEndpointNext lowercaseString]] || 
        [path containsString:[kEndpointBrowse lowercaseString]] ||
        [path containsString:[kEndpointInitPlayback lowercaseString]]) {
        
       
        if (self.HTTPBody) {
            NSDictionary *incomingJSON = [NSJSONSerialization JSONObjectWithData:self.HTTPBody options:0 error:nil];
            if ([incomingJSON isKindOfClass:[NSDictionary class]]) {
                
                NSDictionary *incomingContext = incomingJSON[kJSONKeyContext];
                if ([incomingContext isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *incomingClient = incomingContext[kJSONKeyClient];
                    if ([incomingClient isKindOfClass:[NSDictionary class]] && incomingClient[@"visitorData"]) {
                        [YTInnertubeSession sharedSession].visitorData = incomingClient[@"visitorData"];
                    }
                }
                
                NSDictionary *mutatedJSON = [[YTInnertubeSession sharedSession] buildPayloadWithIncomingBody:incomingJSON];
                NSData *mutatedData = [NSJSONSerialization dataWithJSONObject:mutatedJSON options:0 error:nil];
                if (mutatedData) {
                    self.HTTPBody = mutatedData;
                }
            }
        }
        
        
        NSDictionary *computedHeaders = [YTDirectPlaybackClient apiHeadersForVisitorData:[YTInnertubeSession sharedSession].visitorData];
        for (NSString *headerKey in computedHeaders) {
            [self setValue:computedHeaders[headerKey] forHTTPHeaderField:headerKey];
        }
        
        
        if ([path containsString:[kEndpointInitPlayback lowercaseString]]) {
            NSString *urlString = self.URL.absoluteString;
            if (urlString.length > 0) {
                
                
                NSRegularExpression *regexC = [NSRegularExpression regularExpressionWithPattern:@"([?&])c=[^&]+" options:0 error:nil];
                urlString = [regexC stringByReplacingMatchesInString:urlString options:0 range:NSMakeRange(0, urlString.length) withTemplate:@"$1c=TVHTML5_SIMPLY"];
                
           
                NSRegularExpression *regexCver = [NSRegularExpression regularExpressionWithPattern:@"([?&])cver=[^&]+" options:0 error:nil];
                urlString = [regexCver stringByReplacingMatchesInString:urlString options:0 range:NSMakeRange(0, urlString.length) withTemplate:@"$1cver=1.1"];
                
                NSURL *newURL = [NSURL URLWithString:urlString];
                if (newURL) {
                    [self setURL:newURL];
                }
            }
        }
    }
    
     
    if ([path containsString:@"/videoplayback"]) {
        NSString *urlString = self.URL.absoluteString;
        if (urlString.length > 0) {
            
           
            NSRegularExpression *regexUA = [NSRegularExpression regularExpressionWithPattern:@"([?&])user_agent=[^&]+" options:0 error:nil];
            
           
          urlString = [regexUA stringByReplacingMatchesInString:urlString options:0 range:NSMakeRange(0, urlString.length) withTemplate:@"$1user_agent=Mozilla%2F5.0%20%28PS4%3B%20Leanback%20Shell%29%20Gecko%2F20100101%20Firefox%2F65.0%20LeanbackShell%2F01.00.01.75%20Sony%20PS4%2F%20%28PS4%2C%20%2C%20no%2C%20CH%29"];
            
            NSURL *newURL = [NSURL URLWithString:urlString];
            if (newURL) {
                [self setURL:newURL];
            }
        }
    }
    
    return self;
}

%end



// ============================================================================ 
//                  PART 4b: GTMSessionFetcher
// ============================================================================

@interface GTMSessionFetcher : NSObject
- (id)mutableRequestForTesting;
@end


// ============================================================================ 
//                        SPECIAL HELPERS
// ============================================================================


static void YTApplyCustomHeaders(NSMutableURLRequest *request) {
    if (!request)
        return;

    NSDictionary *headers =
        [YTDirectPlaybackClient apiHeadersForVisitorData:
            [YTInnertubeSession sharedSession].visitorData];

    for (NSString *key in headers) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }
}

static void YTApplyCustomBody(NSMutableURLRequest *request) {
    if (!request.HTTPBody)
        return;

    NSDictionary *incomingJSON =
        [NSJSONSerialization JSONObjectWithData:request.HTTPBody
                                        options:0
                                          error:nil];

    if (![incomingJSON isKindOfClass:[NSDictionary class]])
        return;

    NSString *path = request.URL.path.lowercaseString;

    if (![path containsString:kEndpointPlayer.lowercaseString] &&
        ![path containsString:kEndpointNext.lowercaseString] &&
        ![path containsString:kEndpointBrowse.lowercaseString] &&
        ![path containsString:kEndpointInitPlayback.lowercaseString]) {
        return;
    }

    NSDictionary *incomingContext = incomingJSON[kJSONKeyContext];

    if ([incomingContext isKindOfClass:[NSDictionary class]]) {
        NSDictionary *incomingClient = incomingContext[kJSONKeyClient];

        if ([incomingClient isKindOfClass:[NSDictionary class]] &&
            incomingClient[@"visitorData"]) {

            [YTInnertubeSession sharedSession].visitorData =
                incomingClient[@"visitorData"];
        }
    }

    NSDictionary *mutatedJSON =
        [[YTInnertubeSession sharedSession]
            buildPayloadWithIncomingBody:incomingJSON];

    NSData *mutatedData =
        [NSJSONSerialization dataWithJSONObject:mutatedJSON
                                        options:0
                                          error:nil];

    if (mutatedData) {
        request.HTTPBody = mutatedData;
    }
}



// ============================================================================ 
//                    GTMSessionFetcher HOOK
// ============================================================================

// Catching and mass modifying the request in one of its final stages
%hook GTMSessionFetcher

- (id)initWithRequest:(id)request {

    NSURL *URL = [request URL];

    if (!URL) {
        return %orig(request);
    }

    NSString *path = [URL.path lowercaseString];

    if ([path containsString:[kEndpointPlayer lowercaseString]] || 
        [path containsString:[kEndpointNext lowercaseString]] || 
        [path containsString:[kEndpointBrowse lowercaseString]] ||
        [path containsString:[kEndpointInitPlayback lowercaseString]]) {

        if ([request isKindOfClass:[NSMutableURLRequest class]]) {

            YTApplyCustomBody(request);
            YTApplyCustomHeaders(request);

        }
        else if ([request isKindOfClass:[NSURLRequest class]]) {

            NSMutableURLRequest *mutableRequest =
                [request mutableCopy];

            YTApplyCustomBody(mutableRequest);
            YTApplyCustomHeaders(mutableRequest);

            request = mutableRequest;
        }
    }

    if ([path containsString:[kEndpointVideoPlayback lowercaseString]]) {

        if ([request isKindOfClass:[NSMutableURLRequest class]]) {

            YTApplyCustomHeaders(request);

        }
        else if ([request isKindOfClass:[NSURLRequest class]]) {

            NSMutableURLRequest *mutableRequest =
                [request mutableCopy];

            YTApplyCustomHeaders(mutableRequest);

            request = mutableRequest;
        }
    }

    return %orig(request);
}


- (id)initWithRequest:(id)request configuration:(id)configuration {

    NSURL *URL = [request URL];

    if (!URL) {
        return %orig(request, configuration);
    }

    NSString *path = [URL.path lowercaseString];

    if ([path containsString:[kEndpointPlayer lowercaseString]] || 
        [path containsString:[kEndpointNext lowercaseString]] || 
        [path containsString:[kEndpointBrowse lowercaseString]] ||
        [path containsString:[kEndpointInitPlayback lowercaseString]]) {

        if ([request isKindOfClass:[NSMutableURLRequest class]]) {

            YTApplyCustomBody(request);
            YTApplyCustomHeaders(request);

        }
        else if ([request isKindOfClass:[NSURLRequest class]]) {

            NSMutableURLRequest *mutableRequest =
                [request mutableCopy];

            YTApplyCustomBody(mutableRequest);
            YTApplyCustomHeaders(mutableRequest);

            request = mutableRequest;
        }
    }

    if ([path containsString:[kEndpointVideoPlayback lowercaseString]]) {

        if ([request isKindOfClass:[NSMutableURLRequest class]]) {

            YTApplyCustomHeaders(request);

        }
        else if ([request isKindOfClass:[NSURLRequest class]]) {

            NSMutableURLRequest *mutableRequest =
                [request mutableCopy];

            YTApplyCustomHeaders(mutableRequest);

            request = mutableRequest;
        }
    }

    return %orig(request, configuration);
}


- (void)updateMutableRequest:(id)request {

    NSURL *URL = [request URL];

    if (!URL) {
        %orig(request);
        return;
    }

    NSString *path = [URL.path lowercaseString];

    if ([path containsString:[kEndpointPlayer lowercaseString]] || 
        [path containsString:[kEndpointNext lowercaseString]] || 
        [path containsString:[kEndpointBrowse lowercaseString]] ||
        [path containsString:[kEndpointInitPlayback lowercaseString]]) {

        if ([request isKindOfClass:[NSMutableURLRequest class]]) {

            YTApplyCustomBody(request);
            YTApplyCustomHeaders(request);
        }
    }

    if ([path containsString:[kEndpointVideoPlayback lowercaseString]]) {

        if ([request isKindOfClass:[NSMutableURLRequest class]]) {

            YTApplyCustomHeaders(request);
        }
    }

    %orig(request);
}


- (void)setRequestValue:(id)value
    forHTTPHeaderField:(id)field {

    NSMutableURLRequest *request =
        [self mutableRequestForTesting];

    if (!request) {
        %orig(value, field);
        return;
    }

    NSURL *URL = [request URL];

    if (!URL) {
        %orig(value, field);
        return;
    }

    NSString *path = [URL.path lowercaseString];

    if ([path containsString:[kEndpointPlayer lowercaseString]] || 
        [path containsString:[kEndpointNext lowercaseString]] || 
        [path containsString:[kEndpointBrowse lowercaseString]] ||
        [path containsString:[kEndpointInitPlayback lowercaseString]] ||
        [path containsString:[kEndpointVideoPlayback lowercaseString]]) {

        // Let the original setter run first.
        %orig(value, field);

        // Then enforce our client headers.
        YTApplyCustomHeaders(request);

        return;
    }

    %orig(value, field);
}


- (void)setBodyData:(id)data {

    NSMutableURLRequest *request =
        [self mutableRequestForTesting];

    if (!request) {
        %orig(data);
        return;
    }

    NSURL *URL = [request URL];

    if (!URL) {
        %orig(data);
        return;
    }

    NSString *path = [URL.path lowercaseString];

    if ([path containsString:[kEndpointPlayer lowercaseString]] || 
        [path containsString:[kEndpointNext lowercaseString]] || 
        [path containsString:[kEndpointBrowse lowercaseString]] ||
        [path containsString:[kEndpointInitPlayback lowercaseString]]) {

        %orig(data);

        if (request) {
            YTApplyCustomBody(request);
        }

        return;
    }

    %orig(data);
}


%end


// ============================================================================ 
//            PART 4c: GTMSessionFetcherSessionDelegateDispatcher
// ============================================================================

// Catching the request in what it appears to be its final stage; The dispatcher checks and maybe modifies the final request and it sends it to Google.
%hook GTMSessionFetcherSessionDelegateDispatcher

- (id)connection:(id)connection
willSendRequest:(id)request
redirectResponse:(id)redirectResponse {

    NSURL *URL = [request URL];

    if (!URL) {
        return %orig(connection, request, redirectResponse);
    }

    NSString *path = [URL.path lowercaseString];

    if ([path containsString:[kEndpointPlayer lowercaseString]] || 
        [path containsString:[kEndpointNext lowercaseString]] || 
        [path containsString:[kEndpointBrowse lowercaseString]] ||
        [path containsString:[kEndpointInitPlayback lowercaseString]]) {

        NSMutableURLRequest *mutableRequest =
            [request mutableCopy];

        YTApplyCustomBody(mutableRequest);
        YTApplyCustomHeaders(mutableRequest);

        request = mutableRequest;

    }
    else if ([path containsString:[kEndpointVideoPlayback lowercaseString]]) {

        NSMutableURLRequest *mutableRequest =
            [request mutableCopy];

        YTApplyCustomHeaders(mutableRequest);

        request = mutableRequest;
    }

    return %orig(connection, request, redirectResponse);
}


- (void)URLSession:(id)session
              task:(id)task
willPerformHTTPRedirection:(id)response
        newRequest:(id)newRequest
 completionHandler:(id)completionHandler {

    NSURL *URL = [newRequest URL];

    if (!URL) {
        %orig(session,
              task,
              response,
              newRequest,
              completionHandler);
        return;
    }

    NSString *path = [URL.path lowercaseString];

    if ([path containsString:[kEndpointPlayer lowercaseString]] || 
        [path containsString:[kEndpointNext lowercaseString]] || 
        [path containsString:[kEndpointBrowse lowercaseString]] ||
        [path containsString:[kEndpointInitPlayback lowercaseString]]) {

        NSMutableURLRequest *mutableRequest =
            [newRequest mutableCopy];

        YTApplyCustomBody(mutableRequest);
        YTApplyCustomHeaders(mutableRequest);

        newRequest = mutableRequest;

    }
    else if ([path containsString:[kEndpointVideoPlayback lowercaseString]]) {

        NSMutableURLRequest *mutableRequest =
            [newRequest mutableCopy];

        YTApplyCustomHeaders(mutableRequest);

        newRequest = mutableRequest;
    }

    %orig(session,
          task,
          response,
          newRequest,
          completionHandler);
}


- (void)URLSession:(id)session
              task:(id)task
 needNewBodyStream:(id)completionHandler {

    %orig(session, task, completionHandler);
}


%end


// ========================================================================================
//    PART 5: EXPERIMENTAL PoToken BYPASS (Special Thanks to @tywtyw2002 for the idea)
// ========================================================================================

// In order to use the base_url from YTIOnesieHotConfig, we have to hook this class in order for url and ustreamer_config from YTIIosPlaybackOnesieConfig to become null. This MAY bypass PoToken.

%hook YTIIosPlaybackOnesieConfig

- (BOOL)hasCommonConfig {
return 0; 
}

%end

//Keep in mind this is experimental and there is a good chance that it won't have any effect whatsoever, tho I may update this when I get clue how to maybe patch it better. And sorry if one hooked class seems exaggerated for me to call a PoToken bypass......


%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}
