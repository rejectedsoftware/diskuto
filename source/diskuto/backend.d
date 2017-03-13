module diskuto.backend;

import std.datetime : SysTime;

interface DiskutoBackend {
	StoredComment.ID postComment(StoredComment comment);
	void editComment(StoredComment.ID id, string new_text);
	void deleteComment(StoredComment.ID id);
	void upvote(StoredComment.ID id, StoredComment.UserID user);
	void downvote(StoredComment.ID id, StoredComment.UserID user);
	StoredComment[] getCommentsForTopic(string topic);
	StoredComment[] getLatestComments();
}

struct StoredComment {
	alias ID = string;
	alias UserID = string;
	ID id;
	string topic;
	ID replyTo;
	UserID userID;
	string name;
	string email;
	string website;
	string text;
	SysTime time;
	UserID[] upvotes;
	UserID[] downvotes;
}
