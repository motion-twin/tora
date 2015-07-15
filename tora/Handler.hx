package tora;

class Handler<T> {

	public function new() {
	}
	
	public function onNotify( msg : T ) {
	}
	
	public function onStop() {
	}
	
	public function sendData( d : String ) {
		Sys.print(d);
	}

	function unserialize( nstr : neko.NativeString ) : Dynamic {
		return haxe.Unserializer.run( neko.NativeString.toString(nstr) );
	}
	
}
