/* ************************************************************************ */
/*																			*/
/*  Tora - Neko Application Server											*/
/*  Copyright (c)2008 Motion-Twin											*/
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
package tora;

class Queue<T> {

	var q : Dynamic;
	public var name(default,null) : String;

	function new() {
	}

	public function addHandler( h : Handler<T> ) {
		queue_add_handler(q,h);
	}

	public function notify( message : T ) {
		queue_smart_notify(q,message,serialize);
	}

	public function count() : Int {
		return queue_count(q);
	}

	public function stop() : Void {
		queue_stop(q);
	}

	function serialize( d : T ){
		return neko.NativeString.ofString(haxe.Serializer.run(d));
	}

	public function redisConnect( host : String, port : Int ){
		queue_redis_subscribe( q, neko.NativeString.ofString(host), port );
	}
	
	public static function get<T>( name ) : Queue<T> {
		if( queue_init == null ) {
			queue_init = neko.Lib.load(Api.lib,"queue_init",1);
			queue_add_handler = neko.Lib.load(Api.lib,"queue_add_handler",2);
			queue_smart_notify = neko.Lib.load(Api.lib,"queue_smart_notify",3);
			queue_count = neko.Lib.load(Api.lib,"queue_count",1);
			queue_stop = neko.Lib.load(Api.lib, "queue_stop", 1);
			queue_redis_subscribe = neko.Lib.load(Api.lib, "queue_redis_subscribe", 3);
		}
		var q = new Queue();
		q.name = name;
		q.q = queue_init(untyped name.__s);
		return q;
	}

	static var queue_init;
	static var queue_add_handler;
	static var queue_smart_notify;
	static var queue_count;
	static var queue_stop;
	static var queue_redis_subscribe;
}
