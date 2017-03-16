module diskuto.userstore;

import std.typecons : Nullable;
import vibe.http.server : HTTPServerRequest;


interface DiskutoUserStore {
@safe nothrow:
	Nullable!StoredUser getLoggedInUser(HTTPServerRequest req);
	Nullable!StoredUser getUserForEmail(string email);
}

struct StoredUser {
	alias ID = string;

	ID id; // store specific ID prefixed with a store identifier (e.g. "userman-mongodb-12315235234")
	string name; // Display name
	string email; // e-mail address
	string website; // website URL
	bool isModerator;
}
