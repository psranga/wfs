-- (network) chunk manager.
-- chunk = <filename>\n<begin>\n<end>\n
--
--[[

RESERVEFOR:

  RESERVEFOR\n
  fn: fn\n <-- base64 if not a char possible to type on ANSI US keyb
  begin: begin\n
  end: end\n
  pubsum: public-checksum (MAC)\n
  mysum: private checksum (HMAC)\n
  \n

  blockid: id
  errno: errno
  errno1: suberrorlevel
  errno2: sub-suberrorlevel
  perror: perror

STAGE:

  STAGE\n
  blockid: id\n
  sz: sz\n
  mysum: HMAC\n
  pubsum: MAC\n
  \n
  <raw data>

  mysum: HMAC
  pubsum: MAC
  errno: errno

COMMITIF:

  COMMITIF\n
  fn: fn\n
  begin: begin\n
  end: end\n
  blockid: id
  pubsum: MAC
  mysum: HMAC

COMMITMANY:

  COMMITMANY\n
  0 fn: fn\n
  0 begin: begin\n
  0 end: end\n
  0 blockid: id
  0 pubsum: MAC
  0 mysum: HMAC
  1 fn: fn\n
  1 begin: begin\n
  1 end: ...
  ...
  \n

Output:

  errno:
  0 mysum: HMAC
  0 pubsub: MAC
  0 errno: errno

--]]

