// Comment replies fix, from YouTubeLegacy (PoomSmart) commit 1889df2
// "Fix replies not showing": newer YouTube builds deliver comment replies
// as YTISectionListMutationOperations instead of YTIItemSectionRenderers,
// so hosts that never learned mutation operations render nothing. The
// helpers below harvest both kinds back into plain item sections.
#import "Headers.h"
#import "Headers/YTICommentsResponse.h"
#import "Headers/YTIInsertItemSectionContentOperation.h"
#import "Headers/YTISectionListMutationOperations.h"

extern NSMutableArray <YTIItemSectionRenderer *> *filteredArray(NSArray <YTIItemSectionRenderer *> *array);

#pragma mark - Comment replies mutation operations as item sections

static YTIItemSectionRenderer *itemSectionRendererWithElements(NSArray *elements) {
    if (elements.count == 0)
        return nil;
    YTIItemSectionRenderer *itemSectionRenderer = [[%c(YTIItemSectionRenderer) alloc] init];
    NSMutableArray *contentsArray = itemSectionRenderer.contentsArray;
    for (id element in elements) {
        if ([element isKindOfClass:%c(YTIItemSectionSupportedRenderers)]) {
            [contentsArray addObject:element];
            continue;
        }
        YTIItemSectionSupportedRenderers *supported = [[%c(YTIItemSectionSupportedRenderers) alloc] init];
        supported.elementRenderer = element;
        [contentsArray addObject:supported];
    }
    return contentsArray.count ? itemSectionRenderer : nil;
}

static void harvestSectionContent(id object, NSMutableArray *itemSectionRenderers, NSMutableArray *elements, NSHashTable *seen, NSInteger depth) {
    if (!object || depth > 8)
        return;
    if ([seen containsObject:object])
        return;
    if ([object isKindOfClass:[NSArray class]]) {
        for (id item in object)
            harvestSectionContent(item, itemSectionRenderers, elements, seen, depth + 1);
        return;
    }
    if (![object isKindOfClass:%c(GPBMessage)])
        return;
    [seen addObject:object];

    if ([object isKindOfClass:%c(YTIItemSectionRenderer)]) {
        [itemSectionRenderers addObject:object];
        return;
    }
    if ([object isKindOfClass:%c(YTIElementRenderer)]) {
        [elements addObject:object];
        return;
    }
    if ([object isKindOfClass:%c(YTIItemSectionSupportedRenderers)]) {
        YTIElementRenderer *elementRenderer = ((YTIItemSectionSupportedRenderers *)object).elementRenderer;
        if (elementRenderer)
            [elements addObject:elementRenderer];
        return;
    }
    if ([object isKindOfClass:%c(YTISectionListRenderer)]) {
        harvestSectionContent(((YTISectionListRenderer *)object).contentsArray, itemSectionRenderers, elements, seen, depth + 1);
        return;
    }
    if ([object isKindOfClass:%c(YTISectionListMutationOperations)]) {
        harvestSectionContent(((YTISectionListMutationOperations *)object).operationsArray, itemSectionRenderers, elements, seen, depth + 1);
        return;
    }
    if ([object isKindOfClass:%c(YTIInsertItemSectionContentOperation)]) {
        harvestSectionContent(((YTIInsertItemSectionContentOperation *)object).contentsArray, itemSectionRenderers, elements, seen, depth + 1);
        return;
    }
    harvestSectionContent(((GPBMessage *)object).firstSubmessage, itemSectionRenderers, elements, seen, depth + 1);
}

static NSArray *itemSectionRenderersFromObject(id object) {
    NSMutableArray *itemSectionRenderers = [NSMutableArray array];
    NSMutableArray *elements = [NSMutableArray array];
    NSHashTable *seen = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    harvestSectionContent(object, itemSectionRenderers, elements, seen, 0);
    YTIItemSectionRenderer *wrapped = itemSectionRendererWithElements(elements);
    if (wrapped)
        [itemSectionRenderers insertObject:wrapped atIndex:0];
    return itemSectionRenderers.count ? itemSectionRenderers : nil;
}

static NSArray *normalizedSectionRenderers(NSArray *sectionRenderers) {
    if (sectionRenderers.count == 0)
        return sectionRenderers;

    NSMutableArray *normalized = [NSMutableArray arrayWithCapacity:sectionRenderers.count];
    BOOL changed = NO;
    for (id renderer in sectionRenderers) {
        if ([renderer isKindOfClass:%c(YTIItemSectionRenderer)]) {
            [normalized addObject:renderer];
            continue;
        }
        BOOL shouldConvert = [renderer isKindOfClass:%c(YTISectionListMutationOperations)]
            || [renderer isKindOfClass:%c(YTIElementRenderer)]
            || [renderer isKindOfClass:%c(YTISectionListSupportedRenderers)];
        NSArray *converted = shouldConvert ? itemSectionRenderersFromObject(renderer) : nil;
        if (converted.count) {
            [normalized addObjectsFromArray:converted];
            changed = YES;
        } else {
            [normalized addObject:renderer];
        }
    }
    return changed ? normalized : sectionRenderers;
}

%hook YTISectionListRenderer

- (NSArray *)sectionRenderers {
    NSArray *sectionRenderers = %orig;
    return normalizedSectionRenderers(sectionRenderers);
}

%end

%hook YTICommentsResponse

- (NSArray *)sectionRenderers {
    NSArray *sectionRenderers = %orig;
    return normalizedSectionRenderers(sectionRenderers);
}

%end

%hook YTInnerTubeCollectionViewController

- (void)loadWithModel:(id)model {
    %orig;
    NSMutableArray *sectionRenderers = [self valueForKey:@"_sectionRenderers"];
    NSArray *normalized = normalizedSectionRenderers(sectionRenderers);
    BOOL hasItemSection = NO;
    for (id renderer in normalized) {
        if ([renderer isKindOfClass:%c(YTIItemSectionRenderer)]) {
            hasItemSection = YES;
            break;
        }
    }
    if (!hasItemSection && [model isKindOfClass:%c(YTISectionListRenderer)]) {
        NSArray *fromModel = itemSectionRenderersFromObject(model);
        if (fromModel.count)
            normalized = fromModel;
    }
    if (normalized != sectionRenderers)
        [self setValue:[normalized mutableCopy] forKey:@"_sectionRenderers"];
    NSDictionary *sectionControllerByRenderer = [self valueForKey:@"_sectionControllerByRenderer"];
    if (sectionControllerByRenderer.count == 0)
        [self displaySections];
}

- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    NSMutableArray *sectionRenderers = [self valueForKey:@"_sectionRenderers"];
    NSArray *normalized = normalizedSectionRenderers(sectionRenderers);
    if (IS_ENABLED(RemoveAds)) [self setValue:filteredArray([normalized mutableCopy]) forKey:@"_sectionRenderers"];
    else if (normalized != sectionRenderers) [self setValue:[normalized mutableCopy] forKey:@"_sectionRenderers"];
    %orig;
}

- (void)addSectionsFromArray:(NSArray <YTIItemSectionRenderer *> *)array {
    if (IS_ENABLED(RemoveAds)) array = filteredArray(normalizedSectionRenderers(array));
    else array = normalizedSectionRenderers(array);
    %orig(array);
}
%end