//
//  boe.appleevents.mm
//  BoE
//
//  Created by Celtic Minstrel on 14-03-26.
//
//

#include <Cocoa/Cocoa.h>
#include <memory>
#include <algorithm>
#include "fileio.h"
#include "boe.global.h"
#include "dlogutil.h"
#include "universe.h"

extern void finish_load_party();
extern void end_startup();
extern void post_load();

extern bool app_started_normally, ae_loading, in_startup_mode, startup_loaded, All_Done;
extern eGameMode overall_mode;
extern cUniverse univ;

typedef NSAppleEventDescriptor AEDescr;

@interface AppleEventHandler : NSObject
-(void)handleOpenApp:(AEDescr*)theAppleEvent withReply: (AEDescr*)reply;
-(void)handleOpenDoc:(AEDescr*)theAppleEvent withReply: (AEDescr*)reply;
-(void)handleQuit:(AEDescr*)theAppleEvent withReply: (AEDescr*)reply;
@end

void set_up_apple_events() {
	AppleEventHandler* aeHandler = [[[AppleEventHandler alloc] init] autorelease];
	NSAppleEventManager* AEmgr = [NSAppleEventManager sharedAppleEventManager];
	[AEmgr setEventHandler: aeHandler andSelector: @selector(handleOpenApp:withReply:)
		forEventClass: kCoreEventClass andEventID: kAEOpenApplication];
	[AEmgr setEventHandler: aeHandler andSelector: @selector(handleOpenDoc:withReply:)
		forEventClass: kCoreEventClass andEventID: kAEOpenDocuments];
	[AEmgr setEventHandler: aeHandler andSelector: @selector(handleQuit:withReply:)
		forEventClass: kCoreEventClass andEventID: kAEQuitApplication];
}

// TODO: Not sure, do I need to do anything with the reply event?
@implementation AppleEventHandler
-(void)handleOpenApp:(AEDescr*)theAppleEvent withReply: (AEDescr*)reply {
	app_started_normally = true;
}

-(void)handleOpenDoc:(AEDescr*)theAppleEvent withReply: (AEDescr*)reply {
	NSAppleEventDescriptor* docList = [theAppleEvent paramDescriptorForKeyword: keyDirectObject];
	if(docList == nil) return;
	
	long itemsInList = [docList numberOfItems];
	if(itemsInList == 0) return;
	
	NSAppleEventDescriptor* fileDesc = [docList descriptorAtIndex: 1];
	if(fileDesc == nil) return;
	// TODO: I'm not entirely sure that a file specifier is convertable to a string.
	NSString* file = [fileDesc stringValue];
	if(file == nil) {
		printf("Error: filename was nil\n");
		return;
	}
	
	unsigned long len = [file length], sz = len + 1;
	auto msg = std::shared_ptr<unichar>(new unichar[sz], std::default_delete<unichar[]>());
	std::fill(msg.get(), msg.get() + sz, 0);
	[file getCharacters: msg.get() range: (NSRange){0, len}];
	std::string fileName;
	std::copy(msg.get(), msg.get() + len, std::inserter(fileName, fileName.begin()));
	
	ae_loading = true;
	load_party(fileName);
	finish_load_party();
	ae_loading = false;
	
	if(!in_startup_mode && startup_loaded)
		end_startup();
	if(!in_startup_mode) {
		post_load();
	}
}

-(void)handleQuit:(AEDescr*)theAppleEvent withReply: (AEDescr*)reply {
	if((overall_mode == MODE_STARTUP/*40*/) || (in_startup_mode)) {
		All_Done = true;
		return;
	}
	
	if(overall_mode < MODE_TALK_TOWN) {
		std::string choice = cChoiceDlog("quit-confirm-save.xml", {"save", "quit", "cancel"}).show();
		if(choice == "cancel") return; // TODO: Need to make sure the quit is actually cancelled here
		if(choice == "save")
			save_party(univ.file);
	} else {
		std::string choice = cChoiceDlog("quit-confirm-nosave.xml", {"quit", "cancel"}).show();
		if(choice == "cancel") return; // TODO: Need to make sure the quit is actually cancelled here
	}
	
	All_Done = true;
}
@end