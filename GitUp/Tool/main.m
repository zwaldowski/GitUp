//  Copyright (C) 2015-2019 Pierre-Olivier Latour <info@pol-online.net>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "GitUp-ScriptingDefinition.h"

#if DEBUG
#define kAppBundleIdentifier "co.gitup.mac-debug"
#else
#define kAppBundleIdentifier "co.gitup.mac"
#endif

#define kToolCommand_Help "help"
#define kToolCommand_Open "open"
#define kToolCommand_Map "map"
#define kToolCommand_Commit "commit"
#define kToolCommand_Stash "stash"

#define kHelpFormat "\
Usage: %s [command]\n\
\n\
Commands:\n\
\n\
" kToolCommand_Help "\n\
  Show this help.\n\
\n\
" kToolCommand_Open " (default)\n\
  Open the current Git repository in GitUp.\n\
\n\
" kToolCommand_Map "\n\
  Open the current Git repository in GitUp in Map view.\n\
\n\
" kToolCommand_Commit "\n\
  Open the current Git repository in GitUp in Commit view.\n\
\n\
" kToolCommand_Stash "\n\
  Open the current Git repository in GitUp in Stashes view.\n\
\n\
"

// We don't care about free'ing resources since the tool is one-shot
int main(int argc, const char* argv[]) {
  @autoreleasepool {
    NSURL* executableURL = [NSURL fileURLWithFileSystemRepresentation:argv[0] isDirectory:NO relativeToURL:nil];
    NSString* command = argc >= 2 ? @(argv[1]) : @kToolCommand_Open;

    if ([command isEqual:@kToolCommand_Help]) {
      fprintf(stdout, kHelpFormat, executableURL.lastPathComponent.UTF8String);
      return 0;
    }

    // Remove "Contents/SharedSupport/{executable}"
    NSURL* appURL = [[[[executableURL URLByResolvingSymlinksInPath] URLByDeletingLastPathComponent] URLByDeletingLastPathComponent] URLByDeletingLastPathComponent];
    GitUpApplication* app = [appURL.pathExtension isEqual:@"app"] ? [SBApplication applicationWithURL:appURL] : [SBApplication applicationWithBundleIdentifier:@kAppBundleIdentifier];
    if (!app) {
      fprintf(stderr, "Could not find GitUp application\n");
      return 1;
    }

    // Attempt to open the current directory as a repository.
    NSString* cwdPath = NSFileManager.defaultManager.currentDirectoryPath;
    NSURL* cwd = [NSURL fileURLWithPath:cwdPath isDirectory:YES];
    GitUpDocument* doc = [app open:cwd];
    if (!doc) {
      fprintf(stderr, "Failed opening repository at current path (%s)\n", app.lastError.description.UTF8String ?: "unknown");
      return 1;
    }

    // If specified, attempt to change the window tab.
    if ([command isEqual:@kToolCommand_Map]) {
      doc.mode = GitUpWindowModeMap;
    } else if ([command isEqual:@kToolCommand_Commit]) {
      doc.mode = GitUpWindowModeCommit;
    } else if ([command isEqual:@kToolCommand_Stash]) {
      doc.mode = GitUpWindowModeStashes;
    }

    if (app.lastError) {
      fprintf(stderr, "Failed changing the window mode of the repository (%s)\n", app.lastError.description.UTF8String);
      return 1;
    }

    // All ready. Bring it frontmost.
    [app activate];
    return 0;
  }
}
