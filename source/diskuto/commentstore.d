module diskuto.commentstore;

import diskuto.userstore;

import std.datetime : SysTime;
import vibe.data.serialization : byName, optional;

interface DiskutoCommentStore {
@safe:
	StoredComment.ID postComment(StoredComment comment);
	StoredComment getComment(StoredComment.ID comment);
	void setCommentStatus(StoredComment.ID id, StoredComment.Status status);
	void editComment(StoredComment.ID id, string new_text);
	void deleteComment(StoredComment.ID id);
	VoteDirection vote(StoredComment.ID id, StoredComment.UserID user, VoteDirection direction);
	uint getActiveCommentCount(string topic);
	void iterateAllComments(scope void delegate(ref StoredComment) del);
	void iterateCommentsForTopic(string topic, scope void delegate(ref StoredComment) del);
	void iterateLatestComments(scope void delegate(ref StoredComment) del);

	deprecated("Use VoteDirection instead.")
	final void vote(StoredComment.ID id, StoredComment.UserID user, int direction)
	{ vote(id, user, direction < 0 ? VoteDirection.down : VoteDirection.up); }
}

enum VoteDirection { none = 0, up = 1, down = -1 }

deprecated("Use DiskutoCommentStore instead.") alias DiskutoBackend = DiskutoCommentStore;

struct StoredComment {
	alias ID = string;
	alias UserID = StoredUser.ID;

	enum Status {
		active,
		disabled,
		awaitsModeration,
		spam,
		deleted
	}

	ID id;
	@byName CommentStatus status = CommentStatus.active;
	string topic;
	ID replyTo;
	UserID author;
	string clientAddress; // Client IP address
	string name;
	string email;
	string website;
	string text;
	@optional string moderatorComment;
	SysTime time;
	UserID[] upvotes;
	UserID[] downvotes;
}

deprecated("Use StoredComment.Status instead.")
alias CommentStatus = StoredComment.Status;;
