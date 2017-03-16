module diskuto.backend;

import diskuto.userstore;

import std.datetime : SysTime;
import vibe.data.serialization : byName;

interface DiskutoBackend {
@safe:
	StoredComment.ID postComment(StoredComment comment);
	StoredComment getComment(StoredComment.ID comment);
	void setCommentStatus(StoredComment.ID id, CommentStatus status);
	void editComment(StoredComment.ID id, string new_text);
	void deleteComment(StoredComment.ID id);
	void upvote(StoredComment.ID id, StoredComment.UserID user);
	void downvote(StoredComment.ID id, StoredComment.UserID user);
	StoredComment[] getCommentsForTopic(string topic);
	StoredComment[] getLatestComments();
}

struct StoredComment {
	alias ID = string;
	alias UserID = StoredUser.ID;
	ID id;
	@byName CommentStatus status;
	string topic;
	ID replyTo;
	UserID author;
	string name;
	string email;
	string website;
	string text;
	SysTime time;
	UserID[] upvotes;
	UserID[] downvotes;
}

enum CommentStatus {
	active,
	disabled,
	awaitsModeration,
	spam,
	deleted
}
