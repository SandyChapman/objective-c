/**

 @author Sergey Mamontov
 @version 3.4.0
 @copyright © 2009-13 PubNub Inc.

 */

#import "PNPrivateImports.h"
#import "PNObjectSynchronizationEvent+Protected.h"
#import "PNSynchronizationChannel+Protected.h"
#import "PNChannelEventsResponseParser.h"
#import "PNChannelPresence+Protected.h"
#import "PNPresenceEvent+Protected.h"
#import "PNChannelEvents+Protected.h"
#import "PNResponse+Protected.h"
#import "PNDate.h"


// ARC check
#if !__has_feature(objc_arc)
#error PubNub channel events response parser must be built with ARC.
// You can turn on ARC for only PubNub files by adding '-fobjc-arc' to the build phase for each of its files.
#endif


#pragma mark Static

/**
 Stores reference on index under which events list is stored.
 */
static NSUInteger const kPNResponseEventsListElementIndex = 0;

/**
 Stores reference on time token element index in response for events.
 */
static NSUInteger const kPNResponseTimeTokenElementIndexForEvent = 1;

/**
 Stores reference on index under which channels list is stored.
 */
static NSUInteger const kPNResponseChannelsListElementIndex = 2;

/**
 Stores reference on index under which synchronization events channel mapping is stored.
 */
static NSUInteger const kPNResponseSynchronizationChannelsListElementIndex = 3;


#pragma mark - Private interface methods

@interface PNChannelEventsResponseParser ()


#pragma mark - Properties

/**
 Stores reference on even data object which holds all information about events.
 */
@property (nonatomic, strong) PNChannelEvents *events;


#pragma mark -


@end


#pragma mark - Public interface methods

@implementation PNChannelEventsResponseParser


#pragma mark - Class methods

+ (id)parserForResponse:(PNResponse *)response {

    NSAssert1(0, @"%s SHOULD BE CALLED ONLY FROM PARENT CLASS", __PRETTY_FUNCTION__);


    return nil;
}

+ (BOOL)isResponseConformToRequiredStructure:(PNResponse *)response {

    // Checking base requirement about payload data type.
    BOOL conforms = [response.response isKindOfClass:[NSArray class]];

    // Checking base components
    if (conforms) {

        NSArray *responseData = response.response;
        conforms = ([responseData count] > kPNResponseEventsListElementIndex);
        if (conforms) {

            if ([responseData count] > kPNResponseTimeTokenElementIndexForEvent) {

                id timeToken = [responseData objectAtIndex:kPNResponseTimeTokenElementIndexForEvent];
                conforms = (timeToken && ([timeToken isKindOfClass:[NSNumber class]] || [timeToken isKindOfClass:[NSString class]]));
            }

            id events = [responseData objectAtIndex:kPNResponseEventsListElementIndex];
            conforms = ((conforms && events) ? [events isKindOfClass:[NSArray class]] : conforms);

            if ([responseData count] > kPNResponseChannelsListElementIndex) {

                id channelsList = [responseData objectAtIndex:kPNResponseChannelsListElementIndex];
                conforms = ((conforms && channelsList) ? [channelsList isKindOfClass:[NSString class]] : conforms);

            }
        }
    }


    return conforms;
}


#pragma mark - Instance methods

- (id)initWithResponse:(PNResponse *)response {

    // Check whether initialization successful or not
    if ((self = [super init])) {

        NSArray *responseData = response.response;
        self.events = [PNChannelEvents new];
        PNDate *eventDate = nil;

        // Check whether time token is available or not
        if ([responseData count] > kPNResponseTimeTokenElementIndexForEvent) {

            id timeToken = [responseData objectAtIndex:kPNResponseTimeTokenElementIndexForEvent];
            self.events.timeToken = PNNumberFromUnsignedLongLongString(timeToken);
            eventDate = [PNDate dateWithToken:self.events.timeToken];
        }

        // Retrieving list of events
        NSArray *events = [responseData objectAtIndex:kPNResponseEventsListElementIndex];

        // Retrieving list of channels on which events fired
        NSArray *channels = nil;
        if ([responseData count] > kPNResponseSynchronizationChannelsListElementIndex) {

            channels = [[responseData objectAtIndex:kPNResponseSynchronizationChannelsListElementIndex]
                        componentsSeparatedByString:@","];
        }

        if ([events count] > 0) {

            NSMutableArray *eventObjects = [NSMutableArray arrayWithCapacity:[events count]];
            [events enumerateObjectsUsingBlock:^(id event, NSUInteger eventIdx, BOOL *eventEnumeratorStop) {

                PNChannel *channel = nil;
                if ([channels count] > 0) {

                    // Retrieve reference on channel on which event is occurred
                    channel = [PNChannel channelWithName:[channels objectAtIndex:eventIdx]];

                    // Checking whether event occurred on presence observing channel
                    // or no and retrieve reference on original channel
                    if ([channel isPresenceObserver]) {

                        channel = [(PNChannelPresence *)channel observedChannel];
                    }
                }

                id eventObject = nil;

                // Checking whether event presence event or not
                if ([event isKindOfClass:[NSDictionary class]] &&
                    ([PNPresenceEvent isPresenceEventObject:event] || [PNObjectSynchronizationEvent isSynchronizationEvent:event])) {

                    if ([PNPresenceEvent isPresenceEventObject:event]) {

                        eventObject = [PNPresenceEvent presenceEventForResponse:event];
                        ((PNPresenceEvent *)eventObject).channel = channel;
                    }
                    else if ([PNObjectSynchronizationEvent isSynchronizationEvent:event] ) {

                        if (![channel isObjectSynchronizationChannel]) {

                            NSArray *components = [channel.name componentsSeparatedByString:@"."];
                            if ([components count] > 1) {

                                channel = [PNSynchronizationChannel channelForObject:[components objectAtIndex:0]
                                                dataPath:([components count] > 2 ? [components lastObject] : nil)];
                            }
                        }
                        if ([channel isObjectSynchronizationChannel]) {

                            eventObject = [PNObjectSynchronizationEvent synchronizationEventForObject:((PNSynchronizationChannel *)channel).objectIdentifier
                                           atPath:((PNSynchronizationChannel *)channel).partialObjectDataPath
                                   dromDictionary:event];
                        }
                    }
                }
                else {

                    eventObject = [PNMessage messageFromServiceResponse:event onChannel:channel atDate:eventDate];
                }

                [eventObjects addObject:eventObject];
            }];

            self.events.events = eventObjects;
        }
    }


    return self;
}

- (id)parsedData {

    return self.events;
}

- (NSString *)description {

    return [NSString stringWithFormat:@"%@ (%p) <time token: %@, events: %@>", NSStringFromClass([self class]), self,
                                      self.events.timeToken, self.events.events];
}

#pragma mark -


@end
