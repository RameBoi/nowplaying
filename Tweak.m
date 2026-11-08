#import <UIKit/UIKit.h>
#import <dlfcn.h>

typedef void (^InfoCB)(CFDictionaryRef);
typedef void (^PlayCB)(Boolean);
static void (*GetInfo)(dispatch_queue_t, InfoCB);
static void (*GetPlaying)(dispatch_queue_t, PlayCB);
static NSString *kDir = @"/var/mobile/Library/NowPlaying";
static NSString *lastKey = @"";
static int artVer = 0, cr = 90, cg = 90, cb = 90;

static void colorOf(UIImage *img) {
    const int n = 16; unsigned char px[16*16*4];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(px, n, n, 8, n*4, cs, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(c, CGRectMake(0,0,n,n), img.CGImage);
    double sr=0,sg=0,sb=0,sw=0;
    for (int i=0;i<n*n;i++) {
        double R=px[i*4],G=px[i*4+1],B=px[i*4+2];
        double w=(MAX(R,MAX(G,B))-MIN(R,MIN(G,B)))/255.0+0.05;
        sr+=R*w; sg+=G*w; sb+=B*w; sw+=w;
    }
    CGContextRelease(c); CGColorSpaceRelease(cs);
    cr=sr/sw; cg=sg/sw; cb=sb/sw;
}

static void update(void) {
    if (!GetInfo || !GetPlaying) return;
    GetPlaying(dispatch_get_main_queue(), ^(Boolean playing) {
        GetInfo(dispatch_get_main_queue(), ^(CFDictionaryRef ref) {
            NSDictionary *d = (__bridge NSDictionary *)ref;
            NSString *t = d[@"kMRMediaRemoteNowPlayingInfoTitle"] ?: @"";
            NSString *a = d[@"kMRMediaRemoteNowPlayingInfoArtist"] ?: @"";
            NSString *key = [NSString stringWithFormat:@"%@|%@", t, a];
            NSData *art = d[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
            if (![key isEqualToString:lastKey] || (art && artVer == 0)) {
                lastKey = key;
                UIImage *img = art ? [UIImage imageWithData:art] : nil;
                if (img) {
                    [UIImageJPEGRepresentation(img, 0.85) writeToFile:[kDir stringByAppendingPathComponent:@"artwork.jpg"] atomically:YES];
                    colorOf(img);
                }
                artVer++;
            }
            NSDictionary *o = @{@"title":t, @"artist":a, @"playing":@(playing),
                                @"r":@(cr), @"g":@(cg), @"b":@(cb), @"art":@(artVer)};
            NSData *j = [NSJSONSerialization dataWithJSONObject:o options:0 error:nil];
            [j writeToFile:[kDir stringByAppendingPathComponent:@"nowplaying.json"] atomically:YES];
        });
    });
}

__attribute__((constructor)) static void npInit(void) {
    [[NSFileManager defaultManager] createDirectoryAtPath:kDir withIntermediateDirectories:YES
        attributes:@{NSFilePosixPermissions:@0755} error:nil];
    void *h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    GetInfo = (void (*)(dispatch_queue_t, InfoCB))dlsym(h, "MRMediaRemoteGetNowPlayingInfo");
    GetPlaying = (void (*)(dispatch_queue_t, PlayCB))dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:[NSBlockOperation blockOperationWithBlock:^{update();}]
            selector:@selector(main) userInfo:nil repeats:YES];
    });
}
