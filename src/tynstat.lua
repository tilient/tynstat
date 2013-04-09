----------------------------------------------------------------------------
-- tynstat -----------------------------------------------------------------
----------------------------------------------------------------------------
--
-- Tiny Stats Server
--
--   github.com/wiffel/tynstat
--
--   wiffel@tilient.org
--
----------------------------------------------------------------------------

local ffi = require("ffi");

ffi.cdef [[

  typedef uint32_t pid_t;
  typedef uint32_t mode_t;
  typedef uint32_t size_t;
  typedef uint32_t off_t;
  typedef intptr_t  ssize_t;
  typedef uint32_t fd_set;

  typedef struct {
    long int tv_sec;  // second
    long int tv_usec; // micro seconds
  } timeval;

  typedef struct {
    uint16_t sin_family;
    uint8_t  d[128];
  } sock_stor;

  typedef uint32_t socklen_t;
  typedef uint32_t in_addr_t;

  typedef struct addrinfo {
    int              ai_flags;
    int              ai_family;
    int              ai_socktype;
    int              ai_protocol;
    int              ai_addrlen;
    sock_stor        *ai_addr;
    char             *ai_canonname;
    struct addrinfo  *ai_next;
  } addrinfo_t;

  typedef addrinfo_t *p_addrinfo_t;
  
  typedef struct hostent { 
    char *h_name; 
    char **h_aliases; 
    int  h_addrtype; 
    int  h_length; 
    char **h_addr_list; 
  } hostent_t;

  int getaddrinfo(const char *node, const char *service,
                  const struct addrinfo *hints, struct addrinfo **res);
  const char *gai_strerror(int errcode);

  void freeaddrinfo(struct addrinfo *res);
  int bind(int sockfd, sock_stor *addr, socklen_t addrlen);
  int socket(int domain, int type, int protocol);
  int setsockopt(int s, int level, int optname, 
                 const void *optval, socklen_t optlen);
  int listen(int sockfd, int backlog);
  int accept4(int sockfd, sock_stor *addr, socklen_t *addrlen, int flags);

  int close(int fd);
  ssize_t read(int fd, void *buf, size_t count);
  ssize_t write(int fd, const void *buf, size_t count);
  ssize_t send(int fd, const void *buf, size_t count, int flags);
  int select(int nfds, fd_set *readfds, fd_set *writefds,
             fd_set *exceptfds, timeval *timeout);

  void usleep(uint32_t usecs);
  int daemon(int nochdir, int noclose);
  pid_t fork();
  int mkfifo(const char *pathname, mode_t mode); 
  int remove(const char *pathname);
  int open(const char *pathname, int flags);

]];

C = ffi.C;

----------------------------------------------------------------------------
--- TCP/IP -----------------------------------------------------------------
----------------------------------------------------------------------------

local EAGAIN        = 11;
local AF_INET       = 2;
local AF_INET6      = 10;
local SOCK_STREAM   = 1;
local SO_REUSEDDR   = 2;
local SOL_SOCKET    = 1;
local MSG_NOSIGNAL  = 0x4000;

function lookup(hostname, port)
  local ai    = ffi.new("struct addrinfo *[1]", nil);
  local hints = ffi.new("struct addrinfo [1]");
  local sa    = ffi.new("sock_stor[1]");
  local sa_len;

  hints[0].ai_family = AF_INET;
  hints[0].ai_socktype = SOCK_STREAM;
  local res = C.getaddrinfo(hostname, "" .. port, hints, ai);
  if res == 0 then
    sa_len = ai[0].ai_addrlen;
    ffi.copy(sa, ai[0].ai_addr, sa_len);
  else
    print("ERROR lookup", hostname, res, ffi.string(C.gai_strerror(res)));
  end
  C.freeaddrinfo(ai[0]);
  if not hostname then
    ffi.fill(sa[0].d, 128, 0);
  end
  sa[0].sin_family = AF_INET;
  sa[0].d[1] = port % 256;
  sa[0].d[0] = (port - sa[0].d[1]) / 256;
  return sa, sa_len;
end

function listenSocket(port)
  local sa, saLen  = lookup(nil, port);
  local s = C.socket(AF_INET, SOCK_STREAM, 0);

  local on = ffi.new("int[1]"); on[0] = 1;
  C.setsockopt(s, SOL_SOCKET, SO_REUSEDDR, on, ffi.sizeof(on));

  local res = C.bind(s, sa, saLen);
  C.listen(s, 12);
  return s;
end

function handleIncomingConnections(port, handler)
  local listen_socket = listenSocket(port);
  while true do
    local s = C.accept4(listen_socket, nil, nil, 0);
    if s > 0 then
      local status, err = pcall(handler, s);
      pcall(C.close, s);
      collectgarbage("collect");
      if not status then
        print("** ERROR **", err);
      end
    else
      print("** ERROR ** bad return from accept4");
      return;
    end
  end
end

----------------------------------------------------------------------------

function readLine(fd)
  local buf = ffi.new("char[?]", 1024);
  local numBytesRead = 0;
  local retryCount = 100;
  while retryCount > 0 do
    local res = C.read(fd, buf + numBytesRead, 1);
    if res < 0 then
      error("ERROR in readLine: " .. ffi.errno());
    elseif res == 0 then
      retryCount = retryCount - 1;
      C.usleep(100);
    elseif res == 1 then
      local ch = buf[numBytesRead];
      if ch == 13 then
        -- ignore 
      elseif ch == 10 then
        return ffi.string(buf, numBytesRead);
      else
        numBytesRead = numBytesRead + 1;
      end
      if numBytesRead > 1023 then
        error("ERROR in readLine : buffer too small");
      end
    else
      error("ERROR in readLine : received too many chars");
    end
  end
  error("ERROR in readLine : too many retries");
end

function writeBytes(fd, bytes, nrOfBytes)
  local nrOfBytesWritten = 0;
  while nrOfBytesWritten < nrOfBytes do
    local res = C.send(fd, bytes + nrOfBytesWritten, 
                       nrOfBytes - nrOfBytesWritten,
                       MSG_NOSIGNAL);
    if res < 0 then
      error("Error in writeBytes : " .. ffi.errno());
    end
    nrOfBytesWritten = tonumber(nrOfBytesWritten + res);
    C.usleep(10);
  end
end

function writeString(s, str)
  local nrOfBytes = string.len(str);
  local buffer = ffi.new("char[?]", 1 + nrOfBytes);
  ffi.copy(buffer, str, nrOfBytes);
  writeBytes(s, buffer, nrOfBytes)
end

----------------------------------------------------------------------------
--- Stats ------------------------------------------------------------------
----------------------------------------------------------------------------

function collectUptimeStats(stats)
  local stts = {};
  stats.uptime = stts; 
  local str  = io.open("/proc/uptime"):read("*a");
  stts.seconds, stts.idle = str:match("([%d%.]+)%s*([%d%.]+)");
  stts.seconds = tonumber(stts.seconds);
  stts.idle = tonumber(stts.idle);
end

function collectLoadStats(stats)
  local stts = {};
  stats.loadavg = stts; 
  local str = io.open("/proc/loadavg"):read("*a");
  stts.load1min, stts.load5min, stts.load15min = 
    str:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)");
  stts.load1min = tonumber(stts.load1min);
  stts.load5min = tonumber(stts.load5min);
  stts.load15min = tonumber(stts.load15min);
end

function collectMemStats(stats)
  local stts = {};
  stats.meminfo = stts; 
  for line in io.lines("/proc/meminfo") do
    local k, v = line:match("([%w%(%)]+):%s+([%d%.]+)");
      stts[k] = tonumber(v);
  end
end

function collectDfStats(stats)
  local stts = {};
  stats.df = stts;
  local pr = io.popen("df -h");
  pr:read("*line");
  for str in pr:lines() do
    local st = {};
    stts[#stts+1] = st;
    st.filesystem, st.size, st.used, st.avail, st.usepercentage, st.mount =
      str:match("([%w/]+)%s+([%w%.]+)%s+([%w%.]+)%s+" ..  
                "([%w%.]+)%s+([%w%%]+)%s+(.+)$");
  end
end

function collectPsStats(stats)
  local stts = {};
  stats.ps = stts;
  local pr = io.popen("ps -e -o pcpu,pmem,vsize,rss,cputime,user,args " .. 
                      "--sort -pcpu | head -10");
  pr:read("*line");
  for str in pr:lines() do
    local st = {};
    stts[#stts+1] = st;
    st.cpu, st.mem, st.vsize, st.rss, st.cputime, st.user, st.args =
      str:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.-)%s*$");
    st.cpu   = 0.01 * tonumber(st.cpu);
    st.mem   = 0.01 * tonumber(st.mem);
    st.vsize = tonumber(st.vsize);
    st.rss   = tonumber(st.rss);
  end
end

function collectStats()
  local stats = {};
  collectUptimeStats(stats);
  collectLoadStats(stats);
  collectMemStats(stats);
  collectDfStats(stats);
  collectPsStats(stats);
  return stats;
end

----------------------------------------------------------------------------

function statObj2Html(obj, tstr, indent, d0, d1)
  if not obj then
    tstr[#tstr+1] = "nil";
  else
    local objType = type(obj);
    if objType == "boolean" then
      tstr[#tstr+1] = obj and "true" or "false";
    elseif objType == "string" then
      tstr[#tstr+1] = obj;
    elseif objType == "number" then
      tstr[#tstr+1] = tostring(obj)
    elseif objType == "table" then
      local d0 = d0 or "d0";
      local d1 = d1 or "d1";
      local indent = indent or 0;
      local istr = string.rep(" ", indent);
      tstr[#tstr+1] = "\r\n";
      tstr[#tstr+1] = istr;
      tstr[#tstr+1] = "<table>\r\n";
      for k, v in pairs(obj) do
        d1, d0 = d0, d1;
        tstr[#tstr+1] = istr;
        tstr[#tstr+1] = "  <tr class='";
        tstr[#tstr+1] = d0;
        tstr[#tstr+1] = "'><td class='l'>";
        statObj2Html(k, tstr, indent + 2, d0, d1);
        tstr[#tstr+1] = "</td><td class='r'>";
        statObj2Html(v, tstr, indent + 2, d0, d1);
        tstr[#tstr+1] = "</td></tr>\r\n";
      end
      tstr[#tstr+1] = istr;
      tstr[#tstr+1] = "</table>";
    else
      tstr[#tstr+1] = "???";
    end
  end
end

function stats2html(stats)
  local tstr = {};
  tstr[#tstr+1] = [[<!doctype html>
<html>
  <head>
    <meta charset='utf-8'>
    <meta name='description' content='tenili'>
    <meta name='viewport' content='width=device-width'>
    <style type='text/css'>
      table { background-color : #ffffff; 
              width : 100%;
              cellpadding : 3px;
              cellspacing : 1px }
      tr.d0 { background-color: #eeeeee; }
      tr.d1 { background-color: #dddddd; }
      td.l { vertical-align : top; 
             text-align : right;
             width : 20px; }
      td.r { vertical-align : top; 
             text-align : left;
             width : 80px; }
    </style>
    <meta http-equiv='cleartype' content='on'>
  </head>
  <body>
    <center><table style='width:600px;'><tr><td> ]];
  statObj2Html(stats, tstr, 6);
  tstr[#tstr+1] = [[ </td></tr></table></center>
  </body>
</html>]];
  return table.concat(tstr);
end

----------------------------------------------------------------------------

function statObj2Json(obj, tstr, indent)
  local tstr = tstr or {};
  if not obj then
    tstr[#tstr+1] = "null";
  else
    local objType = type(obj);
    if objType == "boolean" then
      tstr[#tstr+1] = obj and "true" or "false";
    elseif objType == "string" then
      tstr[#tstr+1] = "\"";
      tstr[#tstr+1] = obj;
      tstr[#tstr+1] = "\"";
    elseif objType == "number" then
      tstr[#tstr+1] = tostring(obj);
    elseif objType == "table" then
      local indent = indent or 2;
      local istr = string.rep(" ", indent);
      tstr[#tstr+1] = "{\r\n";
      for k, v in pairs(obj) do
        tstr[#tstr+1] = istr;
        statObj2Json(k, tstr, indent + 2);
        tstr[#tstr+1] = " : ";
        statObj2Json(v, tstr, indent + 2);
        tstr[#tstr+1] = ",\r\n";
      end
      tstr[#tstr] = " }";
    else
      tstr[#tstr+1] = "\"???\"";
    end
  end
  return tstr;
end

function stats2json(stats)
  return table.concat(statObj2Json(stats));
end

----------------------------------------------------------------------------

function handler(s)
  local uri = readLine(s):match("GET%s+([%w/%.]+)%s+") or "/";

  -- ignore all the headers
  local cnt = 5000;
  repeat cnt = cnt - 1; until (cnt < 0) or (readLine(s):len() <= 0);

  if uri == "/html" then
    writeString(s, "HTTP/1.0 200 OK\r\n");
    writeString(s, "Content-Type: text/html\r\n");
    str = stats2html(collectStats());
    writeString(s, "Content-Length: " .. str:len() .. "\r\n\r\n");
    writeString(s, str);
  elseif uri == "/json" then
    writeString(s, "HTTP/1.0 200 OK\r\n");
    writeString(s, "Content-Type: application/json\r\n");
    str = stats2json(collectStats());
    writeString(s, "Content-Length: " .. str:len() .. "\r\n\r\n");
    writeString(s, str);
  else
    writeString(s, "HTTP/1.0 404 Not Found\r\n\r\n");
  end
end


----------------------------------------------------------------------------

config = {
  port      = 27272;
  daemonize = false;
};

function handleArgs()
  local i = 1;
  local cmd = arg[i];
  while cmd do
    if cmd == "-d" then
      config.daemonize = true;
    end
    if cmd == "-p" then
      i = i + 1;
      local port = arg[i];
      config.port = port and tonumber(port) or config.port;
    end
    i = i + 1;
    cmd = arg[i];
  end
end

function main()
  handleArgs();
  if config.daemonize then
    C.daemon(0, 0);
  end
  handleIncomingConnections(config.port, handler);
end

main();

----------------------------------------------------------------------------

