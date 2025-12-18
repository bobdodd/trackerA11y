#import <Foundation/Foundation.h>

// Test the outputEvent function
void outputEvent(NSString* eventType, NSDictionary* eventData) {
    printf("DEBUG: outputEvent called with type: %s\n", [eventType UTF8String]);
    fflush(stdout);
    
    NSError* error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:@{
        @"type": eventType,
        @"timestamp": @((uint64_t)([[NSDate date] timeIntervalSince1970] * 1000000)),
        @"data": eventData
    } options:0 error:&error];
    
    if (error) {
        printf("ERROR: JSON serialization failed: %s\n", [[error localizedDescription] UTF8String]);
        fflush(stdout);
        return;
    }
    
    if (!jsonData) {
        printf("ERROR: No JSON data created\n");
        fflush(stdout);
        return;
    }
    
    NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (!jsonString) {
        printf("ERROR: Failed to create JSON string\n");
        fflush(stdout);
        return;
    }
    
    printf("%s\n", [jsonString UTF8String]);
    fflush(stdout);
}

int main() {
    @autoreleasepool {
        printf("Testing outputEvent function...\n");
        fflush(stdout);
        
        outputEvent(@"system", @{@"message": @"test message"});
        
        printf("Test complete\n");
        fflush(stdout);
        
        return 0;
    }
}