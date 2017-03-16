module diskuto.backend;

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
	void upvote(StoredComment.ID id, StoredComment.UserID user);
	void downvote(StoredComment.ID id, StoredComment.UserID user);
	uint getActiveCommentCount(string topic);
	StoredComment[] getCommentsForTopic(string topic);
	StoredComment[] getLatestComments();
}

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
