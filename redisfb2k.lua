--[[*****************************************************************************
Copyright (c) 2015 Kwang Kye
version = redisfb2k.lua initial release
description = sync playback stats from foobar2000 using redis db
--*******************************************************************************]]

local redis = require 'redis'
--redis lua module by NRK
--https://github.com/nrk/redis-lua

local cli = require 'cliargs'
--command line arguments modules
--https://github.com/amireh/lua_cliargs

-- 4digit year, 2digit month, 2digit date 
local todaysdate = os.date("%Y.%m.%d.%H.%M")

cli:set_name("redisfb2k.exe")
cli:add_opt("-n, --name=fqdn", "fqdn or IP of the redis db server", "localhost")
cli:add_opt("-p, --port=#####", "port of the redis db server", "6379")
cli:add_opt("-d, --db=##", "redis db # to use", "15")

cli:add_opt("-e, --exp=ExportFile", "Specify exported statistics filname or fullpath including filename.", "fb2kpbstats_exp.xml")
cli:add_opt("-i, --imp=NewImportFile", "Specify output filname or fullpath including filename.  Filename will be appended with timestamp and xml file extension", "fb2kpbstats_imp")
cli:add_flag("-l, --log", "Log songs added and song playback statistics modified into fb2kstats_changes.log")
cli:add_flag("-c, --confirm", "Display set options and confirm prior to executing")
cli:add_flag("-h, --help", "Display command line options")
 

local args = cli:parse_args()

if not args then
	-- something wrong happened and an error was printed
	print("Error with command line arguments")
	goto done
end

if args["c"] then
	print("This program will run with the following options: ")
	print("Redis Host: " .. args["n"])
	print("Redis Port: " .. args["p"])
	print("Redis Database Number: " .. args["d"])
	print("Use Export File: " .. args["e"])
	print("Create new Import File: " .. args["i"]  .. todaysdate .. ".xml")
	if args["l"] then 
		print("Log File: fb2kstats_changes.log")
	end	
	local answer
	repeat
		io.write("Do you want this program to execute with these parameters (y/n)?") 
		io.flush()
		answer=io.read()
	until answer=="y" or answer=="n"
	if answer=="y" then
		print("")
	else
		goto done
	end
end


local portnum = tonumber(args["p"])
--****************************************************************************
--*********User defined variables section start
-- set correct redis fqdn or ip
-- set correct redis port

local params = {
	host = args["n"],
	port = portnum,
}

--set redis database # to use

local dbnumber = tonumber(args["d"])

-- All file names include the absolute path 
local fp2infile = args["e"]
--local fp2infile = "k:\\Win4Lin\\foobarplaybackstats_htpc.xml"

local fp2tempfile = "foobartemp_mm.xml"
local fp2outfile = args["i"] .. todaysdate .. ".xml"

if args["l"] then 
	fp2logfile = "fb2kstats_changes.log"
	filelog = io.open (fp2logfile, "w")
end

--*********User defined variables section end
--*****************************************************************************

--print("debug")
--print(args["n"])
--print(portnum)
--print(dbnumber)
--print(fp2infile)
--print(fp2outfile)

-- local file = assert(io.open (fp2tempfile,"w")) 
local fileout = io.open (fp2tempfile, "w")

local startid
local endx
local len
local value
local lname
local startcount
local startfp
local startlp
local startad
local startrat
local goodline
local firstplayed
local songkeyexist
local firstline = 1
local fieldupdated = 0
local countadded = 0
local countupdated = 0

--connect to redis db and switch to the correct db number
local client = redis.connect(params)
client:select(dbnumber)


-- define or set redis command used in this script
redis.commands.hmset = redis.command('hmset')
redis.commands.exists = redis.command('exists')	
	
	
-- This amazing piece of code below is by Nrk.  The redis-lua module writer.
-- I copied it character by character from his example of define commands.
-- https://github.com/nrk/redis-lua/blob/version-2.0/examples/define_commands.lua
 	
redis.commands.hgetall = redis.command('hgetall', {
	response = function(reply, command, ...)
		local new_reply = { }
		for i = 1, #reply, 2 do new_reply[reply[i]] = reply[i + 1] end
		return new_reply
	end
})


--Start reading in the input file and process it line by line.
for line in io.lines(fp2infile) do

	-- print(line)

	if firstline == 1 then
		fileout:write(line .. '\10')
		firstline = 0
	end

	for i in string.gmatch(line, "%S+") do
		-- print(i)
		startid, endx = string.find(i, "ID=")
		if startid then
			len = string.len(i)
			newlen =  len - 1 
			value = string.sub(i, endx+2, newlen)
			-- print(value)
			lname = "song:" .. value
			-- print(lname)
			goodline = 1
		end

		startcount, endx = string.find(i, "Count=")
		if startcount then
			len = string.len(i)
			newlen =  len - 1 
			foobrcnt = string.sub(i, endx+2, newlen)
			-- print(foobrcnt)
		end
		
		startfp, endx = string.find(i, "FirstPlayed=")
		if startfp then
			len = string.len(i)
			newlen =  len - 1 
			foobrfp = string.sub(i, endx+2, newlen)
			-- print(foobrfp)
			firstplayed=1
		end
		
		startlp, endx = string.find(i, "LastPlayed=")
		if startlp then
			len = string.len(i)
			newlen =  len - 1 
			foobrlp = string.sub(i, endx+2, newlen)
			-- print(foobrlp)
		end
		
		startad, endx = string.find(i, "Added=")
		if startad then
			len = string.len(i)
			newlen =  len - 1 
			foobrad = string.sub(i, endx+2, newlen)
			-- print(foobrad)
		end
		
		startrat, endx = string.find(i, "Rating=")
		if startrat then
			len = string.len(i)
			newlen =  len - 1 
			foobrat = string.sub(i, endx+2, newlen)
			-- print(foobrat)
		end
	end

	
	if goodline ==1 then
		
		print("Processing> " .. lname)
		
		songkeyexist = client:exists(lname)
		
		-- print("this is value of songkeyexists: " .. songkeyexist)
		
		if songkeyexist then 
	
			-- print("songkey already exists")
			local song = client:hgetall(lname)
			
			-- print(string.format('%s is id and play count is %s and fplay date is %s and lplay date is %s and addate is %s.', song.id, song.count, song.fplayed, song.lplayed, song.added))
			
			--convert foobrcnt value and song.count value from a string to a number
			-- local foobrcntnum = tonumber(foobrcnt)
			-- local songcountnum = tonumber(song.count) 
			if tonumber(foobrcnt) > tonumber(song.count) then
				client:hmset(lname, 'id', value, 'count', foobrcnt)
				-- print("updated count")
				fieldupdated = fieldupdated + 1
				if args["l"] then 
					logline = (lname .. " play count updated on database from " .. song.count .. " to " .. foobrcnt) 
					filelog:write(logline .. '\10')
				end				
			end
			
			if ((foobrfp ~= "") and (song.fplayed == "")) or ((foobrfp ~= "") and ((foobrfp < song.fplayed))) then
					client:hmset(lname, 'id', value, 'fplayed', foobrfp)
				--	print("updated first played date")
					fieldupdated = fieldupdated + 1
					if args["l"] then 
						logline = (lname .. " first play date updated on database from " .. song.fplayed .. " to " .. foobrfp) 
						filelog:write(logline .. '\10')
					end	
			end
			
			if foobrlp > song.lplayed then
				client:hmset(lname, 'id', value, 'lplayed', foobrlp)
				-- print("updated last played date")
				fieldupdated = fieldupdated + 1
				if args["l"] then 
					logline = (lname .. " last played date updated on database from " .. song.lplayed .. " to " .. foobrlp) 
					filelog:write(logline .. '\10')
				end	
			
				-- if lastplay date has been updated.  Check for rating entry for the song in the xml file or on redis
				-- if a rating in either location is found.  Update the redis rating field with the rating from xml file
				if (foobrat ~= "") or (song.rating ~= "") then
					client:hmset(lname, 'id', value, 'rating', foobrat)
					-- print("updated rating")
					fieldupdated = fieldupdated + 1
					if args["l"] then 
						logline = (lname .. " rating updated on database from " .. song.rating .. " to " .. foobrat) 
						filelog:write(logline .. '\10')
					end	
				end	
						
			end
			
			--if the added date for a song on the input file is older than what we have in the redis db then update the added date in db.
			if foobrad < song.added then
				client:hmset(lname, 'id', value, 'added', foobrad)
				-- print("updated added date")
				fieldupdated = fieldupdated + 1
				if args["l"] then 
					logline = (lname .. " added date updated on database from " .. song.added .. " to " .. foobrad) 
					filelog:write(logline .. '\10')
				end	
			end
			
			-- if any field for a song was updated at the db. we count it as one updated song record.   
			if fieldupdated > 0 then
				countupdated = countupdated + 1
				filelog:write("" .. '\10')
			end
			
			fieldupdated = 0
			
		else
			-- print("new song.  creating a new songkey")
			
			countadded = countadded + 1
			
			client:hmset(lname, 'id', value, 'count', foobrcnt, 'fplayed', foobrfp, 'lplayed', foobrlp, 'added', foobrad, 'rating', foobrat)
			--the values are (song:######, play count, first played, last played, added, and rating)
			
			-- we need an easy way to grab all song id to create a a complete playback stats file from the updated redis db.
			-- for this, we are creating a new redis unsorted set data type named songs:id  
			-- we will add a new song id into this key
			
			client:rpush('listsongs:id', value)
			-- print("in else for newsong.")
			if args["l"] then 
				logline = (lname .. " added to database.") 
				filelog:write(logline .. '\10')
				filelog:write("" .. '\10')
			end
		end


	end

	value = ""
	foobrcnt = ""
	foobrfp = ""
	foobrlp = ""
	foobrad = ""
	foobrat = ""
	goodline = ""
	firstplayed = ""
	songkeyexist = ""
	
end	

print("")
print("*************************************************")
print("Creating an updated and merged import file at:")
print(fp2outfile)
print("")

--Processing of the input file and update of the redis db are complete
--We now define redis command needed to generate the merged output file and some variables

redis.commands.lpop = redis.command('lpop')
redis.commands.rpush = redis.command('rpush')
redis.commands.llen = redis.command('llen')
redis.commands.lindex = redis.command('lindex')  

listindexcount = client:llen('listsongs:id')	
listindexcount = listindexcount - 1 
idx = 0

while idx <= listindexcount do

	-- print("redis index is: " .. idx)
	
	xyz = client:lindex('listsongs:id', idx)
	
	newname = "song:" .. xyz 
	
	-- print(newname)
	
	local sng = client:hgetall(newname)
	
	-- fplayed with rating
	-- fplayed without rating
	-- unplayed with rating
	-- unplayed without rating
	--print("this is value of rating: " .. sng.rating)
	
	if (sng.fplayed ~= "") and (sng.rating ~= "") then

		lineout = [[  <Entry ID="]] .. sng.id .. [[" Count="]] .. sng.count .. [[" FirstPlayed="]] .. sng.fplayed .. [[" LastPlayed="]] ..sng.lplayed .. [[" Added="]] .. sng.added .. [[" Rating="]] .. sng.rating .. [[" />]]
		-- lineout = "firstplayed and rating have values"
		
	elseif (sng.fplayed ~= "") and (sng.rating == "") then

		lineout = [[  <Entry ID="]] .. sng.id .. [[" Count="]] .. sng.count .. [[" FirstPlayed="]] .. sng.fplayed .. [[" LastPlayed="]] ..sng.lplayed .. [[" Added="]] .. sng.added .. [[" />]]
		-- lineout = "firstplayed has a value, but no rating"
		
	elseif (sng.fplayed == "") and (sng.rating ~= "") then

		lineout = [[  <Entry ID="]] .. sng.id .. [[" Count="]] .. sng.count .. [[" Added="]] .. sng.added .. [[" Rating="]] .. sng.rating .. [[" />]]			
		-- lineout = "first played is nil, but there is a rating"
		
	elseif  (sng.fplayed == "") and (sng.rating == "") then
	
		lineout = [[  <Entry ID="]] .. sng.id .. [[" Count="]] .. sng.count .. [[" Added="]] .. sng.added .. [[" />]]
		-- lineout = "first played is nil and there is no rating"
	end
	
	fileout:write(lineout .. '\10')

	idx = idx + 1 
end  

fileout:write("</PlaybackStatistics>")

print("New songs added to the database: " .. countadded)
print("Songs updated on the database: " .. countupdated)
print("*************************************************")


if args["l"] then 
	filelog:write("*************************************************" .. '\10')
	filelog:write("New songs added to the database: " .. countadded .. '\10')
	filelog:write("Songs updated on the database: " .. countupdated .. '\10')
	filelog:close()
end

fileout:close()

--[[Found a stupid problem that I only noticed now since I'm testing out the Lua scripts in Windows.  The merged output file in
windows ends in CRLF.  This is a problem because the unix files and the stat file exported foobar itself follows the unix standard
where a line is ended with LF only.  These differences in whitespace coding cause files containing the same exact text per line to end up 
with different file sizes.  This also cause problems when I'm using diff to debug output.  While there are switches to ignore 
whitespaces of varying levels.  My preference is that if a foobar export file was processed with this script and there were no changes at all.
Then the file that is output by this script should be exactly the same in content.  Since Lua doesn't seem to have a way to encode 
a LF only at eol, which is very annoying.  We actually need to process the merged output crlf formatted file to a new file formatted to lf only.

I found this code at: http://www.lua.org/pil/21.2.2.html
when I was looking into the best way to solve this problem.  For posterity the author describes the code below thusly:

The simple model functions io.input and io.output always open a file in text mode (the default). In Unix, there is no difference between binary
files and text files. But in some systems, notably Windows, binary files must be opened with a special flag. To handle such binary files, you
must use io.open, with the letter `b´ in the mode string.

Binary data in Lua are handled similarly to text. A string in Lua may contain any bytes and almost all functions in the libraries can handle
arbitrary bytes. (You can even do pattern matching over binary data, as long as the pattern does not contain a zero byte. If you want to match
the byte zero, you can use the class %z instead.)

Typically, you read binary data either with the *all pattern, that reads the whole file, or with the pattern n, that reads n bytes. As a simple
example, the following program converts a text file from DOS format to Unix format (that is, it translates sequences of carriage return-newlines
to newlines). It does not use the standard I/O files (stdin/stdout), because those files are open in text mode. Instead, it assumes that the names
of the input file and the output file are given as arguments to the program: 

You can call this program with the following command line:

    > lua prog.lua file.dos file.unix
--]]

local inp = assert(io.open(fp2tempfile, "rb"))
local out = assert(io.open(fp2outfile, "wb"))
    
local data = inp:read("*all")
data = string.gsub(data, "\r\n", "\n")
out:write(data)
    
assert(out:close())

--let close the input file just in case.
assert(inp:close())
--Delete temp file
os.remove(fp2tempfile)

::done::










