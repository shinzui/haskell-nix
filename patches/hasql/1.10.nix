# hasql 1.10.x — enable new-api configure flag
{ pkg, lib, haskellLib }:

haskellLib.appendConfigureFlags pkg [ "--flag=new-api" ]
