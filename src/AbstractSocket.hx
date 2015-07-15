#if !hxssl
typedef AbstractSocket = sys.net.Socket;
#else
typedef AbstractSocket = {
	var input(default,null) : haxe.io.Input;
	var output(default,null) : haxe.io.Output;
	var custom : Dynamic;
	function connect( host : sys.net.Host, port : Int ) : Void;
	function setTimeout( t : Float ) : Void;
	function write( str : String ) : Void;
	function close() : Void;
	function shutdown( read : Bool, write : Bool ) : Void;
	function peer() : { host: sys.net.Host};
	function setFastSend( b : Bool ) : Void;
	function bind( host: sys.net.Host, port: Int ) : Void;
	function listen( c : Int ) : Void;
	function accept() : AbstractSocket;
}
#end