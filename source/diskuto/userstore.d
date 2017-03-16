module diskuto.userstore;

import std.typecons : Nullable;
import vibe.http.server : HTTPServerRequest;


interface DiskutoUserStore {
@safe nothrow:
	Nullable!StoredUser getLoggedInUser(HTTPServerRequest req);
	Nullable!StoredUser getUserForEmail(string email);

	/** Returns the role of a particular user for the given topic.

		Note that this method must accept unknown user IDs. Typical return
		values in this case are `UserRole.user` or `UserRole.banned` (to
		enable posting for registered users only).

		Params:
			user = ID of the user to query
			topic = The topic for which to query the role
	*/
	StoredUser.Role getUserRole(StoredUser.ID user, string topic);
}

struct StoredUser {
	enum Role {
		none,      /// not allowed to read or post
		reader,    /// can only read posts
		commenter, /// can only comment, but not vote
		member,    /// can comment and vote (default if no user store is defined)
		moderator  /// can also modify foreign comments
	}

	alias ID = string;

	ID id; // store specific ID prefixed with a store identifier (e.g. "userman-mongodb-12315235234")
	string name; // Display name
	string email; // e-mail address
	string website; // website URL
}

deprecated("Use StoredUser.Role instead.")
alias UserRole = StoredUser.Role;
