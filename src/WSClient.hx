/* ************************************************************************ */
/*																			*/
/*  Tora - Neko Application Server											*/
/*  Copyright (c)2013 Motion-Twin											*/
/*																			*/
/* This library is free software; you can redistribute it and/or			*/
/* modify it under the terms of the GNU Lesser General Public				*/
/* License as published by the Free Software Foundation; either				*/
/* version 2.1 of the License, or (at your option) any later version.		*/
/*																			*/
/* This library is distributed in the hope that it will be useful,			*/
/* but WITHOUT ANY WARRANTY; without even the implied warranty of			*/
/* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU		*/
/* Lesser General Public License or the LICENSE file for more details.		*/
/*																			*/
/* ************************************************************************ */

import tora.Code;

class WSClient extends Client {

	static inline var GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

	var buf : haxe.io.Bytes;
	var bufpos : Int;
	var initialBufferSize : Int;
	var maxBufferSize : Int;

	var headersReceived : Bool;

	public function new(s,secure,ssl){
		super(s,secure,ssl);
		initialBufferSize = (1 << 10);
		maxBufferSize = (1 << 16);
		bufpos = 0;
		buf = haxe.io.Bytes.alloc(initialBufferSize);
		headersReceived = false;
		httpMethod = "WEBSOCKET";
	}

	override public function prepare() {
		dataBytes = 0;
		outputHeaders = new List();
		postData = null;
		execute = null;
	}


	override function processMessage() : Bool{
		if( cachedCode != null ){
			var newbuf = haxe.io.Bytes.alloc(buf.length+1);
			newbuf.set(0,cachedCode);
			newbuf.blit(1,buf,0,buf.length);
			buf = newbuf;
			bufpos++;
			cachedCode = null;
		}

		var available = buf.length - bufpos;

		if( available == 0 ) {
			var newsize = buf.length * 2;
			if( newsize > maxBufferSize ) {
				newsize = maxBufferSize;
				if( buf.length == maxBufferSize )
					throw "Max buffer size reached";
			}
			var newbuf = haxe.io.Bytes.alloc(newsize);
			newbuf.blit(0,buf,0,bufpos);
			buf = newbuf;
			available = newsize - bufpos;
		}

		sock.setTimeout( 1 );
		var bytes = sock.input.readBytes(buf,bufpos,available);
		var pos = 0;
		var len = bufpos + bytes;
		while( len > 0 ) {
			var m = read(pos,len);
			if( m == 0 )
				break;
			len -= m;
			pos += m;
		}

		if( pos > 0 )
			buf.blit(0,buf,pos,len);
		bufpos = len;

		return execute;
	}

	function read( pos : Int, len : Int ) : Int {
		if( !headersReceived ){
			var p = pos;
			while( p < pos+len ){
				if( buf.get(p) == "\n".code )
					break;
				p++;
			}
			if( p >= pos+len )
				return 0;
			p -= pos;
			var s = buf.getString(pos,p);
			if( s.charCodeAt(s.length-1) == "\r".code )
				s = s.substr(0,-1);
			parseReq(s);
			return p+1;
		}else{
			if( len < 6 )
				return 0;
			var p = pos;
			var a = buf.get(p++);
			var b = buf.get(p++);
			var fin = a&128==128;
			if( !fin )
				throw "Unsupported";
			var rsv = a&112;
			var opcode = a&15;
			var masked = (b&128==128);
			if( !masked )
				throw "Protocol error";
			var l = (b&127);
			if( l == 126 ){
				if( len < 8 )
					return null;
				l = buf.get(p++)<<8 | buf.get(p++);
			}else if( l == 127 )
				throw "Unsupported data length";

			var mask = new haxe.io.BytesInput(buf.sub(p,4)).readInt32();			
			p += 4;

			if( p-pos+l > len )
				return null;
			var data = buf.sub(p,l);

			switch( opcode ){
			case 1: // text
				if( masked ){
					postData = neko.Lib.stringReference(unmask(data,mask));
					execute = true;
				}
			case 8: // close
				send("",8);
				needClose = true;

			case 9: // ping
				send(neko.Lib.stringReference(unmask(data,mask)),10);

			case 10: // pong

			default:
				throw "Unsupported opcode";
			}

			
			return p-pos+l;
		}
	}

	function parseReq( s : String ){
		if( s.length == 0 ){
			hostName = getHeader("Host");
			if( hostName == null )
				throw "Missing host";

			hostName = hostName.split(":")[0];

			ip = sock.peer().host.toString();
			file = Tora.inst.resolveHost(hostName);

			headersReceived = true;
			execute = true;
			return;
		}
		var p = s.indexOf(": ");
		if( p >= 0 ){
			headers.push({k: s.substr(0,p), v: s.substr(p+2)});
			return;
		}

		var f = s.indexOf(" ");
		var l = s.lastIndexOf(" ");

		uri = s.substr(f+1,l-f-1);
		
		var i = uri.indexOf("?");
		if( i >= 0 ){
			getParams = uri.substr(i+1);
			parseGetParams();
			uri = uri.substr(0,i);
		}
	}

	function parseGetParams(){
		var s = getParams;

		while( true ){
			var aand = s.indexOf("&");
			var asep = s.indexOf(";");
			if( aand == -1 || (asep != -1 && asep < aand) )
				aand = asep;
			
			var p = aand==-1 ? s : s.substr(0,aand);
			var aeq = p.indexOf("=");
			if( aeq != -1 )
				params.add({
					k: StringTools.urlDecode(p.substr(0,aeq)), 
					v: StringTools.urlDecode(p.substr(aeq+1))
				});

			if( aand == -1 )
				break;

			s = s.substr(aand+1);
		}
	}

	function getHeader( k : String ){
		k = k.toLowerCase();
		for( h in headers )
			if( h.k.toLowerCase() == k )
				return h.v;
		return null;
	}

	public override function sendHeaders() {
		if( headersSent ) return;
		headersSent = true;

		var rcode = null;
		for( h in outputHeaders ){
			if( h.code == CReturnCode ){
				rcode = h.str;
				break;
			}
		}

		var heads = new List();

		if( rcode != null ){
			heads.add("HTTP/1.1 "+rcode+" Access denied");
			heads.add("Connection: close");
		}else{
			heads.add("HTTP/1.1 101 Switching Protocols");
			heads.add("Upgrade: websocket");
			heads.add("Connection: Upgrade");
			var key = getHeader("Sec-WebSocket-Key");
			if( key == null )
				throw "Missing Sec-WebSocket-Key header";

			var accept = haxe.crypto.Sha1.encode(key+GUID);
			accept = haxe.crypto.BaseCode.decode(accept,"0123456789abcdef");
			accept = haxe.crypto.BaseCode.encode(accept,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/");

			heads.add("Sec-WebSocket-Accept: "+accept+"=");
		}

		var k = null;
		for( h in outputHeaders ){
			switch( h.code ){
			case CHeaderKey: k = h.str;
			case CHeaderValue,CHeaderAddValue:
				if( k != null )
					heads.add(k+": "+h.str);
			default:
			}
		}

		sendHeads( heads );
	}

	inline function sendHeads( l : List<String> ){
		sendData( l.join("\r\n") + "\r\n\r\n" );
	}

	function sendData(str){
		var o = sock.output;
		if( needClose ) return;
		if( writeLock != null ) {
			writeLock.acquire();
			if( needClose ) {
				writeLock.release();
				return;
			}
			try {
				o.writeString( str );
			} catch( e : Dynamic ) {
				writeLock.release();
				neko.Lib.rethrow(e);
			}
			writeLock.release();
		} else {
			o.writeString( str );
		}
	}

	function send( s : String, ?opcode = 1 ){
		var d = new haxe.io.BytesOutput();
		d.writeByte(128|(opcode&15));
		var l = s.length;
		if( l > 0xFFFF )
			throw "Unsupported data length";
		if( l > 125 ){
			d.writeByte(126);
			d.writeByte(l>>>8);
			d.writeByte(l&0xFF);
		}else{
			d.writeByte(s.length);
		}
		if( s.length > 0 )
			d.writeString(s);

		sendData(neko.Lib.stringReference(d.getBytes()));
	}

	override function sendMessage( code : Code, msg : String ){
		switch( code ){
		case CPrint: send(msg);
		case CError: 
			send("Uncaught exception: "+msg);
		case CListen:
		default:
			throw "Unexpected "+Std.string(code);
		}
	}

	// TODO no buffer allocation
	static function unmask( data : haxe.io.Bytes, mask : Int ){
		var r = new haxe.io.BytesOutput();
		var p = 0;
		
		var l = data.length;
		var f = 4-l%4;
		if( f != 0 ){
			var d = haxe.io.Bytes.alloc(l+f);
			d.blit(0,data,0,l);
			data = d;
			l = data.length;
		}
		var bi = new haxe.io.BytesInput(data);
		while( p < l ){
			r.writeInt32( bi.readInt32() ^ mask );
			p += 4;
		}
		return r.getBytes().sub(0,data.length-f);
	}

}
