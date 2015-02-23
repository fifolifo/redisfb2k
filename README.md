# redisfb2k #
Lua script that parses and syncs the exported playback statistics xml from foobar2000 into a Redis DB.  The script outputs a synced xml file that can be imported into foobar2000.

### Description 
This script does the following:
- Parse song data found in the exported playback statistics file.
   - Supported data fields:
      - ID
      - Count
      - FirstPlayed
      - LastPlayed
      - Added
      - Rating
- Create a new song key in Redis and populate with above data values if an existing key isn't found. If a song key      already exists.  Compare the data values for the song from the export file to the data values stored on Redis db.
   If the data value is more current than update the value on the Redis db with the value from the xml file.
- Once the redis db has been fully updated.  Use the updated data to create a new synced playback statistics xml file    that can be imported into foobar2000. 

----------
### Compatibility ###

This script is used in the following environment:
Three Windows 7 computers running foobar 1.1.x running playback statistics component 3.0.x and a Redis server version 2.8.19 running on Linux. 
There is a Windows port of the Redis server on GitHub (https://github.com/MSOpenTech/redis) and in theory, this script should work without issues with this Windows port of Redis.  It's a very small download and the redis server exe itself can be run without installing.  Although if this will be a permanent install.  It should be installed as a service.  I have run this script against this ported version (2.8.17) a few times as a test and it appeared to have worked fine. 

### Limitations ###
----------
All foobar2000 installations must have the same exact mapping value.  You can check this by examining the first line of the exported playback statistics xml file.  If the mapping values differ.  Do not use this script. 

All foobar2000 installations using this script must export the exact same ID# in the exported xml file for a particular song. 

Play counts will be lost when sync are not performed regularly due to the asynchronous operation of this process. 
Example:
- PC A and PC B used this script to update the play count statistic for song C to 5 on the Redis db and locally. 
- Since then, PC A has played song C two more time. PLay count is now at 7.
- Since then, PC B has played song C one more time. Play count is now at 6. 
- When PC A and PC B use this script to update the playcount on the Redis db.
- The play count stored on the Redis db for song C will be 7. 
- One play count from PC B has been lost.

Songs that have been deleted/removed from the foobar library will be orphaned on the redis db.  This is because there is no information on how the hash keys for a song are created by foobar2000.  Without this information, it is not possible to identify the proper record on the db for removal. 

### Dependencies ###
----------
- [Lua 5.2] (http://www.lua.org/)
- LuaSocket
- [redis lua] (https://github.com/nrk/redis-lua)
- [cliargs] (https://github.com/amireh/lua_cliargs)

### License ###
----------
MIT
